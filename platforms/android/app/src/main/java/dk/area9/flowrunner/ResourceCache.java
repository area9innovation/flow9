package dk.area9.flowrunner;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.math.BigInteger;
import java.net.URI;
import java.net.URL;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;

import java.net.HttpURLConnection;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Base64;
import android.util.Log;

public class ResourceCache {
    @Nullable
    private static ResourceCache instance = null;

    @Nullable
    public synchronized static ResourceCache getInstance(@NonNull Context context) {
        if (instance == null)
            instance = new ResourceCache(context.getApplicationContext());
        return instance;
    }

    private Context app_context;

    
    private File cache_dir;
    @Nullable
    private File ext_cache_dir;

    @NonNull
    private HashMap<URI,List<Resolver>> pending_links = new HashMap<URI,List<Resolver>>();
    @NonNull
    private HashMap<URI,List<URI>> pending_tries = new HashMap<URI,List<URI>>();
    @NonNull
    private HashMap<URI,HttpURLConnection> pending_requests = new HashMap<>();

    public ResourceCache(Context context) {
        app_context = context;
    }

    public interface Resolver {
        void resolveFile(String filename);
        void resolveError(String message);
    }

    public synchronized boolean getCachedResource(@NonNull URI base, @NonNull String url, @NonNull Resolver callback) throws IOException {
        URI link = base.resolve(url.replace(" ", "%20"));
        Log.i(Utils.LOG_TAG, "load resource " + link);
        return getCachedResource(link, callback);
    }

    public synchronized boolean getCachedResource(@NonNull URI base, @NonNull String url, @NonNull HashMap<String,String> headers, @NonNull Resolver callback) throws IOException {
        URI link = base.resolve(url.replace(" ", "%20"));
        Log.i(Utils.LOG_TAG, "load resource " + link);
        return getCachedResource(link, headers, callback);
    }

    public synchronized boolean getCachedResource(@NonNull URI link, @NonNull Resolver callback) throws IOException {
        return getCachedResource(link, new HashMap<String,String>(), callback);
    }

    public synchronized boolean getCachedResource(@NonNull URI link, @NonNull HashMap<String,String> headers, @NonNull Resolver callback) throws IOException {
        //Log.i(Utils.LOG_TAG, "Geting resource: " + link.toString());

        if ("file".equals(link.getScheme())) {
            tryLocalFile(link, callback);
            return true;
        }

        // Save the callback if already pending
        List<Resolver> pending = pending_links.get(link);
        if (pending != null) {
            pending.add(callback);
            return false;
        }

        // Try existing files
        String id = getStringHash(link.toString());

        updateCacheDirs();
        if (tryCachedFile(cache_dir, id, callback))
            return true;
        if (tryCachedFile(ext_cache_dir, id, callback))
            return true;

        // Start a download process
        File target_dir = ext_cache_dir;
        if (target_dir == null)
            target_dir = cache_dir;

        // Check, if URI is data URI scheme
        if (link.getScheme().equals("data")) {
            String strLink = link.toString();
            decodeBase64(target_dir, id, strLink.substring(strLink.indexOf(",") + 1), callback);
            return false;
        }

        startDownload(target_dir, id, link, headers, callback);
        return false;
    }

    public synchronized void abortPendingRequest(@NonNull URI base, @NonNull String url) {
        URI link = base.resolve(url.replace(" ", "%20"));
        pending_requests.get(link).disconnect();
    }
    
    public synchronized void removeCachedResource(@NonNull URI base, @NonNull String url) throws IOException {
        URI link = base.resolve(url.replace(" ", "%20"));
        String id = getStringHash(link.toString());
        updateCacheDirs();
        File fn = new File(cache_dir, id);
        fn.delete();
        fn = new File(ext_cache_dir, id);
        fn.delete();
    }

    private void tryLocalFile(URI link, @NonNull Resolver callback) {
        File dfile = new File(link.getPath());
        String apath = dfile.getAbsolutePath();
        if (dfile.isFile())
            callback.resolveFile(apath);
        else
            callback.resolveError("File not found: " + apath);
    }
    
    private boolean tryCachedFile(@Nullable File dir, @NonNull String id, @NonNull Resolver callback) {
        if (dir == null)
            return false;

        File fn = new File(dir, id);
        if (fn.isFile()) {
            callback.resolveFile(fn.getAbsolutePath());
            return true;
        }
        else {
            fn.delete();
            return false;
        }
    }
    
    private void updateCacheDirs() throws IOException {
        cache_dir = app_context.getCacheDir();
        if (cache_dir != null && !cache_dir.exists())
            if (!cache_dir.mkdirs())
                throw new IOException("Main cache dir not accessible");
        
        ext_cache_dir = app_context.getExternalCacheDir();
        if (ext_cache_dir != null && !ext_cache_dir.exists())
            if (!ext_cache_dir.mkdirs())
                ext_cache_dir = null;
    }

    private void startDownload(File dir, @NonNull String id, @NonNull URI link, @NonNull HashMap<String,String> headers, Resolver callback) throws IOException {
        List<URI> uris = new LinkedList<URI>();
        generateVariantURIs(uris, link);
        uris.add(link);
        pending_tries.put(link, uris);

        ArrayList<Resolver> rlst = new ArrayList<Resolver>();
        rlst.add(callback);
        pending_links.put(link, rlst);

        try {
            if (!startDownloadThread(dir, id, link, headers, null))
                resolveAsError(link, "Could not start download");
        } catch (IOException e) {
            resolveAsError(link, "I/O error: " + e.getMessage());
        }
    }
    
