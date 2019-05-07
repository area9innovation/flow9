#ifndef NATIVEFUNCTION_H
#define NATIVEFUNCTION_H

#include <stdlib.h>
#include "CommonTypes.h"

#ifdef _MSC_VER
#define __INLINE_WRAP(content) __forceinline content
#else
#define __INLINE_WRAP(content) content __attribute__((always_inline))
#endif

class ByteCodeRunner;
class GarbageCollector;
class HeapWalker;
class FlowNativeObject;

struct LocalRootRecord;

/*
 * Interface for exposing native object fields to GC and heap walkers.
 */

struct GarbageCollectorFnCallback {
    virtual ~GarbageCollectorFnCallback() {}
    virtual void Process(StackSlot &obj) = 0;
    virtual void Process(FlowNativeObject *obj) = 0;
    virtual void ProcessVector(StackSlot *start, unsigned size) {
        for (unsigned i = 0; i < size; i++)
            Process(start[i]);
    }

protected:
    void ProcessLocalRoots(LocalRootRecord *root);
};

class GarbageCollectorFn {
    GarbageCollectorFnCallback *gc;

public:
    GarbageCollectorFn(GarbageCollectorFnCallback *gc) : gc(gc) {}
    GarbageCollectorFn(const GarbageCollectorFn &gcf) : gc(gcf.gc) {}

    void operator() (StackSlot &obj) const { gc->Process(obj); }
    void operator() (FlowNativeObject *obj) const { gc->Process(obj); }
    void operator() (StackSlot *start, unsigned size) const { gc->ProcessVector(start,size); }
};

inline GarbageCollectorFn operator<< (GarbageCollectorFn fn, int) { return fn; }
inline GarbageCollectorFn operator<< (GarbageCollectorFn fn, double) { return fn; }
inline GarbageCollectorFn operator<< (GarbageCollectorFn fn, const char*) { return fn; }
inline GarbageCollectorFn operator<< (GarbageCollectorFn fn, const std::string&) { return fn; }
inline GarbageCollectorFn operator<< (GarbageCollectorFn fn, const unicode_string&) { return fn; }

inline GarbageCollectorFn operator<< (GarbageCollectorFn fn, StackSlot &obj) { fn(obj); return fn; }
inline GarbageCollectorFn operator<< (GarbageCollectorFn fn, FlowNativeObject *obj) { fn(obj); return fn; }

template<class V1, class V2>
inline GarbageCollectorFn operator<< (GarbageCollectorFn fn, const std::pair<V1,V2> &obj) {
    fn << obj.first << obj.second; return fn;
}

template<class V1, class V2>
inline GarbageCollectorFn operator<< (GarbageCollectorFn fn, std::pair<V1,V2> &obj) {
    fn << obj.first << obj.second; return fn;
}

template<class T>
typename enable_if<has_typedef_iterator<T>,GarbageCollectorFn>::type operator<< (GarbageCollectorFn fn, T &obj) {
    for (typename T::iterator it = obj.begin(); it != obj.end(); ++it)
        fn << *it;
    return fn;
}

/*
 * Implementation of Local Root tracking; used via macros in RunnerMacros.h
 */

struct StackSlot;

class NativeRootCallback {
protected:
    friend class GarbageCollector;
    friend struct GarbageCollectorFnCallback;
    virtual void flowGCObject(GarbageCollectorFn) = 0;
public:
    virtual ~NativeRootCallback() {}
};

struct LocalRootRecord {
    LocalRootRecord *next;
    short type; // 0: roots, 1: root_arr, 2: cb
    short count;
    union {
        StackSlot **roots;
        StackSlot *root_arr;
        NativeRootCallback *cb;
    };
};

class LocalRootHost {
protected:
    friend class GarbageCollector;
    friend class LocalRootDefinitionBase;
    LocalRootRecord *LocalRootStack;
public:
    LocalRootHost() : LocalRootStack(NULL) {}
};

class LocalRootDefinitionBase : public LocalRootRecord {
    LocalRootHost *host;
public:
    LocalRootDefinitionBase(LocalRootHost *h, short t, short c) : host(h) {
        next = host->LocalRootStack;
        type = t; count = c;
        host->LocalRootStack = this;
    }
    ~LocalRootDefinitionBase() {
        host->LocalRootStack = next;
    }
};

