package dk.area9.flowrunner;

import java.util.ArrayList;

import android.content.Context;
import android.os.Handler;
import androidx.annotation.NonNull;
import android.text.Editable;
import android.text.InputFilter;
import android.text.InputType;
import android.text.TextWatcher;
import android.text.method.ScrollingMovementMethod;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewTreeObserver;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.TextView;
import android.widget.EditText;
import android.widget.ScrollView;
import android.view.View.OnFocusChangeListener;
import android.view.ViewTreeObserver.OnGlobalLayoutListener;

class EditWidget extends NativeWidget {
    EditWidget(FlowWidgetGroup group, long id) { super(group, id); }

    @NonNull
    public TextView getText() {
        return (TextView)view;
    }

    public void destroy() {
        if (group.isInFocus(this)) {
            group.dropFocus();
            dropFocus();
        }

        super.destroy();
    }

    protected View createView() {
        TextView textView;
        if (readonly) {
            textView = new TextView(group.getContext());
            textView.setTextIsSelectable(true);
        } else {
            textView = new MyEditText(group.getContext());

            textView.addTextChangedListener(new TextWatcher() {
                String previousText = "";

                @Override
                public void beforeTextChanged(CharSequence s, int start, int count, int after) {

                }

                @Override
                public void onTextChanged(CharSequence s, int start, int before, int count) {

                }

                @Override
                public void afterTextChanged(Editable s) {
                    if (id == 0)
                        return;
                    
                    String oldText = textView.getText().toString();
                    String newText = group.getWrapper().textIsAcceptedByFlowFilters(id, oldText);
                    if (previousText.equals(newText) || newText.equals(oldText)) {
                        return;
                    }
                    previousText = newText;
                    int sel_start = textView.getSelectionStart();
                    int sel_end = textView.getSelectionEnd();
                    textView.setText(newText);
                    ( (EditText)textView ).setSelection(Math.min(sel_start, newText.length()), Math.min(sel_end, newText.length()));
                }
            });
        }

        textView.setBackground(null);
        textView.setPadding(0,0,0,0);
        textView.setGravity(Gravity.TOP);

        return textView;
    }

    private class MyEditText extends EditText {
        MyEditText(Context context) { super(context); }

        protected void onSelectionChanged(int start, int end) {
            reportChange(null);
        }

        protected void onTextChanged (@NonNull CharSequence text, int start, int before, int after) {
            reportChange(text.toString());
        }

        public boolean onKeyUp(int keyCode, KeyEvent event) {
            if (!multiline && keyCode == KeyEvent.KEYCODE_ENTER) {
                sendReturnKey();
                dropFocus();
            }
            return super.onKeyUp(keyCode, event);
        }

        public void onEditorAction (int actionCode) {
            if (!multiline && actionCode == EditorInfo.IME_ACTION_DONE) {
                sendReturnKey();
                dropFocus();
                return;
            }
            super.onEditorAction(actionCode);
        }

        private void sendReturnKey() {
            FlowRunnerWrapper wrapper = group.getWrapper();
            String key = "enter";
            boolean ctrl = false,
                    shift = false,
                    alt = false,
                    meta = false;
            int code = 13,
                keyDown = FlowRunnerWrapper.FLOW_KEYDOWN,
                keyUp = FlowRunnerWrapper.FLOW_KEYUP;

            boolean validateDown =
                wrapper.keyEventFilteredByFlowFilters(
                    id,
                    keyDown,
                    key,
                    ctrl,
                    shift,
                    alt,
                    meta,
                    code
                );

            if (validateDown) {
                wrapper.DispatchKeyEvent(
                    keyDown,
                    key,
                    ctrl,
                    shift,
                    alt,
                    meta,
                    code
                );

//                boolean validateUp =
//                    wrapper.keyEventFilteredByFlowFilters(
//                        id,
//                        keyUp,
//                        key,
//                        ctrl,
//                        shift,
//                        alt,
//                        meta,
//                        code
//                    );
//
//                if (validateUp) {
                wrapper.DispatchKeyEvent(
                    keyUp,
                    key,
                    ctrl,
                    shift,
                    alt,
                    meta,
                    code
                );
//                }
            }
        }
    }

    private void dropFocus() {
        group.getIMM().hideSoftInputFromWindow(
            view.getWindowToken(),
            InputMethodManager.HIDE_NOT_ALWAYS
        );
    }

    private String text;
    private float native_font_size;
    private int text_color;
    private float line_spacing;

    private int alignment;

    private boolean multiline, readonly;
    @NonNull
    private ArrayList<InputFilter> filters = new ArrayList<InputFilter>();
    private int input_type;
    private int ime_options;
    private int sel_start, sel_stop;

    private boolean in_change = false;

    protected void doRequestLayout() {
        super.doRequestLayout();
    }

    public void beforeLayout() {
        if (new_widget && group.isInFocus(this)) {
            if (!readonly) {
                view.requestFocus();
                group.getIMM().showSoftInput(view, 0);
            }
            getText().setTextSize(TypedValue.COMPLEX_UNIT_PX, scale * native_font_size);
        }
        super.beforeLayout();
    }

    private void reportChange(String text) {
        long idv;
        int cursor, start, end;

        if (id == 0 || in_change) return;
        if (group.getBlockEvents()) return;

        TextView tview = getText();
        sel_start = tview.getSelectionStart();
        sel_stop = tview.getSelectionEnd();

        idv = id;
        cursor = sel_start;
        start = Math.min(sel_start,sel_stop);
        end = Math.max(sel_start,sel_stop);

        // This must not be inside synchronized, or it can deadlock
        group.getWrapper().deliverEditStateUpdate(idv, cursor, start, end, text);
    }

