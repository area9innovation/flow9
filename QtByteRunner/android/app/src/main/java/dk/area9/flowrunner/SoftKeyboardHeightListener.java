package dk.area9.flowrunner;

import android.app.Activity;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;
import android.view.Window;

public class SoftKeyboardHeightListener {

    public interface KeyBoardHeightListener {
        void keyboardHeightChanged(int keyboardHeight);
    }

    private Activity activity;

    private View contentView;

    private int previousKeyboardHeight = 0;

    private KeyBoardHeightListener listener;

    private ViewTreeObserver.OnGlobalLayoutListener keyboardLayoutListener = new ViewTreeObserver.OnGlobalLayoutListener() {
        @Override
        public void onGlobalLayout() {
            int heightDiff = contentView.getRootView().getHeight() - contentView.getHeight();
            int contentViewTop = activity.getWindow().findViewById(Window.ID_ANDROID_CONTENT).getTop();

            int keyboardHeight = heightDiff - contentViewTop > 0 ? heightDiff - contentViewTop : 0;
            if(previousKeyboardHeight != keyboardHeight) {
                listener.keyboardHeightChanged(keyboardHeight);
                previousKeyboardHeight = keyboardHeight;
            }
        }
    };

    public SoftKeyboardHeightListener(Activity activity, KeyBoardHeightListener listener) {
        this.contentView = ((ViewGroup) activity.findViewById(android.R.id.content)).getChildAt(0);
        this.activity = activity;
        this.listener = listener;
        contentView.getViewTreeObserver().addOnGlobalLayoutListener(keyboardLayoutListener);
    }

    public void removeListener() {
        contentView.getViewTreeObserver().removeOnGlobalLayoutListener(keyboardLayoutListener);
    }

}
