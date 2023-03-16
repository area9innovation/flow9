package dk.area9.flowrunner;

import android.content.Intent;
import android.net.Uri;
import androidx.annotation.Nullable;
import android.webkit.MimeTypeMap;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.Collections;

class FlowFileSystemInterface {

    private FlowRunnerActivity flowRunnerActivity;
    private FlowRunnerWrapper wrapper;

    private int maxFilesCount;
    private int callbackRoot;

    FlowFileSystemInterface(FlowRunnerActivity ctx, FlowRunnerWrapper wrp) {
        flowRunnerActivity = ctx;
        wrapper = wrp;
    }

    void openFileDialog(int maxFilesCount, String[] fileTypes, int callbackRoot) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            this.callbackRoot = callbackRoot;
            this.maxFilesCount = maxFilesCount;
            if (maxFilesCount == -1)
                this.maxFilesCount = Integer.MAX_VALUE;
            ArrayList<String> types = new ArrayList<>();
            Collections.addAll(types, fileTypes);

            Intent intent = null;
                intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.setType("*/*");
            if (this.maxFilesCount > 1)
                intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);

            intent.addCategory(Intent.CATEGORY_OPENABLE);

            if(types.size() > 0 && !types.contains("*/*")) {
                for(int i = 0; i < types.size(); i++) {
                    String type = types.get(i);
                    if (type.contains(".")) {
                        String extension = type.substring(type.lastIndexOf(".") + 1);
                        types.set(i, MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension));
                    }
                }
                intent.putExtra(Intent.EXTRA_MIME_TYPES, types.toArray(new String[0]));
            }

            flowRunnerActivity.startActivityForResult(intent, 4);
        }
    }

    void handleOpenFileDialogResult(@Nullable final Intent data) {
        ArrayList<Uri> contentUrls = new ArrayList<>();

        if (data != null) {
            if (data.getClipData() != null) {
                int length = Math.min(this.maxFilesCount, data.getClipData().getItemCount());
                for(int i = 0; i < length; i++) {
                    contentUrls.add(data.getClipData().getItemAt(i).getUri());
                }
            } else if (data.getData() != null) {
                contentUrls.add(data.getData());
            }
        }
        ArrayList<String> filePaths = new ArrayList<>();
        for (Uri uri : contentUrls) {
            String mimetype = flowRunnerActivity.getContentResolver().getType(uri);
            String extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimetype);
            try {
                FileInputStream is = (FileInputStream) flowRunnerActivity.getContentResolver().openInputStream(uri);
                // save file in application directory
                File tempFile = File.createTempFile("temp", "." + extension);
                FileOutputStream out = new FileOutputStream(tempFile);
                byte[] buf = new byte[1024];
                int len;
                while ((len = is.read(buf)) > 0) {
                    out.write(buf, 0, len);
                }
                out.flush();
                out.close();
                is.close();
                filePaths.add(tempFile.getPath());
                tempFile.deleteOnExit();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

        wrapper.deliverOpenFileDialogResult(this.callbackRoot, filePaths.toArray(new String[0]));
    }

    String getFileMimeType(String path) {
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(MimeTypeMap.getFileExtensionFromUrl(path));
    }
}