    @NonNull
    private Runnable create_cb = new Runnable() {
        public void run() {
            if (id == 0) return;

            group.setFocus(EditWidget.this);

            try {
                in_change = true;

                    final TextView textView = (TextView)getOrCreateView();
                    textView.setFilters(filters.toArray(new InputFilter[0]));
                    textView.setImeOptions(ime_options);
                    textView.setInputType(input_type);
                    textView.setGravity(alignment);
                    textView.setText(text);
                    textView.setTextColor(text_color | 0xFF000000);
                    textView.setLineSpacing(line_spacing, 1);

                    // Make EditText scrollable vertically
                    if (multiline) {
                        textView.setVerticalScrollBarEnabled(true);
                        textView.setOverScrollMode(View.OVER_SCROLL_ALWAYS);
                        textView.setScrollBarStyle(View.SCROLLBARS_INSIDE_INSET);
                        textView.setMovementMethod(ScrollingMovementMethod.getInstance());

                        textView.setOnTouchListener(new View.OnTouchListener() {
                            @Override
                            public boolean onTouch(@NonNull View view, @NonNull MotionEvent motionEvent) {

                                view.getParent().requestDisallowInterceptTouchEvent(true);
                                if ((motionEvent.getAction() & MotionEvent.ACTION_UP) != 0 && (motionEvent.getActionMasked() & MotionEvent.ACTION_UP) != 0)
                                {
                                    view.getParent().requestDisallowInterceptTouchEvent(false);
                                }
                                return false;
                            }
                        });
                    }

                    if (!readonly) {
                        ( (EditText)textView ).setSelection(Math.min(sel_start, text.length()), Math.min(sel_stop, text.length()));
                    }

                textView.setOnFocusChangeListener(new OnFocusChangeListener() {
                    @NonNull
                    ViewTreeObserver.OnGlobalLayoutListener layoutListener = new OnGlobalLayoutListener() {
                        float shift = 0.0f;
                        final Handler hdlr = new Handler();
                        final ScrollView sv = ((ScrollView) (group.getParent().getParent()));

                        @Override
                        public void onGlobalLayout() {
                            if (!group.getWrapper().isVirtualKeyboardListenerAttached()) {
                                int svh = sv.getHeight();
                                float screen_center = svh / 2.0f;
                                float tview_center = (maxy + miny) / 2.0f;
                                shift = tview_center - screen_center;

                                hdlr.postDelayed(new Runnable() {
                                    @Override
                                    public void run() {
                                        sv.scrollTo(0, 0);
                                        sv.scrollBy(0, (int) shift);
                                    }
                                }, 300); // Delay to override automatic scroll to bottom of edit by android.
                            }
                        }
                    };
                    ViewTreeObserver ViewTreeObserver = textView.getViewTreeObserver();
                    @Override
                    public void onFocusChange(View v, boolean hasFocus) {
                        if(hasFocus) {
                            ViewTreeObserver.addOnGlobalLayoutListener(layoutListener);
                        } else {
                            ViewTreeObserver.removeOnGlobalLayoutListener(layoutListener);
                        }
                    }
                }
              );
            } finally {
                in_change = false;
            }
        }
    };

    public void configure(
            @NonNull String text, float font_size, int font_color,
            boolean multiline, boolean readonly, float line_spacing,
            @NonNull String text_input_type, String alignment,
            int max_size, int cursor_pos, int nsel_start, int nsel_end
    ) {
        this.text = text;
        this.native_font_size = font_size;
        this.text_color = font_color;
        this.multiline = multiline;
        this.readonly = readonly;
        this.line_spacing = line_spacing;

        if ("center".equals(alignment)) {
            this.alignment = Gravity.CENTER_HORIZONTAL;
        } else if ("left".equals(alignment)) {
            this.alignment = Gravity.LEFT;
        } else if ("right".equals(alignment)) {
            this.alignment = Gravity.RIGHT;
        } else {
            this.alignment = Gravity.NO_GRAVITY;
        }

        filters.clear();
        if (max_size > 0) {
            filters.add(new InputFilter.LengthFilter(max_size));
        }

        input_type = 0;
        if (text_input_type.equals("number")) {
            input_type = InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_DECIMAL
                            | InputType.TYPE_NUMBER_FLAG_SIGNED;
            if (text_input_type.equals("password"))
                input_type |= InputType.TYPE_NUMBER_VARIATION_PASSWORD;
        } else if (text_input_type.equals("tel")){
                 input_type = InputType.TYPE_CLASS_PHONE;
        } else {
            input_type = InputType.TYPE_CLASS_TEXT;
            if (text_input_type.equals("email")) {
                input_type |= InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS;
            } else if (text_input_type.equals("url")) {
                input_type |= InputType.TYPE_TEXT_VARIATION_URI;
            }
            if (multiline)
                input_type |= InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_IME_MULTI_LINE;
            if (text_input_type.equals("password"))
                input_type |= InputType.TYPE_TEXT_VARIATION_PASSWORD;
        }

        ime_options = EditorInfo.IME_FLAG_NO_EXTRACT_UI;
        if (!multiline)
            ime_options |= EditorInfo.IME_ACTION_DONE;

        if (nsel_start < nsel_end && nsel_start >= 0 && nsel_end < text.length()) {
            if (cursor_pos > nsel_start) {
                sel_start = nsel_end;
                sel_stop = nsel_start;
            } else {
                sel_start = nsel_start;
                sel_stop = nsel_end;
            }
        } else if (cursor_pos <= text.length()) {
            sel_start = sel_stop = cursor_pos;
        } else {
            sel_start = sel_stop = text.length();
        }

        pad_bottom = multiline ? 0 : 30;

        group.post(create_cb);
    }
}