class LocalRootDefinition : public LocalRootDefinitionBase {
public:
    LocalRootDefinition(LocalRootHost *h, int ncount, StackSlot **nroots)
        : LocalRootDefinitionBase(h, 0, ncount) { roots = nroots; }
    LocalRootDefinition(LocalRootHost *h, int ncount, StackSlot *nroots)
        : LocalRootDefinitionBase(h, 1, ncount) { root_arr = nroots; }
};

template<class T>
class LocalNativeRootDefinition : public LocalRootDefinitionBase, NativeRootCallback
{
    T &obj;
protected:
    virtual void flowGCObject(GarbageCollectorFn ref) { ref << obj; }
public:
    LocalNativeRootDefinition(LocalRootHost *h, T &obj)
        : LocalRootDefinitionBase(h, 2, 0), obj(obj) { cb = this; }
};

/*
 * Native method tracking.
 */

typedef StackSlot (*NativeFunctionPtr)(ByteCodeRunner*,StackSlot*);

class NativeFunction
{
    friend class ByteCodeRunner;
    friend class FlowJitProgram;
    const char *name_;
    int num_args_;

    // Function to call, or a helper thunk in case of method natives.
    // The goal here is to avoid any overhead in calls to SimpleNative
    // objects, and allow call branch prediction for them.
    NativeFunctionPtr func_;

    FlowPtr debug_token_;

protected:
    NativeFunction(const char *name, int num_args, NativeFunctionPtr func)
        : name_(name), num_args_(num_args), func_(func), debug_token_(MakeFlowPtr(0)) {}

    inline static NativeFunction *get_self(ByteCodeRunner*);

public:
    const char *name() const { return name_; }
    int num_args() const { return num_args_; }
    FlowPtr debug_token() const { return debug_token_; }

    virtual ~NativeFunction() {}
};

/*
 * Provider of native methods to a ByteCodeRunner instance.
 */
class NativeMethodHost
{
    friend class ByteCodeRunner;
    ByteCodeRunner *owner;

public:
    enum HostEvent {
        HostEventError,
        HostEventTimer,
        HostEventUserAction,
        HostEventResourceLoad,
        HostEventRunDeferredActions,
        HostEventNetworkIO,
        HostEventMedia,
        HostEventDeferredActionTimeout
    };

protected:
    // Returns the requested native method if supported.
    virtual NativeFunction *MakeNativeFunction(const char * /*name*/, int /*num_args*/) { return NULL; }

    // Called on runner reset or destruction
    virtual void OnRunnerReset(bool inDestructor) {
        if (inDestructor) owner = NULL;
    }

    // Called on various events via ByteCodeRunner::NotifyHostEvent
    virtual void OnHostEvent(HostEvent) {};

    // Adds tokens to the target description produced by getTargetName
    virtual void GetTargetTokens(std::set<std::string>&) {};

    // Called by GC to query for roots owned by the host
    friend class GarbageCollector;
    friend class HeapWalker;
    virtual void flowGCObject(GarbageCollectorFn) {}

public:
    NativeMethodHost(ByteCodeRunner *owner);
    virtual ~NativeMethodHost();

    ByteCodeRunner *getFlowRunner() const { return owner; }
};

/*
 * Native implemented by a simple function or static method.
 */

#define NATIVE_NAME_PREFIX ""

class SimpleNative : public NativeFunction
{
public:
    SimpleNative(const char *name, int num_args, NativeFunctionPtr func)
        : NativeFunction(name, num_args, func) {}
};

#define NATIVE_NAME_MATCHES(string_name, num_method_args) \
    (strcmp(name, NATIVE_NAME_PREFIX string_name) == 0 && num_args == num_method_args)

// The native function is a static method of the host
#define TRY_USE_NATIVE_STATIC_NAME(class_name, method_name, string_name, num_method_args) \
    if (NATIVE_NAME_MATCHES(string_name, num_method_args)) \
        return new SimpleNative(NATIVE_NAME_PREFIX string_name, num_method_args, &class_name::method_name);

