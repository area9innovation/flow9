package dk.area9.flowrunner;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.lang.reflect.Method;
import java.net.URI;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Calendar;
import java.util.HashMap;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.amazonaws.org.apache.http.HttpException;
import com.amazonaws.org.apache.http.HttpHost;
import com.amazonaws.org.apache.http.HttpRequest;
import com.amazonaws.org.apache.http.HttpRequestInterceptor;
import com.amazonaws.org.apache.http.HttpResponse;
import com.amazonaws.org.apache.http.HttpResponseInterceptor;
import com.amazonaws.org.apache.http.client.methods.HttpGet;
import com.amazonaws.org.apache.http.client.methods.HttpPost;
import com.amazonaws.org.apache.http.client.methods.HttpPut;
import com.amazonaws.org.apache.http.client.methods.HttpDelete;
import com.amazonaws.org.apache.http.client.methods.HttpPatch;
import com.amazonaws.org.apache.http.client.methods.HttpUriRequest;
import com.amazonaws.org.apache.http.entity.BasicHttpEntity;
import com.amazonaws.org.apache.http.impl.client.DefaultHttpClient;
import com.amazonaws.org.apache.http.protocol.HttpContext;

// this is only for checking hardware acceleration, probably could be refactored
import android.app.AlertDialog;
import android.app.Dialog;
import android.app.ProgressDialog;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
// for network state change
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Rect;
import android.media.MediaMetadataRetriever;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.preference.PreferenceManager;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.app.FragmentActivity;
import android.support.v4.content.LocalBroadcastManager;
import android.text.method.ScrollingMovementMethod;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewTreeObserver;
import android.view.View.OnClickListener;
import android.view.ViewGroup.LayoutParams;
import android.view.ViewTreeObserver.OnGlobalLayoutListener;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.PopupMenu;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
// this is only for checking hardware acceleration, probably could be refactored
import android.Manifest.permission;
// for network state change

import dk.area9.flowrunner.FlowRunnerWrapper.HttpResolver;
import dk.area9.flowrunner.FlowRunnerWrapper.PictureResolver;

public class FlowRunnerActivity extends FragmentActivity  {

    public static final String DATA_PATH = Environment.getExternalStorageDirectory().getPath() + "/flow/";
    @Nullable
    private static String local_substitute_url = "https://localhost/flow/flowswf.html";
    
    @Nullable
    File tmp_dir;
    
    LinearLayout ContentView; 
    FlowWidgetGroup mView;
    TextView ConsoleTextView;
    LinearLayout ConsoleView;
    
    FlowRunnerWrapper wrapper;
    FlowSoundPlayer sound_player;
    View menu_anchor;
    
    @Nullable
    URI loader_uri;
    
    boolean initialized = false;
    boolean crashed = false;
    boolean paused = true;
    boolean ha_set = false;
    boolean lastConnected = true;
    
    @Nullable
    String php_session_id = null;
    @Nullable
    String php_session_domain = null;

    @Nullable
    private Intent intentOnDestroy = null;
    @Nullable
    private BroadcastReceiver inetStateReceiver;

    @Nullable
    private IFlowGooglePlayServices flowGooglePlayServices = null;

    private SoftKeyboardHeightListener softKeyboardHeightListener;

