package dk.area9.flowrunner;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import android.app.Activity;
import android.app.ProgressDialog;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import androidx.annotation.NonNull;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.Toast;

public class LauncherActivity extends Activity {
    private EditText BytecodeURLField;
    private ListView BytecodeList;
    private EditText URLParametersField;
    
    private ArrayAdapter<String> ListAdapter;
    
    private URI BaseURI = URI.create("https://localhost/flow/");
    @NonNull
    private String BytecodesDir = "bytecodes/";
    
    @NonNull
    private Map<String, String> URLParametersMap = new HashMap<String, String>();
    
    @Override
    public void onCreate(Bundle savedInstanceState) {
      super.onCreate(savedInstanceState);
      
      try {
          int view_id = Class.forName(getPackageName() + ".R$layout").getDeclaredField("launcherview").getInt(null);
          setContentView(view_id);
          
          Class<?> id = Class.forName(getPackageName() + ".R$id");
          BytecodeURLField = findViewById((Integer)(id.getField("url_field").get(null)));
          BytecodeList = findViewById((Integer)(id.getField("downloaded_files").get(null)));
          URLParametersField = findViewById((Integer)(id.getField("url_parameters_field").get(null)));

          Button downloadButton = findViewById((Integer)(id.getField("download_button").get(null)));
          Button runButton = findViewById((Integer)(id.getField("run_button").get(null)));
          
          downloadButton.setOnClickListener(new OnClickListener() {
              public void onClick(View view) {
                  try { downloadBytecode(); } catch (Exception e) { showErrorMessage(e.toString()); }
              }
            });
          
          runButton.setOnClickListener(new OnClickListener() {
              public void onClick(View view) {
                  try { runSelectedBytecode(); } catch (Exception e) { showErrorMessage(e.toString()); }
              }
            });   
          
          File BytecodeDirFile = new File(getFilesDir(), BytecodesDir);
          BytecodeDirFile.mkdir();
          
          ListAdapter = new ArrayAdapter<String>(this, android.R.layout.simple_list_item_single_choice, new ArrayList<String>());
          BytecodeList.setAdapter(ListAdapter);
          BytecodeList.setChoiceMode(ListView.CHOICE_MODE_SINGLE);
          updateListAdapter();
          
          BytecodeList.setOnItemClickListener(new OnItemClickListener() {
              @Override
              public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                  int item_idx = BytecodeList.getCheckedItemPosition();
                  if (item_idx != AdapterView.INVALID_POSITION) {
                      String params = URLParametersMap.get(ListAdapter.getItem(item_idx));
                      URLParametersField.setText(params != null ? params : "");
                  }
                  saveURLParametersMap();
              }
          });
          
          URLParametersField.addTextChangedListener(new TextWatcher() {
              @Override
              public void afterTextChanged(Editable s) { }
              @Override
              public void beforeTextChanged(CharSequence arg0, int arg1, int arg2, int arg3) { }
              @Override
              public void onTextChanged(@NonNull CharSequence text, int arg1, int arg2, int arg3) {
                  int item_idx = BytecodeList.getCheckedItemPosition();
                  if (item_idx != AdapterView.INVALID_POSITION) {
                      URLParametersMap.put(ListAdapter.getItem(item_idx), text.toString());
                  }
              }
          });
          
          loadURLParametersMap();
      } catch (Exception e) {
          Log.e(Utils.LOG_TAG, "Cannot create Launcher Activity view : " + e);
      }
    }
    
    @Override
    public void onDestroy() {
        saveURLParametersMap();
        super.onDestroy();
    }
    
    private void saveURLParametersMap() {
        try {
            FileOutputStream fos = new FileOutputStream(getFilesDir() + "/urlparametersmap.ser");
            ObjectOutputStream oos = new ObjectOutputStream(fos);
            oos.writeObject(URLParametersMap);
            oos.close();
        } catch (Exception e) {
            Log.e(Utils.LOG_TAG, "Cannot save URL parameters");
        }
    }
    
    private void loadURLParametersMap() {
        try {
            FileInputStream fis = new FileInputStream(getFilesDir() + "/urlparametersmap.ser");
            ObjectInputStream ois = new ObjectInputStream(fis);
            URLParametersMap = (Map<String, String>)ois.readObject();
            ois.close();
        } catch (Exception e) {
            Log.e(Utils.LOG_TAG, "Cannot load URL parameters");
        }
    }
    
    private void showErrorMessage(String msg) {
        Toast.makeText(getApplicationContext(), msg, Toast.LENGTH_LONG).show();
        Log.e(Utils.LOG_TAG, msg);
    }
    
    private void updateListAdapter() {
        File dir = new File(getFilesDir(), BytecodesDir);
        String[] bytecode_files = dir.list();
        ListAdapter.clear();
        ListAdapter.addAll(bytecode_files);
    }
    
    private ProgressDialog DownloadingProgressDlg;
    private void showDownloadingProgressBar() {
        DownloadingProgressDlg = new ProgressDialog(this);
        DownloadingProgressDlg.setProgressStyle(ProgressDialog.STYLE_HORIZONTAL);
        DownloadingProgressDlg.setMessage("Downloading file...");
        DownloadingProgressDlg.setCancelable(false);
        DownloadingProgressDlg.setProgress(0);
        DownloadingProgressDlg.show();
    }
    
    private void downloadBytecode() throws FileNotFoundException {
        String url = BytecodeURLField.getText().toString().trim();
        
        if (!url.isEmpty()) {
            if (url.indexOf(".") == -1) url += ".bytecode";
            
            URI full_uri = BaseURI.resolve(url);
            String file_name = (new File(full_uri.getPath())).getName();
            final File dest_file = new File(getFilesDir() + "/" + BytecodesDir, file_name);
            FileOutputStream file_stream = new FileOutputStream(dest_file);
            
            Utils.HttpLoadCallback download_callback = new Utils.HttpLoadAdaptor(url) {
                public void httpContentLength(long bytes) {
                    DownloadingProgressDlg.setMax((int)bytes);
                }
                public void copyProgress(long bytes) {
                    DownloadingProgressDlg.setProgress((int)bytes);
                }
                public void httpError(final String message) {
                    runOnUiThread(new Runnable() {
                        public void run() {
                            DownloadingProgressDlg.dismiss();
                            if (dest_file.exists()) dest_file.delete();
                            updateListAdapter();
                            showErrorMessage(message);
                        }
                    });
                }
                public void httpFinished(int status, HashMap<String, String> headers, final boolean withData) {
                    super.httpFinished(status, headers, withData);
                    runOnUiThread(new Runnable() {
                        public void run() {
                            DownloadingProgressDlg.dismiss();
                            if (!withData) {
                                showErrorMessage("Cannot download.");
                                if (dest_file.exists()) dest_file.delete();
                            }
                            updateListAdapter();
                        }
                    });
                }
            };
            
            try {
                Utils.loadHttpAsync(new URL(full_uri.toString()), null, null, null, file_stream, download_callback);
            } catch (IOException exception) {
                System.out.println("I/O error: " + full_uri.toString());
            }
            showDownloadingProgressBar();
        } else {
            showErrorMessage("Empty bytecode name");
        }
    }
    
    private void runSelectedBytecode() {
        int item_idx = BytecodeList.getCheckedItemPosition();
        if (item_idx == AdapterView.INVALID_POSITION) {
            showErrorMessage("No file selected");
        } else {
            String bytecode_name = ListAdapter.getItem(item_idx);
            Intent runner_intent = new Intent(this, FlowRunnerActivity.class);
            Uri intent_uri = Uri.fromFile(new File(getFilesDir() + "/" + BytecodesDir, bytecode_name));
            
            String url_params = URLParametersMap.get(bytecode_name);
            if (url_params != null) {
                String url_string = intent_uri.toString() + "?" + Uri.encode(url_params, "&=");
                intent_uri = Uri.parse(url_string);
            }
            
            runner_intent.setData(intent_uri);
            runner_intent.setAction(Intent.ACTION_VIEW);
            startActivity(runner_intent);
        }
    }
}
