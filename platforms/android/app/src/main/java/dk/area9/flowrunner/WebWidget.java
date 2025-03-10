package dk.area9.flowrunner;

import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Set;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.MotionEvent;
import android.view.WindowManager;
import android.webkit.ConsoleMessage;
import android.webkit.DownloadListener;
import android.webkit.JavascriptInterface;
import android.webkit.MimeTypeMap;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

class FlowJSInterface {
    private FlowRunnerWrapper wrapper;
    private long webview_id;
    private WebWidget web_widget;
    public FlowJSInterface(FlowRunnerWrapper w, long id, WebWidget widget) { wrapper = w; webview_id = id; web_widget = widget; }
    
    @JavascriptInterface
    public void callflow(@NonNull String[] args) {
        if (args.length > 0) {
            if (args[0].equals("setInnerDomainsWhiteList")) {
                web_widget.setWhiteListDomains(Arrays.copyOfRange(args, 1, args.length));
                return;
            }
            if (args[0].equals("setExternalDocuments")) {
                web_widget.setExternalDocuments(Arrays.copyOfRange(args, 1, args.length));
                return;
            }
        }
        wrapper.callFlowFromWebView(webview_id, args);
    }
}

class WebWidget extends NativeWidget {
    private String url;

    private boolean use_zoom = false;

    @NonNull
    private Set<String> innerDomains = new HashSet<String>(); // Domains of all page frames
    @NonNull
    private Set<String> whiteListDomains = new HashSet<String>();
    @NonNull
    private Set<String> externalDocuments = new HashSet<String>();
    
    public WebWidget(FlowWidgetGroup group, long id) {
        super(group, id);      
    }
    
    @Override
    public void preDestroy() {
        super.preDestroy();
        
        // Workaround for video sound playing after page was destroyed:
        Activity a = (Activity)(group.getContext());
        a.runOnUiThread(new Runnable() {
           @Override public void run() { ((WebView)getOrCreateView()).loadUrl("about:blank"); } 
        });
        
    }
    
    public void setWhiteListDomains(String[] domains) {
        Collections.addAll(whiteListDomains, domains);
       
    }
    
    public void setExternalDocuments(String[] extentions) {
        Collections.addAll(externalDocuments, extentions);
    }
    
    public void setZoomable(boolean zoomable) {
        Log.i(Utils.LOG_TAG, "WebView zoomable to " + zoomable);
        use_zoom = zoomable;
    }
    
    private class WebViewClientImpl {
        private boolean pageLoaded = false;
        private boolean wasError = false;

        private Uri removeQueryParameter(Uri uri, @NonNull String paramName) {
            Uri.Builder tempUri = uri.buildUpon();
            tempUri.clearQuery();

            Set<String> paramList = uri.getQueryParameterNames();
            Iterator<String> paramListIter = paramList.iterator();

            while (paramListIter.hasNext()) {
                String currentParamName = paramListIter.next();
                if (!paramName.equals(currentParamName))
                    tempUri.appendQueryParameter(currentParamName, uri.getQueryParameter(currentParamName));
            }

            return tempUri.build();
        }

        public void onPageStarted(WebView webView, String url, Bitmap favicon) {
            pageLoaded = false;
            wasError = false;
            innerDomains.add(Uri.parse(url).getHost()); // It is called for each frame of the page. Hash changes are not trigger this
        }

        public void onPageFinished(WebView webView, String url) {
            if (!pageLoaded && !wasError) { // It may be called several times for the same url somehow. For every hash change - for sure. May be for each frame?
                group.getWrapper().NotifyWebViewLoaded(id);
            }
            pageLoaded = true;
        }

        public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
            wasError = true;
            group.getWrapper().NotifyWebViewError(id, description);
        }
 
