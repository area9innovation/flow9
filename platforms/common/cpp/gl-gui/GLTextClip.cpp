#include "GLTextClip.h"

#include "core/GarbageCollector.h"
#include "core/RunnerMacros.h"

#include <glm/gtx/epsilon.hpp>
#include <glm/gtx/vector_query.hpp>

IMPLEMENT_FLOW_NATIVE_OBJECT(GLTextClip, GLClip)

static const unicode_string STR_auto = parseUtf8("auto");
static const unicode_string STR_finger = parseUtf8("finger");

bool GLTextClip::FormatRec::operator== (const GLTextClip::FormatRec &rec2)
{
    return (font == rec2.font &&
            glm::equalEpsilon(size, rec2.size, 1e-2f) &&
            glm::areSimilar(color, rec2.color, 1.0f/256.0f) &&
            underline == rec2.underline &&
            link_url == rec2.link_url &&
            link_target == rec2.link_target);
}

GLTextClip::GLTextClip(GLRenderSupport *owner) :
    GLClip(owner)
{
    text_size = explicit_size = vec2(0.0f);
    has_urls = false;
    is_input = false;
    wordwrap = false;
    crop_words = false;
    multiline = true;
    layout_ready = true;
    readonly = false;
    input_type = "text";
    selection_start = selection_end = 0;
    cursor_pos = 0;
    scroll_v = 0;
    max_chars = -1;
    alignment = AlignNone;
    bg_color = vec4(0.0f);
    next_text_input_filter_id = next_text_input_key_down_event_filter_id = next_text_input_key_up_event_filter_id = 0;
    interline_spacing = 0.0;
    line_height_percent = 1.0f;
    need_baseline = true;
    cursor_width = 2.0;
    cursor_color = vec4(-1.0f);
}

bool GLTextClip::flowDestroyObject()
{
    setFocus(false);
    return GLClip::flowDestroyObject();
}

void GLTextClip::flowGCObject(GarbageCollectorFn ref)
{
    GLClip::flowGCObject(ref);
    ref << text_input_filters;
}

void GLTextClip::computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform)
{
    GLClip::computeBBoxSelf(bbox, transform);

    layoutText();

    if (is_input)
        bbox |= transform * GLBoundingBox(vec2(0,0), explicit_size);
    else if (!text_lines.empty())
        bbox |= transform * GLBoundingBox(vec2(0,0), ui_size);
}

void GLTextClip::renderInner(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box)
{
    layoutText();

    if (bg_color.a >= 0.0f)
    {
        surface->makeCurrent();

        renderer->beginDrawSimple(bg_color * global_alpha);
        renderer->drawRect(vec2(0.0f), ui_size);
    }

    if (!text_lines.empty() && !checkFlag(HasNativeWidget)) {
        surface->makeCurrent();

        float y_base = text_lines[scroll_v].baseline_y - text_lines[scroll_v].ascender;

        // Set up a mask rectangle if needed
        bool use_crop = (ui_size.x < text_size.x || ui_size.y < text_size.y-y_base);

        if (use_crop) {
            GLBoundingBox box(vec2(0.0f), ui_size - vec2(1.0f));
            surface->pushCropRect(global_transform, box);
        }

        for (unsigned l = scroll_v; l < text_lines.size(); l++) {
            Line &line = text_lines[l];

            if (line.baseline_y-line.ascender > ui_size.y+y_base)
                break;

            for (unsigned i = 0; i < line.extents.size(); i++) {
                Extent::Ptr extent = line.extents[i];
                
                vec2 origin(line.justify_x + extent->x_offset, line.baseline_y-y_base);
                vec2 adj_origin = origin;

                extent->layout->render(renderer, global_transform, origin, adj_origin,
                                       extent->format.color, global_alpha, extent->format.underline);
            }
        }

        // Clean up
        if (use_crop)
            surface->popCropRect();

        renderer->reportGLErrors("GLPictureClip::renderInner post text");
    }

    GLClip::renderInner(renderer, surface, clip_box);
}

void GLTextClip::addCharsToExtents(const FormatRec &format, bool newline, unicode_string chars)
{
    if (chars.empty() && !newline) return;

    if (text_extents.empty() ||
        text_extents.back()->newline ||
        text_extents.back()->format != format)
    {
        text_extents.push_back(Extent::Ptr(new Extent(format, text_extents.size())));

        if (!format.link_url.empty())
            has_urls = true;
    }

    plain_text.append(chars);
    text_extents.back()->text.append(chars);

    if (newline) {
        unicode_char lchar = '\n';

        if (multiline)
            text_extents.back()->newline = true;
        else
            text_extents.back()->text.push_back(lchar = ' ');

        plain_text.push_back(lchar);
    }
}

void GLTextClip::addSoftNewline()
{
    if (multiline && !text_extents.empty() && !text_extents.back()->newline)
    {
        addCharsToExtents(text_extents.back()->format, true, unicode_string());
    }
}

void GLTextClip::beginBuildExtents(const unicode_string &str)
{
    invalidateLayout();

    html_text = str;

    plain_text.clear();
    text_extents.clear();
    text_size = vec2(0);
    has_urls = false;

    plain_text.reserve(str.length());
}

void GLTextClip::endBuildExtents()
{
    FormatRec *fmt = NULL;

    // Add an empty extent at the very end, if ends with a newline
    if (is_input) {
        if (multiline && !text_extents.empty()) {
            Extent::Ptr &last = text_extents.back();
            if (last->newline)
                fmt = &last->format;
        } else if (!multiline && text_extents.empty()) {
            fmt = &base_format;
        }
    }

    if (fmt)
        text_extents.push_back(Extent::Ptr(new Extent(*fmt, text_extents.size())));
}

