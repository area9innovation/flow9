#include "GLRenderSupport.h"
#include "GLRenderer.h"
#include "GLGraphics.h"
#include "GLClip.h"
#include "GLPictureClip.h"
#include "GLVideoClip.h"
#include "GLFont.h"
#include "GLTextClip.h"
#include "GLFilter.h"
#include "GLSchedule.h"
#include "GLWebClip.h"
#include "GLCamera.h"

#include "core/GarbageCollector.h"
#include "core/RunnerMacros.h"

#include "ImageLoader.h"

#include <algorithm>

static const unicode_string STR_auto = parseUtf8("auto");

static void lock_destroy(const std::vector<GLClip*> &clips)
{
    for (std::vector<GLClip*>::const_iterator it = clips.begin(); it != clips.end(); ++it)
    {
        if (*it)
            (*it)->lock();
    }
}

static void unlock_destroy(const std::vector<GLClip*> &clips)
{
    for (std::vector<GLClip*>::const_iterator it = clips.begin(); it != clips.end(); ++it)
    {
        if (*it)
            (*it)->unlock();
    }
}

GLRenderSupport::GLRenderSupport(ByteCodeRunner *owner) :
    NativeMethodHost(owner),
    gl_transparent()
{
    ScreenRotation = FlowRotation0;
    Width = Height = RealWidth = RealHeight = 100;
    MouseX = MouseY = 0;
    MouseDownX = MouseDownY = 0;
    CurEvent = FlowUnknownEvent;
    Renderer = NULL;
    NoHoverMouse = DrawMouseRect = false;
    MouseRadius = 0.0f;
    cursor = user_cursor = STR_auto;
    GlobalZoomEnabled = DropFocusOnDown = true;
    DebugHighlightClip = NULL;
#ifdef FLOW_INSTRUCTION_PROFILING
    ProfilingInsnCost = 0;
#endif

    setDPI(96);

    ScaleCenterX = ScaleCenterY = 0.5;
    ScaleFactor = 1.0f;
    lastUserAction = -1;
    DisplayDensity = 1.0;

    FontLibrary = GLFontLibrary::Load(this);

    OnRunnerReset(false);
}

GLRenderSupport::~GLRenderSupport()
{
    // Make the clip tree orphaned
    if (Stage)
        Stage->wipeFlags(GLClip::IsStageClipObject);

    // Wipe the listeners
    for (T_EventListeners::iterator it = EventListeners.begin(); it != EventListeners.end(); ++it)
        for (std::set<GLClip*>::iterator it2 = it->second.begin(); it2 != it->second.end(); ++it2)
            (*it2)->wipeFlags(GLClip::ListensToEvents);

    delete Renderer;
}

void GLRenderSupport::flowGCObject(GarbageCollectorFn ref)
{
    ref << Stage;
    ref << PendingPictures;
    ref << HoveredClips << PressedClips;
    ref << NativeWidgetClips << TextFocus << PressTextFocus << CurrentFocus;
    ref << DebugHighlightClip;
}

GLFont::Ptr GLRenderSupport::lookupFont(TextFont textFont)
{
    GLFont::Ptr &ptr = Fonts[textFont];
    if (!ptr)
    {
        ptr = FontLibrary->loadFont(textFont);
        if (!ptr)
            ptr = DefaultFont;
    }
    return ptr;
}

bool GLRenderSupport::setFallbackFont(unicode_string name) {
    if (!FallbackFont) {

        FallbackFont = lookupFont(TextFont::makeWithFamily(encodeUtf8(name)));
        FallbackFont->is_fallback = true;
    } else {
        // Some GlyphInfo might have id & FALLBACK_FONT instead of id.
        // They are expected to be rendered with current fallback font.
        cerr << "Error: FallbackFont should be set only once" << std::endl;
    }
    return DefaultFont && FallbackFont != DefaultFont;
}

void GLRenderSupport::loadNativeFont(std::string filename, std::string familyname, std::vector<unicode_string> aliases, bool set_default)
{
    if (!FontLibrary) return;

    // Check if file url, then normalize to file path
    int is_file_url = filename.compare(0, 7, "file://");
    if (is_file_url == 0) {
        filename = filename.substr(7);
    }
    
    TextFont textFont = TextFont::makeWithFamily(familyname);
    GLFont::Ptr font = FontLibrary->loadNativeFont(filename);
    if (font) {
        if (!DefaultFont || set_default)
            DefaultFont = font;

        Fonts[textFont] = font;

        for (unsigned i = 0; i < aliases.size(); i++)
            Fonts[TextFont::makeWithFamily(encodeUtf8(aliases[i]))] = font;
    } else {
         cerr << "Cannot load font : " << filename << std::endl;
    }
}

void GLRenderSupport::loadFont(std::string filename, std::vector<unicode_string> aliases, bool set_default)
{
    if (!FontLibrary) return;

    TextFont textFont = TextFont::makeWithFamily(filename);
    GLFont::Ptr font = FontLibrary->loadFont(textFont);
    if (font) {
        if (!DefaultFont || set_default)
            DefaultFont = font;

        Fonts[textFont] = font;

        for (unsigned i = 0; i < aliases.size(); i++)
            Fonts[TextFont::makeWithFamily(encodeUtf8(aliases[i]))] = font;
    } else {
         cerr << "Cannot load font : " << filename << std::endl;
    }
}

bool GLRenderSupport::loadAssetData(StaticBuffer *buffer, std::string name, size_t size)
{
    return buffer->load_file(name, size);
}

bool GLRenderSupport::needsRendering()
{
    return Stage && !Stage->checkFlag(GLClip::UnchangedFromRender);
}

void GLRenderSupport::OnRunnerReset(bool inDestructor) {
    NativeMethodHost::OnRunnerReset(inDestructor);

    Stage = NULL;
    PendingPictures.clear();
    EventListeners.clear();
    HoveredClips.clear();
    PressedClips.clear();
    tabIndexedClips.clear();
    NativeWidgetClips.clear();
    CurrentFocus = TextFocus = PressTextFocus = NULL;
    DebugHighlightClip = NULL;

    PictureCache.clear();

    RedrawPending = false;
    FullWindowPending = false;
    IsFullWindow = false;

    if (!inDestructor) {
        Stage = new GLClip(this, true);
        Stage->setFlags(GLClip::IsStageClipObject);
        Stage->setGlobalScale(vec2(ScaleCenterX, ScaleCenterY), ScaleFactor, ScreenRotation);
        Stage->getFlowValue();
    }
}

void GLRenderSupport::OnHostEvent(HostEvent event)
{
    NativeMethodHost::OnHostEvent(event);

    if (needsRendering() || event == HostEventError) {
        if (!RedrawPending) {
            RedrawPending = true;
            doRequestRedraw();

            if (FullWindowPending) {
                toggleFullWindow(true);
            }
        }
    }
}

void GLRenderSupport::setDebugHighlight(GLClip *clip)
{
    if (clip && !clip->isAttachedToStage())
        clip = NULL;

    DebugHighlightClip = clip;
    doRequestRedraw();
}

void GLRenderSupport::removeUrlFromPicturesCache(unicode_string url)
{
    T_PictureCache::iterator cit = PictureCache.find(url);
    if (cit != PictureCache.end()) {
        PictureCache.erase(cit);
    }
}

bool GLRenderSupport::hasNativeWidget(GLClip *clip)
{
    return NativeWidgetClips.count(clip) != 0;
}

void GLRenderSupport::checkNativeWidgets(bool resize)
{
    if (DebugHighlightClip && !DebugHighlightClip->isAttachedToStage())
        DebugHighlightClip = NULL;

    for (T_ClipSet::iterator it = NativeWidgetClips.begin(); it != NativeWidgetClips.end();) {
        GLClip *clip = *it; ++it;

        if (!clip->isAttachedToStage() && !IsFullWindow) {
            destroyNativeWidget(clip);
            continue;
        }

        if (resize && !clip->checkFlag(GLClip::NativeWidgetPosReady)) {
            const GLTransform &trf = clip->getGlobalTransform();
            const GLBoundingBox &bbox = clip->getGlobalBBoxSelf();
            float alpha = clip->getGlobalAlpha();

            clip->setFlags(GLClip::NativeWidgetPosReady);
            doReshapeNativeWidget(clip, bbox, trf.getScale(), alpha);
        }
    }

    assert(!TextFocus || TextFocus->checkFlag(GLClip::HasNativeWidget));
}

bool GLRenderSupport::createNativeWidget(GLClip *clip)
{
    bool neww = false;

    if (!clip->checkFlag(GLClip::HasNativeWidget)) {
        NativeWidgetClips.insert(clip);
        clip->wipeFlags(GLClip::WipeLoseNativeWidget);
        clip->setFlags(GLClip::HasNativeWidget);
        neww = true;

        Stage->wipeFlags(GLClip::WipeChildChanged);
    }

    return doCreateNativeWidget(clip, neww);
}

void GLRenderSupport::destroyNativeWidget(GLClip *clip)
{
    if (clip == CurrentFocus) {
        CurrentFocus = TextFocus = NULL;
    }

    if (clip->checkFlag(GLClip::HasNativeWidget)) {
        NativeWidgetClips.erase(clip);
        clip->wipeFlags(GLClip::WipeLoseNativeWidget);

        Stage->wipeFlags(GLClip::WipeChildChanged);

        doDestroyNativeWidget(clip);
    }
}

bool GLRenderSupport::initGLContext(unsigned root_fb_id)
{
    if (!Renderer)
        Renderer = new GLRenderer();

    if (!Renderer->Init(root_fb_id))
        return false;

    FontLibrary->setMaxTextureSize(Renderer->getMaxTextureSize());
    return true;
}

