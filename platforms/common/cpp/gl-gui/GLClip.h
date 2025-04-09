#ifndef GLCLIP_H
#define GLCLIP_H

#include "GLRenderSupport.h"
#include "GLUtils.h"

class GLGraphics;
class GLDrawSurface;
class GLScheduleNode;
class GLClipScheduleNode;

class GLFilter;

class GLClip : public FlowNativeObject
{
protected:
    GLRenderSupport *owner;

    typedef std::vector<GLClip*> T_Children;
    typedef std::map<int,StackSlot> T_Callbacks;
    typedef std::map<FlowEvent,std::set<int> > T_EventCallbacks;
    typedef std::vector<GLFilter*> T_Filters;
    typedef std::map<std::string, std::string> T_AcessibilityAttributes;

    // ROOTS:
    GLClip *parent;
    T_Children children;
    GLGraphics *graphics;
    GLClip *mask;
    GLClip *mask_owner;
    T_Callbacks callbacks;
    T_Filters filters;
    FlowStackSnapshot *stack;
    StackSlot fileDropDoneCallback;
#ifdef FLOW_DEBUGGER
    std::map<std::string, StackSlot> debug_info;
#endif
    
    T_AcessibilityAttributes accessibility_attributes;

    int destroy_lock;

    void flowGCObject(GarbageCollectorFn);
    bool flowDestroyObject();
    void flowFinalizeObject();

    friend class GLGraphics;
    friend class GLFilter;

    int next_cb_id;
    T_EventCallbacks event_callbacks;
    void addEventCallback(FlowEvent event, bool self);
    int addEventCallback(FlowEvent event, const StackSlot &cb);
    void removeEventCallback(FlowEvent event, int id);

    StackSlot addEventCallback(ByteCodeRunner*, FlowEvent event, const StackSlot &cb, const char *name);
    static StackSlot removeEventCallback_native(ByteCodeRunner*,StackSlot*, void *);
    static StackSlot removeFileDropListener_native(ByteCodeRunner*,StackSlot*, void *);

    std::string access_role;
    bool access_enabled;
    StackSlot access_callback;
    std::vector<int> clip_tab_index;
    unsigned state_flags;
    GLTransform local_transform;
    GLUnpackedTransform local_transform_raw;
    GLBoundingBox scroll_rect_box;
    float alpha;
    bool visible, renderable, scroll_rect, destroyed;
    vec2 size;
    mat3 global_transform_forward;

    // file drop properties
    int maxFilesDropable;
    std::string fileDropMimeTypeRegExFilter;

    GLBoundingBox local_bbox_self;
    GLBoundingBox local_bbox_full; // children + mask
    GLBoundingBox local_bbox_effect;

    GLTransform global_transform; // valid if UnchangedFromRender
    float global_alpha; // computed simultaneously to global_transform
    bool global_visible, global_renderable;

    GLBoundingBox global_bbox_self;
    GLBoundingBox global_bbox_full; // children + mask
    GLBoundingBox global_bbox_effect;

    shared_ptr<GLScheduleNode> schedule_node;

    virtual void computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform);
    virtual void renderInner(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box);

    void collectChildNodes(GLClipScheduleNode *parent);

    StackSlot getGlobalTransformArray();