    private void browseUrl(@NonNull final String url) {
        try {
            if (url.startsWith(local_substitute_url)) {
                intentOnDestroy = getIntent();
                intentOnDestroy.setData(Uri.parse(url));
                finish();
            } else {
                Intent intent = new Intent(Intent.ACTION_VIEW);
                intent.setData(Uri.parse(url));
                startActivity(intent);
            }
        } catch (Exception e) {
            Log.e(Utils.LOG_TAG, e.toString());

            String msg = "Could not open URL";
            Toast.makeText(getApplicationContext(), msg, Toast.LENGTH_SHORT).show();
        }
    }

    
    @Override protected void onCreate(Bundle icicle) {
        super.onCreate(icicle);

        flowGooglePlayServices = FlowGooglePlayServicesFactory.getFlowGooglePlayServices(this);//new FlowGooglePlayServices(this);

        // initialization of different sources of parameters
        String xmlParams = Utils.getAppMetadata(FlowRunnerActivity.this, "url_parameters");
        Utils.manifest_url_params = Utils.decodeUrlQuery(xmlParams == null ? "" : xmlParams);
        Utils.pref_url_parameters = Utils.decodeUrlQuery(PreferenceManager.getDefaultSharedPreferences(getBaseContext()).getString("pref_url_parameters", ""));
        Utils.intent_Uri = Uri.parse(getIntent().getData() == null ? "" : getIntent().getData().toString());

        String localyticsKey = Utils.getAppMetadata(this, "LOCALYTICS_APP_KEY");
        if (localyticsKey != "") {
            Log.i(Utils.LOG_TAG, "Found Localytics key. Trying to invoke Localytics API.");
            try {
                Class<?> c = Class.forName("com.localytics.android.Localytics");
                Method m = c.getDeclaredMethod("registerPush");
                m.invoke(null);
                Log.i(Utils.LOG_TAG, "Localytics API successfully invoked.");
            } catch (Exception e) {
                Log.e(Utils.LOG_TAG, "Were not able to call Localytics.registerPush. Stack trace goes below.");
                e.printStackTrace();
            }
        }

        // Select a temporary file name
        tmp_dir = FlowRunnerActivity.this.getExternalCacheDir();
        if (tmp_dir == null || (!tmp_dir.exists() && !tmp_dir.mkdirs()))
        {
            tmp_dir = FlowRunnerActivity.this.getCacheDir();
            if (tmp_dir == null || (!tmp_dir.exists() && !tmp_dir.mkdirs()))
                throw new RuntimeException("Cache dir not accessible");
        }
        
        DisplayMetrics metrics = new DisplayMetrics();
        getWindowManager().getDefaultDisplay().getMetrics(metrics);
   
//        http_client = Utils.createHttpClient();
        String user_agent = "flow Android " + Build.VERSION.RELEASE + 
                " dpi=" + metrics.densityDpi + " " + metrics.widthPixels + "x" + metrics.heightPixels;
//        http_client.getParams().setParameter("User-Agent", user_agent);
        
        Log.i(Utils.LOG_TAG, "Device info: " + Build.DEVICE + " OS: " + Build.VERSION.RELEASE);
        Log.i(Utils.LOG_TAG, "User agent for Http requests : " + user_agent);
        
        // Workaround for weird rejection of PHPSESSID cookie
//        http_client.addResponseInterceptor(new HttpResponseInterceptor() {
//            public void process(@NonNull final HttpResponse response, final HttpContext context) {
//                if (php_session_id == null && response.containsHeader("Set-Cookie") ) {
//                    String set_cookie_header = response.getFirstHeader("Set-Cookie").getValue();
//                    if (set_cookie_header.startsWith("PHPSESSID")) {
//                        String[] cookie_items = set_cookie_header.split(";");
//                        for (String item : cookie_items) {
//                            int pos = item.indexOf("domain=");
//                            if (pos != -1) {
//                                php_session_domain = item.substring(pos + 7);
//                                php_session_id = set_cookie_header;
//                                Log.i(Utils.LOG_TAG, "PHPSESSID received in SetCookie: " + php_session_id);
//                            }
//                        }
//                    }
//                }
//            }
//        });
//
//        http_client.addRequestInterceptor(new HttpRequestInterceptor() {
//            public void process(@NonNull final HttpRequest request, @NonNull final HttpContext context) {
//                if (php_session_id != null) {
//                    HttpHost target = (HttpHost) context.getAttribute("Host");
//                    if (target.getHostName().endsWith(php_session_domain) ) request.setHeader("Cookie", php_session_id);
//                }
//            }
//        });
        
        wrapper = new FlowRunnerWrapper();
        
        sound_player = new FlowSoundPlayer(this, wrapper);

        wrapper.setStorePath(getDir("store", MODE_PRIVATE).getAbsolutePath());
        wrapper.setTmpPath(tmp_dir.getAbsolutePath());
        
        Log.i(Utils.LOG_TAG, "Store path = " + getDir("store", MODE_PRIVATE).getAbsolutePath());
        Log.i(Utils.LOG_TAG, "Tmp dir path = " + tmp_dir.getAbsolutePath());
             
        wrapper.setDPI((int)((metrics.xdpi + metrics.ydpi) / 2.0f));
        wrapper.setDensity(metrics.density);
        wrapper.setScreenWidthHeight(metrics.widthPixels, metrics.heightPixels);
        
        Log.i(Utils.LOG_TAG, "Display DPI = " + metrics.densityDpi);
        
        wrapper.setAssets(getAssets());
        wrapper.setLocalNotificationsEnabled(Utils.getAppMetadataBoolean(this, "reliable_local_notifications"));
        
        boolean inAppEnabled = Utils.getAppMetadataBoolean(this, "FLOW_INAPP_PURCHASE");
        wrapper.setStorePurchaseEnabled(inAppEnabled);
        
        if (inAppEnabled) {
            Log.i(Utils.LOG_TAG, "Found IN APP BILLING key. Trying to establish connection to Google Play Services.");
            AndroidStorePurchase inAppBillingService = new AndroidStorePurchase(this, wrapper);
            
            wrapper.setStorePurchaseAPI(inAppBillingService);
        }
       
        // Loading DFONTs
        try {
            String[] dfonts = getAssets().list("dfont");
            for (String dfont : dfonts) wrapper.attachFontFile("dfont/" + dfont, new String[] { dfont });
        } catch (IOException e) {
            Log.e(Utils.LOG_TAG, "Cannot load dfonts from assets");
        }

        wrapper.setPictureLoader(new FlowRunnerWrapper.PictureLoader() {
            public void load(@NonNull String url, boolean cache, @NonNull final PictureResolver callback) throws IOException {
                /*// Replace swf with png
                if (url.toLowerCase().endsWith(".swf")) {
                    String png_url = DATA_PATH + url.substring(0, url.length()-4) + ".png";
                    if (new File(png_url).exists()) {
                        callback.resolveFile(png_url);
                        return;
                    }
                }

                String local_url = DATA_PATH + url;
                if (new File(local_url).exists()) {
                    callback.resolveFile(local_url);
                    return;
                }*/

                ResourceCache.getInstance(FlowRunnerActivity.this).getCachedResource(loader_uri, url, callback);
            }

            public void abortPictureLoad(@NonNull String url) {
                ResourceCache.getInstance(FlowRunnerActivity.this).abortPendingRequest(loader_uri, url);
            }
        });
        
        wrapper.setHttpLoader(new FlowRunnerWrapper.HttpLoader() {
            public void request(@NonNull String url, String method, @NonNull String[] headers,
                    byte[] payload, @NonNull HttpResolver callback) {
                HttpUriRequest request;

                BasicHttpEntity entity = new BasicHttpEntity();

                entity.setContent(new ByteArrayInputStream(payload));

                URI uri = loader_uri.resolve(url);
                switch(method) {
                    case "POST":
                        HttpPost post = new HttpPost(uri);
                        post.setEntity(entity);
                        request = post;
                        break;
                    case "PUT":
                        HttpPut put = new HttpPut(uri);
                        put.setEntity(entity);
                        request = put;
                        break;
                    case "DELETE":
                        request = new HttpDelete(uri);
                        break;
                    case "PATCH":
                        HttpPatch patch = new HttpPatch(uri);
                        patch.setEntity(entity);
                        request = patch;
                        break;
                    default:
                        request = new HttpGet(uri);
                        break;
                }

                for (int i = 0; i < headers.length; i+=2)
                    request.addHeader(headers[i], headers[i+1]);
                
                Utils.loadHttpAsync(request, callback);
            }

            public void preloadMedia(@NonNull String url, @NonNull ResourceCache.Resolver callback) throws IOException {
                ResourceCache.getInstance(FlowRunnerActivity.this).getCachedResource(loader_uri, url, callback);
            }
            
            public void removeCachedMedia(@NonNull String url) throws IOException {
                ResourceCache.getInstance(FlowRunnerActivity.this).removeCachedResource(loader_uri, url);
            }
        });
        
        wrapper.addListener(new FlowRunnerWrapper.ListenerAdapter() {
            public boolean onFlowBrowseUrl(@NonNull final String url, String target) {
                Log.i(Utils.LOG_TAG, "url: " + url);
                
                runOnUiThread(new Runnable() {
                    public void run() {
                        if (url.indexOf("://") == -1 && url.indexOf("%3A%2F%2F") != -1)
                            browseUrl(Uri.decode(url));
                        else
                            browseUrl(url);
                    }
                });
                
                return true;
            }
            
            public void onFlowError(final String msg, String debug_info) {
                runOnUiThread(new Runnable() {
                    public void run() {
                        crashed = true;
                        setCurDialog(DIALOG_CRASH_ID);
                        Toast.makeText(getApplicationContext(), msg, Toast.LENGTH_LONG).show();
                    }
                });
            }
        });

        if (wrapper.getLocalNotificationsEnabled()) {
            FlowRunnerServiceWrapper.getInstance().setContext(this);
            FlowRunnerServiceWrapper.getInstance().startService();
            FlowRunnerServiceWrapper.getInstance().bindService();
        }

        wrapper.setFlowNotificationsAPI(FlowNotificationsAPI.getInstance(wrapper));
        FlowNotificationsAPI.getInstance(wrapper).setContext(this);

        wrapper.setFlowCameraAPI(FlowCameraAPI.getInstance());
        FlowCameraAPI.getInstance().setContext(this);
        wrapper.setFlowAudioCaptureAPI(FlowAudioCaptureAPI.getInstance(wrapper));
        FlowAudioCaptureAPI.getInstance(wrapper).setContext(this);
        
        PackageManager packageManager = getPackageManager();
        boolean gelocationPermissionGranted = packageManager.checkPermission(permission.ACCESS_FINE_LOCATION, getPackageName()) == PackageManager.PERMISSION_GRANTED
                || packageManager.checkPermission(permission.ACCESS_COARSE_LOCATION, getPackageName()) == PackageManager.PERMISSION_GRANTED;
        FlowGeolocationAPI flowGeolocation = new FlowGeolocationAPI(this, wrapper, flowGooglePlayServices, gelocationPermissionGranted);
        wrapper.setFlowGeolocationAPI(flowGeolocation);
        flowGooglePlayServices.setFlowGeolocationAPI(flowGeolocation);

        FlowWebSocketSupport flowWebSocketSupport = new FlowWebSocketSupport(wrapper);
        wrapper.setFlowWebSocketSupport(flowWebSocketSupport);

        createContentView();
        
        menu_anchor = new View(this);
        mView.addView(menu_anchor);
        
        show_popup = (getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        
        // Network state part, online / offline
        IntentFilter inetStateFilter = new IntentFilter("android.net.conn.CONNECTIVITY_CHANGE");
        inetStateFilter.addAction("android.net.conn.CONNECTIVITY_CHANGE_IMMEDIATE"); // only higher versions? 5.0?
        inetStateReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(@NonNull Context context, @NonNull Intent intent) {
                Log.i(Utils.LOG_TAG, "Received intent: " + intent.getAction());
                ConnectivityManager cm =
                        (ConnectivityManager)context.getSystemService(Context.CONNECTIVITY_SERVICE);

                NetworkInfo activeNetwork = cm.getActiveNetworkInfo();
                boolean isConnected = activeNetwork != null &&
                                      activeNetwork.isConnected();
                // TODO : make static variable so wrapper witll not spam the same message several times
                if (lastConnected != isConnected) {
                    wrapper.NotifyPlatformEvent(isConnected ? wrapper.PLATFORM_NETWORK_ONLINE : wrapper.PLATFORM_NETWORK_OFFLINE);
                    lastConnected = isConnected;
                }
            }
        };
        registerReceiver(inetStateReceiver, inetStateFilter);
        // Get network state immediately. It's not guaranteed that it will be sent by OS before business logic checks
        inetStateReceiver.onReceive(getApplicationContext(), new Intent("android.net.conn.CONNECTIVITY_CHANGE_IMMEDIATE"));
        
        loadWrapper();

        softKeyboardHeightListener = new SoftKeyboardHeightListener(this,
            new SoftKeyboardHeightListener.KeyBoardHeightListener(){
                @Override
                public void keyboardHeightChanged(int keyboardHeight) {
                    updateContentViewMinHeight();
                    wrapper.VirtualKeyboardHeightCallback((double)keyboardHeight);
                }
        });

        Log.i(Utils.LOG_TAG, "Runner wrapper lib loaded");
    }
    
