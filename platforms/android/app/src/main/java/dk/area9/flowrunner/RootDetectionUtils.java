package dk.area9.flowrunner;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Comprehensive root detection utility for Android applications.
 * Implements multiple detection methods to identify rooted devices and root bypass attempts.
 */
public class RootDetectionUtils {
    
    private static final String TAG = "RootDetection";
    
    // Common root binary paths
    private static final String[] ROOT_BINARIES = {
        "/system/bin/su",
        "/system/xbin/su", 
        "/sbin/su",
        "/system/su",
        "/vendor/bin/su",
        "/system/app/Superuser.apk",
        "/system/app/SuperSU.apk",
        "/system/xbin/busybox",
        "/system/bin/busybox",
        "/data/local/xbin/su",
        "/data/local/bin/su",
        "/system/sd/xbin/su",
        "/system/bin/failsafe/su",
        "/data/local/su"
    };
    
    // Root management applications
    private static final String[] ROOT_APPS = {
        "com.noshufou.android.su",
        "com.noshufou.android.su.elite", 
        "eu.chainfire.supersu",
        "com.koushikdutta.superuser",
        "com.thirdparty.superuser",
        "com.yellowes.su",
        "com.topjohnwu.magisk",
        "com.kingroot.kinguser",
        "com.kingo.root",
        "com.smedialink.oneclickroot",
        "com.zhiqupk.root.global",
        "com.alephzain.framaroot"
    };
    
    // Root hiding/bypass applications
    private static final String[] ROOT_HIDING_APPS = {
        "com.devadvance.rootcloak",
        "com.devadvance.rootcloakplus",
        "de.robv.android.xposed.installer",
        "com.saurik.substrate",
        "com.zachspong.temprootremovejb",
        "com.amphoras.hidemyroot",
        "com.amphoras.hidemyrootadfree",
        "com.formyhm.hiderootPremium",
        "com.formyhm.hideroot"
    };
    
    // Dangerous system properties
    private static final String[] DANGEROUS_PROPS = {
        "ro.debuggable",
        "ro.secure"
    };
    
    // Root detection result
    public static class RootDetectionResult {
        public final boolean isRooted;
        public final String detectionMethod;
        public final String details;
        
        public RootDetectionResult(boolean isRooted, String detectionMethod, String details) {
            this.isRooted = isRooted;
            this.detectionMethod = detectionMethod;
            this.details = details;
        }
    }
    
    /**
     * Performs comprehensive root detection check
     * @param context Application context
     * @return RootDetectionResult with detection details
     */
    public static RootDetectionResult detectRoot(Context context) {
        Log.i(TAG, "Starting comprehensive root detection...");
        
        // Check 1: Binary file detection
        RootDetectionResult result = checkRootBinaries();
        if (result.isRooted) return result;
        
        // Check 2: Root management apps
        result = checkRootApps(context);
        if (result.isRooted) return result;
        
        // Check 3: Root hiding apps (indicates bypass attempt)
        result = checkRootHidingApps(context);
        if (result.isRooted) return result;
        
        // Check 4: Build tags
        result = checkBuildTags();
        if (result.isRooted) return result;
        
        // Check 5: System properties
        result = checkSystemProperties();
        if (result.isRooted) return result;
        
        // Check 6: SU command execution
        result = checkSuCommand();
        if (result.isRooted) return result;
        
        // Check 7: RW system partition
        result = checkRWSystem();
        if (result.isRooted) return result;
        
        // Check 8: Dangerous system apps
        result = checkDangerousApps(context);
        if (result.isRooted) return result;
        
        // Check 9: Emulator detection
        result = checkEmulator(context);
        if (result.isRooted) return result;
        
        // Check 10: Frida detection
        result = checkFridaDetection();
        if (result.isRooted) return result;
        
        // Check 11: Advanced Magisk detection
        result = checkAdvancedMagisk();
        if (result.isRooted) return result;
        
        Log.i(TAG, "Root detection completed - No root detected");
        return new RootDetectionResult(false, "NONE", "Device appears clean");
    }
    
    /**
     * Quick root detection for periodic checks
     * @param context Application context
     * @return RootDetectionResult with detection details
     */
    public static RootDetectionResult quickRootCheck(Context context) {
        // Perform lightweight checks for periodic monitoring
        RootDetectionResult result = checkRootBinaries();
        if (result.isRooted) return result;
        
        result = checkBuildTags();
        if (result.isRooted) return result;
        
        result = checkSuCommand();
        if (result.isRooted) return result;
        
        return new RootDetectionResult(false, "NONE", "Quick check passed");
    }
    