    private void decodeBase64(File dir, @NonNull String id, String base64String, Resolver callback) throws IOException {
        final File result = new File(dir, id);
        BufferedOutputStream output = new BufferedOutputStream(new FileOutputStream(result));

        final byte[] decodedBytes = Base64.decode(base64String, Base64.DEFAULT);
        output.write(decodedBytes);
        output.flush();
        output.close();

        callback.resolveFile(result.getAbsolutePath());
    }

    private void generateVariantURIs(@NonNull List<URI> uris, @NonNull URI link) throws IOException {
        if (Utils.urlHasExtension(link, ".swf"))
            uris.add(Utils.urlWithExtension(link, 4, ".png"));
        if (Utils.urlHasExtension(link, ".flv"))
            uris.add(Utils.urlWithExtension(link, 4, ".mp4"));
    }

    private synchronized List<Resolver> resolve(URI link) {
        //Log.i(Utils.LOG_TAG, "Resolving resource: " + link.toString());

        List<Resolver> rlst = pending_links.get(link);
        if (rlst == null)
            rlst = Collections.emptyList();

        pending_links.remove(link);
        pending_tries.remove(link);

        return rlst;
    }

    private void resolveAsError(URI link, String error) {
        for (Resolver rv : resolve(link))
            rv.resolveError(error);
    }

    private void resolveAsAbort(URI link) {
        pending_links.remove(link);
        pending_tries.remove(link);
    }

    private synchronized List<Resolver> renameAndResolve(URI link, File result, File tmp) {
        result.delete();

        if (!tmp.renameTo(result)) {
            tmp.delete();
            return null;
        }

        return resolve(link);
    }
    
    private void resolveAsFinished(URI link, @NonNull File result, @NonNull File tmp) {
        List<Resolver> rsv = renameAndResolve(link, result, tmp);
        if (rsv == null) {
            resolveAsError(link, "Could not rename temporary file");
            return;
        }

        String fn = result.getAbsolutePath();
        for (Resolver rv : rsv)
            rv.resolveFile(fn);
    }

    private boolean startDownloadThread(final File dir, @NonNull final String id, final URI base_link, @NonNull HashMap<String,String> headers, FileOutputStream old_output) throws IOException {
        List<URI> uris = pending_tries.get(base_link);
        if (uris == null || uris.isEmpty()) {
            pending_tries.remove(base_link);
            return false;
        }

        final URI link = uris.get(0);
        uris.remove(0);

        final File result = new File(dir, id);
        final File tmp = new File(dir, id + ".tmp");
        
        FileOutputStream output = null;

        try {
            forceClose(old_output, tmp);

            output = new FileOutputStream(tmp);
            final FileOutputStream foutput = output;
            URL url = new URL(link.toString());
            Utils.loadHttpAsync(url, null, headers, null, output, new Utils.HttpLoadAdaptor(link.toString()) {
                boolean switched = false;
                
                public boolean httpStatus(int status) {
                    if (status == 404) {
                        try {
                            if (startDownloadThread(dir, id, base_link, headers, foutput)) {
                                switched = true;
                                return false;
                            }
                        } catch (IOException e) {
                            httpError("I/O error: " + e.getMessage());
                            switched = true;
                        }
                    }

                    return status >= 200 && status < 300;
                }

                public void httpOpened(HttpURLConnection connection) {
                    pending_requests.put(link, connection);
                }
                
                public void httpFinished(int status, HashMap<String, String> headers, boolean withData) {
                    super.httpFinished(status, headers, withData);

                    pending_requests.remove(link);
                    if (switched) return;
                    try {
                        foutput.close();
                        if (withData)
                            resolveAsFinished(base_link, result, tmp);
                        else {
                            tmp.delete();
                            resolveAsError(base_link, "No data received");
                        }
                    } catch (IOException e) {
                        resolveAsError(base_link, "I/O error: " + e.getMessage());
                    }
                }
                
                public void httpError(String message) {
                    pending_requests.remove(link);
                    if (switched) return;
                    forceClose(foutput, tmp);
                    resolveAsError(base_link, message);
                }

                public void httpAbort(String message) {
                    pending_requests.remove(link);
                    if (switched) return;
                    forceClose(foutput, tmp);
                    resolveAsAbort(base_link);
                }
            });

            return true;
        } catch (IOException e) {
            forceClose(output, tmp);
            Log.e(Utils.LOG_TAG, "I/O error: " + e.getMessage());
            throw e;
        }
    }

    private static void forceClose(@Nullable OutputStream output, @Nullable File tmp) {
        if (output != null) {
            try { 
                output.close(); 
            } catch (IOException e) {}
        }
        if (tmp != null)
            tmp.delete();
    }
    
    private static String getStringHash(String text) {
        try {
            // Create MD5 Hash
            MessageDigest digest = MessageDigest.getInstance("MD5");
            digest.update(text.getBytes("UTF-8"));
            return String.format("%032x", new BigInteger(1, digest.digest()));
        } catch (NoSuchAlgorithmException e) {
            Log.wtf(Utils.LOG_TAG, "MD5 not supported?", e);
        } catch (UnsupportedEncodingException e) {
            Log.wtf(Utils.LOG_TAG, "UTF-8 not supported?", e);
        }
        return null;
    }
}