void GLRenderSupport::resizeGLContext(int w, int h)
{
    if (!Renderer)
        initGLContext();

    if (!Renderer->isInitialized())
        return;

    RealWidth = w;
    RealHeight = h;

    Renderer->SetSize(w, h);

    updateGlobalScale(true);
}
double startRenderTimestamp = 0.0;
void GLRenderSupport::paintGLContext(unsigned ad_hoc_fb)
{
    RedrawPending = false;

//#define LOG_PAINT_TIME
#ifdef LOG_PAINT_TIME
    double start_time = GetCurrentTime();
#endif

    if (startRenderTimestamp == 0.0) {
        startRenderTimestamp = GetCurrentTime();
    }

    if (lastUserAction != -1 && lastUserAction < GetCurrentTime() - 60.0) {
        getFlowRunner()->NotifyPlatformEvent(PlatformApplicationUserIdle);
        lastUserAction = -1;
    }

    RUNNER_VAR = getFlowRunner();
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    double rendertime = (GetCurrentTime() - startRenderTimestamp) * 1000.0;

    for (unsigned int it = 0; it < DrawFrameListeners.size(); ++it) {
        RUNNER->EvalFunction(RUNNER->LookupRoot(DrawFrameListeners[it]), 1, StackSlot::MakeDouble(rendertime));
    }

    if (DrawFrameListeners.size()) {
        doRequestRedraw();
    }

    ByteCodeRunnerNativeContext rctx(RUNNER, 100);

    if (!Renderer)
        initGLContext();

    if (!Renderer->isInitialized())
        return;

    Renderer->reportGLErrors("paintGLContext start");

    GLDrawSurface surface(Renderer, ad_hoc_fb);

    Renderer->BeginFrame();
    Renderer->reportGLErrors("paintGLContext post clean");

    // Prepare rendering
    GLScheduleNode::Ptr snode;

    if (Stage) {
        ByteCodeRunnerNativeContext rctx2(getFlowRunner(), 101);

        if (!RUNNER->isInitializing())
            Stage->prepareRenderTransforms();


        // This breaks QWebEngineView. See below.
        //checkNativeWidgets(true);

        snode = Stage->getScheduleNode();

        snode->invalidateBufferCache();
        Renderer->InvalidateStaleRetainedBuffers();
    }

    {
        ByteCodeRunnerNativeContext rctx3(getFlowRunner(), 102);

        if (snode) {
            snode->renderRec(Renderer, surface.getBBox());
        }
        // Render the frame
        surface.makeCurrent();
    }

    {
        ByteCodeRunnerNativeContext rctx4(getFlowRunner(), 104);

        glDisable(GL_STENCIL_TEST);
        glDisable(GL_SCISSOR_TEST);

        glStencilMask(GLuint(-1));
        float clear = gl_transparent ? 0.0f : 1.0f;
        glClearColor(clear, clear, clear, clear);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
        Renderer->reportGLErrors("paintGLContext post clear");

        if (snode) {
            snode->renderTo(Renderer, &surface);
            Renderer->reportGLErrors("paintGLContext post renderTo");
        }

        // In error state, paint a transparent red overlay
        if (getFlowRunner()->IsErrorReported()) {
            surface.makeCurrent();
            Renderer->setCurMatrix(mat3());
            Renderer->beginDrawSimple(vec4(1,0,0,1)*0.25);
            surface.drawBBox();
        }

        if (DrawMouseRect)
        {
            surface.makeCurrent();
            Renderer->setCurMatrix(mat3());
            Renderer->beginDrawSimple(vec4(0,1,0,1)*0.25);
            vec2 cur(MouseX, MouseY), rad(MouseRadius);
            Renderer->drawRect(cur-rad, cur+rad);
        }

        if (DebugHighlightClip)
        {
            surface.makeCurrent();
            Renderer->setCurMatrix(mat3());
            Renderer->beginDrawSimple(vec4(0,0,1,1)*0.134);
            GLBoundingBox box = DebugHighlightClip->getGlobalBBox();
            Renderer->drawRect(box.min_pt, box.max_pt);
            box.expand(4);
            Renderer->drawRect(box.min_pt, box.max_pt);
        }

        if (RenderDeferredFunctions.size() > 0) {
            RUNNER_VAR = getFlowRunner();

            for (unsigned int it = 0; it < RenderDeferredFunctions.size(); ++it) {
                RUNNER->EvalFunction(RUNNER->LookupRoot(RenderDeferredFunctions[it]), 0);
                RUNNER->ReleaseRoot(RenderDeferredFunctions[it]);
            }

            RenderDeferredFunctions.clear();
        }

        if (getFlowRunner()->IsProfiling())
            glFinish();
    }

    // Some Qt natives use OpenGL as well, so in order to avoid interference with our own GL state,
    // we postpone updating the natives to after we are done with our own rendering
    // (Specifically, Qt's WebEngineView will not work if its size is set in the middle of our
    // rendering and will invalidate our OpenGL state)
    if (Stage)
        checkNativeWidgets(true);

    Renderer->CleanStaleObjectsPost();
    Renderer->reportGLErrors("paintGLContext end");

#ifdef LOG_PAINT_TIME
    getFlowRunner()->flow_err << "PAINT: " << (GetCurrentTime() - start_time) << endl;
#endif
}

void GLRenderSupport::updateLastUserAction()
{
    if (lastUserAction == -1) {
        getFlowRunner()->NotifyPlatformEvent(PlatformApplicationUserActive);
    }

    lastUserAction = GetCurrentTime();
}

void GLRenderSupport::adjustGlobalScale(float shift_x, float shift_y, float center_x, float center_y, float df)
{
    if (!GlobalZoomEnabled) return;

    vec2 div = ScaleFactor*vec2(Width,Height);
    vec2 ScaleCenter(ScaleCenterX, ScaleCenterY);

    ScaleCenter -= vec2(shift_x, shift_y)/div;

    vec2 delta = vec2(center_x, center_y)/div - vec2(0.5f/ScaleFactor);
    float new_df = ScaleFactor * df;

    if (new_df > 2.0f)
        df = 2.0f / ScaleFactor;

    ScaleFactor *= df;
    ScaleCenter += delta*(df - 1.0f);

    if (ScaleFactor < 1.0f) {
        ScaleFactor = 1.0f;
        ScaleCenter = vec2(0.5f);
    } else {
        vec2 bound = vec2(0.5f)/ScaleFactor;
        ScaleCenter = glm::max(ScaleCenter, bound);
        ScaleCenter = glm::min(ScaleCenter, vec2(1.0f) - bound);
    }

    ScaleCenterX = ScaleCenter.x;
    ScaleCenterY = ScaleCenter.y;

    updateGlobalScale();
}

void GLRenderSupport::setGlobalScale(float scale_center_x, float scale_center_y, float scale_factor)
{
    ScaleCenterX = scale_center_x;
    ScaleCenterY = scale_center_y;
    ScaleFactor = scale_factor;
    updateGlobalScale();
}

void GLRenderSupport::setScreenRotation(FlowScreenRotation newRotation)
{
    if (newRotation == ScreenRotation)
        return;

    ScreenRotation = newRotation;

    updateGlobalScale(true);
}

void GLRenderSupport::updateGlobalScale(bool resized)
{
    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    bool rotated = isScreenRotated();

    Width = rotated ? RealHeight : RealWidth;
    Height = rotated ? RealWidth : RealHeight;

    if (Stage)
        Stage->setGlobalScale(vec2(ScaleCenterX, ScaleCenterY), ScaleFactor, ScreenRotation);

    if (resized)
        dispatchEventCallbacks(FlowSceneResize, 0, NULL);

    getFlowRunner()->NotifyHostEvent(HostEventUserAction);
}

void GLRenderSupport::addEventListener(FlowEvent event, GLClip *clip)
{
    clip->setFlags(GLClip::ListensToEvents);

    if (event == FlowMouseEnter || event == FlowMouseLeave) {
        clip->setFlags(GLClip::ListensToOverOutEvents);
    }

    EventListeners[event].insert(clip);
}

void GLRenderSupport::removeEventListener(FlowEvent event, GLClip *clip)
{
    EventListeners[event].erase(clip);

    if ((event == FlowMouseEnter || event == FlowMouseLeave) && EventListeners[FlowMouseEnter].size() == 0 && EventListeners[FlowMouseLeave].size() == 0) {
        clip->wipeFlags(GLClip::ListensToOverOutEvents);
    }
}

void GLRenderSupport::removeEventListener(GLClip *clip)
{
    for (T_EventListeners::iterator it = EventListeners.begin(); it != EventListeners.end(); ++it)
        it->second.erase(clip);

    clip->wipeFlags(GLClip::ListensToEvents);
    clip->wipeFlags(GLClip::ListensToOverOutEvents);
}

void GLRenderSupport::dispatchEventCallbacks(FlowEvent event, int num_args, StackSlot *args)
{
    std::vector<GLClip*> tmp(EventListeners[event].begin(), EventListeners[event].end());

    if (event == FlowMouseUp && CurEvent == FlowMouseCancel) {
        for (unsigned i = 0; i < tmp.size(); i++)
            if (tmp[i] && EventListeners[FlowMouseCancel].count(tmp[i]))
                tmp[i] = NULL;
    }

    dispatchEventCallbacks(tmp, event, num_args, args);
}

