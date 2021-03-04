#include "GLClip.h"
#include "GLGraphics.h"
#include "GLFilter.h"

#include "GLSchedule.h"

#define _USE_MATH_DEFINES
#include <cmath>
#include <sstream>
using namespace std;

#include "core/GarbageCollector.h"
#include "core/RunnerMacros.h"

#define FIX_NAN_VALUE(var,defval,name) \
    if (isnan(var) || isinf(var)) { \
        RUNNER->flow_err << "NaN or Inf in " name << std::endl; \
        var = defval; \
    }

IMPLEMENT_FLOW_NATIVE_OBJECT(GLClip, FlowNativeObject);

GLClip::GLClip(GLRenderSupport *owner_, bool world_visible) :
    FlowNativeObject(owner_->getFlowRunner()), owner(owner_)
{
    parent = NULL;
    graphics = NULL;
    mask = mask_owner = NULL;
    next_cb_id = 0;
    state_flags = 0;
    stack = NULL;
    destroy_lock = 0;
    access_role = "";
    access_enabled = true;
    access_callback = StackSlot::MakeVoid();

    fileDropDoneCallback = StackSlot::MakeVoid();

    global_alpha = alpha = 1.0f;

    global_visible = visible = renderable = true;
    global_renderable = world_visible;
    scroll_rect = destroyed = false;

    scroll_rect_box.min_pt = vec2(0.0f);
    size = vec2(-1.0f);
    global_transform_forward = mat3(-1.0f);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost*10, 110);
#endif
}

void GLClip::flowGCObject(GarbageCollectorFn ref)
{
    ref << parent << children
        << graphics << filters
        << mask << mask_owner
        << callbacks
        << fileDropDoneCallback
        << access_callback
        << stack;
#ifdef FLOW_DEBUGGER
    ref << debug_info;
#endif
}

bool GLClip::flowDestroyObject()
{
    // Forbid manual delete of some objects that are busy or too complicated
    if (destroy_lock > 0 || checkFlag(IsStageClipObject) || checkFlag(HasNativeWidget))
        return false;

    destroyed = true;

    // Remove local links
    if (parent) {
        eraseItem(parent->children, this);
        parent->wipeFlags(WipeChildChanged);
    }

    parent = NULL;

    for (size_t i = 0; i < children.size(); i++) {
        children[i]->parent = NULL;
        children[i]->wipeFlags(WipeParentChanged);
    }

    children.clear();

    if (mask)
        mask->mask_owner = NULL;

    if (mask_owner) {
        mask_owner->mask = NULL;
        mask_owner->wipeFlags(WipeChildChanged);
    }

    mask = mask_owner = NULL;

    if (graphics)
        getFlowRunner()->DeleteNative(graphics);

    // Remove global links
    owner->PressedClips.erase(this);
    owner->HoveredClips.erase(this);

    if (owner->DebugHighlightClip == this)
        owner->DebugHighlightClip = NULL;

    if ((GLClip*)(owner->PressTextFocus) == this)
        owner->PressTextFocus = NULL;

    if ((GLClip*)(owner->CurrentFocus) == this)
        owner->CurrentFocus = NULL;

    owner->tabIndexedClips.erase(this);

    return true;
}

void GLClip::flowFinalizeObject()
{
    // Remove the weak references
    if (checkFlag(ListensToEvents))
        owner->removeEventListener(this);

    for (size_t i = 0; i < filters.size(); i++)
        eraseItem(filters[i]->clips, this);
}

void GLClip::wipeFlags(unsigned flags)
{
    static const unsigned parent_propagated
        = ChildrenUnchangedFromRender | ScheduleNodeReady;

    unsigned old = state_flags & flags;
    state_flags &= ~flags;

    unsigned toParent = old & parent_propagated;
    if (toParent != 0) {
        if (parent)
            parent->wipeFlags(toParent);
        if (mask_owner)
            mask_owner->wipeFlags(toParent);
    }
}

const GLTransform &GLClip::getLocalTransform()
{
    if (!checkFlag(LocalTransformReady)) {
        setFlags(LocalTransformReady);
        if (local_transform_raw.ox != 0 || local_transform_raw.oy != 0) {
            local_transform = local_transform_raw.toMatrixForm(getLocalBBox().size().x, getLocalBBox().size().y);
        } else {
            local_transform = local_transform_raw.toMatrixForm();
        }

    }

    return local_transform;
}

void GLClip::setGlobalScale(vec2 center, float factor, FlowScreenRotation rotation)
{
    assert(checkFlag(IsStageClipObject));

    vec2 wcenter = vec2(owner->Width, owner->Height) * (vec2(0.5f) - factor * center);

    local_transform_raw.sx = local_transform_raw.sy = factor;

    switch (rotation) {
    case FlowRotation0:
        local_transform_raw.angle = 0.0f;
        local_transform_raw.x = wcenter.x;
        local_transform_raw.y = wcenter.y;
        break;

    case FlowRotation90:
        local_transform_raw.angle = 90.0f;
        local_transform_raw.x = owner->RealWidth - wcenter.y;
        local_transform_raw.y = wcenter.x;
        break;

    case FlowRotation180:
        local_transform_raw.angle = 180.0f;
        local_transform_raw.x = owner->RealWidth - wcenter.x;
        local_transform_raw.y = owner->RealHeight - wcenter.y;
        break;

    case FlowRotation270:
        local_transform_raw.angle = 270.0f;
        local_transform_raw.x = wcenter.y;
        local_transform_raw.y = owner->RealHeight - wcenter.x;
        break;
    }

    wipeFlags(WipeLocalTransformChanged);
}