void GLTextClip::setPlainText(const unicode_string &str)
{
    beginBuildExtents(str);

    unsigned start = 0;
    for (unsigned i = 0; i < str.size(); i++) {
        if (str[i] == '\n') {
            addCharsToExtents(base_format, true, str.substr(start, i-start));
            start = i+1;
        }
    }

    addCharsToExtents(base_format, false, str.substr(start));
    endBuildExtents();
}

void GLTextClip::layoutTextWrapLines(bool rtl)
{
    text_lines.clear();
    text_lines.reserve(text_extents.size());
    text_lines.push_back(Line());

    text_real_extents.clear();
    text_real_extents.reserve(text_extents.size());

    text_char_index.clear();

    size_t cur_char;
    bool prev_newline = false;
    T_index::iterator idx_it = text_lines.back().extent_index.begin();
    T_int_index::iterator cidx_it = text_char_index.begin();
    for (unsigned i = 0; i < text_extents.size(); i++) {
        Extent::Ptr extent = text_extents[i];

        assert(extent->newline || !extent->text.empty() || (i == text_extents.size()-1));

        unicode_string ctext = extent->text;
        GLFont::Ptr font = extent->format.font;
        if (!font) continue;
        float fsize = extent->format.size;
        float fspacing = extent->format.spacing;
        bool already_split = false;
        shared_ptr<Utf32InputIterator> ctexti;

        DecodeUtf16toUtf32 decoder(extent->text);

        // TODO linkage to DecodeUtf16toUtf32 via shared_ptr to make it automatically disposable when all iterators gone.
        shared_ptr<Utf32InputIterator> strBegin, strEnd;
        strBegin = decoder.begin().clone();
        strEnd = decoder.end().clone();
        applyProcessing(input_type, *strBegin, *strEnd, &strBegin, &strEnd);
        ctexti = strBegin->clone();
        cur_char = extent->char_idx = ctexti->position();
        extent->layout.reset();

        // Word-wrapping loop:
        do {
            cur_char = ctexti->position();

            if (already_split || prev_newline) {
                text_lines.push_back(Line());
                idx_it = text_lines.back().extent_index.begin();
            }

            Line &line = text_lines.back();
            float limit = ((wordwrap && (!is_input || multiline)) ? explicit_size.x - line.width : -1.0f);

            GLTextLayout::Ptr layout = font->layoutTextLine(*ctexti, *strEnd, fsize, limit, fspacing, (!is_input || multiline) && crop_words, rtl);

            // Wrapping splits
            if (*layout->getEndPos() != *strEnd) {
                shared_ptr<Utf32InputIterator> wpos = layout->getEndPos()->cloneReversed();
                bool on_new_line = line.extents.empty();

                already_split = true;

                if (*layout->getEndPos() != *ctexti) {
                    ++*wpos;
                    for (; *wpos != *ctexti && *wpos != *strEnd; ++*wpos) {
                        ucs4_char c = **wpos;
                        if (isspace(c) || c == '-')
                            break;
                    }
                    wpos = wpos->cloneReversed();

                    if (*wpos != *ctexti)
                    	++*wpos;
                    else if (on_new_line)
                    	wpos = layout->getEndPos();
                } else if (on_new_line) {
                    wpos = ctexti->clone();
                    ++*wpos;
                }

                // If doesn't fit && not immediately after a newline,
                // then insert one and retry. Insertion is caused by
                // setting already_split to true earlier.
                if (*wpos == *strBegin)
                    continue;

                if (*ctexti != *wpos)
                    layout = font->layoutTextLine(*ctexti, *wpos, fsize, -1.0f, fspacing, (!is_input || multiline) && crop_words, rtl);
                ctexti = wpos;
            } else {
                ctexti = strEnd;
            }

            Extent::Ptr real_extent = extent;
            if (already_split) {
                real_extent = Extent::Ptr(new Extent(extent));
                real_extent->newline = extent->newline && ctext.empty();
            }

            // Configure the extent
            real_extent->x_offset = line.width;
            real_extent->layout = layout;
            real_extent->char_idx = cur_char;
            real_extent->line_idx = text_lines.size()-1;

            // Add the extent to the line
            real_extent->line_ext_idx = line.extents.size();

            line.extents.push_back(real_extent);
            line.width += layout->getWidth();

            T_index::value_type line_x_ref(line.width, real_extent->line_ext_idx);
            idx_it = line.extent_index.insert(idx_it, line_x_ref);

            // Add the extent to the char index
            real_extent->idx = text_real_extents.size();
            text_real_extents.push_back(real_extent);

            T_int_index::value_type char_ref(cur_char, real_extent->idx);
            cidx_it = text_char_index.insert(cidx_it, char_ref);

            cur_char += real_extent->text.size() + (real_extent->newline ? 1 : 0);
        } while (*ctexti != *strEnd);

        prev_newline = extent->newline;
        cur_char = strEnd->position();
    }

    T_int_index::value_type char_ref(cur_char, text_real_extents.size());
    cidx_it = text_char_index.insert(cidx_it, char_ref);

    if (unsigned(scroll_v) >= text_lines.size())
        scroll_v = text_lines.size()-1;
}