void GLRenderSupport::dispatchEventCallbacks(const std::vector<GLClip*> &clips, FlowEvent event, int num_args, StackSlot *args)
{
    RUNNER_VAR = getFlowRunner();
    RUNNER_RegisterNativeRoot(std::vector<GLClip*>, clips);

    lock_destroy(clips);

    for (std::vector<GLClip*>::const_iterator it = clips.begin(); it != clips.end(); ++it)
    {
        if (!*it || !EventListeners[event].count(*it))
            continue;

        (*it)->invokeEventCallbacks(event, num_args, args);
    }

    unlock_destroy(clips);
}

struct PredicateFn {
    bool operator() (GLClip* clip) {
        return clip->checkFlag(GLClip::ListensToOverOutEvents);
    }
};

struct ActionFn {
    void operator() (GLClip* clip) {
        if (clip->checkFlag(GLClip::ListensToOverOutEvents) && !clip->checkFlag(GLClip::IsUnderMouseCursor)) {
            clip->setFlags(GLClip::IsUnderMouseCursor);
            clip->invokeEventCallbacks(FlowMouseEnter, 0, NULL);
        }
    }
};

struct PredicatableActionFn {
    void operator() (GLClip* clip, GLClip::HitType hit) {
        if (!hit && clip->checkFlag(GLClip::IsUnderMouseCursor) && clip->checkFlag(GLClip::ListensToOverOutEvents)) {
            clip->wipeFlags(GLClip::IsUnderMouseCursor);
            clip->invokeEventCallbacks(FlowMouseLeave, 0, NULL);
        }
    }
};

void GLRenderSupport::updateHoveredClips()
{
    std::vector<GLClip*>::iterator it;
    std::set<GLClip*> hover;

    if (CurEvent != FlowMouseCancel) {
        PredicateFn predicate;
        ActionFn action;
        PredicatableActionFn predicatableAction;
        Stage->computeHitSubtreesOrdered(Stage->getStageMousePos(), &hover, NULL, predicate, action, predicatableAction);
    }

    HoveredClips.swap(hover);

    std::vector<GLClip*> pold;

    // Clips leaving hover
    pold.resize(hover.size(), NULL);

    it = set_difference(hover.begin(), hover.end(),
                        HoveredClips.begin(), HoveredClips.end(),
                        pold.begin());
    pold.erase(it, pold.end());

    lock_destroy(pold);

    // Release hover if haven't been already released
    for (it = pold.begin(); it != pold.end(); ++it) {
        GLClip* clip = *it;
        if (!clip || !clip->getParent() || !clip->checkFlag(GLClip::ListensToEvents) || !clip->checkFlag(GLClip::IsUnderMouseCursor))
            continue;

        clip->wipeFlags(GLClip::IsUnderMouseCursor);
        clip->invokeEventCallbacks(FlowMouseLeave, 0, NULL);
    }

    unlock_destroy(pold);
}

void GLRenderSupport::dispatchMouseEvent(FlowEvent event, int x, int y)
{
    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    if (event == FlowMouseCancel) {
        x = MouseDownX; y = MouseDownY;
        PressedClips.clear();
        PressTextFocus = NULL;
    }

    CurEvent = event;
    MouseX = x; MouseY = y;

    if (DrawMouseRect)
        doRequestRedraw();

    updateHoveredClips();

    if (event == FlowMouseDown || event == FlowMouseRightDown || event == FlowMouseMiddleDown) {
        std::set<GLClip*> pressClips;
        Stage->computeHitSubtrees(Stage->getStageMousePos(), &pressClips, NULL);

        PressedClips = pressClips;
        MouseDownX = x; MouseDownY = y;
        PressTextFocus = TextFocus;
    }

    if (event == FlowMouseDownInTextEdit) {
        event = FlowMouseDown;
    } else if (event == FlowMouseRightDownInTextEdit) {
        event = FlowMouseRightDown;
    } else if (event == FlowMouseMiddleDownInTextEdit) {
        event = FlowMouseMiddleDown;
    }

    dispatchEventCallbacks(event, 0, NULL);

    if (event == FlowMouseCancel) {
        event = FlowMouseUp;
        dispatchEventCallbacks(event, 0, NULL);
    }

    if (event == FlowMouseUp) {
        std::set<GLClip*> releaseClips;
        Stage->computeHitSubtrees(Stage->getStageMousePos(), &releaseClips, NULL);

        std::vector<GLClip*> to_click(PressedClips.size(), NULL);
        set_intersection(PressedClips.begin(), PressedClips.end(),
                         releaseClips.begin(), releaseClips.end(),
                         to_click.begin());

        dispatchEventCallbacks(to_click, FlowMouseClick, 0, NULL);
        PressedClips.clear();

        // On touch screens release hover:
        if (NoHoverMouse) {
            std::vector<GLClip*> tmp(HoveredClips.begin(), HoveredClips.end());
            for (unsigned i = 0; i < tmp.size(); i++) {
                tmp.at(i)->wipeFlags(GLClip::IsUnderMouseCursor);
                tmp.at(i)->invokeEventCallbacks(FlowMouseLeave, 0, NULL);
            }
            HoveredClips.clear();
        }
    }

    if (DropFocusOnDown && (event == FlowMouseUp || event == FlowMouseRightUp || event == FlowMouseMiddleUp)) {
        // If edit focus hasn't been changed during
        // event processing, release it.
        if (TextFocus && PressTextFocus == TextFocus)
            TextFocus->setFocus(false);
        PressTextFocus = NULL;
    }

    getFlowRunner()->NotifyHostEvent(HostEventUserAction);
}

void GLRenderSupport::dispatchKeyEvent(FlowEvent event, unicode_string key,
                                       bool ctrl, bool shift, bool alt, bool meta, FlowKeyCode code)
{
    if (!code && key.empty()) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    CurEvent = event;

    // Adjust strings to match codes
    switch (code) {
#define SSTR(str) { static const unicode_string v = parseUtf8(str); key = v; }
#define CASE(name, str) case name: SSTR(str); break;
    CASE(FlowKey_Backspace, "backspace");
    CASE(FlowKey_Tab, "tab");
    CASE(FlowKey_Enter, "enter");
    case FlowKey_Shift:
        shift = true; SSTR("shift"); break;
    case FlowKey_Ctrl:
        ctrl = true; SSTR("ctrl"); break;
    case FlowKey_Meta:
        meta = true; SSTR("meta"); break;
    CASE(FlowKey_Escape, "esc");
    CASE(FlowKey_Space, " ");
    CASE(FlowKey_PageUp, "page up");
    CASE(FlowKey_PageDown, "page down");
    CASE(FlowKey_End, "end");
    CASE(FlowKey_Home, "home");
    CASE(FlowKey_Left, "left");
    CASE(FlowKey_Up, "up");
    CASE(FlowKey_Right, "right");
    CASE(FlowKey_Down, "down");
    CASE(FlowKey_Insert, "insert");
    CASE(FlowKey_Delete, "delete");
    CASE(FlowKey_Numpad_Multiply, "*");
    CASE(FlowKey_Numpad_Add, "+");
    CASE(FlowKey_Numpad_Subtract, "-");
    CASE(FlowKey_Numpad_Decimal, ".");
    CASE(FlowKey_Numpad_Divide, "/");
    case FlowKey_F1: case FlowKey_F2: case FlowKey_F3:
    case FlowKey_F4: case FlowKey_F5: case FlowKey_F6:
    case FlowKey_F7: case FlowKey_F8: case FlowKey_F9:
    case FlowKey_F10: case FlowKey_F11: case FlowKey_F12:
    case FlowKey_F13: case FlowKey_F14: case FlowKey_F15:
        {
            char tmp[16];
            int sz = sprintf(tmp, "F%i", code - FlowKey_F1 + 1);
            key = parseUtf8(tmp, sz);
            break;
        }
    case FlowKey_Null:
    case FlowKey_Numpad_0:;
#undef SSTR
#undef CASE
    default: break; // Do nothing
    }

    if (!EventListeners[event].empty())
    {
        RUNNER_VAR = getFlowRunner();
        RUNNER_DefSlotArray(args, 7);

        args[0] = RUNNER->AllocateString(key);
        args[1] = StackSlot::MakeBool(ctrl);
        args[2] = StackSlot::MakeBool(shift);
        args[3] = StackSlot::MakeBool(alt);
        args[4] = StackSlot::MakeBool(meta);
        args[5] = StackSlot::MakeInt(code);
        args[6] = RUNNER->AllocateConstClosure(0, StackSlot::MakeVoid());

        dispatchEventCallbacks(event, 7, args);
    }

    getFlowRunner()->NotifyHostEvent(HostEventUserAction);
}

void GLRenderSupport::dispatchFlowKeyEvent(FlowKeyEvent event)
{
    if (!event.code && event.key.empty()) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    CurEvent = event.event;

    if (!EventListeners[event.event].empty())
    {
        RUNNER_VAR = getFlowRunner();
        RUNNER_DefSlotArray(args, 7);

        args[0] = RUNNER->AllocateString(event.key);
        args[1] = StackSlot::MakeBool(event.ctrl);
        args[2] = StackSlot::MakeBool(event.shift);
        args[3] = StackSlot::MakeBool(event.alt);
        args[4] = StackSlot::MakeBool(event.meta);
        args[5] = StackSlot::MakeInt(event.code);
        args[6] = RUNNER->AllocateConstClosure(0, StackSlot::MakeVoid());

        dispatchEventCallbacks(event.event, 7, args);
    }

    getFlowRunner()->NotifyHostEvent(HostEventUserAction);
}

void GLRenderSupport::dispatchEditStateUpdate(GLClip* clip, int cursor, int sel_start, int sel_end, bool set_text, unicode_string text)
{
    if (!hasNativeWidget(clip)) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    GLTextClip* tclip = flow_native_cast<GLTextClip>(clip);
    if (tclip)
        tclip->setEditState(cursor, sel_start, sel_end, set_text, text);

    getFlowRunner()->NotifyHostEvent(HostEventUserAction);
}

