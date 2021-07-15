package dk.area9.flowrunner;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.view.View;

abstract class NativeWidget {
    protected final FlowWidgetGroup group;
    
    protected long id;
    @Nullable
    protected View view;
    protected boolean new_widget = true; // didn't have layout
    protected boolean visible = false;
    protected int minx = 0, miny = 0, maxx = 0, maxy = 0;
    protected int pad_left = 0, pad_top = 0, pad_right = 0, pad_bottom = 0;
    protected float scale = 1.0f, alpha = 1.0f;
    
    public NativeWidget(FlowWidgetGroup flowWidgetGroup, long id) { 
        group = flowWidgetGroup;
        this.id = id; 
    }
    
    @Nullable
    public final View getView() {
        return view;
    }
    
    @Nullable
    public final View getOrCreateView() {
        if (view == null)
            group.addView(view = createView());

        return view;
    }
    
    @Nullable
    protected abstract View createView();

    public void preDestroy() {
        id = 0;
    }
    
    public void destroy() {
        if (view != null) {
            group.removeView(view);
            view = null;
        }
    }
    
    @NonNull
    private Runnable resize_cb = new Runnable() {
        public void run() {
            if (id != 0 && view != null)
                doRequestLayout();
        }
    };

    protected void doRequestLayout() {
        view.setVisibility(visible ? FlowWidgetGroup.VISIBLE : FlowWidgetGroup.INVISIBLE);
        view.requestLayout();
    }

    protected void requestLayout() {
        group.post(resize_cb);
    }
    
    public void resize(boolean nvisible, int nminx, int nminy, int nmaxx, int nmaxy, float nscale, float nalpha)
    {
        if (id == 0) return;
        
        boolean changed = (visible != nvisible); 
        if (nvisible)
            changed = (changed || minx != nminx || miny != nminy || maxx != nmaxx || maxy != nmaxy); 
        
        if (changed) 
        {
            visible = nvisible;
            if (nvisible) {
                minx = nminx; miny = nminy; maxx = nmaxx; maxy = nmaxy;
            }

            scale = nscale;
            alpha = nalpha;

            if (alpha <= 0.0f)
                visible = false;

            requestLayout();
        }
    }

    public void beforeLayout() {
        new_widget = false; 
    }
    
    public void measure() {
        if (view == null)
            return;

        int width = maxx - minx + pad_left + pad_right;
        int xspec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY);
        int height = maxy - miny + pad_top + pad_bottom;
        int yspec = View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY);
        view.measure(xspec, yspec);
    }

    public void layout() {
        if (view == null)
            return;
        
        if (visible)
            beforeLayout();

        view.layout(minx - pad_left, miny - pad_top, maxx + pad_right, maxy + pad_bottom);
    }
}