#define TRY_USE_NATIVE_STATIC(class_name, method_name, num_method_args) \
    TRY_USE_NATIVE_STATIC_NAME(class_name, method_name, #method_name, num_method_args)

/*
 * Native implemented by a method of a global object, e.g. a native method host.
 */

template<class T>
class MethodNative : public NativeFunction
{
    typedef StackSlot (T::*NativeMethodPtr)(ByteCodeRunner*,StackSlot*);

public:
    MethodNative(const char *name, int num_args, T *host, NativeMethodPtr func)
        : NativeFunction(name, num_args, thunk), Host(host), Func(func) {}

private:
    T *Host;
    NativeMethodPtr Func;
    static StackSlot thunk(ByteCodeRunner *runner, StackSlot *args);
};

#define DECLARE_NATIVE_METHOD(name) StackSlot name(ByteCodeRunner*,StackSlot*);

// The native function is a normal method of the host
#define TRY_USE_NATIVE_METHOD_NAME(class_name, method_name, string_name, num_method_args) \
    if (NATIVE_NAME_MATCHES(string_name, num_method_args)) \
        return new MethodNative<class_name>(NATIVE_NAME_PREFIX string_name, num_method_args, this, &class_name::method_name);

#define TRY_USE_NATIVE_METHOD(class_name, method_name, num_method_args) \
    TRY_USE_NATIVE_METHOD_NAME(class_name, method_name, #method_name, num_method_args)

/*
 * Native implemented by a method of a FlowNativeObject.
 * The object instance becomes the first argument to the native.
 */

template<class T>
class ObjectMethodNative : public NativeFunction
{
    typedef StackSlot (T::*NativeMethodPtr)(ByteCodeRunner*,StackSlot*);

public:
    ObjectMethodNative(const char *name, int num_args, NativeMethodPtr func)
        : NativeFunction(name, num_args, thunk), Func(func) {}

private:
    NativeMethodPtr Func;
    static StackSlot thunk(ByteCodeRunner *runner, StackSlot *args);
};

// The native function is a normal method of the native object passed as first argument.
#define TRY_USE_OBJECT_METHOD_NAME(class_name, method_name, string_name, num_method_args) \
    if (NATIVE_NAME_MATCHES(string_name, num_method_args)) \
        return new ObjectMethodNative<class_name>(NATIVE_NAME_PREFIX string_name, num_method_args, &class_name::method_name);

#define TRY_USE_OBJECT_METHOD(class_name, method_name, num_method_args) \
    TRY_USE_OBJECT_METHOD_NAME(class_name, method_name, #method_name, num_method_args)

/*
 * Native that wraps some native data - rarely used.
 */

typedef StackSlot (*NativeClosurePtr)(ByteCodeRunner*, StackSlot*, void *data);

class NativeClosure : public NativeFunction
{
public:
    NativeClosure(const char *name, int num_args, NativeClosurePtr func, void *data)
        : NativeFunction(name, num_args, thunk), Clos(func), data(data) {}
private:
    NativeClosurePtr Clos;   
    void *data;
    static StackSlot thunk(ByteCodeRunner *runner, StackSlot *args);
};

/*
 * Stub for a native that is not implemented.
 */

class StubNative : public NativeFunction
{
    static StackSlot thunk(ByteCodeRunner *runner, StackSlot *args);
public:
    // Reports usage of an unimplemented function, and returns Void
    StubNative(const char *name, int num_args) : NativeFunction(name, num_args, thunk) {}
};

// Native value wrappers

class FlowNativeValueType;

/*
 * Objects that are aware of and designed to interact with
 * the flow runner, and be controlled by its GC.
 *
 * Note that the object is owned by GC only after its StackSlot
 * value is created via getFlowValue() or other methods.
 */

class FlowNativeObjectBase {
    // is_base_of<A,B> only works if A != B
};

class FlowNativeObject : private FlowNativeObjectBase {
    friend class FlowNativeValueType;
    ByteCodeRunner *owner;
    T_GC_Tag id_tag;
    StackSlot id_slot;

    void autoRegisterValue() const;

protected:
    // Called by GC to query for flow references in fields
    friend class GarbageCollector;
    friend class HeapWalker;
    virtual void flowGCObject(GarbageCollectorFn) {}

    // Called by GC before native objects that became garbage are deleted
    friend class ByteCodeRunner;
    virtual void flowFinalizeObject() {}

    // Called by the DeleteNative native. Return true if the object can be immediately deleted.
    virtual bool flowDestroyObject() { return false; }

public:
    FlowNativeObject(ByteCodeRunner *owner) : owner(owner) {
        id_tag = 0;
        StackSlot::SetVoid(id_slot);
    }
    virtual ~FlowNativeObject();

    ByteCodeRunner *getFlowRunner() const { return owner; }

    __INLINE_WRAP(const StackSlot &getFlowValue() const) {
        if (unlikely(!id_slot.IsNative())) autoRegisterValue();
        return id_slot;
    }
    virtual FlowNativeValueType *getFlowValueType() const = 0;
};

/* Fully abstract native values */

class AbstractNativeValue;

class NativeValueTypeBase {
    friend class AbstractNativeValue;
    const char *name_str;
    NativeValueTypeBase *parent_obj;
protected:
    virtual void ReferenceValue(ByteCodeRunner *runner, AbstractNativeValue *wrapper) = 0;
    virtual void DereferenceValue(ByteCodeRunner *runner, AbstractNativeValue *wrapper) = 0;
public:
    NativeValueTypeBase(const char *name_str, NativeValueTypeBase *parent = NULL)
        : name_str(name_str), parent_obj(parent) {}
    virtual ~NativeValueTypeBase() {}

    const char *name() const { return name_str; }
    NativeValueTypeBase *parent() const { return parent_obj; }
};

class AbstractNativeValue {
    friend class ByteCodeRunner;
    friend class GarbageCollector;
    StackSlot id_slot;
    ByteCodeRunner *owner;
    NativeValueTypeBase *type_tag;
protected:
    FlowNativeObject *object;
protected:
    void registerSelf(const StackSlot &name) {
        id_slot = name;
        type_tag->ReferenceValue(owner, this);
    }
    void deregisterSelf() {
        if (!id_slot.IsVoid())
            type_tag->DereferenceValue(owner, this);
    }
protected:
    AbstractNativeValue(ByteCodeRunner *owner, NativeValueTypeBase *type_tag, FlowNativeObject *object = NULL)
        : owner(owner), type_tag(type_tag), object(object) {
        StackSlot::SetVoid(id_slot);
    }
public:
    virtual ~AbstractNativeValue() {}

    const StackSlot &id() const { return id_slot; }
    NativeValueTypeBase *type() const { return type_tag; }
    FlowNativeObject *nativeObject() const { return object; }
};

/* Templated wrappers for concrete native values */

#define IS_FLOW_NATIVE_OBJ_PTR(T) \
    flow_is_base_of<FlowNativeObjectBase,typename pointer_base_of<T>::type>::value

template<class T, bool is_native = IS_FLOW_NATIVE_OBJ_PTR(T)>
class NativeValueType {};

template<class T>
class NativeValueType<T,false> : public NativeValueTypeBase {
public:
    typedef void (*AccounterCallback)(ByteCodeRunner *owner, T &value_ref);
private:
    AccounterCallback *reference_cb;
    AccounterCallback *dereference_cb;
protected:
    virtual void ReferenceValue(ByteCodeRunner *runner, AbstractNativeValue *wrapper);
    virtual void DereferenceValue(ByteCodeRunner *runner, AbstractNativeValue *wrapper);
public:
    static NativeValueType<T,false> Tag;
    NativeValueType(const char *name_str, AccounterCallback *reference_cb = NULL, AccounterCallback *dereference_cb = NULL)
        : NativeValueTypeBase(name_str), reference_cb(reference_cb), dereference_cb(dereference_cb) {}
};

#define IMPLEMENT_NATIVE_VALUE_TYPE(name) \
    template<> NativeValueType<name,false> NativeValueType<name,false>::Tag(#name);

#define FLOW_VALUE_TYPE(name) (&NativeValueType<name>::Tag)

template<class T, bool is_native = IS_FLOW_NATIVE_OBJ_PTR(T)>
class NativeValue {};

template<class T>
class NativeValue<T,false> : public AbstractNativeValue {
private:
    T value;
public:
    NativeValue(ByteCodeRunner *owner, const T &value)
        : AbstractNativeValue(owner, FLOW_VALUE_TYPE(T)), value(value) {}
    ~NativeValue() { deregisterSelf(); }
    T &getValue() { return value; }
};

template<class T>
void NativeValueType<T,false>::ReferenceValue(ByteCodeRunner *runner, AbstractNativeValue *wrapper) {
    if (reference_cb) (*reference_cb)(runner, static_cast<NativeValue<T>*>(wrapper)->getValue());
}
template<class T>
void NativeValueType<T,false>::DereferenceValue(ByteCodeRunner *runner, AbstractNativeValue *wrapper) {
    if (dereference_cb) (*dereference_cb)(runner, static_cast<NativeValue<T>*>(wrapper)->getValue());
}

/* Abstract flow-aware native values (FlowNativeObject*) */

class FlowNativeValue;

class FlowNativeValueType : public NativeValueTypeBase {
protected:
    friend class FlowNativeObject;
    virtual void ReferenceValue(ByteCodeRunner *runner, AbstractNativeValue *wrapper);
    virtual void DereferenceValue(ByteCodeRunner *runner, AbstractNativeValue *wrapper);
    virtual FlowNativeValue *WrapNativePointer(ByteCodeRunner *owner, FlowNativeObject *object) = 0;
public:
    FlowNativeValueType(const char *name_str, NativeValueTypeBase *parent)
        : NativeValueTypeBase(name_str, parent) {}
};

class FlowNativeValue : public AbstractNativeValue {
public:
    FlowNativeValue(ByteCodeRunner *owner, FlowNativeValueType *type_tag, FlowNativeObject *object)
        : AbstractNativeValue(owner, type_tag, object) {}
    virtual ~FlowNativeValue() { deregisterSelf(); }
    FlowNativeObject *getValue() { return nativeObject(); }
};

/* Templated concrete wrappers for flow-aware natives */

#define ENABLE_IF_FLOW_NOBJ(T,tname) typename enable_if<flow_is_base_of<FlowNativeObjectBase,T>,tname>::type
#define ENABLE_IF_FLOW_NOBJ_PTR(T,tname) ENABLE_IF_FLOW_NOBJ(typename pointer_base_of<T>::type,tname)
#define DISABLE_IF_FLOW_NOBJ(T,tname) typename disable_if<flow_is_base_of<FlowNativeObjectBase,T>,tname>::type
#define DISABLE_IF_FLOW_NOBJ_PTR(T,tname) DISABLE_IF_FLOW_NOBJ(typename pointer_base_of<T>::type,tname)

template<class T>
class NativeValue<T*,true>
        : public FlowNativeValue
{
public:
    NativeValue(ByteCodeRunner *owner, T* value)
        : FlowNativeValue(owner, FLOW_VALUE_TYPE(T*), value) {}
    T *getValue() { return static_cast<T*>(object); }
};

template<class T>
class NativeValueType<T*, true>
        : public FlowNativeValueType
{
protected:
    virtual FlowNativeValue *WrapNativePointer(ByteCodeRunner *owner, FlowNativeObject *object) {
        return new NativeValue<T*,true>(owner, static_cast<T*>(object));
    }
public:
    static NativeValueType<T*,true> Tag;
    NativeValueType(const char *name_str, FlowNativeValueType *parent)
        : FlowNativeValueType(name_str, parent) {}
};

#define DEFINE_FLOW_NATIVE_OBJECT(name, parent) \
    virtual FlowNativeValueType *getFlowValueType() const;

#define IMPLEMENT_FLOW_NATIVE_OBJECT(name, parent) \
    template<> NativeValueType<name*,true> NativeValueType<name*,true>::Tag(#name "*", FLOW_VALUE_TYPE(parent*)); \
    FlowNativeValueType * name::getFlowValueType() const { return FLOW_VALUE_TYPE(name*); }


bool flow_instanceof(FlowNativeObject *obj, FlowNativeValueType *type);

template<class T>
bool flow_instanceof(FlowNativeObject *obj) {
    return obj && flow_instanceof(obj, &NativeValueType<T*>::Tag);
}

template<class T>
T *flow_native_cast(FlowNativeObject *obj) {
    return flow_instanceof<T>(obj) ? static_cast<T*>(obj) : NULL;
}

#endif // NATIVEFUNCTION_H