void GLRenderSupport::dispatchVideoNotFound(GLClip* clip)
{
    if (!hasNativeWidget(clip)) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    GLVideoClip *video = flow_native_cast<GLVideoClip>(clip);
    if (video)
        video->notifyNotFound();

    getFlowRunner()->NotifyHostEvent(HostEventResourceLoad);
}

void GLRenderSupport::dispatchVideoDuration(GLClip* clip, int64_t duration)
{
    if (!hasNativeWidget(clip)) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    GLVideoClip* video = flow_native_cast<GLVideoClip>(clip);
    if (video)
        video->notify(GLVideoClip::DurationChange, duration);

    getFlowRunner()->NotifyHostEvent(HostEventMedia);
}

void GLRenderSupport::dispatchVideoSize(GLClip* clip, int width, int height)
{
    if (!hasNativeWidget(clip)) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    GLVideoClip* video = flow_native_cast<GLVideoClip>(clip);
    if (video)
        video->notify(GLVideoClip::SizeChange, width, height);

    getFlowRunner()->NotifyHostEvent(HostEventMedia);
}

void GLRenderSupport::dispatchVideoPosition(GLClip* clip, int64_t position)
{
    if (!hasNativeWidget(clip)) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    GLVideoClip *video = flow_native_cast<GLVideoClip>(clip);
    if (video) {
        video->wipeFlags(GLClip::ChildrenUnchangedFromRender | GLClip::SelfUnchangedFromRender);
        video->notify(GLVideoClip::PositionChange, position);
    }

    getFlowRunner()->NotifyHostEvent(HostEventMedia);
}

void GLRenderSupport::dispatchVideoPlayStatus(GLClip* clip, /*GLVideoClip::Event*/int event)
{
    if (!hasNativeWidget(clip)) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    GLVideoClip *video = flow_native_cast<GLVideoClip>(clip);
    if (video) {
        if (event == GLVideoClip::UserResume) {
            video->notify(GLVideoClip::PlayChange, 1);
        } else if (event == GLVideoClip::UserPause) {
            video->notify(GLVideoClip::PlayChange, 0);
        }

        video->notifyEvent((GLVideoClip::Event)event);
    }

    getFlowRunner()->NotifyHostEvent(HostEventMedia);
}

void GLRenderSupport::dispatchCameraError(GLClip *clip)
{
    if (!hasNativeWidget(clip)) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    GLCamera *camera = flow_native_cast<GLCamera>(clip);
    if (camera)
        camera->notifyError();

    getFlowRunner()->NotifyHostEvent(HostEventResourceLoad);
}

void GLRenderSupport::dispatchCameraStatus(GLClip *clip, /*GLCamera::Event*/int event)
{
    if (!hasNativeWidget(clip)) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    GLCamera *camera = flow_native_cast<GLCamera>(clip);
    if (camera)
    {
        if (event == GLCamera::RecordReady)
            camera->notifyReadyForRecording();
        else
            camera->notifyEvent((GLCamera::Event)event);
    }

    getFlowRunner()->NotifyHostEvent(HostEventMedia);
}

void GLRenderSupport::dispatchPageLoaded(GLClip *clip)
{
    if (!hasNativeWidget(clip)) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    GLWebClip *webclip = flow_native_cast<GLWebClip>(clip);
    if (webclip)
        webclip->notifyPageLoaded();

    getFlowRunner()->NotifyHostEvent(HostEventResourceLoad);
}

void GLRenderSupport::dispatchPageError(GLClip *clip, const std::string &message)
{
    if (!hasNativeWidget(clip)) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    GLWebClip *webclip = flow_native_cast<GLWebClip>(clip);
    if (webclip)
        webclip->notifyError(message);

    getFlowRunner()->NotifyHostEvent(HostEventResourceLoad);
}

void GLRenderSupport::dispatchPageCall(GLClip *clip, const StackSlot &args)
{
    if (!hasNativeWidget(clip)) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    GLWebClip *webclip = flow_native_cast<GLWebClip>(clip);
    if (webclip)
    {
        getFlowRunner()->EvalFunction(webclip->getFlowCallback(), 1, args);
    }

    getFlowRunner()->NotifyHostEvent(HostEventMedia);
}

