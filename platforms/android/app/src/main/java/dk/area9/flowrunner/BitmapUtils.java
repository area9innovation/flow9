package dk.area9.flowrunner;

import java.io.IOException;
import java.io.InputStream;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.net.Uri;
import android.os.Build;
import androidx.annotation.NonNull;

public class BitmapUtils {
    public static final int FIT_CONTAIN = 0;
    public static final int FIT_FILL = 1;
    public static final int FIT_COVER = 2;
    
    // Next 4 methods responsible for issues with too high image resolution or wrong image orientation
    // Wrong image orientation issue appears with front camera
    // more info here: http://stackoverflow.com/questions/14066038/why-image-captured-using-camera-intent-gets-rotated-on-some-devices-in-android
    /**
     * This method is responsible for solving the rotation issue if exist. Also scale the images to
     * 1024x1024 resolution
     *
     * @param context       The current context
     * @param selectedImage The Image URI
     * @return Bitmap image results
     * @throws IOException
     */
    public static Bitmap handleSamplingAndRotationBitmap(Context context, @NonNull Uri selectedImage, int desiredWidth, int desiredHeight, int fitMode) throws IOException {
        // NOTICE: Because this method use context.getContentResolver().openInputStream, better to run this method in background thread
        // First decode with inJustDecodeBounds=true to check dimensions
        final BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        InputStream imageStream = context.getContentResolver().openInputStream(selectedImage);
        BitmapFactory.decodeStream(imageStream, null, options);
        imageStream.close();

        int imageOrientation = getImageOrientation(context, selectedImage);

        // Calculate inSampleSize
        if (imageOrientation == 90 || imageOrientation == 270) {
            // image is rotated for 90 or 270 degrees, we should swap desiredWidth and desiredHeight
            int tmp = desiredWidth;
            desiredWidth = desiredHeight;
            desiredHeight = tmp;
        }
        options.inSampleSize = calculateInSampleSize(options, desiredWidth, desiredHeight);

        // Decode bitmap with inSampleSize set
        options.inJustDecodeBounds = false;
        imageStream = context.getContentResolver().openInputStream(selectedImage);
        Bitmap img = BitmapFactory.decodeStream(imageStream, null, options);
        if (fitMode == FIT_FILL) {
            Bitmap scaledImg = Bitmap.createScaledBitmap(img, desiredWidth, desiredHeight, true);
            img.recycle();
            img = scaledImg;
        } else if (fitMode == FIT_COVER) {
            int newWidth, newHeight;
            if (desiredWidth > desiredHeight)
            {
                newWidth = desiredWidth;
                newHeight = (int)(img.getHeight() * ((double)desiredWidth / img.getWidth()));
            } else {
                newWidth = (int)(img.getWidth() * ((double)desiredHeight / img.getHeight()));
                newHeight = desiredHeight;
            }
            Bitmap tmp = Bitmap.createScaledBitmap(img, newWidth, newHeight, true);
            img.recycle();
            img = Bitmap.createBitmap(tmp, (tmp.getWidth() - desiredWidth) / 2, (tmp.getHeight() - desiredHeight) / 2, desiredWidth, desiredHeight);
            tmp.recycle();
        }

        return imageOrientation == 0 ? img : rotateImage(img, imageOrientation);
    }
    
    /**
     * Calculate an inSampleSize for use in a {@link BitmapFactory.Options} object when decoding
     * bitmaps using the decode* methods from {@link BitmapFactory}. This implementation calculates
     * the closest inSampleSize that will result in the final decoded bitmap having a width and
     * height equal to or larger than the requested width and height. This implementation does not
     * ensure a power of 2 is returned for inSampleSize which can be faster when decoding but
     * results in a larger bitmap which isn't as useful for caching purposes.
     *
     * @param options   An options object with out* params already populated (run through a decode*
     *                  method with inJustDecodeBounds==true
     * @param reqWidth  The requested width of the resulting bitmap
     * @param reqHeight The requested height of the resulting bitmap
     * @return The value to be used for inSampleSize
     */
    private static int calculateInSampleSize(BitmapFactory.Options options, int reqWidth, int reqHeight) {
        // Raw height and width of image
        final int height = options.outHeight;
        final int width = options.outWidth;
        int inSampleSize = 1;
    
        if (height > reqHeight || width > reqWidth) {
    
            // Calculate ratios of height and width to requested height and width
            final int heightRatio = Math.round((float) height / (float) reqHeight);
            final int widthRatio = Math.round((float) width / (float) reqWidth);
    
            // Choose the smallest ratio as inSampleSize value, this will guarantee a final image
            // with both dimensions larger than or equal to the requested height and width.
            inSampleSize = heightRatio < widthRatio ? heightRatio : widthRatio;
    
            // This offers some additional logic in case the image has a strange
            // aspect ratio. For example, a panorama may have a much larger
            // width than height. In these cases the total pixels might still
            // end up being too large to fit comfortably in memory, so we should
            // be more aggressive with sample down the image (=larger inSampleSize).
    
            final float totalPixels = width * height;
    
            // Anything more than 2x the requested pixels we'll sample down further
            final float totalReqPixelsCap = reqWidth * reqHeight * 2;
    
            while (totalPixels / (inSampleSize * inSampleSize) > totalReqPixelsCap) {
                inSampleSize++;
            }
        }
        return inSampleSize;
    }
    
    /**
     * Rotate an image if required.
     *
     * @param img           The image bitmap
     * @param selectedImage Image URI
     * @return The resulted Bitmap after manipulation
     */
    private static Bitmap rotateImageIfRequired(@NonNull Context context, @NonNull Bitmap img, @NonNull Uri selectedImage) throws IOException {
        String path = Utils.getPath(context, selectedImage);
        if (path == null) {
            return img;
        }
        ExifInterface ei = new ExifInterface(path);
        int orientation = ei.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL);

        switch (orientation) {
            case ExifInterface.ORIENTATION_ROTATE_90:
                return rotateImage(img, 90);
            case ExifInterface.ORIENTATION_ROTATE_180:
                return rotateImage(img, 180);
            case ExifInterface.ORIENTATION_ROTATE_270:
                return rotateImage(img, 270);
            default:
                return img;
        }
    }
    
    private static int getImageOrientation(@NonNull Context context, @NonNull Uri selectedImage) throws IOException {

        ExifInterface ei;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            InputStream imageStream = context.getContentResolver().openInputStream(selectedImage);
            ei = new ExifInterface(imageStream);
            imageStream.close();
        } else {
            String path = Utils.getPath(context, selectedImage);
            if (path == null) {
                return 0; // TODO: we can't give info about orientation, may be we should inform about that?
            }
            ei = new ExifInterface(path);
        }

        int orientation = ei.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL);

        switch (orientation) {
            case ExifInterface.ORIENTATION_ROTATE_90:
                return 90;
            case ExifInterface.ORIENTATION_ROTATE_180:
                return 180;
            case ExifInterface.ORIENTATION_ROTATE_270:
                return 270;
            default:
                return 0;
        }
    }
    
    private static Bitmap rotateImage(@NonNull Bitmap img, int degree) {
        Matrix matrix = new Matrix();
        matrix.postRotate(degree);
        Bitmap rotatedImg = Bitmap.createBitmap(img, 0, 0, img.getWidth(), img.getHeight(), matrix, true);
        img.recycle();
        return rotatedImg;
    }
}