void GLClip::prepareRenderTransforms(const GLTransform &parent, bool force, float parent_alpha, bool parent_visible, bool parent_renderable)
{
    // Force means that one of the parents might have a changed transform
    if (!force && checkFlag(UnchangedFromRender)) {
        return;
    }

    if (!checkFlag(SelfUnchangedFromRender)) {
        force = true;
    }

    // Reset readiness; require bbox recomputation
    if (force || !checkFlag(ChildrenUnchangedFromRender)) {
        wipeFlags(WipeContentMayHaveChanged);
    }
    setFlags(UnchangedFromRender);

    // Transform might have changed
    if (force) {
        global_transform = parent * getLocalTransform();
        invokeEventCallbacks(FlowTransformChange, 0, NULL);
        global_alpha = parent_alpha * alpha;
        global_visible = parent_visible && visible;
        global_renderable = parent_renderable && renderable;
        wipeFlags(WipeGlobalTransformRecomputed);
    }

    // Recurse into children
    for (T_Children::iterator it = children.begin(); it != children.end(); ++it)
        (*it)->prepareRenderTransforms(global_transform, force, global_alpha, global_visible, global_renderable);
}

const GLBoundingBox &GLClip::getGlobalBBoxSelf()
{
    if (!checkFlag(GlobalBBoxSelfReady) && renderable && !destroyed) {
        global_bbox_self.clear();
        computeBBoxSelf(global_bbox_self, global_transform);
        setFlags(GlobalBBoxSelfReady);
    }

    return global_bbox_self;
}

const GLBoundingBox &GLClip::getGlobalBBox()
{
    if (!checkFlag(GlobalBBoxReady) && renderable && !destroyed) {
        // Local bbox
        global_bbox_full = getGlobalBBoxSelf();

        // + children
        for (T_Children::iterator it = children.begin(); it != children.end(); ++it)
            global_bbox_full |= (*it)->getGlobalBBox();
        if (scroll_rect)
            global_bbox_full = global_transform * scroll_rect_box;
        if (mask)
            global_bbox_full = mask->getGlobalBBox();

        // + effects
        global_bbox_effect = global_bbox_full;

        setFlags(GlobalBBoxReady);

        for (T_Filters::iterator it = filters.begin(); it != filters.end(); ++it)
            (*it)->updateBBox(this, global_bbox_full, &global_bbox_effect);

        if (local_transform_raw.ox != 0 || local_transform_raw.oy != 0) {
            wipeFlags(WipeLocalTransformChanged);
        }
    }

    return global_bbox_effect;
}

const GLBoundingBox &GLClip::getLocalBBox()
{
    if (!checkFlag(LocalBBoxReady) && renderable && !destroyed) {
        // Local bbox
        local_bbox_full = getLocalBBoxSelf();

        // + children
        for (T_Children::iterator it = children.begin(); it != children.end(); ++it)
            local_bbox_full |= (*it)->getLocalBBox();
        if (scroll_rect)
            local_bbox_full = scroll_rect_box;
        if (mask)
            local_bbox_full = mask->getLocalBBox();

        // + effects
        local_bbox_effect = local_bbox_full;

        setFlags(LocalBBoxReady);

        for (T_Filters::iterator it = filters.begin(); it != filters.end(); ++it)
            (*it)->updateBBox(this, local_bbox_full, &local_bbox_effect);

        if (local_transform_raw.ox != 0 || local_transform_raw.oy != 0) {
            wipeFlags(WipeLocalTransformChanged);
        }
    }

    return local_bbox_effect;
}

const GLBoundingBox &GLClip::getLocalBBoxSelf()
{
    if (!checkFlag(LocalBBoxSelfReady)) {
        local_bbox_self.clear();
        computeBBoxSelf(local_bbox_self, GLTransform());
        setFlags(LocalBBoxSelfReady);
    }

    return local_bbox_self;
}

GLBoundingBox GLClip::getGlobalMaskBBox()
{
    GLBoundingBox res;
    GLClip * clp = this;
    while (clp) {
        GLClip * msk = clp->mask;
        if (msk) {
            GLBoundingBox msk_bbx = msk->getGlobalBBox();
            if (res.isEmpty) res = msk_bbx; else res &= msk_bbx;
        }
        clp = clp->parent;
    }    
    return res;
}

void GLClip::computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform)
{
    if (graphics)
        graphics->computeBBox(bbox, transform);
}

vec3 GLClip::getStageMousePos()
{
    return makeStageFromGlobal(vec2(owner->MouseX,owner->MouseY));
}