void GLTextClip::layoutTextSpaceLines() {
    text_line_index.clear();
    T_index::iterator idx_it = text_line_index.begin();

    // Find maximum real width
    float real_width = 0.0f;
    for (unsigned l = 0; l < text_lines.size(); l++)
        real_width = std::max(real_width, text_lines[l].width);

    // Find the justification width
    float justify_width = std::max(real_width, explicit_size.x);

    float top_limit = 0.0f;
    float prev_height = 0.0f;
    float line_width = 0.0f;

    for (unsigned l = 0; l < text_lines.size(); l++) {
        Line &line = text_lines[l];

        // Measure height across all extents
        line.ascender = line.descender = line.height = 0.0f;

        for (unsigned i = 0; i < line.extents.size(); i++) {
            Extent::Ptr extent = line.extents[i];

            line.ascender = std::max(line.ascender, extent->layout->getAscent() * line_height_percent);
            line.descender = std::min(line.descender, extent->layout->getDescent() * line_height_percent - interline_spacing);
            line.height = std::max(line.height, extent->layout->getLineHeight() * line_height_percent + interline_spacing);
        }

        // Apply spacing and compute baseline y
        float y_pos = top_limit + line.ascender;

        if (l > 0) {
            float max_height = std::max(prev_height, line.height);
            y_pos = std::max(y_pos, text_lines[l-1].baseline_y + max_height);
        }

        line.baseline_y = y_pos;

        // Horizontal justify
        switch (alignment) {
        case AlignNone:
            line.justify_x = textDirection == RTL? justify_width - line.width : 0.0f;
            break;

        case AlignLeft:
            line.justify_x = 0.0f;
            break;

        case AlignRight:
            line.justify_x = justify_width - line.width;
            break;

        case AlignCenter:
            line.justify_x = (justify_width - line.width) * 0.5f;
            break;
        }

        // Advance y position and index the line
        prev_height = line.height;
        top_limit = y_pos - line.descender;
        if (line.width > line_width) {
            line_width = line.width;
        }

        idx_it = text_line_index.insert(idx_it, T_index::value_type(top_limit, l));
    }

    text_size = vec2(line_width, top_limit);
}

void GLTextClip::invalidateLayout()
{
    layout_ready = false;
    wipeFlags(WipeGraphicsChanged);
}

void GLTextClip::layoutText()
{
    if (layout_ready) return;

    layoutTextWrapLines(textDirection == RTL);
    layoutTextSpaceLines();

    if (is_input && explicit_size != vec2(0.0f))
        ui_size = explicit_size;
    else
        ui_size = text_size;

    layout_ready = true;
}

void GLTextClip::applyProcessing(
    std::string input_type,
    Utf32InputIterator &inputBegin, Utf32InputIterator &inputEnd,
    shared_ptr<Utf32InputIterator> *outputBegin, shared_ptr<Utf32InputIterator> *outputEnd
) {
    shared_ptr<Utf32InputIterator> processor;
    if (input_type == "password")
        processor.reset(new PasswordUtf32Iter(inputBegin, inputEnd));
    else
        processor.reset(new LigatureUtf32Iter(inputBegin, inputEnd));
    *outputBegin = processor;
    *outputEnd = processor->clone();
    (*outputEnd)->seekEnd();
}

std::pair<GLTextClip::Extent::Ptr,float> GLTextClip::findExtentByPos(vec2 pos, bool nearest)
{
    typedef std::pair<GLTextClip::Extent::Ptr,float> TRV;
    static TRV NOT_FOUND(Extent::Ptr(), 0.0f);

    layoutText();

    // Empty text?
    if (text_real_extents.empty())
        return NOT_FOUND;

    // Adjust for scrolling
    pos.y += text_lines[scroll_v].baseline_y - text_lines[scroll_v].ascender;

    // Precise and out of bounds?
    if (!nearest && (pos.x < 0 || pos.y < 0 || pos.x > justify_width || pos.y > text_size.y))
        return NOT_FOUND;

    // Find the line using the Y coordinate
    T_index::iterator line_it = text_line_index.upper_bound(pos.y);
    bool line_found = (line_it != text_line_index.end());

    if (!line_found && !nearest)
        return NOT_FOUND;

    Line &line = (line_found ? text_lines[line_it->second] : text_lines.back());
    float rel_x = pos.x - line.justify_x;

    // Find the extent using the X coordinate
    T_index::iterator ext_it = line.extent_index.upper_bound(rel_x);
    bool ext_found = (ext_it != line.extent_index.end());

    if ((rel_x < 0 || !ext_found) && !nearest)
        return NOT_FOUND;

    Extent::Ptr ext = (ext_found ? line.extents[ext_it->second] : line.extents.back());

    // Check the Y bounds
    if (!nearest) {
        float y_delta = line.baseline_y - pos.y;
        if (y_delta > ext->layout->getAscent() ||
            y_delta < ext->layout->getDescent())
            return NOT_FOUND;
    }

    return TRV(ext, rel_x - ext->x_offset);
}

int GLTextClip::findCharIdxByPos(vec2 pos, bool nearest)
{
    std::pair<GLTextClip::Extent::Ptr,float> ext = findExtentByPos(pos, nearest);
    if (!ext.first)
        return -1;

    int eidx = ext.first->layout->findIndexByPos(ext.second, nearest);
    if (eidx < 0)
        return -1;

    return ext.first->char_idx + eidx;
}

void GLTextClip::parseHtmlEntity(const unicode_string &str, unsigned &pos, const FormatRec &format)
{
    unicode_string out_chars(1, '&');
    std::string code;
    unicode_char cur = 0;
    unsigned psave = pos;

    while (pos < str.size()) {
        cur = str[pos++];
        if (cur == ';') break;
        code.push_back(char(cur));
    }

    if (cur == ';' && code.size() >= 2) {
        if (code[0] == '#') {
            int base = 10;
            const char *str = code.c_str()+1;
            if (str[0] == 'x') {
                str++; base = 16;
            }

            char *p = NULL;
            cur = strtol(str, &p, base);
            if (p == code.c_str()+code.size()) {
                out_chars = unicode_string(1, cur);
                psave = pos;
            }
        } else {
            unicode_char out = 0;
            if (code == "nbsp")
                out = ' ';
            else if (code == "lt")
                out = '<';
            else if (code == "gt")
                out = '>';
            else if (code == "amp")
                out = '&';
            else if (code == "quot")
                out = '"';
            else if (code == "apos")
                out = '\'';

            if (out) {
                out_chars = unicode_string(1, out);
                psave = pos;
            }
        }
    }

    addCharsToExtents(format, false, out_chars);
    pos = psave;
}