NativeFunction *GLRenderSupport::MakeNativeFunction(const char *name, int num_args)
{
    TRY_USE_NATIVE_METHOD_NAME(GLRenderSupport, NativeGetUrl, "Native.getUrl", 2);

#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "RenderSupport."

    TRY_USE_NATIVE_METHOD(GLRenderSupport, getPixelsPerCm, 0);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, setHitboxRadius, 1);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, loadFSFont, 2);

    // Camera API
    TRY_USE_NATIVE_METHOD(GLRenderSupport, makeCamera, 10);
    TRY_USE_OBJECT_METHOD(GLCamera, startRecord, 3);
    TRY_USE_OBJECT_METHOD(GLCamera, stopRecord, 1);
    TRY_USE_OBJECT_METHOD(GLCamera, addCameraStatusListener, 2);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, getNumberOfCameras, 0);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, getCameraInfo, 1);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, cameraTakePhoto, 7);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, cameraTakeVideo, 6);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, startRecordAudio, 3);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, stopRecordAudio, 0);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, takeAudioRecord, 0);

    // Root
    TRY_USE_NATIVE_METHOD(GLRenderSupport, makeClip, 0);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, makeTextField, 1);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, makePicture, 7);
    TRY_USE_NATIVE_METHOD_NAME(GLRenderSupport, makePicture4, "makePicture", 4);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, makeVideo, 4);

    TRY_USE_NATIVE_METHOD(GLRenderSupport, makeBlur, 2);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, makeBevel, 9);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, makeDropShadow, 7);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, makeGlow, 5);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, makeShader, 3);

    TRY_USE_NATIVE_METHOD(GLRenderSupport, getCursor, 0);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, setCursor, 1);

    TRY_USE_NATIVE_METHOD(GLRenderSupport, getStage, 0);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, getStageWidth, 0);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, getStageHeight, 0);

    TRY_USE_NATIVE_METHOD(GLRenderSupport, currentClip, 0);

    TRY_USE_NATIVE_METHOD(GLRenderSupport, enableResize, 0);

    TRY_USE_NATIVE_METHOD(GLRenderSupport, deferUntilRender, 1);

    TRY_USE_NATIVE_METHOD(GLRenderSupport, resetFullWindowTarget, 0);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, toggleFullWindow, 1);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, onFullWindow, 1);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, isFullWindow, 0);

    TRY_USE_NATIVE_METHOD(GLRenderSupport, addDrawFrameEventListener, 1);

    TRY_USE_NATIVE_METHOD(GLRenderSupport, addVirtualKeyboardHeightListener, 1);

    TRY_USE_NATIVE_METHOD(GLRenderSupport, setDropCurrentFocusOnDown, 1);

    // Clip
    TRY_USE_OBJECT_METHOD(GLClip, addChild, 2);
    TRY_USE_OBJECT_METHOD(GLClip, addChildAt, 3);
    TRY_USE_OBJECT_METHOD(GLClip, removeChild, 2);
    TRY_USE_OBJECT_METHOD(GLClip, getClipChildren, 1);

    TRY_USE_OBJECT_METHOD(GLClip, getGraphics, 1);

    TRY_USE_OBJECT_METHOD(GLClip, setClipMask, 2);

    TRY_USE_OBJECT_METHOD(GLClip, setClipX, 2);
    TRY_USE_OBJECT_METHOD(GLClip, setClipY, 2);
    TRY_USE_OBJECT_METHOD(GLClip, setClipScaleX, 2);
    TRY_USE_OBJECT_METHOD(GLClip, setClipScaleY, 2);
    TRY_USE_OBJECT_METHOD(GLClip, setClipRotation, 2);
    TRY_USE_OBJECT_METHOD(GLClip, setClipOrigin, 3);
    TRY_USE_OBJECT_METHOD(GLClip, setClipAlpha, 2);
    TRY_USE_OBJECT_METHOD(GLClip, setClipCallstack, 2);
    TRY_USE_OBJECT_METHOD(GLClip, setClipDebugInfo, 3);

    TRY_USE_OBJECT_METHOD(GLClip, addEventListener, 3);
    TRY_USE_OBJECT_METHOD(GLClip, emitMouseEvent, 4);
    TRY_USE_OBJECT_METHOD(GLClip, emitKeyEvent, 8);
    TRY_USE_OBJECT_METHOD(GLClip, addKeyEventListener, 3);
    TRY_USE_OBJECT_METHOD(GLClip, addMouseWheelEventListener, 2);
    TRY_USE_OBJECT_METHOD(GLClip, addFinegrainMouseWheelEventListener, 2);

    TRY_USE_OBJECT_METHOD(GLClip, getMouseX, 1);
    TRY_USE_OBJECT_METHOD(GLClip, getMouseY, 1);
    TRY_USE_OBJECT_METHOD(GLClip, hittest, 3);
    TRY_USE_OBJECT_METHOD(GLClip, getTouchPoints, 1);

    TRY_USE_OBJECT_METHOD(GLClip, addFilters, 2);

    TRY_USE_OBJECT_METHOD(GLClip, setAccessAttributes, 2);
    TRY_USE_OBJECT_METHOD(GLClip, setAccessCallback, 2);
    TRY_USE_OBJECT_METHOD(GLClip, setScrollRect, 5);
    TRY_USE_OBJECT_METHOD(GLClip, setClipVisible, 2);
    TRY_USE_OBJECT_METHOD(GLClip, setClipRenderable, 2);
    TRY_USE_OBJECT_METHOD(GLClip, getClipVisible, 1);

    TRY_USE_OBJECT_METHOD(GLClip, setFocus, 2);
    TRY_USE_OBJECT_METHOD(GLClip, getFocus, 1);
    TRY_USE_OBJECT_METHOD(GLClip, setTabIndex, 2);
    TRY_USE_OBJECT_METHOD(GLClip, getGlobalTransform, 1);

    TRY_USE_OBJECT_METHOD(GLClip, setFullWindowTarget, 1);

    // Graphics
    TRY_USE_NATIVE_STATIC(GLGraphics, makeMatrix, 5);

    TRY_USE_OBJECT_METHOD(GLGraphics, setLineStyle, 4);
    TRY_USE_OBJECT_METHOD(GLGraphics, moveTo, 3);
    TRY_USE_OBJECT_METHOD(GLGraphics, lineTo, 3);
    TRY_USE_OBJECT_METHOD(GLGraphics, curveTo, 5);
    TRY_USE_OBJECT_METHOD(GLGraphics, beginFill, 3);
    TRY_USE_OBJECT_METHOD(GLGraphics, endFill, 1);
    TRY_USE_OBJECT_METHOD(GLGraphics, beginGradientFill, 6);
    TRY_USE_OBJECT_METHOD(GLGraphics, beginLineGradientFill, 5);
    TRY_USE_OBJECT_METHOD(GLGraphics, setLineGradientStroke, 5);
    TRY_USE_OBJECT_METHOD(GLGraphics, clearGraphics, 1);

    // Text Clip
    TRY_USE_OBJECT_METHOD(GLTextClip, setTextInput, 1);
    TRY_USE_OBJECT_METHOD(GLTextClip, setTextAndStyle, 11);
    TRY_USE_OBJECT_METHOD(GLTextClip, setTextDirection, 2);

    TRY_USE_OBJECT_METHOD_NAME(GLTextClip, setTextAndStyle9, "setTextAndStyle", 9);

    TRY_USE_OBJECT_METHOD(GLTextClip, setMultiline, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, setWordWrap, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, setAutoAlign, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, setAdvancedText, 4);
    TRY_USE_OBJECT_METHOD(GLTextClip, setReadOnly, 2);

    TRY_USE_OBJECT_METHOD(GLTextClip, getTextMetrics, 1);
    TRY_USE_OBJECT_METHOD(GLTextClip, getScrollV, 1);
    TRY_USE_OBJECT_METHOD(GLTextClip, getBottomScrollV, 1);
    TRY_USE_OBJECT_METHOD(GLTextClip, getNumLines, 1);
    TRY_USE_OBJECT_METHOD(GLTextClip, setScrollV, 2);

    TRY_USE_OBJECT_METHOD(GLTextClip, getTextFieldCharXPosition, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, findTextFieldCharByPosition, 3)
    TRY_USE_OBJECT_METHOD(GLTextClip, getTextFieldWidth, 1);
    TRY_USE_OBJECT_METHOD(GLTextClip, getTextFieldHeight, 1);
    TRY_USE_OBJECT_METHOD(GLTextClip, setTextFieldWidth, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, setTextFieldHeight, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, setTextFieldCropWords, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, setTextFieldCursorColor, 3);
    TRY_USE_OBJECT_METHOD(GLTextClip, setTextFieldCursorWidth, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, setTextFieldInterlineSpacing, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, setLineHeightPercent, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, setTextNeedBaseline, 2);

    TRY_USE_OBJECT_METHOD(GLTextClip, getContent, 1);
    TRY_USE_OBJECT_METHOD(GLTextClip, getCursorPosition, 1);
    TRY_USE_OBJECT_METHOD(GLTextClip, getSelectionStart, 1);
    TRY_USE_OBJECT_METHOD(GLTextClip, getSelectionEnd, 1);
    TRY_USE_OBJECT_METHOD(GLTextClip, setSelection, 3);
    TRY_USE_OBJECT_METHOD(GLTextClip, setTextInputType, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, setMaxChars, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, addTextInputFilter, 2);
    TRY_USE_OBJECT_METHOD(GLTextClip, addTextInputKeyEventFilter, 3);

    // Video Clip
    TRY_USE_OBJECT_METHOD(GLVideoClip, playVideo, 4);
    TRY_USE_OBJECT_METHOD(GLVideoClip, playVideoFromMediaStream, 3);
    TRY_USE_OBJECT_METHOD_NAME(GLVideoClip, playVideo2, "playVideo", 2);
    TRY_USE_OBJECT_METHOD(GLVideoClip, seekVideo, 2);
    TRY_USE_OBJECT_METHOD(GLVideoClip, pauseVideo, 1);
    TRY_USE_OBJECT_METHOD(GLVideoClip, resumeVideo, 1);
    TRY_USE_OBJECT_METHOD(GLVideoClip, closeVideo, 1);
    TRY_USE_OBJECT_METHOD(GLVideoClip, getVideoPosition, 1);
    TRY_USE_OBJECT_METHOD(GLVideoClip, setVideoVolume, 2);
    TRY_USE_OBJECT_METHOD(GLVideoClip, setVideoPlaybackRate, 2);
    TRY_USE_OBJECT_METHOD(GLVideoClip, setVideoTimeRange, 3);
    TRY_USE_OBJECT_METHOD(GLVideoClip, setVideoLooping, 2);
    TRY_USE_OBJECT_METHOD(GLVideoClip, setVideoControls, 2);
    TRY_USE_OBJECT_METHOD(GLVideoClip, setVideoSubtitle, 17);
    TRY_USE_OBJECT_METHOD(GLVideoClip, addStreamStatusListener, 2);

    // Web Clip
    TRY_USE_NATIVE_METHOD(GLRenderSupport, makeWebClip, 7);
    TRY_USE_OBJECT_METHOD(GLWebClip, webClipHostCall, 3);
    TRY_USE_OBJECT_METHOD(GLWebClip, webClipEvalJS, 3);
    TRY_USE_OBJECT_METHOD(GLWebClip, setWebClipZoomable, 2);
    TRY_USE_OBJECT_METHOD(GLWebClip, setWebClipDomains, 2);

    TRY_USE_NATIVE_METHOD(GLRenderSupport, addGestureListener, 2);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, setInterfaceOrientation, 1);
    TRY_USE_NATIVE_METHOD(GLRenderSupport, setGlobalZoomEnabled, 1);

    return NULL;
}

void GLRenderSupport::GetTargetTokens(std::set<std::string> &tokens)
{
    NativeMethodHost::GetTargetTokens(tokens);
    tokens.insert("gui");
    tokens.insert("opengl");
    tokens.insert(stl_sprintf("dpi=%d", DisplayDPI));

    if (NoHoverMouse) {
        tokens.insert("mobile");
    } else {
        tokens.insert(stl_sprintf("density=%f", DisplayDensity));
    }
}

StackSlot GLRenderSupport::NativeGetUrl(RUNNER_ARGS)
{
    RUNNER_PopArgs2(url, target);
    RUNNER_CheckTag2(TString, url, target);

    doOpenUrl(RUNNER->GetString(url), RUNNER->GetString(target));

    RETVOID;
}

StackSlot GLRenderSupport::getPixelsPerCm(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeDouble(PixelsPerCm);
}

StackSlot GLRenderSupport::setHitboxRadius(RUNNER_ARGS)
{
    RUNNER_PopArgs1(radius);
    RUNNER_CheckTag(TDouble, radius);
    MouseRadius = (float)radius.GetDouble();
    return StackSlot::MakeBool(true);
}

StackSlot GLRenderSupport::loadFSFont(RUNNER_ARGS)
{
    RUNNER_PopArgs2(fontname, url);
    RUNNER_CheckTag2(TString, fontname, url);
    
    this->loadNativeFont(encodeUtf8(RUNNER->GetString(url)), encodeUtf8(RUNNER->GetString(fontname)), std::vector<unicode_string>());
    
    RETVOID;
}

StackSlot GLRenderSupport::makeClip(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return RUNNER->AllocNative(new GLClip(this));
}

StackSlot GLRenderSupport::makeTextField(RUNNER_ARGS)
{
    RUNNER_PopArgs1(fontfamily);
    RUNNER_CheckTag(TString, fontfamily);
    return RUNNER->AllocNative(new GLTextClip(this));
}

StackSlot GLRenderSupport::makePicture4(RUNNER_ARGS)
{
    RUNNER_CopyArgArray(newargs, 4, 1);
    newargs[4] = StackSlot::MakeBool(false);
    return makePicture(RUNNER, newargs);
}

StackSlot GLRenderSupport::makePicture(RUNNER_ARGS)
{
    RUNNER_PopArgs7(url_str, cache, metrix_cb, error_cb, only_download, altText, headers);
    RUNNER_CheckTag2(TString, url_str, altText);
    RUNNER_CheckTag2(TBool, cache, only_download);
    RUNNER_DefSlots1(retval);
    RUNNER_CheckTag1(TArray, headers)

    unicode_string url = RUNNER->GetString(url_str);

    HttpRequest::T_SMap map_headers;

    for (unsigned i = 0; i < RUNNER->GetArraySize(headers); i++) {
        const StackSlot &header_slot = RUNNER->GetArraySlot(headers, i);
        RUNNER_CheckTag(TArray, header_slot);

        unicode_string name     = RUNNER->GetString(RUNNER->GetArraySlot(header_slot, 0));
        unicode_string value    = RUNNER->GetString(RUNNER->GetArraySlot(header_slot, 1));

        map_headers[name] = value;
    }

    GLPictureClip *pclip = new GLPictureClip(this, url);
    retval = RUNNER->AllocNative(pclip);

    pclip->setCallbacks(metrix_cb, error_cb, only_download.GetBool());

    // Try using an already loaded picture
    T_PictureCache::iterator cit = PictureCache.find(url);
    if (cit != PictureCache.end()) {
        GLTextureBitmap::Ptr img = cit->second.lock();
        if (img) {
            pclip->setImage(img);
            return retval;
        } else {
            PictureCache.erase(cit);
        }
    }

    // Resolve if only download set & already downloaded
    if (pclip->isOnlyDownload() && DownloadedPictures.count(url)) {
        pclip->setDownloaded();
        return retval;
    }

    // Queue a request
    std::vector<GLPictureClip*> &pics = PendingPictures[url];
    bool already_pending = !pics.empty();

    pics.push_back(pclip);

    if (already_pending)
        return retval;

    if (!loadPicture(url, map_headers, cache.GetBool()))
        resolvePictureError(url, parseUtf8("loadPicture failed"));

    return retval;
}