vec3 GLClip::makeStageFromGlobal(vec2 global)
{
    const GLTransform &tf = owner->Stage->getLocalTransform();
    return toVec3(global) / tf;
}

vec3 GLClip::makeStageCoords(vec2 stage) {
    const GLTransform &tf = owner->Stage->getLocalTransform();
    return toVec3(stage) * tf.getScale();
}

bool GLClip::transformFromStage(vec3 *coord, bool verify_masks)
{
    bool ok;
    if (parent)
        ok = parent->transformFromStage(coord, verify_masks);
    else
        return checkFlag(IsStageClipObject);

    if (ok && coord) {
        vec3 local = *coord / getLocalTransform();

        if (verify_masks) {
            if (local_transform_raw.isZeroScale())
                return false;

            if (scroll_rect)
            {
                if (!scroll_rect_box.contains(local))
                    return false;
            }

            if (mask) {
                if (mask->local_transform_raw.isZeroScale())
                    return false;

                if (!mask->pointHitsSubtree(*coord / mask->getLocalTransform()))
                    return false;
            }
        }

        *coord = local;
    }

    return ok;
}

struct PredicateMockFn {
    bool operator() (GLClip* /*clip*/) { return true; }
};

struct ActionMockFn {
    void operator() (GLClip* /*clip*/) {}
};

struct PredicatableActionMockFn {
    void operator() (GLClip* /*clip*/, GLClip::HitType /*hit*/) {}
};

GLClip::HitType GLClip::computeHitSubtrees(vec3 pos, std::set<GLClip*> *out, std::vector<GLClip*> *leaves) {
    PredicateMockFn predicate;
    ActionMockFn action;
    PredicatableActionMockFn predicatableAction;

    return computeHitSubtreesOrdered(pos, out, leaves, predicate, action, predicatableAction);
}

bool GLClip::pointHitsSubtree(vec3 pos) {
    return computeHitSubtrees(pos, NULL, NULL) != HitNone;
}

void GLClip::collectChildNodes(GLClipScheduleNode *parent)
{
    for (T_Children::iterator it = children.begin(); it != children.end(); ++it) {
        GLClip *child = *it;

        if (child->mask_owner)
            continue;

        GLScheduleNode::Ptr node = child->getScheduleNode();

        if (node)
            parent->addInput(node);
        else
            child->collectChildNodes(parent);
    }
}

GLScheduleNode::Ptr GLClip::getScheduleNode()
{
    if (!checkFlag(ScheduleNodeReady)) {
        schedule_node.reset();
        setFlags(ScheduleNodeReady);

        bool needsNode = mask || mask_owner // both sides of a mask
                      || !filters.empty() // any fiter-owning clip
                      || checkFlag(IsStageClipObject); // the stage

        if (needsNode) {
            GLClipScheduleNode *cnode = new GLClipScheduleNode(this);
            GLScheduleNode::Ptr root(cnode);

            collectChildNodes(cnode);
            schedule_node = root;

            if (mask) {
                GLScheduleNode *nn = new GLMaskScheduleNode(this, schedule_node, mask->getScheduleNode());
                schedule_node = GLScheduleNode::Ptr(nn);
            }

            for (unsigned i = 0; i < filters.size(); i++) {
                GLScheduleNode *nn = new GLFilterScheduleNode(this, schedule_node, filters[i]);
                schedule_node = GLScheduleNode::Ptr(nn);
            }
        }

        if (schedule_node && !mask_owner)
            schedule_node->setInClip();
    }

    return schedule_node;
}

void GLClip::render(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box, bool from_node)
{
    if (global_alpha <= 0.0f || !global_visible || !global_renderable) return;

    GLBoundingBox my_clip_box = getGlobalBBox();

    my_clip_box &= clip_box;
    if (my_clip_box.isEmpty) return;

    renderer->reportGLErrors("GLClip::render start");
    renderer->setCurMatrix(global_transform.forward);

    if (schedule_node && !from_node) {
        schedule_node->renderTo(renderer, surface);
        renderer->reportGLErrors("GLClip::render post effects");
    } else if (scroll_rect) {
        surface->pushCropRect(global_transform, scroll_rect_box);

        renderInner(renderer, surface, my_clip_box);
        renderer->reportGLErrors("GLClip::render post inner");

        surface->popCropRect();
    } else {
        renderInner(renderer, surface, my_clip_box);
        renderer->reportGLErrors("GLClip::render post inner");
    }
}

void GLClip::renderInner(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box)
{
    renderer->reportGLErrors("GLClip::renderInner start");

    if (graphics && !graphics->isEmpty()) {
        surface->makeCurrent();
        graphics->render(renderer, global_transform, global_alpha);
        renderer->reportGLErrors("GLClip::renderInner post graphics");
    }

    for (T_Children::iterator it = children.begin(); it != children.end(); ++it) {
        if ((*it)->mask_owner)
            continue;

        (*it)->render(renderer, surface, clip_box);
    }
}

