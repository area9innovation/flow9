package dk.area9.flowrunner;

import android.text.InputType;
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
                int flowKeyCode = 0;
                if (keyCode == KeyEvent.KEYCODE_DEL) {
                    flowKeyCode = 8;
                }
                wrp.DispatchKeyEvent(
                    event.getAction() == KeyEvent.ACTION_UP ? FlowRunnerWrapper.FLOW_KEYUP : FlowRunnerWrapper.FLOW_KEYDOWN,
                    Character.toString((char)event.getUnicodeChar()),
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
        BaseInputConnection fic = new BaseInputConnection(this, false);
        outAttrs.actionLabel = null;
        outAttrs.inputType = InputType.TYPE_NULL;
        outAttrs.imeOptions = EditorInfo.IME_ACTION_NEXT;
        return fic;
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

}