    private boolean startsEmbeddedCodeWithoutParams(Intent intent) {
        Uri uri = intent.getData();
        if (uri == null) return true;
        if (uri.getScheme().equalsIgnoreCase("http") || uri.getScheme().equalsIgnoreCase("https") || uri.getScheme().equalsIgnoreCase("file") ) return false;
        return uri.getQuery() == null || uri.getQuery().equals("");
    }
    
    private void callOnFlowNotificationClick(Intent intent) {
        wrapper.onFlowLocalNotificationClick(
                intent.getExtras().getInt(getPackageName() + FlowNotificationsAPI.EXTRA_NOTIFICATION_ID),
                intent.getExtras().getString(getPackageName() + FlowNotificationsAPI.EXTRA_NOTIFICATION_CALLBACK_ARGS)
        );
    }
    
    private boolean isAssociatedFileUrl(@Nullable Uri uri) {
        return uri != null && uri.getScheme().equalsIgnoreCase("content");
    }
    
    @Override protected void onNewIntent(@NonNull Intent intent) {
        Uri new_uri = intent.getData();
        if (new_uri != null && new_uri.equals(getIntent().getData()) && !new_uri.getScheme().equalsIgnoreCase("http") && !new_uri.getScheme().equalsIgnoreCase("https") && !new_uri.getScheme().equalsIgnoreCase("file"))
            return;
        
        Utils.intent_Uri = Uri.parse(new_uri == null ? "" : new_uri.toString());

        if (startsEmbeddedCodeWithoutParams(intent) && startsEmbeddedCodeWithoutParams(getIntent())) {
            if (intent.getAction().equals(getPackageName() + FlowNotificationsAPI.ON_NOTIFICATION_CLICK)) {
                callOnFlowNotificationClick(intent);
            } else if (isAssociatedFileUrl(new_uri)) {
                wrapper.NotifyCustomFileTypeOpened(new_uri);
            }
            return;
        }
        
        Log.i(Utils.LOG_TAG, "onNewIntent: data = " + intent.getData());
        setIntent(intent);
        loadWrapper();

        if (intent.getAction().equals(getPackageName() + FlowNotificationsAPI.ON_NOTIFICATION_CLICK)) {
            callOnFlowNotificationClick(intent);
        }
    }
    
    @Override public void onBackPressed() {
        String on_back_button = Utils.getAppMetadata(FlowRunnerActivity.this, "on_back_button");
        boolean cancelled = false;

        if (wrapper != null) {
            cancelled |= wrapper.NotifyPlatformEvent(wrapper.PLATFORM_DEVICE_BACK_BUTTON);
        }

        if (!cancelled && !on_back_button.equalsIgnoreCase("ignore")) {
            moveTaskToBack(true);
        }
    }
    