int GLClip::addEventCallback(FlowEvent event, const StackSlot &cb)
{
    int id = next_cb_id++;
    callbacks[id] = cb;
    event_callbacks[event].insert(id);

    owner->addEventListener(event, this);

    return id;
}

void GLClip::removeEventCallback(FlowEvent event, int id)
{
    callbacks.erase(id);

    T_EventCallbacks::iterator ecit = event_callbacks.find(event);
    if (ecit == event_callbacks.end())
        return;

    ecit->second.erase(id);

    if (ecit->second.empty()) {
        event_callbacks.erase(ecit);

        if (event_callbacks.empty())
            owner->removeEventListener(this);
        else
            owner->removeEventListener(event, this);
    }
}

void GLClip::addEventCallback(FlowEvent event, bool self)
{
    if (self) {
        event_callbacks[event].insert(-1);
        owner->addEventListener(event, this);
    } else {
        removeEventCallback(event, -1);
    }
}

StackSlot GLClip::removeEventCallback_native(RUNNER_ARGS, void *)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 3);
    GLClip *clip = RUNNER->GetNative<GLClip*>(slot[0]);

    clip->removeEventCallback((FlowEvent)slot[1].GetInt(), slot[2].GetInt());

    RETVOID;
}

StackSlot GLClip::addEventCallback(RUNNER_VAR, FlowEvent event, const StackSlot &cb, const char *name)
{
    if (event == FlowUnknownEvent)
        return RUNNER->AllocateConstClosure(0, StackSlot::MakeVoid());
    else
    {
        int id = addEventCallback(event, cb);

        return RUNNER->AllocateNativeClosure(removeEventCallback_native, name, 0, NULL,
                                             3, getFlowValue(), StackSlot::MakeInt(event), StackSlot::MakeInt(id));
    }
}

void GLClip::invokeEventCallbacks(FlowEvent event, int num_args, StackSlot *args)
{
    T_EventCallbacks::iterator it = event_callbacks.find(event);
    if (it == event_callbacks.end())
        return;

    lock();

    std::set<int> ids = it->second;
    for (std::set<int>::iterator iit = ids.begin(); iit != ids.end(); ++iit) {
        T_Callbacks::iterator cit = callbacks.find(*iit);
        if (cit != callbacks.end())
            getFlowRunner()->EvalFunctionArr(cit->second, num_args, args);
    }

    unlock();
}

void GLClip::removeFileDropCallback()
{
    maxFilesDropable = -1;
    fileDropMimeTypeRegExFilter = "";
    fileDropDoneCallback = StackSlot::MakeVoid();

    owner->eraseFileDropClip(this);
}

StackSlot GLClip::addChild(RUNNER_ARGS)
{
    RUNNER_PopArgs1(child);
    RUNNER_CheckTag1(TNative, child);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost*5, 110);
#endif

    GLClip *pchild = RUNNER->GetNative<GLClip*>(child);

#ifdef FLOW_DEBUGGER
    GLClip *oldparent = pchild->parent;
    owner->onClipBeginSetParent(pchild, this, oldparent);
#endif

    addChild(pchild);


#ifdef FLOW_DEBUGGER
    owner->onClipEndSetParent(pchild, this, oldparent);
#endif

    RETVOID;
}

void GLClip::addChild(GLClip *pchild)
{
    if (pchild->parent) {
        pchild->parent->wipeFlags(WipeChildChanged);
        eraseItem(pchild->parent->children, pchild);
    }

    pchild->parent = this;
    children.push_back(pchild);

    wipeFlags(WipeChildChanged);
    pchild->wipeFlags(WipeParentChanged);
}

StackSlot GLClip::addChildAt(RUNNER_ARGS)
{
    RUNNER_PopArgs2(child, id);
    RUNNER_CheckTag1(TNative, child);
    RUNNER_CheckTag1(TInt, id);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost*5, 110);
#endif

    GLClip *pchild = RUNNER->GetNative<GLClip*>(child);

#ifdef FLOW_DEBUGGER
    GLClip *oldparent = pchild->parent;
    owner->onClipBeginSetParent(pchild, this, oldparent);
#endif

    addChildAt(pchild, id.GetInt());


#ifdef FLOW_DEBUGGER
    owner->onClipEndSetParent(pchild, this, oldparent);
#endif

    RETVOID;
}

void GLClip::addChildAt(GLClip *pchild, int id)
{
    if (pchild->parent) {
        pchild->parent->wipeFlags(WipeChildChanged);
        eraseItem(pchild->parent->children, pchild);
    }

    pchild->parent = this;
    children.insert(children.begin() + std::min(id, (int) children.size()), pchild);

    wipeFlags(WipeChildChanged);
    pchild->wipeFlags(WipeParentChanged);
}

StackSlot GLClip::removeChild(RUNNER_ARGS)
{
    RUNNER_PopArgs1(child);
    RUNNER_CheckTag1(TNative, child);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost*5, 110);