public:
    /* Clip status flags. Used to reduce state recomputation. */
    enum StateFlags {
        // Global transform couldn't have changed.
        // Wiping implicitly passed down to children
        // during global transform recomputation.
        SelfUnchangedFromRender     = 0x1,
        // Self and subtree not changed.
        // Wiping implies global bbox recomputation.
        ChildrenUnchangedFromRender = 0x2,
        // local_transform computed from raw
        LocalTransformReady         = 0x4,
        // Topmost clip
        IsStageClipObject           = 0x8,
        // Self bbox computed from graphics
        LocalBBoxSelfReady          = 0x10,
        GlobalBBoxSelfReady         = 0x20,
        // Cumulative global bbox computed for rendering
        GlobalBBoxReady             = 0x40,
        // Listens to events (thus has to remove itself on finalize)
        ListensToEvents             = 0x80,
        // Is under cursor at the moment
        IsUnderMouseCursor         = 0x100,
        // Render schedule up to date
        ScheduleNodeReady          = 0x200,
        // Has a native widget overlay
        HasNativeWidget            = 0x400,
        NativeWidgetPosReady       = 0x800,
        // Render node may reuse a cached buffer
        ScheduleNodeCacheValid    = 0x1000,
        // Listens to mouseenter/mouseout events
        ListensToOverOutEvents         = 0x2000,
        LocalBBoxReady         = 0x4000
    };

    /* Multiple-flag groups for checks or mass wiping. */
    enum WipeMasks {
        // Nothing to recompute since render
        UnchangedFromRender
            = ChildrenUnchangedFromRender | SelfUnchangedFromRender,

        // A child or mask added or removed
        WipeChildChanged
            = ChildrenUnchangedFromRender
            | ScheduleNodeReady,
        // Parent changed => global transform might have.
        WipeParentChanged
            = ChildrenUnchangedFromRender | SelfUnchangedFromRender
            | ScheduleNodeReady,
        // Alpha changed => recompute global transform and alpha
        WipeAlphaChanged
            = ChildrenUnchangedFromRender | SelfUnchangedFromRender,
        // Local transform needs recomputation.
        WipeLocalTransformChanged
            = ChildrenUnchangedFromRender | SelfUnchangedFromRender
            | LocalTransformReady,
        // Graphics changed; bbox might have.
        WipeGraphicsChanged
            = ChildrenUnchangedFromRender
            | LocalBBoxSelfReady
            | GlobalBBoxSelfReady
            | NativeWidgetPosReady,
        // Global transform was just recomputed
        WipeGlobalTransformRecomputed
            = GlobalBBoxSelfReady
            | NativeWidgetPosReady,
        // Native widget was deleted or created
        WipeLoseNativeWidget
            = HasNativeWidget
            | NativeWidgetPosReady
            | ChildrenUnchangedFromRender,
        // Content appearance may have changed
        WipeContentMayHaveChanged
            = GlobalBBoxReady
            | LocalBBoxReady
            | ScheduleNodeCacheValid
    };

    GLClip(GLRenderSupport *owner, bool world_visible = false);

    DEFINE_FLOW_NATIVE_OBJECT(GLClip, FlowNativeObject)

    void lock() { destroy_lock++; }
    void unlock() { destroy_lock--; }
    bool isDestroyed() { return destroyed; }

    void setFlags(unsigned flags) { state_flags |= flags; }
    void wipeFlags(unsigned flags);
    bool checkFlag(unsigned flags) { return (state_flags & flags) == flags; }

    const GLTransform &getGlobalTransform() { return global_transform; }
    virtual const GLTransform &getLocalTransform();

    float getGlobalAlpha() { return global_visible && global_renderable && !destroyed ? global_alpha : 0.0f; }

    FlowStackSnapshot *getFlowStack() { return stack; }

    // Sets UnchangedFromRender
    void prepareRenderTransforms(const GLTransform &parent, bool force, float parent_alpha, bool parent_visible, bool parent_renderable);
    void prepareRenderTransforms() { prepareRenderTransforms(GLTransform(), false, 1.0f, true, true); }

    const GLBoundingBox &getGlobalBBox();
    const GLBoundingBox &getGlobalBBoxSelf();
    const GLBoundingBox &getLocalBBoxSelf();
    const GLBoundingBox &getLocalBBox();
    GLBoundingBox getGlobalMaskBBox();

    shared_ptr<GLScheduleNode> getScheduleNode();

    void render(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box, bool from_node = false);

    bool transformFromStage(vec3 *coord, bool verify_masks = false);
    bool isAttachedToStage() { return transformFromStage(NULL); }

    // Really only depend on owner:
    vec3 getStageMousePos();
    vec3 makeStageFromGlobal(vec2 global);
    vec3 makeStageCoords(vec2 stage);

    void dispatchAccessCallback();

    vec2 getLocalMousePos(bool *ok = NULL);

    bool accessFocusEnabled();

    std::string getAccessRole() { return access_role; }
    bool getAccessEnabled() { return access_enabled; }
    std::vector<int> getTabIndex() { return clip_tab_index; }
    virtual void invokeEventCallbacks(FlowEvent event, int num_args, StackSlot *args);

    // File Drop functionality
    int getFilesCountDroppable() { return maxFilesDropable; }
    std::string getFileDropMimeTypeRegExFilter() { return fileDropMimeTypeRegExFilter; }
    const StackSlot &getFileDropDoneCallback() { return fileDropDoneCallback; }

    void removeFileDropCallback();

    enum HitType {
        // Intersection contradicts predicate
        HitTransparent = -1,
        // No intersection with cursor
        HitNone = 0,
        // Cursor partly touches
        HitWeak = 1,
        // Cursor fully within the bounding box
        HitFull = 2
    };

    HitType computeHitSubtrees(vec3 pos, std::set<GLClip*> *lst, std::vector<GLClip*> *leaves);
    
    bool pointHitsSubtree(vec3 pos);

    void setGlobalScale(vec2 center, float factor, FlowScreenRotation rotation);

    virtual void setFocus(bool focus);
    void setAccessRole(std::string role);
    void setAccessEnabled(bool enabled);
    void setNodeIndex(std::vector<int> idx);
    
    GLClip *getParent() { return parent; }
    GLClip *getMask() { return mask; }
    GLClip *getMaskOwner() { return mask_owner; }
    GLGraphics *getGraphicsData() { return graphics; }

#ifdef FLOW_DEBUGGER
    const std::map<std::string,StackSlot> &getDebugInfo() { return debug_info; }