bool GLTextClip::parseHtmlTag(const unicode_string &str, unsigned &pos,
                              int *pterm, std::string *ptag, std::map<std::string,unicode_string> *pattrs)
{
    unicode_char cur;

    *pterm = 0;

    // < [space*]
    while (pos < str.size() && isuspace(str[pos])) pos++;

    // < space* [/?]
    if (pos < str.size() && str[pos] == '/') {
        *pterm |= 1;
        pos++;
    }

    // < space* /? [space*]
    while (pos < str.size() && isuspace(str[pos])) pos++;

    // < space* /? space* [tag-name]
    while (pos < str.size() && isualpha(str[pos]))
        ptag->push_back(tolower(str[pos++]));

    if (ptag->empty())
        return false;

    // < space* /? space* tag-name [attr=value* /? >]
    for (;;) {
        while (pos < str.size() && isuspace(str[pos])) pos++;

        if (pos >= str.size()) return false;
        cur = str[pos++];

        if (cur == '>') {
            return true;
        } else if (cur == '/' && !*pterm) {
            *pterm |= 2;
        } else if (isualpha(cur) && !*pterm) {
            // [attr-name]
            std::string attr;
            attr.push_back(tolower(cur));
            while (pos < str.size() && isualpha(str[pos]))
                attr.push_back(tolower(str[pos++]));
            // attr-name [space*]
            while (pos < str.size() && isuspace(str[pos])) pos++;
            // attr-name space* [=]
            if (pos >= str.size() || str[pos++] != '=')
                return false;
            // attr-name space* = [space*]
            while (pos < str.size() && isuspace(str[pos])) pos++;
            // attr-name space* = space* ['value']
            if (pos >= str.size())
                return false;
            unicode_char quote = str[pos++];
            if (quote != '\'' && quote != '"')
                return false;
            unicode_string value;
            while (pos < str.size() && (cur = str[pos++]) != quote)
                value.push_back(cur);
            if (cur != quote)
                return false;
            (*pattrs)[attr] = value;
        } else {
            return false;
        }
    }
}

std::string GLTextClip::parseHtmlRec(const unicode_string &str, unsigned &pos, const FormatRec &format, std::set<std::string> &open_tags)
{
    while (pos < str.size()) {
        unicode_char cur = 0;
        unicode_string raw_chars;

        while (pos < str.size()) {
            cur = str[pos++];

            if (cur == '\n') {
                addCharsToExtents(format, true, raw_chars);
                raw_chars.clear();
            } else if (cur == '<' || cur == '&') {
                break;
            } else {
                raw_chars.push_back(cur);
            }

            cur = 0;
        }

        if (!raw_chars.empty())
            addCharsToExtents(format, false, raw_chars);

        if (!cur) break;

        if (cur == '&')
            parseHtmlEntity(str, pos, format);
        else if (cur == '<') {
            unsigned psave = pos;
            int term;
            std::string tag;
            std::map<std::string,unicode_string> attrs;

            if (!parseHtmlTag(str, pos, &term, &tag, &attrs)) {
                addCharsToExtents(format, false, unicode_string(1, '<'));
                pos = psave;
                continue;
            }

            if (term == 1) {
                if (open_tags.count(tag))
                    return tag;
                continue;
            }

            FormatRec new_format = format;

            if (tag == "font") {
                if (attrs.count("face"))
                    new_format.font = owner->lookupFont(TextFont::makeWithFamily(encodeUtf8(attrs["face"])));
                if (attrs.count("size"))
                    new_format.size = atof(encodeUtf8(attrs["size"]).c_str());
                if (attrs.count("color") && attrs["color"][0] == '#') {
                    StackSlot color = StackSlot::MakeInt(strtol(encodeUtf8(attrs["color"]).c_str()+1, NULL, 16));
                    new_format.color = flowToColor(color, StackSlot::MakeDouble(format.color.a));
                }
            } else if (tag == "u") {
                new_format.underline = true;
            } else if (tag == "a") {
                new_format.underline = true;
                new_format.color = vec4(0,0,1,1) * format.color.a;
                new_format.link_url = attrs["href"];
                new_format.link_target = attrs["target"];
            } else if (tag == "br") {
                addCharsToExtents(format, true, unicode_string());
                continue;
            } else if (tag == "p") {
                addSoftNewline();
            } else if (tag == "center") {
                alignment = AlignCenter;
            }

            if (!term) {
                bool newv = open_tags.insert(tag).second;
                std::string rtag = parseHtmlRec(str, pos, new_format, open_tags);
                if (newv)
                    open_tags.erase(tag);
                if (tag == "p")
                    addSoftNewline();
                if (rtag != tag)
                    return rtag;
            }
        }
    }

    return "";
}