void GLRenderSupport::removePictureFromPending(GLPictureClip *clip)
{
    std::vector<GLPictureClip*> &pics = PendingPictures[clip->getName()];
    std::vector<GLPictureClip*>::iterator clipIterator = std::find(pics.begin(), pics.end(), clip);
    if (clipIterator != pics.end()) {
        pics.erase(clipIterator);
        if (pics.empty()) {
            abortPictureLoading(clip->getName());
        }
    }
}

bool GLRenderSupport::resolvePictureError(unicode_string url, unicode_string error)
{
    std::vector<GLPictureClip*> copy;
    copy.swap(PendingPictures[url]);
    PendingPictures.erase(url);

    if (!copy.empty()) {
        WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

        RUNNER_VAR = getFlowRunner();
        RUNNER_RegisterNativeRoot(std::vector<GLPictureClip*>, copy);

        for (unsigned i = 0; i < copy.size(); i++)
            copy[i]->reportError(error);

        getFlowRunner()->NotifyHostEvent(HostEventResourceLoad);

        return true;
    }

    return false;
}

bool GLRenderSupport::resolvePictureDownloaded(unicode_string url)
{
    std::vector<GLPictureClip*> &pending = PendingPictures[url];

    for (unsigned i = 0; i < pending.size(); i++)
        if (!pending[i]->isOnlyDownload())
            return false;

    // All pending pictures are OnlyDownload
    std::vector<GLPictureClip*> copy;
    copy.swap(pending);
    PendingPictures.erase(url);

    DownloadedPictures.insert(url);

    if (!copy.empty()) {
        WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

        RUNNER_VAR = getFlowRunner();
        RUNNER_RegisterNativeRoot(std::vector<GLPictureClip*>, copy);

        for (unsigned i = 0; i < copy.size(); i++)
            copy[i]->setDownloaded();

        getFlowRunner()->NotifyHostEvent(HostEventResourceLoad);
    }

    return true;
}

bool GLRenderSupport::resolvePicture(unicode_string url, shared_ptr<GLTextureBitmap> image)
{
    if (image->getSize().x <= 0 || image->getSize().y <= 0)
        return resolvePictureError(url, parseUtf8("Empty picture."));

    std::vector<GLPictureClip*> copy;
    copy.swap(PendingPictures[url]);
    PendingPictures.erase(url);

    DownloadedPictures.insert(url);
    PictureCache[url] = image;

    if (!copy.empty()) {
        WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

        RUNNER_VAR = getFlowRunner();
        RUNNER_RegisterNativeRoot(std::vector<GLPictureClip*>, copy);

        for (unsigned i = 0; i < copy.size(); i++)
            copy[i]->setImage(image);

        getFlowRunner()->NotifyHostEvent(HostEventResourceLoad);

        return true;
    }

    return false;
}

bool GLRenderSupport::resolvePicture(unicode_string url, std::string filename)
{
    if (resolvePictureDownloaded(url))
        return true;

    StaticBuffer data;
    if (!data.load_file(filename))
        return resolvePictureError(url, parseUtf8("Image file not found: ") + url);

    GLTextureBitmap::Ptr bmp = loadImageAuto(data.data(), data.size(), 256*256);

    if (!bmp)
        return resolvePictureError(url, parseUtf8("Could not decode image: ") + url);

    if (bmp->isStub())
        PictureFiles[url] = filename;

    return resolvePicture(url, bmp);
}

bool GLRenderSupport::loadStubPicture(unicode_string url, shared_ptr<GLTextureBitmap> &img)
{
    if (!img || !img->isBitmap() || !img->isStub() || !PictureFiles.count(url))
        return false;

    StaticBuffer data;
    if (!data.load_file(PictureFiles[url]))
        return false;

    GLTextureBitmap::Ptr bmp = loadImageAuto(data.data(), data.size());

    if (!bmp)
    {
        cerr << "Could not lazy-load picture: " << PictureFiles[url] << std::endl;
        return false;
    }

    // Supply the image data
    static_cast<GLTextureBitmap*>(img.get())->share(bmp);

    return true;
}

bool GLRenderSupport::resolvePicture(unicode_string url, const uint8_t *data, unsigned size)
{
    GLTextureBitmap::Ptr bmp = loadImageAuto(data, size);

    if (!bmp)
        return resolvePictureError(url, parseUtf8("Could not decode image: ") + url);

    return resolvePicture(url, bmp);
}

void GLRenderSupport::updateAccessibleClips()
{
    accessible_clips.clear();
    doUpdateAccessibleClips(Stage, accessible_clips, true);
}

void GLRenderSupport::doUpdateAccessibleClips(GLClip * clip, std::vector<GLClip*> & accessible_clips, bool parent_enabled)
{
    if (!clip->isVisible()) return;
    bool enabled = parent_enabled;

    if (!clip->getAccessibilityAttributes().empty()) {
        enabled = !(!parent_enabled || !clip->getAccessEnabled());
        clip->setAccessEnabled(enabled);
        accessible_clips.push_back(clip);
    }

    const std::vector<GLClip*> childs = clip->getChildren();
    for (std::vector<GLClip*>::const_iterator ch_it = childs.begin(); ch_it != childs.end(); ++ch_it)
        doUpdateAccessibleClips(*ch_it, accessible_clips, enabled);
}

StackSlot GLRenderSupport::getNumberOfCameras(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    int cams = doGetNumberOfCameras();

    return StackSlot::MakeInt(cams);
}

StackSlot GLRenderSupport::getCameraInfo(RUNNER_ARGS)
{
    RUNNER_PopArgs1(id);
    RUNNER_CheckTag1(TInt, id);

    std::string info = doGetCameraInfo(id.GetInt());
    return RUNNER->AllocateString(info.data());
}

StackSlot GLRenderSupport::cameraTakePhoto(RUNNER_ARGS)
{
    RUNNER_PopArgs7(cameraId, additionalInfo, desiredWidth, desiredHeight, compressQuality, fileName, fitMode);
    RUNNER_CheckTag5(TInt, cameraId, desiredWidth, desiredHeight, compressQuality, fitMode);
    RUNNER_CheckTag2(TString, additionalInfo, fileName);

    doCameraTakePhoto(cameraId.GetInt(), encodeUtf8(RUNNER->GetString(additionalInfo)), desiredWidth.GetInt(), desiredHeight.GetInt(), compressQuality.GetInt(),
                      encodeUtf8(RUNNER->GetString(fileName)), fitMode.GetInt());

    RETVOID;
}

StackSlot GLRenderSupport::cameraTakeVideo(RUNNER_ARGS)
{
    RUNNER_PopArgs6(cameraId, additionalInfo, duration, size, quality, fileName);
    RUNNER_CheckTag4(TInt, cameraId, duration, size, quality);
    RUNNER_CheckTag2(TString, additionalInfo, fileName);

    doCameraTakeVideo(cameraId.GetInt(), encodeUtf8(RUNNER->GetString(additionalInfo)), duration.GetInt(), size.GetInt(), quality.GetInt(),
                      encodeUtf8(RUNNER->GetString(fileName)));

    RETVOID;
}

StackSlot GLRenderSupport::startRecordAudio(RUNNER_ARGS)
{
    RUNNER_PopArgs3(additionalInfo, fileName, duration);
    RUNNER_CheckTag2(TString, additionalInfo, fileName);
    RUNNER_CheckTag1(TInt, duration);

    doStartRecordAudio(encodeUtf8(RUNNER->GetString(additionalInfo)), encodeUtf8(RUNNER->GetString(fileName)), duration.GetInt());

    RETVOID;
}

StackSlot GLRenderSupport::stopRecordAudio(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    doStopRecordAudio();

    RETVOID;
}

StackSlot GLRenderSupport::takeAudioRecord(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    doTakeAudioRecord();

    RETVOID;
}

StackSlot GLRenderSupport::makeVideo(RUNNER_ARGS)
{
    RUNNER_PopArgs4(metricsFn, playFn, durationFn, positionFn);

    return RUNNER->AllocNative(new GLVideoClip(this, metricsFn, playFn, durationFn, positionFn));
}

StackSlot GLRenderSupport::makeBlur(RUNNER_ARGS)
{
    RUNNER_PopArgs2(radius, spread);
    RUNNER_CheckTag2(TDouble, radius, spread);

    return RUNNER->AllocNative(new GLBlurFilter(this, radius.GetDouble(), spread.GetDouble()));
}

