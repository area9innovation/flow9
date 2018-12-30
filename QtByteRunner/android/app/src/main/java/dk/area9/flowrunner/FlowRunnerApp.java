package dk.area9.flowrunner;

import java.lang.reflect.Constructor;

import android.app.Application;
import android.content.Context;
import android.util.Log;

// Use Reflection for calls to Localytics
// to allow linking it's jar optionally

public class FlowRunnerApp extends Application {
 	@Override
    public void onCreate() {
       super.onCreate();
       String localyticsKey = Utils.getAppMetadata(this, "LOCALYTICS_APP_KEY");
       
       if (localyticsKey != "") {
           Log.i(Utils.LOG_TAG, "Found Localytics key. Trying to invoke Localytics API (app level).");
           try {
               Class<?> c = Class.forName("com.localytics.android.LocalyticsActivityLifecycleCallbacks");
               Constructor<?> co = c.getConstructor(Context.class);
               registerActivityLifecycleCallbacks(
                       (ActivityLifecycleCallbacks) co.newInstance(this)
               );
               Log.i(Utils.LOG_TAG, "Localytics API successfully invoked (app level).");
           } catch (Exception e) {
               Log.e(Utils.LOG_TAG, "Were not able to registerActivityLifecycleCallback(LocalyticsActivityLifecycleCallback). Stack trace goes below.");
                e.printStackTrace();
           }
       }
    }
}