    private void createContentView() {
        try {
            int debug_view_id = Class.forName(getPackageName() + ".R$layout").getDeclaredField("debugview").getInt(null);
            LayoutInflater inflater = LayoutInflater.from(this);
            
            ConsoleView = (LinearLayout)inflater.inflate(debug_view_id, null, false);
            ConsoleView.setLayoutParams(new LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, 0, 0.0f));
            
            Class<?> id = Class.forName(getPackageName() + ".R$id");
            ConsoleTextView = ConsoleView.findViewById((Integer)(id.getField("log_view").get(null)));
            ConsoleTextView.setMovementMethod(new ScrollingMovementMethod());

            Button update_log_button = ConsoleView.findViewById((Integer)(id.getField("update_log_button").get(null)));
            update_log_button.setOnClickListener(new OnClickListener() {
                public void onClick(View view) {
                    updateLogCatOutput();
                }
            });
            
            Button clear_log_button = ConsoleView.findViewById((Integer)(id.getField("clear_log_button").get(null)));
            clear_log_button.setOnClickListener(new OnClickListener() {
                public void onClick(View view) {
                    clearLogCatOutput(); updateLogCatOutput();
                }
            });
            
            final Button minimize_log_button = ConsoleView.findViewById((Integer)(id.getField("minimize_log_button").get(null)));
            
            minimize_log_button.setOnClickListener(new OnClickListener() {
                boolean isMinimized = false;
                public void onClick(View view) {
                    if (isMinimized) {
                        setConsoleViewWeight(1.0f);
                        minimize_log_button.setText("Minimize");
                        isMinimized = false;
                    } else {
                        setConsoleViewWeight(0.3f);
                        minimize_log_button.setText("Maximize");
                        isMinimized = true;
                    }
                }
            });
            
            Button close_log_button = ConsoleView.findViewById((Integer)(id.getField("close_log_button").get(null)));
            close_log_button.setOnClickListener(new OnClickListener() {
                public void onClick(View view) {
                    hideConsoleView();
                }
            });
            
            mView = new FlowWidgetGroup(this, wrapper, new Handler());
            mView.setLayoutParams(new LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, 0, 1.0f));
            
            ScrollView wrapper = new ScrollView(this); // To scroll to textinput when soft kbd is shown
            wrapper.setFillViewport(true);
            // Block any touch events for ScrollView to prevent user from scrolling
            wrapper.setOnTouchListener(new View.OnTouchListener() {
                @Override
                public boolean onTouch(View v, MotionEvent event) {
                    return false;
                }
            });
           
            ContentView = new LinearLayout(this);
            ContentView.setOrientation(LinearLayout.VERTICAL);
            ContentView.addView(mView);
            ContentView.addView(ConsoleView);

            wrapper.addView(ContentView);
            setContentView(wrapper);