StackSlot GLRenderSupport::makeBevel(RUNNER_ARGS)
{
    RUNNER_PopArgs9(angle, distance, radius, spread, color1, alpha1, color2, alpha2, inner);
    RUNNER_CheckTag6(TDouble, angle, distance, radius, spread, alpha1, alpha2);
    RUNNER_CheckTag2(TInt, color1, color2);
    RUNNER_CheckTag(TBool, inner);

    GLBevelFilter *f = new GLBevelFilter(this, flowAngledVector(angle, distance),
                                         flowToColor(color1, alpha1, true),
                                         flowToColor(color2, alpha2, true),
                                         inner.GetBool(), radius.GetDouble(), spread.GetDouble());
    return RUNNER->AllocNative(f);
}

StackSlot GLRenderSupport::makeDropShadow(RUNNER_ARGS)
{
    RUNNER_PopArgs7(angle, distance, radius, spread, color_val, alpha, inner);
    RUNNER_CheckTag5(TDouble, angle, distance, radius, spread, alpha);
    RUNNER_CheckTag(TInt, color_val);
    RUNNER_CheckTag(TBool, inner);

    GLDropShadowFilter *f = new GLDropShadowFilter(this, flowAngledVector(angle, distance),
                                                   flowToColor(color_val, alpha, true),
                                                   inner.GetBool(), radius.GetDouble(), spread.GetDouble());
    return RUNNER->AllocNative(f);
}

StackSlot GLRenderSupport::makeGlow(RUNNER_ARGS)
{
    RUNNER_PopArgs5(radius, spread, color_val, alpha, inner);
    RUNNER_CheckTag3(TDouble, radius, spread, alpha);
    RUNNER_CheckTag(TInt, color_val);
    RUNNER_CheckTag(TBool, inner);

    // Experiments have shown that glow is identical to shadow with zero offset.
    GLDropShadowFilter *f = new GLDropShadowFilter(this, vec2(0.0f),
                                                   flowToColor(color_val, alpha, false),
                                                   inner.GetBool(), radius.GetDouble(), spread.GetDouble());
    return RUNNER->AllocNative(f);
}

StackSlot GLRenderSupport::makeShader(RUNNER_ARGS)
{
    RUNNER_PopArgs3(vertex, fragment, uniform);
    RUNNER_CheckTag3(TArray, vertex, fragment, uniform);

    std::vector<std::string> vertex_vector;

    for (unsigned i = 0; i < RUNNER->GetArraySize(vertex); i++) {
        const StackSlot &vertex_slot = RUNNER->GetArraySlot(vertex, i);
        RUNNER_CheckTag(TString, vertex_slot);

        vertex_vector.push_back(encodeUtf8(RUNNER->GetString(vertex_slot)));
    }

    std::vector<std::string> fragment_vector;

    for (unsigned i = 0; i < RUNNER->GetArraySize(fragment); i++) {
        const StackSlot &fragment_slot = RUNNER->GetArraySlot(fragment, i);
        RUNNER_CheckTag(TString, fragment_slot);

        fragment_vector.push_back(encodeUtf8(RUNNER->GetString(fragment_slot)));
    }

    std::vector<ShaderUniform> uniform_vector;

    for (unsigned i = 0; i < RUNNER->GetArraySize(uniform); i++) {
        const StackSlot &uniform_slot = RUNNER->GetArraySlot(uniform, i);
        RUNNER_CheckTag(TArray, uniform_slot);

        uniform_vector.push_back(
            ShaderUniform(
                encodeUtf8(RUNNER->GetString(RUNNER->GetArraySlot(uniform_slot, 0))),
                encodeUtf8(RUNNER->GetString(RUNNER->GetArraySlot(uniform_slot, 1))),
                encodeUtf8(RUNNER->GetString(RUNNER->GetArraySlot(uniform_slot, 2)))
            )
        );
    }

    // Experiments have shown that glow is identical to shadow with zero offset.
    GLShaderFilter *f = new GLShaderFilter(this, vertex_vector, fragment_vector, uniform_vector);
    return RUNNER->AllocNative(f);
}


StackSlot GLRenderSupport::getCursor(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    return RUNNER->AllocateString(cursor);
}

StackSlot GLRenderSupport::setCursor(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cursor_str);
    RUNNER_CheckTag(TString, cursor_str);

    doSetCursor(encodeUtf8(user_cursor = cursor = RUNNER->GetString(cursor_str)));

    RETVOID;
}

void GLRenderSupport::adviseCursor(unicode_string name)
{
    if (user_cursor == STR_auto && cursor != name)
        doSetCursor(encodeUtf8(cursor = name));
}

StackSlot GLRenderSupport::getStage(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return RUNNER->AllocNative(Stage);
}

StackSlot GLRenderSupport::getStageWidth(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeDouble(Width);
}

StackSlot GLRenderSupport::getStageHeight(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeDouble(Height);
}

StackSlot GLRenderSupport::currentClip(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return RUNNER->AllocNative(Stage);
}

StackSlot GLRenderSupport::enableResize(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    doEnableResize(true);
    RETVOID;
}

StackSlot GLRenderSupport::makeWebClip(RUNNER_ARGS)
{
    RUNNER_PopArgs6(url, domain, use_cache, reload_block, cb, ondone);
    RUNNER_CheckTag2(TString, url, domain);
    RUNNER_CheckTag2(TBool, use_cache, reload_block);
    return RUNNER->AllocNative(new GLWebClip(this, ivec2(100, 100), RUNNER->GetString(url), use_cache.GetBool(), cb, ondone));
}

StackSlot GLRenderSupport::makeCamera(RUNNER_ARGS)
{
    RUNNER_PopArgs8(uri, camID, camWidth, camHeight, camFps, vidWidth, vidHeight, recordMode);
    RUNNER_CheckTag1(TString, uri);
    RUNNER_CheckTag6(TInt, camID, camWidth, camHeight, vidWidth, vidHeight, recordMode);
    RUNNER_CheckTag1(TDouble, camFps);

    StackSlot &cbOnReadyForRecording = RUNNER_ARG(8);
    StackSlot &cbOnFailed = RUNNER_ARG(9);

    RUNNER_DefSlots1(ret_arr);

    int ncamFps = round(camFps.GetDouble());
    ret_arr = RUNNER->AllocateArray(2);

    GLCamera *cam = new GLCamera(this, ivec2(vidWidth.GetInt(), vidHeight.GetInt()), camID.GetInt(), camWidth.GetInt(), camHeight.GetInt(), ncamFps, recordMode.GetInt(), cbOnReadyForRecording, cbOnFailed);

    RUNNER->SetArraySlot(ret_arr, 0, cam->getFlowValue());
    RUNNER->SetArraySlot(ret_arr, 1, cam->getFlowValue());

    return ret_arr;
}

bool GLRenderSupport::dispatchGestureEvent(FlowEvent event, FlowGestureState state, float p1, float p2, float p3, float p4)
{
    T_Listeners * listeners = NULL;
    if (FlowSwipeEvent == event) listeners = &SwipeListeners;
    else if (FlowPinchEvent == event) listeners = &PinchListeners;
    else if (FlowPanEvent == event) listeners = &PanListeners;

    // Flow code should receive coordinates/velocity relative to Stage
    const vec3 & pos = Stage->makeStageFromGlobal(vec2(p1, p2));
    p1 = pos.x; p2 = pos.y;

    if ((FlowSwipeEvent == event || FlowPanEvent == event) && isScreenRotated()) {
        float tmp = p3; p3 = p4; p4 = tmp;
        if (ScreenRotation == FlowRotation90) p4 = -p4;
        else if (ScreenRotation == FlowRotation270) p3 = -p3;
    }

    bool prevent_default = false;
    RUNNER_VAR = getFlowRunner();
    if (NULL != listeners) {
        for (unsigned int it = 0; it < listeners->size(); ++it) {
            StackSlot args[] = {StackSlot::MakeInt(state), StackSlot::MakeDouble(p1), StackSlot::MakeDouble(p2), StackSlot::MakeDouble(p3), StackSlot::MakeDouble(p4)};
            const StackSlot & result = RUNNER->EvalFunctionArr(RUNNER->LookupRoot((*listeners)[it]), 5, args);
            prevent_default |= (result.IsBool() && result.GetBool());
        }
    }

    RUNNER->NotifyHostEvent(NativeMethodHost::HostEventUserAction);

    //getFlowRunner()->flow_out << "dispatchGesture ret = " << ( prevent_default ? "true" : "false" ) << endl;

    return prevent_default;
}

void GLRenderSupport::dispatchWheelEvent(float delta)
{
    ByteCodeRunner * rnr = getFlowRunner();

    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(args, 1);

    args[0] = StackSlot::MakeDouble(delta);

    dispatchEventCallbacks(FlowMouseWheel, 1, args);
    rnr->NotifyHostEvent(NativeMethodHost::HostEventUserAction);
}

void GLRenderSupport::dispatchFineGrainWheelEvent(float deltax, float deltay)
{
    ByteCodeRunner * rnr = getFlowRunner();

    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(args, 2);

    args[0] = StackSlot::MakeDouble(deltax);
    args[1] = StackSlot::MakeDouble(deltay);

    dispatchEventCallbacks(FlowFineGrainMouseWheel, 2, args);
    rnr->NotifyHostEvent(NativeMethodHost::HostEventUserAction);
}

StackSlot GLRenderSupport::removeListener(RUNNER_ARGS, void * data)
{
    // TO DO: lock for multithreading??
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    int cb_root = slot[0].GetInt();
    T_Listeners * listeners = (T_Listeners*)data;
    if (NULL != listeners) listeners->erase(std::find(listeners->begin(), listeners->end(), cb_root));
    RUNNER->ReleaseRoot(cb_root);

    RETVOID;
}