#endif

    bool isVisible() { return visible; }
    void setVisible(bool state);
    void setRenderable(bool state);

    const T_Filters &getFilters() { return filters; }
    const T_Children & getChildren() { return children; }
    const T_AcessibilityAttributes & getAccessibilityAttributes() { return accessibility_attributes; }

    void addChild(GLClip *pchild);
    void addChildAt(GLClip *pchild, int id);
    T_Children removeChildren();

public:
    DECLARE_NATIVE_METHOD(addChild)
    DECLARE_NATIVE_METHOD(addChildAt)
    DECLARE_NATIVE_METHOD(removeChild)
    DECLARE_NATIVE_METHOD(getClipChildren)

    DECLARE_NATIVE_METHOD(getGraphics)

    DECLARE_NATIVE_METHOD(setClipMask)

    DECLARE_NATIVE_METHOD(setClipX)
    DECLARE_NATIVE_METHOD(setClipY)
    DECLARE_NATIVE_METHOD(setClipScaleX)
    DECLARE_NATIVE_METHOD(setClipScaleY)
    DECLARE_NATIVE_METHOD(setClipRotation)
    DECLARE_NATIVE_METHOD(setClipOrigin)
    DECLARE_NATIVE_METHOD(setClipAlpha)
    DECLARE_NATIVE_METHOD(setClipVisible)
    DECLARE_NATIVE_METHOD(setClipRenderable)
    DECLARE_NATIVE_METHOD(getClipVisible)

    DECLARE_NATIVE_METHOD(setClipCallstack)
    DECLARE_NATIVE_METHOD(setClipDebugInfo)

    DECLARE_NATIVE_METHOD(addEventListener)
    DECLARE_NATIVE_METHOD(emitMouseEvent)
    DECLARE_NATIVE_METHOD(emitKeyEvent)
    DECLARE_NATIVE_METHOD(addKeyEventListener)
    DECLARE_NATIVE_METHOD(addMouseWheelEventListener)
    DECLARE_NATIVE_METHOD(addFinegrainMouseWheelEventListener)
    DECLARE_NATIVE_METHOD(addFileDropListener)

    DECLARE_NATIVE_METHOD(getMouseX)
    DECLARE_NATIVE_METHOD(getMouseY)
    DECLARE_NATIVE_METHOD(hittest)
    DECLARE_NATIVE_METHOD(getTouchPoints)

    DECLARE_NATIVE_METHOD(setFocus)
    DECLARE_NATIVE_METHOD(getFocus)

    DECLARE_NATIVE_METHOD(addFilters)

    DECLARE_NATIVE_METHOD(setAccessAttributes)
    DECLARE_NATIVE_METHOD(setAccessCallback)

    DECLARE_NATIVE_METHOD(setScrollRect)

    DECLARE_NATIVE_METHOD(setTabIndex)
    
    DECLARE_NATIVE_METHOD(getGlobalTransform)

    DECLARE_NATIVE_METHOD(setFullWindowTarget)
    
public:
    template<class Predicate, class Action, class PredicatableAction>
    HitType computeHitSubtreesOrdered(
            vec3 pos, std::set<GLClip*> *out,
            std::vector<GLClip*> *leaves,
            Predicate predicate,
            Action action,
            PredicatableAction predicatableAction) {
        if (local_transform_raw.isZeroScale() || !global_visible)
            return HitNone;
        
        HitType hit = HitNone;
        float radius = owner->MouseRadius;
        
        // Check local hit
        if (getLocalBBoxSelf().contains(pos, -radius))
            hit = HitFull;
        else if (radius > 0 && getLocalBBoxSelf().contains(pos, radius))
            hit = HitWeak;
        
        if (hit && !predicate(this))
            hit = HitTransparent;
        
        if (hit) {
            if (leaves)
                leaves->push_back(this);
            
            if (!out)
                return hit;
        }
        
        // Walk children right-to-left (i.e. z order top to bottom)
        for (int i = children.size() - 1; i >= 0; --i) {
            GLClip *child = children[i];
            
            if (child->mask_owner)
                continue;
            
            if (child->mask) {
                vec3 mpos = pos / child->mask->getLocalTransform();
                if (!child->mask->pointHitsSubtree(mpos))
                    continue;
            }
            
            vec3 cpos = pos / child->getLocalTransform();
            
            if (child->scroll_rect && !child->scroll_rect_box.contains(cpos))
                continue;
            
            HitType c_hit = child->computeHitSubtreesOrdered(cpos, out, leaves, predicate, action, predicatableAction);
            
            if (c_hit == HitTransparent) {
                if (predicate(this))
                    c_hit = HitFull;
                else
                    hit = c_hit;
            }
            
            if (c_hit) {
                if (!out)
                    return c_hit;
                
                if (c_hit > hit)
                    hit = c_hit;
                
                if (c_hit == HitFull)
                    break;
            }
        }
        
        if (((hit && out) || hit == HitTransparent) && predicate(this)) {
            out->insert(this);
            action(this);
        }
        
        if (predicate(this)) {
            predicatableAction(this, hit);
        }
        
        return hit;
        
    }
};

#endif // GLCLIP_H