void GLTextClip::invokeEventCallbacks(FlowEvent event, int num_args, StackSlot *args)
{
    GLClip::invokeEventCallbacks(event, num_args, args);

    // is_top doesnot work properly for now
    bool is_top = true; //(!owner->HoveredLeaves.empty() && owner->HoveredLeaves.back() == this);

    if (is_top && is_input && event == FlowMouseClick) {
        if (!checkFlag(HasNativeWidget) && !hasSelection()) {
            vec2 pos = getLocalMousePos();
            int idx = findCharIdxByPos(pos, true);
            if (idx >= 0 && cursor_pos != idx) {
                cursor_pos = idx;
                invokeEventCallbacks(FlowTextChange, 0, NULL);
            }
        }

        setFocus(true);
        return;
    }

    if (has_urls && (event == FlowMouseClick ||
                     event == FlowMouseEnter ||
                     event == FlowMouseLeave ||
                     event == FlowMouseMove))
    {
        vec2 pos = getLocalMousePos();
        Extent::Ptr ext = findExtentByPos(pos).first;
        bool in_url = is_top && ext && !ext->format.link_url.empty();

        if (checkFlag(IsUnderMouseCursor))
            owner->adviseCursor(in_url ? STR_finger : STR_auto);

        switch (event) {
        case FlowMouseClick:
            if (in_url)
                owner->doOpenUrl(ext->format.link_url, ext->format.link_target);
            break;

        case FlowMouseEnter:
            addEventCallback(FlowMouseMove, true);
            break;

        case FlowMouseLeave:
            addEventCallback(FlowMouseMove, false);
            owner->adviseCursor(STR_auto);
            break;

        default:;
        }
    }
}

void GLTextClip::setupEvents()
{
    addEventCallback(FlowMouseClick, is_input || has_urls);

    if (owner->hasCursorSupport()) {
        addEventCallback(FlowMouseEnter, has_urls);
        addEventCallback(FlowMouseLeave, has_urls);
        if (!has_urls)
            addEventCallback(FlowMouseMove, false);
    }
}

StackSlot GLTextClip::setTextInput(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    invalidateLayout();
    is_input = true;
    wordwrap = true;
    multiline = false;

    stateChanged();
    RETVOID;
}

StackSlot GLTextClip::setTextAndStyle9(RUNNER_ARGS)
{
    #define SIZE 8
    RUNNER_CopyArgArray(newargs, SIZE, 2);
    newargs[SIZE] = StackSlot::MakeInt(0);
    newargs[SIZE+1] = StackSlot::MakeDouble(0);
    return setTextAndStyle(RUNNER, newargs);
    #undef SIZE
}

StackSlot GLTextClip::setTextAndStyle(RUNNER_ARGS)
{
    RUNNER_PopArgs10(text_str, font_str, font_size, font_weight, font_slope_str, font_color_i, opacity, spacing, background_color_i, background_opacity);
    RUNNER_CheckTag3(TString, text_str, font_str, font_slope_str);
    RUNNER_CheckTag4(TDouble, font_size, opacity, spacing, background_opacity);
    RUNNER_CheckTag3(TInt, font_weight, font_color_i, background_color_i);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost*5, 110);
#endif

    unicode_string font_slope = RUNNER->GetString(font_slope_str);
    base_font_name = RUNNER->GetString(font_str);

    base_format.color = flowToColor(font_color_i, opacity);
    base_format.text_font = TextFont::makeWithParameters(encodeUtf8(base_font_name), font_weight.GetInt(), encodeUtf8(font_slope));
    base_format.font = owner->lookupFont(base_format.text_font);

    base_format.size = font_size.GetDouble();
    base_format.spacing = spacing.GetDouble();

    bg_color = flowToColor(background_color_i, background_opacity);
    bg_color_int = background_color_i.GetInt();

    unicode_string str = RUNNER->GetString(text_str);

    if (is_input)
    {
        setPlainText(str);
    }
    else
    {
        beginBuildExtents(str);

        if (base_format.font) {
            unsigned pos = 0;
            std::set<std::string> open_tags;
            parseHtmlRec(html_text, pos, base_format, open_tags);
        }

        endBuildExtents();
    }

    if (!textDirectionFixed) {
        DecodeUtf16toUtf32 decoder(plain_text);
        char flags = 0;
        shared_ptr<Utf32InputIterator> ctexti = decoder.begin().clone();
        while(decoder.end() != *ctexti) {
            if (GLTextLayout::isLtrChar(**ctexti)) flags |= 1;
            if (GLTextLayout::isRtlChar(**ctexti)) flags |= 2;
            ++*ctexti;
        }
        switch(flags) {
        case 1:
            textDirection = LTR;
            break;
        case 2:
            textDirection = RTL;
            break;
        }
    }

    setupEvents();

    invokeEventCallbacks(FlowTextScroll, 0, NULL);

    stateChanged();
    RETVOID;
}

StackSlot GLTextClip::setTextDirection(RUNNER_ARGS)
{
    RUNNER_PopArgs1(dir_str);
    RUNNER_CheckTag(TString, dir_str);

    std::string val = encodeUtf8(RUNNER->GetString(dir_str));

    if (val == "LTR" || val == "ltr") {
        textDirection = LTR;
        textDirectionFixed = true;
    } else if (val == "RTL" || val == "rtl") {
        textDirection = RTL;
        textDirectionFixed = true;
    } else
        RUNNER->ReportError(InvalidArgument, "Unknown TextDirection type: %s", val.c_str());

    invalidateLayout();
    stateChanged();
    layoutText();
    RETVOID;
}

StackSlot GLTextClip::getTextMetrics(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    RUNNER_DefSlots1(ret_array);

    float ascent = 0, descent = 0, leading = 0;

    layoutText();

    if (!text_lines.empty()) {
        ascent = text_lines[0].ascender;
        descent = text_lines[0].descender;
        leading = text_lines[0].height - (ascent - descent);
    }

    if (ascent == 0 && base_format.font != NULL) {
        // To have correct value of baseline for empty fillin field
        ascent = base_format.font->getAscender() * base_format.size;
    }

    ret_array = RUNNER->AllocateArray(3);
    RUNNER->SetArraySlot(ret_array, 0, StackSlot::MakeDouble(ascent));
    RUNNER->SetArraySlot(ret_array, 1, StackSlot::MakeDouble(descent));
    RUNNER->SetArraySlot(ret_array, 2, StackSlot::MakeDouble(leading));

    return ret_array;
}

