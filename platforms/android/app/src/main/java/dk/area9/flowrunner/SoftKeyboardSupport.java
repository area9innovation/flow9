package dk.area9.flowrunner;

import android.text.Editable;
import android.text.InputType;
import android.text.Selection;
import android.text.SpannableStringBuilder;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;
import android.view.Window;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;

public class SoftKeyboardSupport extends View {

    private FlowRunnerActivity activity;
    private View contentView;

    private int previousKeyboardHeight = 0;
    private KeyBoardHeightListener heightListener = h -> {};

    private ViewTreeObserver.OnGlobalLayoutListener keyboardLayoutListener = new ViewTreeObserver.OnGlobalLayoutListener() {
        @Override
        public void onGlobalLayout() {
            int heightDiff = contentView.getRootView().getHeight() - contentView.getHeight();
            int contentViewTop = activity.getWindow().findViewById(Window.ID_ANDROID_CONTENT).getTop();

            int keyboardHeight = heightDiff - contentViewTop > 0 ? heightDiff - contentViewTop : 0;
            if (previousKeyboardHeight != keyboardHeight) {
                heightListener.keyboardHeightChanged(keyboardHeight);
                previousKeyboardHeight = keyboardHeight;
            }
        }
    };

    public SoftKeyboardSupport(FlowRunnerActivity activity, FlowRunnerWrapper wrp) {
        super(activity.mView.getContext());
        setFocusableInTouchMode(true);
        this.activity = activity;
        this.contentView = ((ViewGroup) activity.findViewById(android.R.id.content)).getChildAt(0);
        contentView.getViewTreeObserver().addOnGlobalLayoutListener(keyboardLayoutListener);
        this.layout(-1, 0, 0, 0);
        this.setOnKeyListener(new OnKeyListener() {
            @Override
            public boolean onKey(View v, int keyCode, KeyEvent event) {
                if(event.getUnicodeChar() == (int)ONE_UNPROCESSED_CHARACTER.charAt(0))
                    return true;

                int flowKeyCode = 0;
                if (keyCode == KeyEvent.KEYCODE_DEL) {
                    flowKeyCode = 8;
                }
                wrp.DispatchKeyEvent(
                    event.getAction() == KeyEvent.ACTION_UP ? FlowRunnerWrapper.FLOW_KEYUP : FlowRunnerWrapper.FLOW_KEYDOWN,
                    Character.toString((char) event.getUnicodeChar()),
                    false,
                    false,
                    false,
                    false,
                    flowKeyCode
                );
                return true;
            }
        });
    }

    @Override
    public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
        InputConnectionAccomodatingLatinIMETypeNullIssues baseInputConnection =
                new InputConnectionAccomodatingLatinIMETypeNullIssues(this, false);
        outAttrs.actionLabel = null;
        outAttrs.inputType = InputType.TYPE_NULL;
        outAttrs.imeOptions = EditorInfo.IME_ACTION_NEXT;
        return baseInputConnection;
    }

    public void showKeyboard() {
        this.requestFocus();
        activity.mView.getIMM().showSoftInput(this, 0);
    }

    public void hideKeyboard() {
        activity.mView.getIMM().hideSoftInputFromWindow(
            this.getWindowToken(),
            InputMethodManager.HIDE_NOT_ALWAYS
        );
    }

    public void setKeyboardHeightListener(KeyBoardHeightListener listener) {
        this.heightListener = listener;
    }

    public void removeListener() {
        contentView.getViewTreeObserver().removeOnGlobalLayoutListener(keyboardLayoutListener);
    }

    public interface KeyBoardHeightListener {
        void keyboardHeightChanged(int keyboardHeight);
    }

    //used to fix bug with KEYCODE_DEL not being delivered on some devices https://stackoverflow.com/a/19980975
    public static CharSequence ONE_UNPROCESSED_CHARACTER = "\t";

    public class EditableAccomodatingLatinIMETypeNullIssues extends SpannableStringBuilder {
        EditableAccomodatingLatinIMETypeNullIssues(CharSequence source) {
            super(source);
        }

        @Override
        public SpannableStringBuilder replace(final int
                                                      spannableStringStart, final int spannableStringEnd, CharSequence replacementSequence,
                                              int replacementStart, int replacementEnd) {
            if (replacementEnd > replacementStart) {
                super.replace(0, length(), "", 0, 0);
                return super.replace(0, 0, replacementSequence, replacementStart, replacementEnd);
            } else if (spannableStringEnd > spannableStringStart) {
                super.replace(0, length(), "", 0, 0);

                return super.replace(0, 0, ONE_UNPROCESSED_CHARACTER, 0, 1);
            }

            return super.replace(spannableStringStart, spannableStringEnd,
                    replacementSequence, replacementStart, replacementEnd);
        }
    }

    public class InputConnectionAccomodatingLatinIMETypeNullIssues extends BaseInputConnection {

        Editable myEditable = null;

        public InputConnectionAccomodatingLatinIMETypeNullIssues(View targetView, boolean fullEditor) {
            super(targetView, fullEditor);
        }

        @Override
        public Editable getEditable() {
            if (myEditable == null) {
                myEditable = new EditableAccomodatingLatinIMETypeNullIssues(ONE_UNPROCESSED_CHARACTER);
                Selection.setSelection(myEditable, 1);
            } else {
                int myEditableLength = myEditable.length();
                if (myEditableLength == 0) {
                    myEditable.append(ONE_UNPROCESSED_CHARACTER);
                    Selection.setSelection(myEditable, 1);
                }
            }
            return myEditable;
        }

        @Override
        public boolean deleteSurroundingText(int beforeLength, int afterLength) {
            if (beforeLength == 1 && afterLength == 0) {
                return super.sendKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL))
                        && super.sendKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_DEL));
            } else {
                return super.deleteSurroundingText(beforeLength, afterLength);
            }
        }
    }

}