            updateContentViewMinHeight();
        } catch (Exception e) {
            Log.e(Utils.LOG_TAG, "Cannot create content view");
        }
    }

    private void updateContentViewMinHeight() {
        ViewTreeObserver observer = getWindow().getDecorView().getViewTreeObserver();
        observer.addOnGlobalLayoutListener(new OnGlobalLayoutListener() {
            @Override
            public void onGlobalLayout() {
                View d = getWindow().getDecorView();
                int h = 0;

                if (!wrapper.isVirtualKeyboardListenerAttached()) {
                    int dh = d.getHeight();
                    Rect r = new Rect();
                    d.getWindowVisibleDisplayFrame(r);
                    h = dh - r.top;
                }

                if (h != ContentView.getMinimumHeight()) {
                    ContentView.setMinimumHeight(h);
                }
                d.getViewTreeObserver().removeOnGlobalLayoutListener(this);
            }
        });
    }
    
    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        updateContentViewMinHeight();
    }
    
    private boolean show_popup = false;
    public void showPopupMenu() {
        if (!show_popup) return;
        try {
           // Get menu resource ID for inflater:
           int id = Class.forName(getPackageName() + ".R$menu").getDeclaredFields()[0].getInt(null);
           PopupMenu popup_menu = new PopupMenu(this, menu_anchor);
           popup_menu.getMenuInflater().inflate(id, popup_menu.getMenu());
           popup_menu.setOnMenuItemClickListener(new PopupMenu.OnMenuItemClickListener() {
               @Override
               public boolean onMenuItemClick(@NonNull MenuItem item) {
                  if (item.getTitle().equals("Settings")) {
                      Intent settingsActivity = new Intent(getBaseContext(), FlowPreferenceActivity.class);
                      startActivity(settingsActivity);
                  } else if (item.getTitle().equals("Exit")) {
                      finish();
                  } else if (item.getTitle().equals("Show Console")) {
                      showConsoleView();
                  } else if (item.getTitle().equals("Don't show again")) {
                      show_popup = false;
                  }
                  return true;
               }
           });
          popup_menu.show();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    private void setConsoleViewWeight(float weight) {
        LinearLayout.LayoutParams lp = (LinearLayout.LayoutParams)ConsoleView.getLayoutParams();
        lp.weight = weight;
        ConsoleView.setLayoutParams(lp);
        updateLogCatOutput();
    }
        
    private void showConsoleView() {
        setConsoleViewWeight(1.0f);
        updateLogCatOutput();
    }
    
    private void hideConsoleView() {
        setConsoleViewWeight(0.0f);
    }
    
    private String LeadLogcatTimestamp = "";
    private void clearLogCatOutput() {
        // it will show logcat messages only with timestamp > the current one
        LeadLogcatTimestamp = new SimpleDateFormat("HH:mm:ss").format(Calendar.getInstance().getTime());
    }
    
    private void updateLogCatOutput() {
        Process logcat;
        final StringBuilder log = new StringBuilder();
        try {
            logcat = Runtime.getRuntime().exec(new String[]{"logcat", "-d", "-v", "time"});
            BufferedReader br = new BufferedReader(new InputStreamReader(logcat.getInputStream()), 4 * 1024);
            
            String line; 
            Pattern ptime = Pattern.compile("([0-9]+:[0-9]+:[0-9]+)");  
           
            while ((line = br.readLine()) != null) {
                if (!line.contains("StaticBuffer")) {
                    Matcher m = ptime.matcher(line);
                    m.find();
                    try {
                        String time = m.group();
                        if (time.compareTo(LeadLogcatTimestamp) > 0) log.append(line + "\n");
                    } catch(Exception e) {
                        log.append(line + "\n");
                    }
                }
            }
            ConsoleTextView.setText(log);
        } catch (Exception e) {
            ConsoleTextView.setText("Cannot get logcat output : " + e);
        }
    }
    
    private void loadWrapper() {
        Intent intent = getIntent();
                
        Utils.handleHardwareAcceleration(initialized, FlowRunnerActivity.this);

        // Kill the old loader
        if (loader != null) {
            loader.interrupt();
            try {
                loader.join();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            loader = null;
            initialized = true;
        }
        
        // Reset
        if (initialized)
            wrapper.reset();

        initialized = crashed = false;
        mView.setBlockEvents(true);
        loader_uri = null;
        
        loader = new LoadThread(intent);
        if (!paused)
            loader.start();
    }
    
    @Override protected void onPause() {
        if (loader == null) {
            wrapper.NotifyPlatformEvent(wrapper.PLATFORM_APPLICATION_SUSPENDED);
        }
        super.onPause();
        mView.onPause();
        paused = true;
    }

    @Override protected void onResume() {
        super.onResume();
        mView.onResume();
        
        paused = false;

        if (loader != null)
            loader.start();
        else
            wrapper.NotifyPlatformEvent(wrapper.PLATFORM_APPLICATION_RESUMED);
    }
    
    @Override
    public void onStart() {
        super.onStart();

        flowGooglePlayServices.connectGooglePlayServices();
        if (wrapper.getLocalNotificationsEnabled()) {
            FlowRunnerServiceWrapper.getInstance().bindService();
        }

        LocalBroadcastManager.getInstance(this).registerReceiver(mMessageReceiver,
                new IntentFilter("FBMessage")
        );
        LocalBroadcastManager.getInstance(this).registerReceiver(mTokenReceiver,
                new IntentFilter("FBToken")
        );
    }
    

    @Override
    public void onStop() {
        super.onStop();

        if (wrapper.getLocalNotificationsEnabled()) {
            FlowRunnerServiceWrapper.getInstance().unbindService();
        }

        LocalBroadcastManager.getInstance(this).unregisterReceiver(mMessageReceiver);
        LocalBroadcastManager.getInstance(this).unregisterReceiver(mTokenReceiver);
    }
    
    @Override protected void onDestroy() {
        Log.i(Utils.LOG_TAG, "ACTIVITY ON-DESTROY");
        unregisterReceiver(inetStateReceiver);

        wrapper.onGoogleServicesDisconnected();
        flowGooglePlayServices.disconnectGooglePlayServices();

        softKeyboardHeightListener.removeListener();

        wrapper.destroy();
        Log.i(Utils.LOG_TAG, "Runner wrapper destroyed successfully");
        
        if (intentOnDestroy != null) {
            startActivity(intentOnDestroy);
            intentOnDestroy = null;
        }
        
        super.onDestroy();
    }

    @NonNull
    private BroadcastReceiver mMessageReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, final Intent intent) {
            final Bundle extras = intent.getExtras();

            wrapper.DeliverFBMessage(
                    extras.getString("id"),
                    extras.getString("body"),
                    extras.getString("title"),
                    extras.getString("from"),
                    extras.getLong("stamp"),
                    (HashMap<String, String>)intent.getSerializableExtra("data")
            );
        }
    };

    @NonNull
    private BroadcastReceiver mTokenReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            final Bundle extras = intent.getExtras();

            wrapper.DeliverFBToken(extras.getString("token"));
        }
    };
    
    /* Dialogs */
    static final int DIALOG_LOADING_ID = 1;
    static final int DIALOG_DOWNLOAD_FAILED_ID = 2;
    static final int DIALOG_LOAD_FAILED_ID = 3;
    static final int DIALOG_CRASH_ID = 4;
    static final int DIALOG_DOWNLOADING_ID = 5;

    private int cur_dialog = 0;
    
    private void setCurDialog(int id) {
        if (cur_dialog == id)
            return;
        if (cur_dialog != 0)
            dismissDialog(cur_dialog);
        cur_dialog = id;
        if (cur_dialog != 0)
            showDialog(cur_dialog);
    }
    
    private void configureErrorDialog(AlertDialog.Builder builder, String restart_btn)
    {
        builder.setCancelable(false)
               .setPositiveButton(restart_btn, new DialogInterface.OnClickListener() {
                   public void onClick(@NonNull DialogInterface dialog, int id) {
                       dialog.dismiss();
                       cur_dialog = 0;
                       loadWrapper();
                   }
               })
               .setNegativeButton("Exit", new DialogInterface.OnClickListener() {
                   public void onClick(DialogInterface dialog, int id) {
                       FlowRunnerActivity.this.finish();
                   }
               });
    }
    
    @Nullable
    private ProgressDialog download_progress = null;

    @Nullable
    protected Dialog onCreateDialog(int id) {
        ProgressDialog progressDialog;
        AlertDialog.Builder builder;

        switch(id) {
        case DIALOG_LOADING_ID:
            progressDialog = new ProgressDialog(this);
            //progressDialog.setProgressStyle(ProgressDialog.STYLE_HORIZONTAL);
            progressDialog.setMessage("Loading executable...");
            progressDialog.setCancelable(false);
            return progressDialog;
        case DIALOG_DOWNLOAD_FAILED_ID:
            builder = new AlertDialog.Builder(this);
            builder.setMessage("Could not access the network server.");
            configureErrorDialog(builder, "Retry");
            return builder.create();
        case DIALOG_LOAD_FAILED_ID:
            builder = new AlertDialog.Builder(this);
            builder.setMessage("Could not load the executable.");
            configureErrorDialog(builder, "Retry");
            return builder.create();
        case DIALOG_CRASH_ID:
            builder = new AlertDialog.Builder(this);
            builder.setMessage("The program has crashed.");
            configureErrorDialog(builder, "Restart");
            return builder.create();
        case DIALOG_DOWNLOADING_ID:
            progressDialog = new ProgressDialog(this);
            progressDialog.setProgressStyle(ProgressDialog.STYLE_HORIZONTAL);
            progressDialog.setMessage("Downloading data...");
            progressDialog.setCancelable(false);
            progressDialog.setProgress(0);
            return download_progress = progressDialog;
        default:
            return null;
        }
    }

    /**
     * Active bytecode loader thread.
     */
    @Nullable
    private LoadThread loader = null;
    
    private class LoadThread extends Thread {
        private Intent intent;
        private boolean started = false; 
        
        LoadThread(Intent intent) { this.intent = intent; }
        
        public void start() {
            if (started)
                return;
            started = true;
            setCurDialog(DIALOG_LOADING_ID);
            super.start();
        }
        
        private boolean isActual() {
            return (loader == LoadThread.this && !crashed);
        }
        
        private boolean finishLoad() {
            if (loader != LoadThread.this)
                return false;
            loader = null;
            return !crashed;
        }
        
        private void resolveError(final int code) {
            runOnUiThread(new Runnable() {
                public void run() {
                    if (!finishLoad()) return;

                    setCurDialog(code);
                    crashed = true;
                }
            });
        }
        
        private void resolveSuccess() {
            runOnUiThread(new Runnable() {
                public void run() {
                    if (!finishLoad()) return;

                    setCurDialog(0);
                    initialized = true;
                    mView.setBlockEvents(false);
                }
            });
        }
        
        private void startProgress(final long size) {
            runOnUiThread(new Runnable() {
                public void run() {
                    if (!isActual()) return;

                    setCurDialog(DIALOG_DOWNLOADING_ID);
                    if (download_progress == null)
                        return;

                    download_progress.setProgress(0);
                    download_progress.setMax((int)size);
                }
            });
        }
        
        private void updateProgress(final long pos) {
            runOnUiThread(new Runnable() {
                public void run() {
                    if (!isActual()) return;

                    if (cur_dialog != DIALOG_DOWNLOADING_ID || download_progress == null)
                        return;

                    download_progress.setProgress((int)pos);
                }
            });
        }

        private void stopProgress() {
            runOnUiThread(new Runnable() {
                public void run() {
                    if (!isActual()) return;
                    setCurDialog(DIALOG_LOADING_ID);
                }
            });
        }

        private void downloadByteCodeFile(final URI link, @NonNull final String file_name) {
            // Actually retrieve the bytecode
            Log.i(Utils.LOG_TAG, "LOADING FROM URL: " + link.toString());

            boolean dl_ok = false;
            final boolean[] ended = new boolean[] { false };
            Utils.HttpLoadCallback callback = new Utils.HttpLoadAdaptor(link.toString()) {
                public void httpContentLength(long bytes) {
                    startProgress(bytes);
                }
                long last_time = 0;
                public void copyProgress(long bytes) {
                    long time = System.currentTimeMillis();
                    if ((time - last_time) >= 100) {
                        last_time = time;
                        updateProgress(bytes);
                    }
                }
                public void httpFinished(int status, HashMap<String, String> headers, boolean withData) {
                    super.httpFinished(status, headers, withData);
                    ended[0] = withData; 
                }
            };
            dl_ok = Utils.loadHttpFile(link.toString(), file_name, callback);
            if (!ended[0])
                dl_ok = false;

            if (!dl_ok) {
                resolveError(DIALOG_DOWNLOAD_FAILED_ID);
                return;
            } else {
                stopProgress();
            } 
        }
        
        public void run() {
            Log.i(Utils.LOG_TAG, "Start loader thread");

            try {
                boolean ok = false;
                SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(getBaseContext());

                // Base URL from application dev/debugging settings. Default is "".
                String overriden_substitute_url = prefs.getString("pref_override_loader_url", "");
                // If none, then
                if (overriden_substitute_url.equals(""))
                    // one from building XML configuration.
                    overriden_substitute_url = Utils.getAppMetadata(FlowRunnerActivity.this, "local_substitute_url");
                // Then, if none again -- leave local_substitute_url as is, otherwise override it.
                if (!overriden_substitute_url.equals(""))
                    local_substitute_url = overriden_substitute_url;

                URI new_uri = null;
                boolean localNotificationClicked = intent.getAction().equals(getPackageName() + FlowNotificationsAPI.ON_NOTIFICATION_CLICK);
                
                // Retrieve and load bytecode
                // TO DO : Refactor that
                if (intent.getAction().equals(Intent.ACTION_MAIN) ) {
                    new_uri = new URI(local_substitute_url);
                    ok = wrapper.loadBytecode(Utils.loadAssetData(getAssets(), "default.b"));
                } else if (intent.getData() != null) {
                    Uri link = intent.getData();
                    try{
                        new_uri = new URI(link.toString());
                    } catch (java.net.URISyntaxException e) {
                        new_uri = new URI(link.toString() + "?");
                    }

                    if ( // http(s) link to flowrunner.html or bytecode file.
                           ("http".equalsIgnoreCase(new_uri.getScheme()) || "https".equalsIgnoreCase(new_uri.getScheme())) &&
                           (new_uri.getPath().contains("flowrunner.html") || new_uri.getPath().contains(".bytecode") ) 
                        ) {
                      
                        File tmp_file = new File(tmp_dir, "bytecode.tmp");
                        String tmp_name = tmp_file.getAbsolutePath();

                        try {
                            // Download
                            String name = link.getQueryParameter("name");

                            URI bc_uri;
                            if (name != null) // "http://localhost/flow/flowrunner.html?name=..."
                                bc_uri = new_uri.resolve(name + ".bytecode");
                            else // "http://myhost/local.bytecode..."
                                bc_uri = new_uri;

                            downloadByteCodeFile(bc_uri, tmp_name);
    
                            ok = wrapper.loadBytecode(tmp_name);
                        } finally {
                            tmp_file.delete();
                        }
                    } else {
                        String linkstr = link.toString();
                        int qidx = linkstr.indexOf('?');
                        new_uri = new URI(local_substitute_url + (qidx >= 0 ? linkstr.substring(qidx) : ""));
                        
                        if ("file".equals(link.getScheme())) {
                            ok = wrapper.loadBytecode(link.getPath());
                        } else if (link.getQueryParameter("bytecode") != null && !link.getQueryParameter("bytecode").isEmpty()) { // loading bytecode by URL
                            Log.i(Utils.LOG_TAG, "START PERFORMING LOADING ACTIONS: " + link.getQueryParameter("bytecode"));
                            File tmp_file = new File(tmp_dir, "bytecode.tmp");
                            String tmp_name = tmp_file.getAbsolutePath();

                            downloadByteCodeFile(new URI(link.getQueryParameter("bytecode")), tmp_name);

                            ok = wrapper.loadBytecode(tmp_name);
                        } else { // Custom URI scheme
                            Log.i(Utils.LOG_TAG, "Start the app with URL = " + linkstr);
                            ok = wrapper.loadBytecode(Utils.loadAssetData(getAssets(), "default.b"));
                            if (!ok) Log.e(Utils.LOG_TAG, "loadBytecode failed");
                        }
                    }
                } else if (localNotificationClicked) {
                    new_uri = new URI(local_substitute_url);
                    ok = wrapper.loadBytecode(Utils.loadAssetData(getAssets(), "default.b"));
                }
                
                if (!ok || isInterrupted()) {
                    if (!ok) resolveError(DIALOG_LOAD_FAILED_ID);
                    return;
                }

                Log.i(Utils.LOG_TAG, "URL = " + new_uri);
                
                // Configure the root URI
                loader_uri = new_uri;
                
                // Get URL parameters from the settings
                String url_params_prefs = prefs.getString("pref_url_parameters", "");
                Log.i(Utils.LOG_TAG, "URL Parameters from app settings = " + url_params_prefs);
                
                // Get URL parameters from the Android manifest metadata
                String url_parameters_meta =  Utils.getAppMetadata(FlowRunnerActivity.this, "url_parameters"); 
                Log.i(Utils.LOG_TAG, "URL Parameters from app metadata = " + url_parameters_meta);
                wrapper.setUrlParameters(new_uri.toString(), url_parameters_meta + "&" + url_params_prefs  + "&" + new_uri.getRawQuery());
                
                boolean flow_time_profile = prefs.getBoolean("pref_flow_time_profile", false);
                short flow_time_profile_trace_per = Short.parseShort(prefs.getString("pref_flow_time_profile_trace_per", "5000"));
                Log.i(Utils.LOG_TAG, "Flow time profiling = " + flow_time_profile + ", instructions per sample = " + flow_time_profile_trace_per);
                wrapper.setFlowTimeProfile(flow_time_profile, flow_time_profile_trace_per);

                boolean flow_http_profiling = prefs.getBoolean("pref_flow_http_profile", false);
                Log.i(Utils.LOG_TAG, "Flow HTTP profiling (to this log) = " + flow_http_profiling);
                Utils.setHttpProfiling(flow_http_profiling);
                
                sound_player.setLoaderURI(new_uri);
                mView.setResourceURI(new_uri);
                
                // Run main
                Log.i(Utils.LOG_TAG, "MAIN STARTED");
                ok = wrapper.runMain();
                if (ok) {
                    Log.i(Utils.LOG_TAG, "MAIN COMPLETED");
                    if (localNotificationClicked) {
                        callOnFlowNotificationClick(intent);
                    }
                    if (isAssociatedFileUrl(intent.getData())) {
                        wrapper.NotifyCustomFileTypeOpened(intent.getData());
                    }
                    if (onActivityResultArgs != null) {
                        safeOnActivityResult(onActivityResultArgs.requestCode, onActivityResultArgs.resultCode, onActivityResultArgs.data);
                        onActivityResultArgs = null;
                    }
                } else {
                    Log.i(Utils.LOG_TAG, "MAIN FAILED");
                }
                
                if (!ok || isInterrupted()) {
                    if (!ok) resolveError(DIALOG_LOAD_FAILED_ID);
                } else {
                    resolveSuccess();
                }
            } catch (Exception e) {
                Log.e(Utils.LOG_TAG, "LOAD EXCEPTION: " + e.toString());
                e.printStackTrace();
                resolveError(DIALOG_LOAD_FAILED_ID);
            }
        }
    }
    
    @Override
    protected void onSaveInstanceState(@NonNull Bundle outState) {
        outState.putString(FlowCameraAPI.CAMERA_PHOTO_PATH, FlowCameraAPI.cameraAppPhotoFilePath);
        outState.putString(FlowCameraAPI.CAMERA_VIDEO_PATH, FlowCameraAPI.cameraAppVideoFilePath);
        outState.putString(FlowCameraAPI.CAMERA_APP_CALLBACK_ADDITIONAL_INFO, FlowCameraAPI.cameraAppCallbackAdditionalInfo);
        outState.putString(FlowAudioCaptureAPI.AUDIO_APP_CALLBACK_ADDITIONAL_INFO, FlowAudioCaptureAPI.audioAppCallbackAdditionalInfo);
        outState.putString(FlowAudioCaptureAPI.AUDIO_APP_DESIRED_FILENAME, FlowAudioCaptureAPI.audioAppDesiredFilename);
        outState.putInt(FlowAudioCaptureAPI.AUDIO_APP_DURATION, FlowAudioCaptureAPI.audioAppDuration);
        outState.putInt(FlowCameraAPI.CAMERA_APP_DESIRED_WIDTH, FlowCameraAPI.cameraAppDesiredWidth);
        outState.putInt(FlowCameraAPI.CAMERA_APP_DESIRED_HEIGHT, FlowCameraAPI.cameraAppDesiredHeight);
        outState.putInt(FlowCameraAPI.CAMERA_APP_COMPRESS_QUALITY, FlowCameraAPI.cameraAppCompressQuality);
        outState.putString(FlowCameraAPI.CAMERA_APP_DESIRED_FILENAME, FlowCameraAPI.cameraAppDesiredFilename);
        outState.putInt(FlowCameraAPI.CAMERA_APP_FIT_MODE, FlowCameraAPI.cameraAppFitMode);
        outState.putInt(FlowCameraAPI.CAMERA_APP_DURATION, FlowCameraAPI.cameraAppDuration);
        outState.putInt(FlowCameraAPI.CAMERA_APP_SIZE, FlowCameraAPI.cameraAppSize);
        outState.putInt(FlowCameraAPI.CAMERA_APP_VIDEO_QUALITY, FlowCameraAPI.cameraAppVideoQuality);
       
        super.onSaveInstanceState(outState);
    }

    @Override
    protected void onRestoreInstanceState(@NonNull Bundle savedInstanceState) {
        super.onRestoreInstanceState(savedInstanceState);
       
        FlowCameraAPI.cameraAppPhotoFilePath = savedInstanceState.getString(FlowCameraAPI.CAMERA_PHOTO_PATH);
        FlowCameraAPI.cameraAppVideoFilePath = savedInstanceState.getString(FlowCameraAPI.CAMERA_VIDEO_PATH);
        FlowCameraAPI.cameraAppCallbackAdditionalInfo = savedInstanceState.getString(FlowCameraAPI.CAMERA_APP_CALLBACK_ADDITIONAL_INFO);
        FlowAudioCaptureAPI.audioAppCallbackAdditionalInfo = savedInstanceState.getString(FlowAudioCaptureAPI.AUDIO_APP_CALLBACK_ADDITIONAL_INFO);
        FlowAudioCaptureAPI.audioAppDesiredFilename = savedInstanceState.getString(FlowAudioCaptureAPI.AUDIO_APP_DESIRED_FILENAME);
        FlowAudioCaptureAPI.audioAppDuration = savedInstanceState.getInt(FlowAudioCaptureAPI.AUDIO_APP_DURATION);
        FlowCameraAPI.cameraAppDesiredWidth = savedInstanceState.getInt(FlowCameraAPI.CAMERA_APP_DESIRED_WIDTH);
        FlowCameraAPI.cameraAppDesiredHeight = savedInstanceState.getInt(FlowCameraAPI.CAMERA_APP_DESIRED_HEIGHT);
        FlowCameraAPI.cameraAppCompressQuality = savedInstanceState.getInt(FlowCameraAPI.CAMERA_APP_COMPRESS_QUALITY);
        FlowCameraAPI.cameraAppDesiredFilename = savedInstanceState.getString(FlowCameraAPI.CAMERA_APP_DESIRED_FILENAME);
        FlowCameraAPI.cameraAppFitMode = savedInstanceState.getInt(FlowCameraAPI.CAMERA_APP_FIT_MODE);
        FlowCameraAPI.cameraAppDuration = savedInstanceState.getInt(FlowCameraAPI.CAMERA_APP_DURATION);
        FlowCameraAPI.cameraAppSize = savedInstanceState.getInt(FlowCameraAPI.CAMERA_APP_SIZE);
        FlowCameraAPI.cameraAppVideoQuality = savedInstanceState.getInt(FlowCameraAPI.CAMERA_APP_VIDEO_QUALITY);
    }
    
    @Override
    protected void onActivityResult(int requestCode, int resultCode, @NonNull Intent data) {
        if (wrapper.getStorePurchaseAPI() != null && data.getStringExtra("INAPP_PURCHASE_DATA") != null) {
            wrapper.getStorePurchaseAPI().callbackPurchase(resultCode, data);
        }
        
        if (loader == null) {
            safeOnActivityResult(requestCode, resultCode, data);
        } else {
            this.onActivityResultArgs = new onActivityResultArgs(requestCode, resultCode, data);
        }
    }
    
    private class onActivityResultArgs {
        public final int requestCode;
        public final int resultCode;
        public final Intent data;
        
        public onActivityResultArgs(int requestCode, int resultCode, Intent data) {
            this.requestCode = requestCode;
            this.resultCode = resultCode;
            this.data = data;
        }
    }
    
    @Nullable
    private onActivityResultArgs onActivityResultArgs = null;
    
    private void handleImagePickerResult(@NonNull final Uri uri, final boolean fromCamera) {
        final Context me = this;
        AsyncTask.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    Bitmap bitmap = BitmapUtils.handleSamplingAndRotationBitmap(me, uri, FlowCameraAPI.cameraAppDesiredWidth, FlowCameraAPI.cameraAppDesiredHeight, FlowCameraAPI.cameraAppFitMode);
                    // save file in application directory
                    File privateImageFile = new File(getApplicationInfo().dataDir, fromCamera ? uri.getLastPathSegment() : FlowCameraAPI.cameraAppDesiredFilename + ".jpg");
                    FileOutputStream out = new FileOutputStream(privateImageFile);
                    bitmap.compress(Bitmap.CompressFormat.JPEG, FlowCameraAPI.cameraAppCompressQuality, out);
                    out.flush();
                    out.close();
                    if (fromCamera) {
                        // Delete original file photo from camera
                        // Possible problem: image file still will be presented in gallery after delete operation till new rescan
                        // consider to use getContentResolver().delete method here
                        (new File(uri.getPath())).delete();
                    }
                    // Notify flow about photo capture event
                    wrapper.NotifyCameraEvent(0, privateImageFile.getAbsolutePath(), FlowCameraAPI.cameraAppCallbackAdditionalInfo, bitmap.getWidth(), bitmap.getHeight());
                } catch (IOException e) {
                    wrapper.NotifyCameraEvent(1, "ERROR: failed to save image file", FlowCameraAPI.cameraAppCallbackAdditionalInfo, -1, -1);
                }
            }
         });
    }
    
    private void handleVideoPickerResult(@NonNull final Uri uri, final boolean fromCamera) {
        final Context me = this;
        AsyncTask.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    FileInputStream is = (FileInputStream) getContentResolver().openInputStream(uri);
                    // save file in application directory
                    File privateVideoFile = new File(getApplicationInfo().dataDir, fromCamera ? uri.getLastPathSegment() : FlowCameraAPI.cameraAppDesiredFilename + ".mp4");
                    FileOutputStream out = new FileOutputStream(privateVideoFile);
                    byte[] buf = new byte[1024];
                    int len;
                    while ((len = is.read(buf)) > 0) {
                        out.write(buf, 0, len);
                    }
                    out.flush();
                    out.close();
                    MediaMetadataRetriever retriever = new MediaMetadataRetriever();
                    retriever.setDataSource(me, Uri.fromFile(privateVideoFile));
                    if (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) != null) {
                        String time = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
                        int timeInSec = Integer.parseInt(time) / 1000;
                        String widthS = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH);
                        int width = Integer.parseInt(widthS);
                        String heightS = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT);
                        int height = Integer.parseInt(heightS);
                        int size = (int) privateVideoFile.length();
                        retriever.release();

                        if (fromCamera) {
                            // Delete original file video from camera
                            // Possible problem: image file still will be presented in gallery after delete operation till new rescan
                            // consider to use getContentResolver().delete method here
                            (new File(uri.getPath())).delete();
                        }
                        // Notify flow about video capture event
                        wrapper.NotifyCameraEventVideo(0, privateVideoFile.getAbsolutePath(), FlowCameraAPI.cameraAppCallbackAdditionalInfo, width, height, timeInSec, size);
                    } else {
                        retriever.release();
                        wrapper.NotifyCameraEventVideo(1, "ERROR: non video file chosen", FlowCameraAPI.cameraAppCallbackAdditionalInfo, -1, -1, -1, -1);
                    }
                } catch (IOException e) {
                    wrapper.NotifyCameraEventVideo(2, "ERROR: failed to save video file", FlowCameraAPI.cameraAppCallbackAdditionalInfo, -1, -1, -1, -1);
                }
            }
         });
    }

    public static final int FlowCameraAPIPermissionCode = 1;

    public void onRequestPermissionsResult(int requestCode, String permissions[], int[] grantResults) {
        switch (requestCode) {
            case FlowCameraAPIPermissionCode: {
                boolean granted = true;
                for (int result : grantResults) {
                    if (result == PackageManager.PERMISSION_DENIED) {
                        granted = false;
                        break;
                    }
                }
                if (Arrays.asList(permissions).contains(permission.RECORD_AUDIO)) {
                    if (granted) {
                        FlowCameraAPI.cameraAppOpenVideoRunnable.run();
                        FlowCameraAPI.cameraAppOpenVideoRunnable = null;
                    } else {
                        wrapper.NotifyCameraEventVideo(3, "ERROR: Permission not granted", FlowCameraAPI.cameraAppCallbackAdditionalInfo, -1, -1, -1, -1);
                    }
                } else {
                    if (granted) {
                        FlowCameraAPI.cameraAppOpenPhotoRunnable.run();
                        FlowCameraAPI.cameraAppOpenPhotoRunnable = null;
                    } else {
                        wrapper.NotifyCameraEvent(3, "ERROR: Permission not granted", FlowCameraAPI.cameraAppCallbackAdditionalInfo, -1, -1);
                    }
                }
                break;
            }
        }
    }
    
    private void safeOnActivityResult(int requestCode, int resultCode, @Nullable final Intent data) {
        if (resultCode != RESULT_OK) {
            // TODO: add some info about errors
            return;
        }        
        String filePath = data == null ? "" : data.getStringExtra("FILE_SELECTED");
        // on some devices data == null when we use MediaStore.EXTRA_OUTPUT
        if (requestCode == FlowCameraAPI.CAMERA_APP_PHOTO_MODE) {
            handleImagePickerResult(Uri.fromFile(new File(FlowCameraAPI.cameraAppPhotoFilePath)), true);
        } else if (requestCode == FlowCameraAPI.GALLERY_PHOTO_PICKER_MODE) {
            handleImagePickerResult(data.getData(), false);
        } else if (requestCode == FlowCameraAPI.CAMERA_APP_VIDEO_MODE) {
            handleVideoPickerResult(Uri.fromFile(new File(FlowCameraAPI.cameraAppVideoFilePath)), true);
        } else if (requestCode == FlowCameraAPI.GALLERY_VIDEO_PICKER_MODE) {
            handleVideoPickerResult(data.getData(), false);
        }
    }
    
    // Google Play Services callbacks
    public void onGoogleServicesConnected() {
        if (loader == null) {
            wrapper.onGoogleServicesConnected();
        }
    }

    public void onGoogleServicesDisconnected() {
        if (loader == null) {
            wrapper.onGoogleServicesDisconnected();
        }
    }
}