StackSlot GLTextClip::getNumLines(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    layoutText();

    return StackSlot::MakeInt(text_lines.size());
}

StackSlot GLTextClip::getScrollV(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    layoutText();

    return StackSlot::MakeInt(scroll_v+1);
}

StackSlot GLTextClip::getBottomScrollV(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    layoutText();

    float y_base = text_lines[scroll_v].baseline_y - text_lines[scroll_v].ascender;
    unsigned i = scroll_v+1;

    for (; i < text_lines.size(); i++)
    {
        Line &line = text_lines[i];

        if (line.baseline_y-line.descender > ui_size.y+y_base)
            break;
    }

    return StackSlot::MakeInt(i);
}

StackSlot GLTextClip::setScrollV(RUNNER_ARGS)
{
    RUNNER_PopArgs1(value);
    RUNNER_CheckTag1(TInt, value);

    layoutText();

    int sv = std::max(0, std::min(value.GetInt(), (int)text_lines.size())-1);

    if (sv != scroll_v)
    {
        scroll_v = sv;

        wipeFlags(ChildrenUnchangedFromRender);
        stateChanged();
    }

    RETVOID;
}


StackSlot GLTextClip::getTextFieldCharXPosition(RUNNER_ARGS)
{
    RUNNER_PopArgs1(idx);
    RUNNER_CheckTag1(TInt, idx);
    int idx_v = idx.GetInt();

    layoutText();
    Extent::Ptr extent;
    for (int i = text_real_extents.size() - 1; i >= 0; --i) {
        extent = text_real_extents[i];
        if (extent->char_idx <= idx_v) break;
    }
    if (!extent) return StackSlot::MakeDouble(-1.0);
    int glyphIdx = extent->layout->getCharGlyphPositionIdx(idx_v-extent->char_idx);
    int orgGlyphCharIdx = extent->layout->getCharIndices()[glyphIdx];
    float glyphPos = extent->layout->getPositions()[glyphIdx];
    float glyphAdvance = extent->layout->getGlyphAdvance(glyphIdx);

    // TODO upgrade to valid calculation when we have ligatures of more than 2 characters.
    int glyphCharsCompo = extent->layout->getGlyphCharsCompo(glyphIdx);

    int charIdxDelta = idx_v-extent->char_idx-orgGlyphCharIdx;
    double glyphStartOffset = glyphAdvance;
    if (glyphIdx) glyphStartOffset += extent->format.spacing;
    if (glyphCharsCompo) {
        glyphStartOffset -= fabs(glyphAdvance * charIdxDelta/glyphCharsCompo);
        if (extent->layout->getDirections()[glyphIdx] != CharDirection::RTL)
            glyphStartOffset = glyphAdvance-glyphStartOffset;
    }
    return StackSlot::MakeDouble(glyphPos + glyphStartOffset);
}

StackSlot GLTextClip::findTextFieldCharByPosition(RUNNER_ARGS)
{
    // TODO check glyphs order in layout object is correct (monotone) due GLTextLayout::buildLayout was rewritten.
    RUNNER_PopArgs2(posx, posy);
    RUNNER_CheckTag2(TDouble, posx, posy);
    int char_idx = -1;

    std::pair<GLTextClip::Extent::Ptr,float> ext = findExtentByPos(vec2(posx.GetDouble(), posy.GetDouble()), true);
    if (ext.first) {
        int eidx = ext.first->layout->findIndexByPos(ext.second, true);
        if (eidx >= 0) {
            const std::vector<float> &positions = ext.first->layout->getPositions();
            const std::vector<size_t> &char_indices = ext.first->layout->getCharIndices();
            int glyph_idx = ext.first->char_idx + eidx;
            double inGlyphPos = ext.second - positions[eidx];
            double glyphAdv = ext.first->layout->getGlyphAdvance(glyph_idx);
            int glyphCharsCompo = ext.first->layout->getGlyphCharsCompo(glyph_idx);

            char_idx = char_indices[glyph_idx];

            if (ext.first->layout->getDirections()[glyph_idx] == CharDirection::RTL)
                inGlyphPos = glyphAdv-inGlyphPos;
            if (glyphAdv) {
                if (inGlyphPos > glyphAdv) inGlyphPos = glyphAdv;
                char_idx += (int)(0.5+glyphCharsCompo*inGlyphPos/glyphAdv);
            }
        }
    }
    return StackSlot::MakeInt(char_idx);
}

StackSlot GLTextClip::getTextFieldWidth(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    if (is_input && explicit_size.x != 0.0) return StackSlot::MakeDouble(explicit_size.x);

    layoutText();

    return StackSlot::MakeDouble(ui_size.x);
}

StackSlot GLTextClip::getTextFieldHeight(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    if (is_input && explicit_size.y != 0.0) return StackSlot::MakeDouble(explicit_size.y);

    layoutText();

    return StackSlot::MakeDouble(ui_size.y);
}

StackSlot GLTextClip::setTextFieldWidth(RUNNER_ARGS)
{
    RUNNER_PopArgs1(width);
    RUNNER_CheckTag1(TDouble, width);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    invalidateLayout();
    explicit_size.x = width.GetDouble();

    RETVOID;
}

StackSlot GLTextClip::setTextFieldHeight(RUNNER_ARGS)
{
    RUNNER_PopArgs1(height);
    RUNNER_CheckTag1(TDouble, height);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    invalidateLayout();
    explicit_size.y = height.GetDouble();

    RETVOID;
}

StackSlot GLTextClip::setTextFieldCropWords(RUNNER_ARGS)
{
    RUNNER_PopArgs1(crop);
    RUNNER_CheckTag1(TBool, crop);

    invalidateLayout();
    crop_words = crop.GetBool();

    stateChanged();
    RETVOID;
}

