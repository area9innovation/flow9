#ifndef GLTEXTCLIP_H
#define GLTEXTCLIP_H

#include "GLClip.h"
#include "GLFont.h"

class GLTextClip : public GLClip
{
public:
    enum Alignment {
        AlignNone, AlignLeft, AlignRight, AlignCenter
    };
    enum TextDirection {
        LTR, RTL
    };

protected:
    struct FormatRec {
        GLFont::Ptr font;
        TextFont text_font;

        vec4 color;
        float size, spacing;
        bool underline;
        unicode_string link_url;
        unicode_string link_target;

        FormatRec() : color(0.0f), size(12.0f), spacing(0.0f), underline(false) {}
        bool operator== (const FormatRec &rec2);
        bool operator!= (const FormatRec &rec2) { return !(*this == rec2); }
    };

    struct Extent {
        typedef shared_ptr<Extent> Ptr;

        FormatRec format;
        bool newline; // extent ends with a newline
        unicode_string text;

        int idx;          // index in text_real_extents
        int char_idx;     // index of the first character in plain_text
        int line_idx;     // index of the line in text_lines
        int line_ext_idx; // index in Line::extents
        float x_offset;   // offset from Line::justify_x

        GLTextLayout::Ptr layout;

        Ptr original;     // if split, pointer to original in text_extents

        Extent(const FormatRec &fmt, int idx) :
            format(fmt), newline(false), idx(idx) {}
        Extent(Ptr orig) : format(orig->format), newline(false), original(orig) {}
    };

    typedef std::vector<Extent::Ptr> T_extents;
    typedef std::map<float,int> T_index;
    typedef std::map<int,int> T_int_index;

    struct Line {
        float baseline_y, width, justify_x;
        float ascender, descender, height;
        T_extents extents;
        T_index extent_index; // x_offset end -> line_ext_idx

        Line() : baseline_y(0.0f), width(0.0f) {}
    };

    typedef std::vector<Line> T_lines;

    unicode_string html_text, plain_text;
    unicode_string base_font_name;
    TextDirection textDirection;
    bool textDirectionFixed = false;
    FormatRec base_format;

    bool has_urls;
    T_extents text_extents;

    bool layout_ready, crop_words, first_render_layout_invalidated;
    T_lines text_lines;
    T_index text_line_index; // y end -> line_idx
    T_extents text_real_extents;
    T_int_index text_char_index; // char_idx -> text_real_extents idx
    vec2 text_size, ui_size;
    float justify_width, interline_spacing, cursor_width, line_height_percent;

    int scroll_v;

    vec4 bg_color, cursor_color;
    int bg_color_int;

    bool is_input, multiline, wordwrap, readonly, need_baseline;
    vec2 explicit_size;

    Alignment alignment;

    std::string input_type;
    int max_chars;
    int selection_start, selection_end, cursor_pos;

    void beginBuildExtents(const unicode_string &html);
    void addCharsToExtents(const FormatRec &format, bool newline, unicode_string chars);
    void addSoftNewline();
    void endBuildExtents();
    void setPlainText(const unicode_string &str);

    void parseHtmlEntity(const unicode_string &str, unsigned &pos, const FormatRec &format);
    bool parseHtmlTag(const unicode_string &str, unsigned &pos,
                      int *pterm, std::string *ptag, std::map<std::string,unicode_string> *pattrs);

    std::string parseHtmlRec(const unicode_string &str, unsigned &pos, const FormatRec &format, std::set<std::string> &open_tags);

    void invalidateLayout();
    static void applyProcessing(
        std::string input_type,
        Utf32InputIterator &inputBegin, Utf32InputIterator &inputEnd,
        shared_ptr<Utf32InputIterator> *outputBegin, shared_ptr<Utf32InputIterator> *outputEnd
    );
    void layoutText();
    void layoutTextWrapLines(bool rtl);
    void layoutTextSpaceLines();

    std::pair<Extent::Ptr,float> findExtentByPos(vec2 pos, bool nearest = false);
    int findCharIdxByPos(vec2 pos, bool nearest = false);

    void setupEvents();

    void computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform);

    void renderInner(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box);

    typedef std::map<int, int> T_TextInputFilters;
    T_TextInputFilters text_input_filters, text_input_key_down_event_filters, text_input_key_up_event_filters;
    int next_text_input_filter_id, next_text_input_key_down_event_filter_id, next_text_input_key_up_event_filter_id;

    static StackSlot removeTextInputFilter(ByteCodeRunner*, StackSlot*, void *);
    static StackSlot removeTextInputKeyDownEventFilter(ByteCodeRunner*, StackSlot*, void *);
    static StackSlot removeTextInputKeyUpEventFilter(ByteCodeRunner*, StackSlot*, void *);

    bool flowDestroyObject();
    void flowGCObject(GarbageCollectorFn);
    void stateChanged();