#endif

    GLClip *pchild = RUNNER->GetNative<GLClip*>(child);

    if (pchild->parent == this) {
#ifdef FLOW_DEBUGGER
        owner->onClipBeginSetParent(pchild, NULL, this);
#endif

        eraseItem(children, pchild);
        pchild->parent = NULL;

        wipeFlags(WipeChildChanged);
        pchild->wipeFlags(WipeParentChanged);

#ifdef FLOW_DEBUGGER
        owner->onClipEndSetParent(pchild, NULL, this);
#endif
    }

    RETVOID;
}

std::vector<GLClip*> GLClip::removeChildren()
{
    for (unsigned i = 0; i < children.size(); i++) {
        GLClip *pchild = children[i];
        pchild->parent = NULL;

        pchild->wipeFlags(WipeParentChanged);
        wipeFlags(WipeChildChanged);
    }

    std::vector<GLClip*> childs = children;
    children.clear();
    return childs;
}

StackSlot GLClip::getClipChildren(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    RUNNER_DefSlots1(rv);

    rv = RUNNER->AllocateArray(children.size());
    for (size_t i = 0; i < children.size(); i++)
        RUNNER->SetArraySlot(rv, i, children[i]->getFlowValue());

    return rv;
}

StackSlot GLClip::getGraphics(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    if (!graphics)
    {
        graphics = new GLGraphics(this);

#ifdef FLOW_DEBUGGER
        owner->onClipDataChanged(this);
#endif

#ifdef FLOW_INSTRUCTION_PROFILING
        getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost*10, 110);
#endif
    }

    return RUNNER->AllocNative(graphics);
}

StackSlot GLClip::setClipMask(RUNNER_ARGS)
{
    RUNNER_PopArgs1(mask_clip);
    RUNNER_CheckTag1(TNative, mask_clip);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost*5, 110);
#endif

    GLClip *pmask = RUNNER->GetNative<GLClip*>(mask_clip);

    if (mask) {
        //mask->wipeFlags(UnchangedFromRender);
        mask->mask_owner = NULL;

#ifdef FLOW_DEBUGGER
        owner->onClipDataChanged(mask);
#endif
    }

    if (pmask->mask_owner) {
        pmask->mask_owner->wipeFlags(WipeChildChanged);
        pmask->mask_owner->mask = NULL;

#ifdef FLOW_DEBUGGER
        owner->onClipDataChanged(pmask->mask_owner);
#endif
    }

    wipeFlags(WipeChildChanged);
    mask = pmask;

    pmask->mask_owner = this;
    pmask->wipeFlags(WipeParentChanged);

#ifdef FLOW_DEBUGGER
    owner->onClipDataChanged(this);
    owner->onClipDataChanged(pmask);
#endif

    RETVOID;
}

StackSlot GLClip::setClipX(RUNNER_ARGS)
{
    RUNNER_PopArgs1(x);
    RUNNER_CheckTag(TDouble, x);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    wipeFlags(WipeLocalTransformChanged);
    local_transform_raw.x = x.GetDouble();

    FIX_NAN_VALUE(local_transform_raw.x, 0.0f, "setClipX");

    RETVOID;
}

StackSlot GLClip::setClipY(RUNNER_ARGS)
{
    RUNNER_PopArgs1(y);
    RUNNER_CheckTag(TDouble, y);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    wipeFlags(WipeLocalTransformChanged);
    local_transform_raw.y = y.GetDouble();

    FIX_NAN_VALUE(local_transform_raw.y, 0.0f, "setClipY");

    RETVOID;
}

StackSlot GLClip::setClipScaleX(RUNNER_ARGS)
{
    RUNNER_PopArgs1(x);
    RUNNER_CheckTag(TDouble, x);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    wipeFlags(WipeLocalTransformChanged);
    local_transform_raw.sx = x.GetDouble();

    FIX_NAN_VALUE(local_transform_raw.sx, 1.0f, "setClipScaleX");

    RETVOID;
}

StackSlot GLClip::setClipScaleY(RUNNER_ARGS)
{
    RUNNER_PopArgs1(y);
    RUNNER_CheckTag(TDouble, y);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    wipeFlags(WipeLocalTransformChanged);
    local_transform_raw.sy = y.GetDouble();

    FIX_NAN_VALUE(local_transform_raw.sy, 1.0f, "setClipScaleY");

    RETVOID;
}

StackSlot GLClip::setClipRotation(RUNNER_ARGS)
{
    RUNNER_PopArgs1(angle);
    RUNNER_CheckTag(TDouble, angle);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    wipeFlags(WipeLocalTransformChanged);
    local_transform_raw.angle = angle.GetDouble();

    FIX_NAN_VALUE(local_transform_raw.angle, 0.0f, "setClipRotation");

    RETVOID;
}

StackSlot GLClip::setClipOrigin(RUNNER_ARGS)
{
    RUNNER_PopArgs2(x, y);
    RUNNER_CheckTag(TDouble, x);
    RUNNER_CheckTag(TDouble, y);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    wipeFlags(WipeLocalTransformChanged);
    local_transform_raw.ox = x.GetDouble();
    local_transform_raw.oy = y.GetDouble();

    FIX_NAN_VALUE(local_transform_raw.ox, 0.0f, "setClipOrigin");
    FIX_NAN_VALUE(local_transform_raw.oy, 0.0f, "setClipOrigin");

    RETVOID;
}