StackSlot GLTextClip::setTextFieldCursorColor(RUNNER_ARGS)
{
    RUNNER_PopArgs2(color, opacity);
    RUNNER_CheckTag1(TInt, color);
    RUNNER_CheckTag1(TDouble, opacity);

    invalidateLayout();
    cursor_color = flowToColor(color, opacity);

    stateChanged();
    RETVOID;
}


StackSlot GLTextClip::setTextFieldCursorWidth(RUNNER_ARGS)
{
    RUNNER_PopArgs1(width);
    RUNNER_CheckTag1(TDouble, width);

    invalidateLayout();
    cursor_width = width.GetDouble();

    stateChanged();
    RETVOID;
}

StackSlot GLTextClip::setTextFieldInterlineSpacing(RUNNER_ARGS)
{
    RUNNER_PopArgs1(spacing);
    RUNNER_CheckTag(TDouble, spacing);

    invalidateLayout();
    interline_spacing = spacing.GetDouble();

    stateChanged();
    RETVOID;
}

StackSlot GLTextClip::setLineHeightPercent(RUNNER_ARGS)
{
    RUNNER_PopArgs1(lineHeightPercent);
    RUNNER_CheckTag(TDouble, lineHeightPercent);

    invalidateLayout();
    line_height_percent = lineHeightPercent.GetDouble() + 0.2f;

    stateChanged();
    RETVOID;
}

StackSlot GLTextClip::setTextNeedBaseline(RUNNER_ARGS)
{
    RUNNER_PopArgs1(needBaseline);
    RUNNER_CheckTag(TBool, needBaseline);

    invalidateLayout();
    need_baseline = needBaseline.GetBool();

    stateChanged();
    RETVOID;
}

StackSlot GLTextClip::setMultiline(RUNNER_ARGS)
{
    RUNNER_PopArgs1(state);
    RUNNER_CheckTag1(TBool, state);

    invalidateLayout();
    multiline = state.GetBool();

    stateChanged();
    RETVOID;
}

StackSlot GLTextClip::setReadOnly(RUNNER_ARGS)
{
    RUNNER_PopArgs1(state);
    RUNNER_CheckTag1(TBool, state);

    readonly = state.GetBool();

    stateChanged();
    RETVOID;
}

StackSlot GLTextClip::setWordWrap(RUNNER_ARGS)
{
    RUNNER_PopArgs1(state);
    RUNNER_CheckTag1(TBool, state);

    invalidateLayout();
    wordwrap = state.GetBool();

    stateChanged();
    RETVOID;
}

StackSlot GLTextClip::setAutoAlign(RUNNER_ARGS)
{
    RUNNER_PopArgs1(state);
    RUNNER_CheckTag1(TString, state);

    std::string val = encodeUtf8(RUNNER->GetString(state));

    invalidateLayout();

    if (val == "AutoAlignLeft")
        alignment = AlignLeft;
    else if (val == "AutoAlignRight")
        alignment = AlignRight;
    else if (val == "AutoAlignCenter")
        alignment = AlignCenter;
    else if (val == "AutoAlignNone")
        alignment = AlignNone;
    else
        RUNNER->ReportError(InvalidArgument, "Unknown AutoAlign type: %s", val.c_str());

    stateChanged();
    RETVOID;
}

StackSlot GLTextClip::setAdvancedText(RUNNER_ARGS)
{
    RUNNER_PopArgs3(sharpness, antialias, grid_fit);
    RUNNER_CheckTag3(TInt, sharpness, antialias, grid_fit);

    // TODO

    RETVOID;
}

void GLTextClip::setFocus(bool focus)
{
    if (!is_input)
        return;

    if (checkFlag(HasNativeWidget) && !focus) {
        selection_start = -1;
        selection_end = -1;

        owner->destroyNativeWidget(this);
    } else if (focus && owner->TextFocus != this) {
        if (owner->TextFocus)
            owner->destroyNativeWidget(owner->TextFocus);
        owner->createNativeWidget(this);
        owner->CurrentFocus = owner->TextFocus = this;
    }

    GLClip::setFocus(focus);
}

StackSlot GLTextClip::getContent(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return RUNNER->AllocateString(getPlainText());
}

StackSlot GLTextClip::getCursorPosition(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeInt(cursor_pos);
}

StackSlot GLTextClip::getSelectionStart(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeInt(selection_start);
}

StackSlot GLTextClip::getSelectionEnd(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeInt(selection_end);
}

void GLTextClip::setEditState(int cursor, int sel_start, int sel_end, bool set_text, unicode_string text, int scroll_pos)
{
    cursor_pos = cursor;
    selection_start = sel_start;
    selection_end = sel_end;

    if (set_text)
        setPlainText(text);

    bool set_scroll = false;
    if (scroll_pos >= 0)
    {
        int nscroll = std::min(scroll_pos, (int)text_lines.size()-1);
        set_scroll = (nscroll != scroll_v);
        scroll_v = nscroll;
    }

    invokeEventCallbacks(FlowTextChange, 0, NULL);

    if (set_text || set_scroll)
        invokeEventCallbacks(FlowTextScroll, 0, NULL);
}

StackSlot GLTextClip::setSelection(RUNNER_ARGS)
{
    RUNNER_PopArgs2(start, end);
    RUNNER_CheckTag2(TInt, start, end);

#ifdef FLOW_INSTRUCTION_PROFILING
    getFlowRunner()->ClaimInstructionsSpent(owner->ProfilingInsnCost, 110);
#endif

    int length = plain_text.size();

    selection_start = cursor_pos = std::min(std::max(0, start.GetInt()), length);
    selection_end = std::min(std::max(0, end.GetInt()), length);

    RETVOID;
}