    private static RootDetectionResult checkRootBinaries() {
        for (String path : ROOT_BINARIES) {
            try {
                File file = new File(path);
                if (file.exists()) {
                    Log.w(TAG, "Root binary detected: " + path);
                    return new RootDetectionResult(true, "BINARY_CHECK", "Found root binary: " + path);
                }
            } catch (Exception e) {
                // File access exception might indicate root hiding
                Log.w(TAG, "Exception checking binary " + path + ": " + e.getMessage());
            }
        }
        return new RootDetectionResult(false, "BINARY_CHECK", "No root binaries found");
    }
    
    private static RootDetectionResult checkRootApps(Context context) {
        PackageManager pm = context.getPackageManager();
        for (String packageName : ROOT_APPS) {
            try {
                pm.getPackageInfo(packageName, 0);
                Log.w(TAG, "Root management app detected: " + packageName);
                return new RootDetectionResult(true, "ROOT_APP_CHECK", "Found root app: " + packageName);
            } catch (PackageManager.NameNotFoundException e) {
                // App not found - this is expected for non-rooted devices
            }
        }
        return new RootDetectionResult(false, "ROOT_APP_CHECK", "No root apps detected");
    }
    
    private static RootDetectionResult checkRootHidingApps(Context context) {
        PackageManager pm = context.getPackageManager();
        for (String packageName : ROOT_HIDING_APPS) {
            try {
                pm.getPackageInfo(packageName, 0);
                Log.w(TAG, "Root hiding app detected: " + packageName);
                return new RootDetectionResult(true, "ROOT_HIDING_APP", "Found root hiding app: " + packageName);
            } catch (PackageManager.NameNotFoundException e) {
                // App not found - this is expected
            }
        }
        return new RootDetectionResult(false, "ROOT_HIDING_APP", "No root hiding apps detected");
    }
    
    private static RootDetectionResult checkBuildTags() {
        String buildTags = Build.TAGS;
        if (buildTags != null && buildTags.contains("test-keys")) {
            Log.w(TAG, "Test-keys build detected: " + buildTags);
            return new RootDetectionResult(true, "BUILD_TAGS", "Test-keys build: " + buildTags);
        }
        return new RootDetectionResult(false, "BUILD_TAGS", "Build tags clean");
    }
    
    private static RootDetectionResult checkSystemProperties() {
        try {
            // Check ro.debuggable
            String debuggable = getSystemProperty("ro.debuggable");
            if ("1".equals(debuggable)) {
                Log.w(TAG, "Debuggable build detected");
                return new RootDetectionResult(true, "SYSTEM_PROPS", "ro.debuggable=1");
            }
            
            // Check ro.secure
            String secure = getSystemProperty("ro.secure");
            if ("0".equals(secure)) {
                Log.w(TAG, "Insecure build detected");
                return new RootDetectionResult(true, "SYSTEM_PROPS", "ro.secure=0");
            }
        } catch (Exception e) {
            Log.w(TAG, "Exception checking system properties: " + e.getMessage());
        }
        return new RootDetectionResult(false, "SYSTEM_PROPS", "System properties clean");
    }
    
    private static RootDetectionResult checkSuCommand() {
        try {
            Process process = Runtime.getRuntime().exec(new String[]{"which", "su"});
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line = reader.readLine();
            if (line != null && !line.isEmpty()) {
                Log.w(TAG, "SU command found: " + line);
                return new RootDetectionResult(true, "SU_COMMAND", "SU found at: " + line);
            }
        } catch (Exception e) {
            // Exception is expected on non-rooted devices
        }
        
        // Try direct su execution
        try {
            Process process = Runtime.getRuntime().exec("su");
            process.destroy();
            Log.w(TAG, "SU command executed successfully");
            return new RootDetectionResult(true, "SU_EXECUTION", "SU command executed");
        } catch (Exception e) {
            // Exception is expected on non-rooted devices
        }
        
        return new RootDetectionResult(false, "SU_COMMAND", "SU command not available");
    }
    