StackSlot GLClip::setClipAlpha(RUNNER_ARGS)
{
    RUNNER_PopArgs1(new_alpha);
    RUNNER_CheckTag(TDouble, new_alpha);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    wipeFlags(WipeAlphaChanged);
    alpha = new_alpha.GetDouble();

    FIX_NAN_VALUE(alpha, 1.0f, "setClipAlpha");

    if (alpha < 0.0f) alpha = 0.0f;
    else if (alpha > 1.0f) alpha = 1.0f;

    RETVOID;
}

void GLClip::setVisible(bool state)
{
    wipeFlags(ChildrenUnchangedFromRender | SelfUnchangedFromRender);
    visible = state;

#ifdef FLOW_DEBUGGER
    owner->onClipDataChanged(this);
#endif
}

void GLClip::setRenderable(bool state)
{
    wipeFlags(ChildrenUnchangedFromRender | SelfUnchangedFromRender);
    renderable = state;

#ifdef FLOW_DEBUGGER
    owner->onClipDataChanged(this);
#endif
}

StackSlot GLClip::setClipVisible(RUNNER_ARGS)
{
    RUNNER_PopArgs1(new_visible);
    RUNNER_CheckTag(TBool, new_visible);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    setVisible(new_visible.GetBool());

    RETVOID;
}

StackSlot GLClip::setClipRenderable(RUNNER_ARGS)
{
    RUNNER_PopArgs1(new_renderable);
    RUNNER_CheckTag(TBool, new_renderable);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    setRenderable(new_renderable.GetBool());

    RETVOID;
}

StackSlot GLClip::getClipVisible(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeBool(global_visible);
}

StackSlot GLClip::setClipCallstack(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cstack);

    if (!cstack.IsVoid()) {
        RUNNER_CheckTag(TNative, cstack);

        stack = RUNNER->GetNative<FlowStackSnapshot*>(cstack);

#ifdef FLOW_DEBUGGER
        owner->onClipDataChanged(this);
#endif
    }

    RETVOID;
}

StackSlot GLClip::setClipDebugInfo(RUNNER_ARGS)
{
    RUNNER_PopArgs2(key,val);
    RUNNER_CheckTag(TString, key);

#ifdef FLOW_DEBUGGER
    if (RUNNER->IsDebugging()) {
        debug_info[encodeUtf8(RUNNER->GetString(key))] = val;
        owner->onClipDataChanged(this);
    }
#endif

    RETVOID;
}

StackSlot GLClip::addEventListener(RUNNER_ARGS)
{
    RUNNER_PopArgs2(event_name, cb);
    RUNNER_CheckTag(TString, event_name);

    std::string event = encodeUtf8(RUNNER->GetString(event_name));

    FlowEvent type = FlowUnknownEvent;

    if (event == "mouseenter" || event == "rollover")
        type = FlowMouseEnter;
    else if (event == "mouseleave" || event == "rollout")
        type = FlowMouseLeave;
    else if (event == "mousemove")
        type = FlowMouseMove;
    else if (event == "mousedown")
        type = FlowMouseDown;
    else if (event == "mouseup")
        type = FlowMouseUp;
    else if (event == "mouserightdown")
        type = FlowMouseRightDown;
    else if (event == "mouserightup")
        type = FlowMouseRightUp;
    else if (event == "mousemiddledown")
        type = FlowMouseMiddleDown;
    else if (event == "mousemiddleup")
        type = FlowMouseMiddleUp;
    else if (event == "click")
        type = FlowMouseClick;
    else if (event == "resize")
        type = FlowSceneResize;
    else if (event == "change")
        type = FlowTextChange;
    else if (event == "scroll")
        type = FlowTextScroll;
    else if (event == "focusin")
        type = FlowFocusIn;
    else if (event == "focusout")
        type = FlowFocusOut;
    else if (event == "transformchanged")
        type = FlowTransformChange;

    return addEventCallback(RUNNER, type, cb, "addEventListener$disposer");
}

StackSlot GLClip::emitMouseEvent(RUNNER_ARGS)
{
    RUNNER_PopArgs3(event_name, x, y);
    RUNNER_CheckTag(TString, event_name);
    RUNNER_CheckTag(TDouble, x);
    RUNNER_CheckTag(TDouble, y);

    std::string event = encodeUtf8(RUNNER->GetString(event_name));
    int mouseX = (int) x.GetDouble();
    int mouseY = (int) y.GetDouble();

    FlowEvent type = FlowUnknownEvent;

    if (event == "mouseenter" || event == "rollover")
        type = FlowMouseEnter;
    else if (event == "mouseleave" || event == "rollout")
        type = FlowMouseLeave;
    else if (event == "mousemove")
        type = FlowMouseMove;
    else if (event == "mousedown")
        type = FlowMouseDown;
    else if (event == "mouseup")
        type = FlowMouseUp;
    else if (event == "mouserightdown")
        type = FlowMouseRightDown;
    else if (event == "mouserightup")
        type = FlowMouseRightUp;
    else if (event == "mousemiddledown")
        type = FlowMouseMiddleDown;
    else if (event == "mousemiddleup")
        type = FlowMouseMiddleUp;
    else if (event == "click")
        type = FlowMouseClick;

    owner->dispatchMouseEvent(type, mouseX, mouseY);

    RETVOID;
}

