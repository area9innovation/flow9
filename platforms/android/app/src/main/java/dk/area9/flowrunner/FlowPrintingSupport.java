package dk.area9.flowrunner;

import android.content.Context;
import android.os.Build;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.print.PageRange;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintDocumentInfo;
import android.print.PrintManager;
import androidx.annotation.RequiresApi;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URL;

public class FlowPrintingSupport {

    private FlowRunnerActivity flowRunnerActivity;

    public FlowPrintingSupport(FlowRunnerActivity ctx) {
        flowRunnerActivity = ctx;
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    public void printHTML(String html) {
        flowRunnerActivity.runOnUiThread(() -> {
            WebView webView = new WebView(flowRunnerActivity);
            webView.setWebViewClient(new WebViewClient() {

                public boolean shouldOverrideUrlLoading(WebView view, String url) {
                    return false;
                }

                @Override
                public void onPageFinished(WebView view, String url) {
                    PrintManager printManager = (PrintManager) flowRunnerActivity.getSystemService(Context.PRINT_SERVICE);

                    PrintDocumentAdapter printAdapter = webView.createPrintDocumentAdapter("HTMLDocumentAdapter");
                    printManager.print("PrintHTMLJob", printAdapter, new PrintAttributes.Builder().build());
                }
            });
            webView.loadDataWithBaseURL(null, html, "text/HTML", "UTF-8", null);
        });
    }

    @RequiresApi(api = Build.VERSION_CODES.KITKAT)
    public void printURL(String url) {
        PrintDocumentAdapter pda = new PrintDocumentAdapter() {

            @Override
            public void onWrite(PageRange[] pages, final ParcelFileDescriptor destination, CancellationSignal cancellationSignal, final WriteResultCallback callback) {
                Thread thread = new Thread(() -> {
                    InputStream input = null;
                    OutputStream output = null;
                    try {
                        input = new URL(url).openStream();
                        output = new FileOutputStream(destination.getFileDescriptor());

                        byte[] buf = new byte[1024];
                        int bytesRead;

                        while ((bytesRead = input.read(buf)) > 0) {
                            output.write(buf, 0, bytesRead);
                        }

                        callback.onWriteFinished(new PageRange[]{PageRange.ALL_PAGES});
                    } catch (Exception e) {
                        e.printStackTrace();
                    } finally {
                        try {
                            input.close();
                            output.close();
                        } catch (Exception e) {
                            e.printStackTrace();
                        }
                    }
                });
                thread.start();
            }

            @Override
            public void onLayout(PrintAttributes oldAttributes, PrintAttributes newAttributes, CancellationSignal cancellationSignal, LayoutResultCallback callback, Bundle extras) {
                if (cancellationSignal.isCanceled()) {
                    callback.onLayoutCancelled();
                    return;
                }
                PrintDocumentInfo pdi = new PrintDocumentInfo.Builder("DocumentBuilder").setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT).build();
                callback.onLayoutFinished(pdi, true);
            }
        };
        PrintManager printManager = (PrintManager) flowRunnerActivity.getSystemService(Context.PRINT_SERVICE);
        printManager.print("PrintUrlJob", pda, new PrintAttributes.Builder().build());
    }

}
