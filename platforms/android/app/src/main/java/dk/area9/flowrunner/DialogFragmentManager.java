package dk.area9.flowrunner;

import android.app.AlertDialog;
import android.app.Dialog;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.fragment.app.DialogFragment;
import androidx.fragment.app.FragmentManager;


public class DialogFragmentManager {
    /* Dialogs */
    static final int DIALOG_LOADING_ID = 1;
    static final int DIALOG_DOWNLOAD_FAILED_ID = 2;
    static final int DIALOG_LOAD_FAILED_ID = 3;
    static final int DIALOG_CRASH_ID = 4;
    static final int DIALOG_DOWNLOADING_ID = 5;

    private FragmentManager fragmentManager;
    private DialogFragment currentDialog = null;

    DialogFragmentManager(FragmentManager fragmentManager) {
        this.fragmentManager = fragmentManager;
    }

    void setCurDialog(int id) {
        if (currentDialog != null) {
            int cur_dialog_id = currentDialog.getArguments().getInt("id");
            if (cur_dialog_id == id)
                return;
            if (cur_dialog_id != 0)
                currentDialog.dismiss();
        }
        if (id != 0) {
            switch (id) {
                case DIALOG_LOADING_ID:
                    currentDialog = ProgressDialogFragment.newInstance(id, ProgressDialog.STYLE_SPINNER, "Loading executable...");
                    break;
                case DIALOG_DOWNLOAD_FAILED_ID:
                    currentDialog = AlertDialogFragment.newInstance(id, "Could not access the network server.", "Retry");
                    break;
                case DIALOG_LOAD_FAILED_ID:
                    currentDialog = AlertDialogFragment.newInstance(id, "Could not load the executable.", "Retry");
                    break;
                case DIALOG_CRASH_ID:
                    currentDialog = AlertDialogFragment.newInstance(id, "The program has crashed.", "Restart");
                    break;
                case DIALOG_DOWNLOADING_ID:
                    currentDialog = ProgressDialogFragment.newInstance(id, ProgressDialog.STYLE_HORIZONTAL, "Downloading data...");
                    break;
                default:
                    return;
            }
            currentDialog.show(fragmentManager, String.valueOf(id));
        }
    }

    void setProgress(int value) {
        if (currentDialog instanceof ProgressDialogFragment) {
            ((ProgressDialogFragment)currentDialog).setProgress(value);
        }
    }

    void setMax(int value) {
        if (currentDialog instanceof ProgressDialogFragment) {
            ((ProgressDialogFragment)currentDialog).setMax(value);
        }
    }

    public static class ProgressDialogFragment extends DialogFragment {

        public static ProgressDialogFragment newInstance(int id, int style, String message) {
            ProgressDialogFragment f = new ProgressDialogFragment();

            Bundle args = new Bundle();
            args.putInt("id", id);
            args.putInt("style", style);
            args.putString("message", message);
            f.setArguments(args);

            return f;
        }

        @NonNull
        @Override
        public Dialog onCreateDialog(Bundle savedInstanceState) {
            ProgressDialog progressDialog = new ProgressDialog(getActivity());
            progressDialog.setProgressStyle(getArguments().getInt("style"));
            progressDialog.setMessage(getArguments().getString("message"));
            progressDialog.setCancelable(false);
            return progressDialog;
        }

        public void setProgress(int value) {
            if (getDialog() != null)
                ((ProgressDialog) getDialog()).setProgress(value);
        }

        public void setMax(int value) {
            if (getDialog() != null)
                ((ProgressDialog)getDialog()).setMax(value);
        }
    }

    public static class AlertDialogFragment extends DialogFragment {

        public static AlertDialogFragment newInstance(int id, String message, String restartButton) {
            AlertDialogFragment f = new AlertDialogFragment();

            Bundle args = new Bundle();
            args.putInt("id", id);
            args.putString("message", message);
            args.putString("restartButton", restartButton);
            f.setArguments(args);

            return f;
        }

        @NonNull
        @Override
        public Dialog onCreateDialog(Bundle savedInstanceState) {
            String message = getArguments().getString("message");
            String restartBtn = getArguments().getString("restartButton");

            AlertDialog.Builder builder = new AlertDialog.Builder(getActivity());
            builder.setMessage(message);

            builder.setCancelable(false)
                    .setPositiveButton(restartBtn, new DialogInterface.OnClickListener() {
                        public void onClick(@NonNull DialogInterface dialog, int id) {
                            dismiss();
                            ((FlowRunnerActivity)getActivity()).loadWrapper();
                        }
                    })
                    .setNegativeButton("Exit", new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dialog, int id) {
                            getActivity().finish();
                        }
                    });

            return builder.create();
        }
    }

}