StackSlot GLClip::emitKeyEvent(RUNNER_ARGS)
{
    RUNNER_PopArgs7(event_name, key, ctrl, shift, alt, meta, key_code);
    RUNNER_CheckTag(TString, event_name);
    RUNNER_CheckTag(TString, key);
    RUNNER_CheckTag(TBool, ctrl);
    RUNNER_CheckTag(TBool, shift);
    RUNNER_CheckTag(TBool, alt);
    RUNNER_CheckTag(TBool, meta);
    RUNNER_CheckTag(TInt, key_code);

    std::string event = encodeUtf8(RUNNER->GetString(event_name));
    FlowEvent type = FlowUnknownEvent;

    if (event == "keydown")
        type = FlowKeyDown;
    else if (event == "keyup")
        type = FlowKeyUp;

    owner->dispatchKeyEvent(type, RUNNER->GetString(key), ctrl.GetBool(), shift.GetBool(), alt.GetBool(), meta.GetBool(), (FlowKeyCode) key_code.GetInt());

    RETVOID;
}

StackSlot GLClip::addKeyEventListener(RUNNER_ARGS)
{
    RUNNER_PopArgs2(event_name, cb);
    RUNNER_CheckTag(TString, event_name);

    std::string event = encodeUtf8(RUNNER->GetString(event_name));

    FlowEvent type = FlowUnknownEvent;

    if (event == "keydown")
        type = FlowKeyDown;
    else if (event == "keyup")
        type = FlowKeyUp;

    return addEventCallback(RUNNER, type, cb, "addKeyEventListener$disposer");
}

StackSlot GLClip::addMouseWheelEventListener(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    return addEventCallback(RUNNER, FlowMouseWheel, cb, "addMouseWheelEventListener$disposer");
}

StackSlot GLClip::addFinegrainMouseWheelEventListener(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    return addEventCallback(RUNNER, FlowFineGrainMouseWheel, cb, "addFinegrainMouseWheelEventListener$disposer");
}

StackSlot GLClip::removeFileDropListener_native(RUNNER_ARGS, void *)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    GLClip *clip = RUNNER->GetNative<GLClip*>(slot[0]);

    clip->removeFileDropCallback();

    RETVOID;
}

StackSlot GLClip::addFileDropListener(RUNNER_ARGS)
{
    RUNNER_PopArgs3(maxFiles, mimeTypeFilter, onDone);
    RUNNER_CheckTag1(TInt, maxFiles);
    RUNNER_CheckTag1(TString, mimeTypeFilter);

    maxFilesDropable = maxFiles.GetInt();
    fileDropMimeTypeRegExFilter = encodeUtf8(RUNNER->GetString(mimeTypeFilter));
    fileDropDoneCallback = onDone;

    owner->addFileDropClip(this);

    return RUNNER->AllocateNativeClosure(removeFileDropListener_native, "addFileDropListener$disposer", 0, NULL, 1, getFlowValue());
}

vec2 GLClip::getLocalMousePos(bool *pok)
{
    vec3 pos = getStageMousePos();
    bool ok = transformFromStage(&pos);
    if (pok) *pok = ok;
    return toVec2(pos);
}

StackSlot GLClip::getMouseX(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeDouble(getLocalMousePos().x);
}

StackSlot GLClip::getMouseY(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeDouble(getLocalMousePos().y);
}

StackSlot GLClip::hittest(RUNNER_ARGS)
{
    RUNNER_PopArgs2(x_val, y_val);
    RUNNER_CheckTag2(TDouble, x_val, y_val);

    // Ensure proper scaling factor for confidence radius
    vec3 pos = makeStageCoords(vec2(x_val.GetDouble(), y_val.GetDouble()));

    if (!transformFromStage(&pos, true) || owner->CurEvent == FlowMouseCancel)
    {
        return StackSlot::MakeBool(false);
    }

    return StackSlot::MakeBool(pointHitsSubtree(pos));
}

StackSlot GLClip::addFilters(RUNNER_ARGS)
{
    RUNNER_PopArgs1(arr);
    RUNNER_CheckTag(TArray, arr);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost*10, 110);
#endif

    wipeFlags(WipeChildChanged); // for lack of better mask

    int len = RUNNER->GetArraySize(arr);

    for (int i = 0; i < len; ++i)
    {
        GLFilter *effect = RUNNER->GetNative<GLFilter*>(RUNNER->GetArraySlot(arr, i));
        filters.push_back(effect);
        effect->clips.push_back(this);
    }

#ifdef FLOW_DEBUGGER
    owner->onClipDataChanged(this);
#endif

    RETVOID;
}