public:
    GLTextClip(GLRenderSupport *owner);

    DEFINE_FLOW_NATIVE_OBJECT(GLTextClip, GLClip)

    void invokeEventCallbacks(FlowEvent event, int num_args, StackSlot *args);

    const unicode_string &getPlainText() { return plain_text; }

    Alignment getAlignment() { return alignment; }
    TextDirection getTextDirection() { return textDirection; }

    bool isMultiline() { return multiline; }
    bool isNumeric() { return input_type == "number"; }
    bool isPassword() { return input_type == "password"; }
    bool isReadonly() { return readonly; }
    bool wordWrap() { return wordwrap; }
    bool cropWords() { return crop_words; }
    std::string inputType() { return input_type; }

    vec2 getExplicitSize() { return explicit_size; }

    unicode_string getFontName() { return base_font_name; }

    TextFont getTextFont() { return base_format.text_font; }

    float getFontSize() { return base_format.size; }
    vec4 getFontColor() { return base_format.color; }
    vec4 getBackgroundColor() { return bg_color; }
    int getBackgroundColorInt() { return bg_color_int; }

    int getMaxChars() { return max_chars; }
    int getSelectionStart() { return selection_start; }
    int getSelectionEnd() { return selection_end; }
    int getCursorPos() { return cursor_pos; }
    vec4 getCursorColor() { if (cursor_color.a >= 0) return cursor_color; else return getFontColor(); }
    float getCursorWidth() { return cursor_width; }
    int getVScroll() { return scroll_v; }
    float getInterlineSpacing() { return interline_spacing; }

    bool hasSelection() { return selection_start >= 0 && selection_start < selection_end; }

    void setFocus(bool focus);

    void setEditState(int cursor, int sel_start, int sel_end, bool set_text, unicode_string text, int scroll_pos = -1);

    const unicode_string textFilteredByFlowFilters(const unicode_string &str);
    bool keyEventFilteredByFlowFilters(const FlowKeyEvent &flowKeyEvent);

public:
    DECLARE_NATIVE_METHOD(setTextInput)
    DECLARE_NATIVE_METHOD(setTextAndStyle)
    DECLARE_NATIVE_METHOD(setTextAndStyle9)
    DECLARE_NATIVE_METHOD(setTextDirection)

    DECLARE_NATIVE_METHOD(setMultiline)
    DECLARE_NATIVE_METHOD(setWordWrap)
    DECLARE_NATIVE_METHOD(setAutoAlign)
    DECLARE_NATIVE_METHOD(setAdvancedText)
    DECLARE_NATIVE_METHOD(setReadOnly)

    DECLARE_NATIVE_METHOD(getTextMetrics)

    DECLARE_NATIVE_METHOD(getNumLines)
    DECLARE_NATIVE_METHOD(getScrollV)
    DECLARE_NATIVE_METHOD(setScrollV)
    DECLARE_NATIVE_METHOD(getBottomScrollV)

    DECLARE_NATIVE_METHOD(getTextFieldWidth)
    DECLARE_NATIVE_METHOD(getTextFieldHeight)
    DECLARE_NATIVE_METHOD(getTextFieldCharXPosition)
    DECLARE_NATIVE_METHOD(findTextFieldCharByPosition)
    DECLARE_NATIVE_METHOD(setTextFieldWidth)
    DECLARE_NATIVE_METHOD(setTextFieldHeight)
    DECLARE_NATIVE_METHOD(setTextFieldCropWords)
    DECLARE_NATIVE_METHOD(setTextFieldCursorColor)
    DECLARE_NATIVE_METHOD(setTextFieldCursorWidth)
    DECLARE_NATIVE_METHOD(setTextFieldInterlineSpacing)
    DECLARE_NATIVE_METHOD(setLineHeightPercent)
    DECLARE_NATIVE_METHOD(setTextNeedBaseline)

    DECLARE_NATIVE_METHOD(getContent)
    DECLARE_NATIVE_METHOD(getCursorPosition)
    DECLARE_NATIVE_METHOD(getSelectionStart)
    DECLARE_NATIVE_METHOD(getSelectionEnd)
    DECLARE_NATIVE_METHOD(setSelection)
    DECLARE_NATIVE_METHOD(setTextInputType)
    DECLARE_NATIVE_METHOD(setMaxChars)
    DECLARE_NATIVE_METHOD(addTextInputFilter)
    DECLARE_NATIVE_METHOD(addTextInputKeyEventFilter)
};

#endif // GLTEXTCLIP_H