        public boolean shouldOverrideUrlLoading(@NonNull WebView view, String url) {
            if (pageLoaded) {
                Log.d(Utils.LOG_TAG, "shouldOverrideUrlLoading URL: " + url + " from view with URL: " + view.getUrl());
                Uri uri = Uri.parse(url);
                String scheme = uri.getScheme();
                String host = uri.getHost();

                Boolean isExternalUri = false;
                String extParameter = "";
                try {
                    extParameter = uri.getQueryParameter("external_browser");

                    if (extParameter == null || extParameter.equals("")) {
                        extParameter = Utils.getParam("external_browser");
                    }
                    if (extParameter == null) extParameter = "";
                    
                    if (extParameter.equals("2")) {
                        uri = removeQueryParameter(uri, "external_browser");
                        url = uri.toString();
                        isExternalUri = true;
                    }
                    else if (extParameter.equals("1")) {
                        isExternalUri = true;
                    }
                } catch (Exception e) {
                    isExternalUri = false;
                }                

                Log.d(Utils.LOG_TAG, "whiteListDomain/innerDomain/externalDocument: " + whiteListDomains.contains(host) + "/" + innerDomains.contains(host) + "/" +
                    externalDocuments.contains(MimeTypeMap.getFileExtensionFromUrl(host)));
                
                isExternalUri |= pageLoaded && !whiteListDomains.contains(host) && !innerDomains.contains(host);
                isExternalUri |= externalDocuments.contains(MimeTypeMap.getFileExtensionFromUrl(host));

                if (extParameter.equals("0")) isExternalUri = false;
                
                if ( !isExternalUri && (scheme.equals("http") || scheme.equals("https")) ) { // Unable to distinguish redirects and user clicks?
                    view.loadUrl(url);
                } else {
                    try {
                         Log.d(Utils.LOG_TAG, "Starting activity for URL: " + url);
                         Intent intent = null;
                         if (scheme.equals("intent")) {
                             intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME);
                         } else {
                             intent = new Intent(Intent.ACTION_VIEW, uri);
                         }
                         Activity activity = (Activity)view.getContext();
                         activity.startActivity(intent);
                    } catch (Exception e) {
                        Log.d(Utils.LOG_TAG, "WebView Error:" + e.getMessage());
                    }
                }
                
                return true;
            } else {
                // one known way to get here is to receive (302, "Moved temporarily") when opening a page (for example, posting LTI form to Connect)
                // which doesn't mean this link should be opened in external browser
                // However, if intention is really to download file and download link will return 302, there should be workaround here
                Log.d(Utils.LOG_TAG, "shouldOverrideUrlLoading URL: skipping when page is not loaded (redirected)");
                return false;
            }
        }
    }
    
    private class WebChromeClientImpl {
        public boolean onJsAlert (WebView view, String url, String message, @NonNull final android.webkit.JsResult result)
        {
            Context ctx = group.getContext();
            new AlertDialog.Builder(ctx)
            .setTitle("JS Alert")
            .setMessage(message)
            .setPositiveButton(android.R.string.ok,
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int which) { result.confirm(); }
                }).setCancelable(false).create().show();
            return true;
        }
        
        public boolean onConsoleMessage(@NonNull ConsoleMessage cm) {
            Log.d(Utils.LOG_TAG, "RealHTML JS: " + cm.message() + " -- From line "
                                 + cm.lineNumber() + " of "
                                 + cm.sourceId() );
            return true;
         }

         public boolean onCreateWindow(WebView viewp, boolean isDialog, boolean isUserGesture, @NonNull Message resultMsg) {
            WebView newWebView = new WebView(group.getContext());
            
            newWebView.setWebViewClient(new WebViewClient() {
                // need to check to miss redirects
                boolean pageStarted = false;
                
                @Override
                public void onPageStarted(@NonNull WebView view, String url, Bitmap favicon) {
                    if (!pageStarted) {
                        Intent browserIntent = new Intent(Intent.ACTION_VIEW);
                        browserIntent.setData(Uri.parse(url));
                        Activity activity = (Activity)view.getContext();
                        activity.startActivity(browserIntent);
                        pageStarted = true;
                    }
                }
            });
            
            WebView.WebViewTransport transport = (WebView.WebViewTransport) resultMsg.obj;
            transport.setWebView(newWebView);
            resultMsg.sendToTarget();

            return true;
         }
         
         @Nullable
         private View mFullscreenView;
         public void onShowCustomView(View view, WebChromeClient.CustomViewCallback callback) {
             Log.d(Utils.LOG_TAG, "Entering Full Screen Mode!");
             if (mFullscreenView != null) {
                 ((ViewGroup) mFullscreenView.getParent()).removeView(mFullscreenView);
             }
             mFullscreenView = view;
             Activity a = (Activity)group.getContext();
             a.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
             a.getWindow().addContentView(mFullscreenView, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                     ViewGroup.LayoutParams.MATCH_PARENT, Gravity.CENTER));
             // For some reason, GL surface view stays on top of full screen view. Regardless of order in layout. Hiding it helped
             View gls = group.getFlowRunnerView();
             if (gls != null) {
                 gls.setVisibility(View.INVISIBLE);
             }
         }
         
         public void onHideCustomView() {
             Log.d(Utils.LOG_TAG, "Exiting Full Screen Mode!");
             Activity a = (Activity)group.getContext();
             
             if (mFullscreenView == null) {
                 return;
             }
             
             a.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
             ((ViewGroup) mFullscreenView.getParent()).removeView(mFullscreenView);
             mFullscreenView = null;
             View gls = group.getFlowRunnerView();
             if (gls != null) {
                 gls.setVisibility(View.VISIBLE);
             }
         }
    }
    
    private void setCustomUserAgent(@NonNull WebView web_view) {
        Context ctx = group.getContext();
        PackageManager pm = ctx.getPackageManager();
        String app_label = ctx.getApplicationInfo().loadLabel(pm).toString();
        String app_version = "";
        try { app_version = pm.getPackageInfo(ctx.getPackageName(), 0).versionName; } catch(Exception e) {}
        String ua = web_view.getSettings().getUserAgentString() + " [" + app_label + "/v" + app_version + "]";
        web_view.getSettings().setUserAgentString(ua);
        Log.i(Utils.LOG_TAG, "WebView UserAgent = " + ua);
    }
    
    private void setupCache(@NonNull WebView web_view) {
        Context ctx = group.getContext();
        java.io.File cache_dir = ctx.getCacheDir();
        if (!cache_dir.exists()) {
            cache_dir.mkdirs();
        }
        Log.i(Utils.LOG_TAG, "HTML5 App Cache path to be configured as: " + cache_dir.getPath());
        // files are too sticky with LOAD_DEFAULT
        web_view.getSettings().setCacheMode(WebSettings.LOAD_NO_CACHE);
        // but we need appcache 
        web_view.getSettings().setAppCachePath(cache_dir.getPath());
        web_view.getSettings().setAppCacheEnabled(true);
    }
    
    private static boolean debuggingEnabled = false;
    private void enableWebViewDebugging() {
        if (debuggingEnabled) return;
        debuggingEnabled = true;
        try {
            Activity activity = (Activity)group.getContext();
            if ( (activity.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0 ) {
                // Accessible for Android > 4.4
                Method m = WebView.class.getDeclaredMethod("setWebContentsDebuggingEnabled", boolean.class);
                m.invoke(null, true);
            }
        } catch(Exception e) {
            Log.i(Utils.LOG_TAG, "Cannot enable WebView debugging");
        }
    }

    @Nullable
    @SuppressLint("SetJavaScriptEnabled")
	protected View createView() {
        final Context ctx = group.getContext();
        WebView web_view = null; 
        

        web_view = new WebView(ctx) {
            @Override
            public boolean onTouchEvent(MotionEvent event) {
                group.requestDisallowInterceptTouchEvent(use_zoom);
                return super.onTouchEvent(event);
            }
        };

        web_view.setWebChromeClient(new WebChromeClient() {
            @NonNull
            private WebChromeClientImpl impl = new WebChromeClientImpl();
            // Show JS alert. (Otherwise JS "alert()" is ignored)
            @Override
            public boolean onJsAlert (WebView view, String url, String message, @NonNull final android.webkit.JsResult result) {
                return impl.onJsAlert(view, url, message, result);
            }
            @Override
            public boolean onConsoleMessage(@NonNull ConsoleMessage cm) {
                return impl.onConsoleMessage(cm);
            }
            @Override
            public boolean onCreateWindow(WebView viewp, boolean isDialog, boolean isUserGesture, @NonNull Message resultMsg) {
                return impl.onCreateWindow(viewp, isDialog, isUserGesture, resultMsg);
            }
            @Override
            public void onShowCustomView(View view, WebChromeClient.CustomViewCallback callback) {
                impl.onShowCustomView(view, callback);
            }
            @Override
            public void onHideCustomView() {
                impl.onHideCustomView();
            }
        });

        web_view.setWebViewClient(new WebViewClient() {
            @NonNull
            private WebViewClientImpl impl = new WebViewClientImpl();
            @Override
            public void onPageStarted(WebView webView, String url, Bitmap favicon) {
                impl.onPageStarted(webView, url, favicon);
            }
            @Override
            public void onPageFinished(WebView webView, String url) {
                impl.onPageFinished(webView, url);
            }
            @Override
            public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
                impl.onReceivedError(view, errorCode, description, failingUrl);
            }
            @Override
            public boolean shouldOverrideUrlLoading(@NonNull WebView view, String url) {
                return impl.shouldOverrideUrlLoading(view, url);
            }
        });

        setCustomUserAgent(web_view);
        setupCache(web_view);

        web_view.getSettings().setJavaScriptEnabled(true);
        web_view.getSettings().setDomStorageEnabled(true);
        web_view.getSettings().setSupportMultipleWindows(true);
        // zoom settings up (should not work without requestDisallowInterceptTouceEvent inside onTouchEvent)
        web_view.getSettings().setSupportZoom(true);
        web_view.getSettings().setBuiltInZoomControls(true);
        web_view.getSettings().setDisplayZoomControls(false);

        enableWebViewDebugging();

        // Download files like a browser does
        web_view.setDownloadListener(new DownloadListener() {
           @Override
           public void onDownloadStart(String url, String userAgent,
                   String contentDisposition, String mimetype,
                   long contentLength) {
               Utils.systemDownloadFile(ctx, url);
            }
       });

        web_view.addJavascriptInterface(new FlowJSInterface(group.getWrapper(), id, this), "flow");

		ViewGroup.LayoutParams layoutParams = new ViewGroup.LayoutParams(
			ViewGroup.LayoutParams.MATCH_PARENT,
			ViewGroup.LayoutParams.MATCH_PARENT
		);

		web_view.setLayoutParams(layoutParams);

        return web_view;
    }

    @Nullable
    private Runnable create_cb = new Runnable() {
        public void run() {
            if (id == 0 || url == null) return;
            WebView view = (WebView) getOrCreateView();
            view.loadUrl(group.resource_uri.resolve(url).toString());
        }
    };

    private static final String ALLOWED_URI_CHARS = "@#&=*+-_.,:!?()/~'%";
    public void configure(final String url) {
        this.url = Uri.encode(url, ALLOWED_URI_CHARS);
        group.post(create_cb);
    }

    public void evalJS(final String js) {
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            public void run() {
            final WebView view = (WebView)getOrCreateView();
            view.loadUrl("javascript:" + js);
        } // Should always run in main UI thread
    });
    }
}