StackSlot GLClip::setAccessAttributes(RUNNER_ARGS)
{
    RUNNER_PopArgs1(arr);
    RUNNER_CheckTag(TArray, arr);

    ByteCodeRunner * rnr = owner->getFlowRunner();
    int len = rnr->GetArraySize(arr);
    
    for (int i = 0; i < len; ++i)
    {
        const StackSlot & item = rnr->GetArraySlot(arr, i);
        std::string key = encodeUtf8(rnr->GetString(rnr->GetArraySlot(item, 0)));
        const StackSlot & value_slot = rnr->GetArraySlot(item, 1);
        if (value_slot.IsString()) {
            std::string value = encodeUtf8(rnr->GetString(value_slot));
            accessibility_attributes[key] = value;

            if (key == "enabled") {
                setAccessEnabled(value == "true");
            } else if (key == "nodeindex") {
                std::istringstream iss(value);
                std::vector<int> nodeindexes;

                int idx;
                while (iss >> idx) {
                     nodeindexes.push_back(idx);
                }

                setNodeIndex(nodeindexes);
            } else if (key == "role") {
                setAccessRole(value);
            }
        }
    }

    owner->updateAccessibleClips();

    RETVOID;
}

StackSlot GLClip::setAccessCallback(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    access_callback = cb;

    RETVOID;
}

StackSlot GLClip::setScrollRect(RUNNER_ARGS)
{
    RUNNER_PopArgs4(left,top,width,height);
    RUNNER_CheckTag4(TDouble,left,top,width,height);

    wipeFlags(WipeLocalTransformChanged);

    vec2 min_pt(left.GetDouble(), top.GetDouble());
    local_transform_raw.x = -min_pt.x;
    local_transform_raw.y = -min_pt.y;

    vec2 size(width.GetDouble(), height.GetDouble());
    scroll_rect_box = GLBoundingBox(min_pt, min_pt+size);
    scroll_rect = true;

    RETVOID;
}

void GLClip::dispatchAccessCallback()
{
     if (access_enabled && !access_callback.IsVoid()) {
         owner->getFlowRunner()->EvalFunction(access_callback, 0);
     }
}

StackSlot GLClip::setTabIndex(RUNNER_ARGS)
{
    RUNNER_PopArgs1(tabindex);
    RUNNER_CheckTag1(TInt, tabindex);

    std::vector<int> tabIndexes;

    tabIndexes.push_back(-1);
    tabIndexes.push_back(tabindex.GetInt());

    setNodeIndex(tabIndexes);

    RETVOID;
}

void GLClip::setNodeIndex(std::vector<int> idx)
{
    if (owner->tabIndexedClips.find(this) == owner->tabIndexedClips.end())
        owner->tabIndexedClips.insert(this);

    clip_tab_index = idx;
}

void GLClip::setAccessRole(std::string role)
{
    access_role = role;

    if (!accessFocusEnabled())
        setFocus(false);
}

void GLClip::setAccessEnabled(bool enabled)
{
    access_enabled = enabled;
}

bool GLClip::accessFocusEnabled()
{
    return access_enabled && (
                access_role == "button" ||
                access_role == "checkbox" ||
                access_role == "textbox" ||
                access_role == "listitem" ||
                access_role == "menu" ||
                access_role == "radio");
}

void GLClip::setFocus(bool focus)
{
    if (focus)
        owner->CurrentFocus = this;
    else if (owner->CurrentFocus == this)
        owner->CurrentFocus = NULL;

    invokeEventCallbacks(focus ? FlowFocusIn : FlowFocusOut, 0, NULL);
}

StackSlot GLClip::setFocus(RUNNER_ARGS)
{
    RUNNER_PopArgs1(focus);
    RUNNER_CheckTag1(TBool, focus);

    setFocus(focus.GetBool());

    RETVOID;
}

StackSlot GLClip::getFocus(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    return StackSlot::MakeBool(owner->CurrentFocus == this);
}

StackSlot GLClip::getGlobalTransformArray()
{
    RUNNER_VAR = getFlowRunner();

    const StackSlot & arr = RUNNER->AllocateArray(6);
    const mat3 & m = global_transform.forward;
    float s = m[2][2];
    float a = m[0][0] / s;
    float b = m[1][0] / s;
    float tx = m[2][0] / s;
    float c = m[0][1] / s;
    float d = m[1][1] / s;
    float ty = m[2][1] / s;

    RUNNER->SetArraySlot(arr, 0, StackSlot::MakeDouble(a));
    RUNNER->SetArraySlot(arr, 1, StackSlot::MakeDouble(b));
    RUNNER->SetArraySlot(arr, 2, StackSlot::MakeDouble(c));
    RUNNER->SetArraySlot(arr, 3, StackSlot::MakeDouble(d));
    RUNNER->SetArraySlot(arr, 4, StackSlot::MakeDouble(tx));
    RUNNER->SetArraySlot(arr, 5, StackSlot::MakeDouble(ty));

    return arr;
}

StackSlot GLClip::getGlobalTransform(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    
    return getGlobalTransformArray();
}

StackSlot GLClip::setFullWindowTarget(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    owner->setFullWindowTarget(this);

    RETVOID;
}