StackSlot GLTextClip::setTextInputType(RUNNER_ARGS)
{
    RUNNER_PopArgs1(type);
    RUNNER_CheckTag1(TString, type);

    std::string inputType = encodeUtf8(RUNNER->GetString(type));
    if (input_type == inputType)
        RETVOID;

    input_type = inputType;
    stateChanged();

    RETVOID;
}

StackSlot GLTextClip::setMaxChars(RUNNER_ARGS)
{
    RUNNER_PopArgs1(chars);
    RUNNER_CheckTag1(TInt, chars);

    max_chars = chars.GetInt();
    stateChanged();

    RETVOID;
}

StackSlot GLTextClip::addTextInputFilter(RUNNER_ARGS)
{
    RUNNER_PopArgs1(filter);

    text_input_filters[++next_text_input_filter_id] = RUNNER->RegisterRoot(filter);

    return RUNNER->AllocateNativeClosure(removeTextInputFilter, "addTextInputFilter$disposer", 0, NULL,
                                         2, getFlowValue(), StackSlot::MakeInt(next_text_input_filter_id));
}

StackSlot GLTextClip::addTextInputKeyEventFilter(RUNNER_ARGS)
{
    RUNNER_PopArgs2(event_name, filter);
    RUNNER_CheckTag(TString, event_name);

    if (RUNNER->GetString(event_name) == parseUtf8("keydown")) {
        text_input_key_down_event_filters[++next_text_input_key_down_event_filter_id] = RUNNER->RegisterRoot(filter);

        return RUNNER->AllocateNativeClosure(removeTextInputKeyDownEventFilter, "addTextInputKeyEventFilter$disposer", 0, NULL,
            2, getFlowValue(), StackSlot::MakeInt(next_text_input_key_down_event_filter_id));
    } else if (RUNNER->GetString(event_name) == parseUtf8("keyup")) {
        text_input_key_up_event_filters[++next_text_input_key_up_event_filter_id] = RUNNER->RegisterRoot(filter);
        return RUNNER->AllocateNativeClosure(removeTextInputKeyUpEventFilter, "addTextInputKeyEventFilter$disposer", 0, NULL,
            2, getFlowValue(), StackSlot::MakeInt(next_text_input_key_up_event_filter_id));
    } else {
        return RUNNER->AllocateConstClosure(0, StackSlot::MakeVoid());
    }
}

StackSlot GLTextClip::removeTextInputFilter(RUNNER_ARGS, void *)
{
    const StackSlot * slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    GLTextClip * clip = RUNNER->GetNative<GLTextClip*>(slot[0]);
    int filter_id = slot[1].GetInt();
    int root_id = clip->text_input_filters[filter_id];
    clip->text_input_filters.erase(filter_id);

    RUNNER->ReleaseRoot(root_id);
    RETVOID;
}

StackSlot GLTextClip::removeTextInputKeyDownEventFilter(RUNNER_ARGS, void *)
{
    const StackSlot * slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    GLTextClip * clip = RUNNER->GetNative<GLTextClip*>(slot[0]);
    int filter_id = slot[1].GetInt();

    int root_id = clip->text_input_key_down_event_filters[filter_id];
    clip->text_input_key_down_event_filters.erase(filter_id);

    RUNNER->ReleaseRoot(root_id);
    RETVOID;
}

StackSlot GLTextClip::removeTextInputKeyUpEventFilter(RUNNER_ARGS, void *)
{
    const StackSlot * slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    GLTextClip * clip = RUNNER->GetNative<GLTextClip*>(slot[0]);
    int filter_id = slot[1].GetInt();

    int root_id = clip->text_input_key_up_event_filters[filter_id];
    clip->text_input_key_up_event_filters.erase(filter_id);

    RUNNER->ReleaseRoot(root_id);
    RETVOID;
}

const unicode_string GLTextClip::textFilteredByFlowFilters(const unicode_string &str)
{
    if (text_input_filters.empty())
        return str;

    unicode_string result_str = str;
    RUNNER_VAR = getFlowRunner();

     for (T_TextInputFilters::iterator it = text_input_filters.begin(); it != text_input_filters.end(); ++it) {
        const StackSlot & res = RUNNER->EvalFunction(RUNNER->LookupRoot((*it).second), 1, RUNNER->AllocateString(result_str));
        if (res.IsString())
            result_str = RUNNER->GetString(res);
    }

    return result_str;
}

bool GLTextClip::keyEventFilteredByFlowFilters(const FlowKeyEvent &flowKeyEvent)
{
    T_TextInputFilters text_input_key_event_filters;
    if (flowKeyEvent.event == FlowKeyDown) {
        text_input_key_event_filters = text_input_key_down_event_filters;
    } else if (flowKeyEvent.event == FlowKeyUp) {
        text_input_key_event_filters = text_input_key_up_event_filters;
    }

    if (text_input_key_event_filters.empty())
        return true;

    RUNNER_VAR = getFlowRunner();

    for (T_TextInputFilters::iterator it = text_input_key_event_filters.begin(); it != text_input_key_event_filters.end(); ++it) {
        const StackSlot & res = RUNNER->EvalFunction(RUNNER->LookupRoot((*it).second), 6, RUNNER->AllocateString(flowKeyEvent.key), StackSlot::MakeBool(flowKeyEvent.ctrl),
            StackSlot::MakeBool(flowKeyEvent.shift), StackSlot::MakeBool(flowKeyEvent.alt), StackSlot::MakeBool(flowKeyEvent.meta), StackSlot::MakeInt(flowKeyEvent.code));

        if (res.IsBool() && !res.GetBool())
            return false;
    }

    return true;
}

void GLTextClip::stateChanged()
{
    if (!checkFlag(HasNativeWidget))
        return;

    owner->onTextClipStateChanged(this);
}