    private static RootDetectionResult checkRWSystem() {
        try {
            // Check if system partition is mounted as read-write
            Process process = Runtime.getRuntime().exec("mount");
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            while ((line = reader.readLine()) != null) {
                if (line.contains("/system") && line.contains("rw")) {
                    Log.w(TAG, "System partition mounted RW: " + line);
                    return new RootDetectionResult(true, "RW_SYSTEM", "System partition RW");
                }
            }
        } catch (Exception e) {
            // Exception handling
        }
        return new RootDetectionResult(false, "RW_SYSTEM", "System partition read-only");
    }
    
    private static RootDetectionResult checkDangerousApps(Context context) {
        try {
            PackageManager pm = context.getPackageManager();
            List<ApplicationInfo> packages = pm.getInstalledApplications(PackageManager.GET_META_DATA);
            
            for (ApplicationInfo packageInfo : packages) {
                // Check for apps with system-level permissions that shouldn't have them
                if ((packageInfo.flags & ApplicationInfo.FLAG_SYSTEM) == 0) {
                    try {
                        String[] permissions = pm.getPackageInfo(packageInfo.packageName, 
                            PackageManager.GET_PERMISSIONS).requestedPermissions;
                        if (permissions != null) {
                            for (String permission : permissions) {
                                if (permission.equals("android.permission.WRITE_SECURE_SETTINGS") ||
                                    permission.equals("android.permission.INSTALL_PACKAGES")) {
                                    Log.w(TAG, "Dangerous app detected: " + packageInfo.packageName);
                                    return new RootDetectionResult(true, "DANGEROUS_APP", 
                                        "App with dangerous permissions: " + packageInfo.packageName);
                                }
                            }
                        }
                    } catch (Exception e) {
                        // Continue checking other apps
                    }
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "Exception checking dangerous apps: " + e.getMessage());
        }
        return new RootDetectionResult(false, "DANGEROUS_APP", "No dangerous apps detected");
    }
    
    private static String getSystemProperty(String key) {
        try {
            Process process = Runtime.getRuntime().exec("getprop " + key);
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String value = reader.readLine();
            return value != null ? value.trim() : "";
        } catch (Exception e) {
            return "";
        }
    }
    
    /**
     * Detects if the app is running on an emulator
     * Based on Indusface recommendations for emulator detection
     */
    private static RootDetectionResult checkEmulator(Context context) {
        try {
            // Check 1: Hardware characteristics
            if (Build.HARDWARE.contains("goldfish") || 
                Build.HARDWARE.contains("ranchu") ||
                Build.HARDWARE.contains("vbox") ||
                Build.PRODUCT.contains("sdk") ||
                Build.PRODUCT.contains("emulator") ||
                Build.PRODUCT.contains("simulator")) {
                Log.w(TAG, "Emulator detected via hardware/product: " + Build.HARDWARE + "/" + Build.PRODUCT);
                return new RootDetectionResult(true, "EMULATOR_DETECTION", "Hardware/Product indicates emulator");
            }
            
            // Check 2: Build characteristics
            if (Build.BRAND.equals("generic") || 
                Build.DEVICE.equals("generic") ||
                Build.MODEL.contains("Emulator") ||
                Build.MODEL.contains("Android SDK")) {
                Log.w(TAG, "Emulator detected via build info: " + Build.BRAND + "/" + Build.DEVICE + "/" + Build.MODEL);
                return new RootDetectionResult(true, "EMULATOR_DETECTION", "Build info indicates emulator");
            }
            
            // Check 3: Telephony manager (emulators often have fake values)
            try {
                android.telephony.TelephonyManager tm = (android.telephony.TelephonyManager) 
                    context.getSystemService(Context.TELEPHONY_SERVICE);
                if (tm != null) {
                    String networkOperator = tm.getNetworkOperatorName();
                    if ("Android".equals(networkOperator)) {
                        Log.w(TAG, "Emulator detected via network operator: " + networkOperator);
                        return new RootDetectionResult(true, "EMULATOR_DETECTION", "Network operator indicates emulator");
                    }
                }
            } catch (Exception e) {
                // Continue with other checks
            }
            
        } catch (Exception e) {
            Log.w(TAG, "Exception in emulator detection: " + e.getMessage());
        }
        return new RootDetectionResult(false, "EMULATOR_DETECTION", "Device appears to be physical");
    }
    
    /**
     * Detects Frida instrumentation framework
     * Based on Indusface recommendations for Frida detection
     */
    private static RootDetectionResult checkFridaDetection() {
        try {
            // Check 1: Frida named pipes
            String[] fridaPipes = {
                "/dev/socket/linjector",
                "/dev/socket/frida-server",
                "/dev/socket/frida-helper-32",
                "/dev/socket/frida-helper-64"
            };
            
            for (String pipe : fridaPipes) {
                File pipeFile = new File(pipe);
                if (pipeFile.exists()) {
                    Log.w(TAG, "Frida pipe detected: " + pipe);
                    return new RootDetectionResult(true, "FRIDA_DETECTION", "Frida pipe found: " + pipe);
                }
            }
            
            // Check 2: Frida processes
            try {
                Process process = Runtime.getRuntime().exec("ps");
                BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.contains("frida-server") || 
                        line.contains("frida-agent") ||
                        line.contains("frida-gadget") ||
                        line.contains("re.frida.server")) {
                        Log.w(TAG, "Frida process detected: " + line);
                        return new RootDetectionResult(true, "FRIDA_DETECTION", "Frida process running");
                    }
                }
            } catch (Exception e) {
                // Continue with other checks
            }
            
            // Check 3: Frida libraries in memory
            try {
                Process process = Runtime.getRuntime().exec("cat /proc/self/maps");
                BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.contains("frida-agent") || 
                        line.contains("frida-gadget") ||
                        line.contains("libfrida")) {
                        Log.w(TAG, "Frida library detected in memory: " + line);
                        return new RootDetectionResult(true, "FRIDA_DETECTION", "Frida library in memory");
                    }
                }
            } catch (Exception e) {
                // Continue with other checks
            }
            
        } catch (Exception e) {
            Log.w(TAG, "Exception in Frida detection: " + e.getMessage());
        }
        return new RootDetectionResult(false, "FRIDA_DETECTION", "No Frida detected");
    }
    
    /**
     * Advanced Magisk detection
     * Based on Indusface recommendations for Magisk detection
     */
    private static RootDetectionResult checkAdvancedMagisk() {
        try {
            // Check 1: Magisk specific files and directories
            String[] magiskPaths = {
                "/sbin/.magisk",
                "/sbin/.core",
                "/cache/.disable_magisk",
                "/dev/.magisk.unblock",
                "/cache/magisk.log",
                "/data/adb/magisk",
                "/data/adb/modules",
                "/data/adb/post-fs-data.d",
                "/data/adb/service.d"
            };
            
            for (String path : magiskPaths) {
                File file = new File(path);
                if (file.exists()) {
                    Log.w(TAG, "Magisk path detected: " + path);
                    return new RootDetectionResult(true, "MAGISK_DETECTION", "Magisk path found: " + path);
                }
            }
            
            // Check 2: Magisk mount points
            try {
                Process process = Runtime.getRuntime().exec("mount");
                BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.contains("magisk") || 
                        line.contains("/sbin/.magisk") ||
                        line.contains("worker") && line.contains("/dev/")) {
                        Log.w(TAG, "Magisk mount detected: " + line);
                        return new RootDetectionResult(true, "MAGISK_DETECTION", "Magisk mount point found");
                    }
                }
            } catch (Exception e) {
                // Continue with other checks
            }
            
            // Check 3: Magisk processes
            try {
                Process process = Runtime.getRuntime().exec("ps -A");
                BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.contains("magisk") || 
                        line.contains("magiskd") ||
                        line.contains("magiskhide")) {
                        Log.w(TAG, "Magisk process detected: " + line);
                        return new RootDetectionResult(true, "MAGISK_DETECTION", "Magisk process running");
                    }
                }
            } catch (Exception e) {
                // Continue with other checks
            }
            
            // Check 4: Magisk environment variables
            try {
                String magiskTmp = System.getenv("MAGISKTMP");
                if (magiskTmp != null && !magiskTmp.isEmpty()) {
                    Log.w(TAG, "Magisk environment variable detected: " + magiskTmp);
                    return new RootDetectionResult(true, "MAGISK_DETECTION", "MAGISKTMP environment variable found");
                }
            } catch (Exception e) {
                // Continue with other checks
            }
            
        } catch (Exception e) {
            Log.w(TAG, "Exception in Magisk detection: " + e.getMessage());
        }
        return new RootDetectionResult(false, "MAGISK_DETECTION", "No Magisk detected");
    }
    
    /**
     * Get device information for logging
     * @return Device info string
     */
    public static String getDeviceInfo() {
        return String.format("Device: %s %s, OS: %s (API %d), Build: %s", 
            Build.MANUFACTURER, Build.MODEL, Build.VERSION.RELEASE, 
            Build.VERSION.SDK_INT, Build.DISPLAY);
    }
}