GLClip* GLRenderSupport::getCurrentFocus()
{
    if (CurrentFocus != NULL)
        return CurrentFocus;
    else
        return NULL;
}

GLClip* getMinTabIdxClip(GLClip *first, GLClip *second)
{
    if (first && second) {
        if (first->getTabIndex() < second->getTabIndex())
            return first;
        else if (first->getTabIndex() != second->getTabIndex())
            return second;
        else
            return NULL;
    } else if (!first) {
        return second;
    } else {
        return first;
    }
}

GLClip* getMaxTabIdxClip(GLClip *first, GLClip *second)
{
    if (first && second) {
        if (first->getTabIndex() > second->getTabIndex())
            return first;
        else if (first->getTabIndex() != second->getTabIndex())
           return second;
        else
            return NULL;
    } else if (!first) {
        return second;
    } else {
        return first;
    }
}

void GLRenderSupport::tryFocusNextClip(GLClip *focused, bool direct)
{
   if (focused == CurrentFocus)
    {
        if (CurrentFocus)
            CurrentFocus->setFocus(false);

        GLClip* next_tab_clip = NULL;
        T_TabIndexClips::iterator it = tabIndexedClips.begin();

        while (it != tabIndexedClips.end())
        {
            if ((*it)->isVisible() && (*it)->accessFocusEnabled() && (*it) != focused)
            {
                GLClip *next = NULL;
                if (direct) {
                    next = getMaxTabIdxClip(getMinTabIdxClip(*it, next_tab_clip), focused);
                } else {
                    next = getMinTabIdxClip(getMaxTabIdxClip(*it, next_tab_clip), focused);
                }

                if (next && next != focused)
                    next_tab_clip = next;
            }

            it++;
        }

        if (next_tab_clip != focused)
        {
            if (next_tab_clip)
                next_tab_clip->setFocus(true);
        }

    }
}

StackSlot GLRenderSupport::addGestureListener(RUNNER_ARGS)
{
    RUNNER_PopArgs2(gesture, cb);
    RUNNER_CheckTag1(TString, gesture);

    std::string gesture_type = encodeUtf8(RUNNER->GetString(gesture));

    int cb_root = RUNNER->RegisterRoot(cb);

    T_Listeners * listeners = NULL;

    if (gesture_type == "swipe") listeners = &SwipeListeners;
    else if (gesture_type == "pinch") listeners = &PinchListeners;
    else if (gesture_type == "pan") listeners = &PanListeners;

    if (NULL != listeners) listeners->push_back(cb_root);

    return RUNNER->AllocateNativeClosure(removeListener, "addGestureListener$disposer", 0, listeners,
                                         1, StackSlot::MakeInt(cb_root));
}

StackSlot GLRenderSupport::setInterfaceOrientation(RUNNER_ARGS)
{
    RUNNER_PopArgs1(orientation);
    RUNNER_CheckTag(TString, orientation);

    doSetInterfaceOrientation(encodeUtf8(RUNNER->GetString(orientation)));

    RETVOID;
}

StackSlot GLRenderSupport::setGlobalZoomEnabled(RUNNER_ARGS)
{
    RUNNER_PopArgs1(enabled);
    RUNNER_CheckTag(TBool, enabled);

    GlobalZoomEnabled = enabled.GetBool();
    if (!GlobalZoomEnabled) setGlobalScale(0.5f, 0.5f, 1.0f);

    RETVOID;
}

StackSlot GLRenderSupport::deferUntilRender(RUNNER_ARGS)
{
    interruptibleDeferUntilRender(RUNNER, pRunnerArgs__);

    RETVOID;
}

StackSlot GLRenderSupport::removeDeferredFunction(RUNNER_ARGS, void *data)
{
    RUNNER_PopArgs1(cb_root);
    RUNNER_CheckTag(TInt, cb_root);

    GLRenderSupport *instance = reinterpret_cast<GLRenderSupport*>(data);
    std::remove(instance->RenderDeferredFunctions.begin(), instance->RenderDeferredFunctions.end(), cb_root.GetInt());

    RETVOID;
}


StackSlot GLRenderSupport::interruptibleDeferUntilRender(RUNNER_ARGS)
{
    RUNNER_PopArgs1(fn);
    int cb_root = RUNNER->RegisterRoot(fn);
    RenderDeferredFunctions.push_back(cb_root);
    doRequestRedraw();

    return RUNNER->AllocateNativeClosure(ByteCodeRunner::RemoveDeferredAction, "InterruptibleTimer$disposer", 0, this, 1, cb_root);
}

GLClip *fullWindowClipParent = NULL;
std::vector<int> hiddenClipsIds;
StackSlot GLRenderSupport::toggleFullWindow(RUNNER_ARGS)
{
    RUNNER_PopArgs1(fw);
    RUNNER_CheckTag(TBool, fw);

    toggleFullWindow(fw.GetBool());

    RETVOID;
}

void GLRenderSupport::toggleFullWindow(bool fw)
{
    if (FullWindowTarget != NULL && fw != IsFullWindow) {
        FullWindowPending = false;
        doRequestRedraw();

        if (fw) {
            fullWindowClipParent = FullWindowTarget->getParent();

            if (fullWindowClipParent != NULL) {
                const auto& children = Stage->getChildren();

                if (children.size() != 0) {
                    for (auto child : children) {
                        if (child->isVisible()) {
                            hiddenClipsIds.push_back(child->getFlowValue().GetNativeValId());
                            child->setVisible(false);
                        }
                    }
                    Stage->addChild(FullWindowTarget);

                    notifyFullWindow(true);
                } else { // Stage is not ready yet
                    FullWindowPending = true;
                }
            } else {
                FullWindowPending = true;
            }
        } else {
            if (fullWindowClipParent != NULL && hiddenClipsIds.size() != 0) {
                const auto& children = Stage->getChildren();
                for (auto child : children) {
                    if (find(hiddenClipsIds.begin(), hiddenClipsIds.end(), child->getFlowValue().GetNativeValId()) != hiddenClipsIds.end()) {
                        child->setVisible(true);
                    }
                }
                hiddenClipsIds.clear();

                if (!FullWindowTarget->isDestroyed() && !fullWindowClipParent->isDestroyed())
                    fullWindowClipParent->addChild(FullWindowTarget);

                notifyFullWindow(false);
            }
        }
    }
}

void GLRenderSupport::notifyFullWindow(bool fw)
{
    if (IsFullWindow != fw) {
        IsFullWindow = fw;
        RUNNER_VAR = getFlowRunner();
        for (unsigned int it = 0; it < FullWindowListeners.size(); ++it) {
            RUNNER->EvalFunction(RUNNER->LookupRoot(FullWindowListeners[it]), 1, StackSlot::MakeBool(fw));
        }
    }
}

StackSlot GLRenderSupport::onFullWindow(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_root = RUNNER->RegisterRoot(cb);

    FullWindowListeners.push_back(cb_root);

    return RUNNER->AllocateNativeClosure(removeFullWindowListener, "onFullWindow$disposer", 0, &FullWindowListeners, 1, StackSlot::MakeInt(cb_root));
}

StackSlot GLRenderSupport::removeFullWindowListener(RUNNER_ARGS, void * data)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 2);
    int cb_root = slot[0].GetInt();
    T_Listeners * listeners = (T_Listeners*)data;
    if (NULL != listeners) listeners->erase(std::find(listeners->begin(), listeners->end(), cb_root));
    RUNNER->ReleaseRoot(cb_root);

    RETVOID;
}

StackSlot GLRenderSupport::isFullWindow(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS

    return StackSlot::MakeBool(IsFullWindow);
}

StackSlot GLRenderSupport::resetFullWindowTarget(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    setFullWindowTarget(NULL);

    RETVOID;
}

void GLRenderSupport::setFullWindowTarget(GLClip *clip)
{
    if (FullWindowTarget != clip) {
        if (IsFullWindow) {
            toggleFullWindow(false);
            FullWindowTarget = clip;
            if (clip != NULL)
                toggleFullWindow(true);
        } else {
            FullWindowTarget = clip;
        }
    }
}

void GLRenderSupport::dispatchVirtualKeyboardCallbacks(double height)
{
    RUNNER_VAR = getFlowRunner();
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    for (unsigned int it = 0; it < VirtualKeyboardHeightListeners.size(); ++it) {
        RUNNER->EvalFunction(RUNNER->LookupRoot(VirtualKeyboardHeightListeners[it]), 1, StackSlot::MakeDouble(height));
    }
}

StackSlot GLRenderSupport::addDrawFrameEventListener(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_root = RUNNER->RegisterRoot(cb);

    DrawFrameListeners.push_back(cb_root);

    doRequestRedraw();

    return RUNNER->AllocateNativeClosure(removeListener, "addDrawFrameEventListener$disposer", 0, &DrawFrameListeners,
                                         1, StackSlot::MakeInt(cb_root));
}

StackSlot GLRenderSupport::setDropCurrentFocusOnDown(RUNNER_ARGS)
{
    RUNNER_PopArgs1(drop);
    RUNNER_CheckTag(TBool, drop);

    DropFocusOnDown = drop.GetBool();

    RETVOID;
}

StackSlot GLRenderSupport::addVirtualKeyboardHeightListener(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_root = RUNNER->RegisterRoot(cb);

    VirtualKeyboardHeightListeners.push_back(cb_root);

    return RUNNER->AllocateNativeClosure(removeListener, "addVirtualKeyboardHeightListener$disposer", 0, &VirtualKeyboardHeightListeners,
                                         1, StackSlot::MakeInt(cb_root));
}

bool GLRenderSupport::isVirtualKeyboardListenerAttached() {
    return VirtualKeyboardHeightListeners.size() != 0;
}
