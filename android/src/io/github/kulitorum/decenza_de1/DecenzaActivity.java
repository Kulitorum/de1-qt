package io.github.kulitorum.decenza_de1;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import org.qtproject.qt.android.bindings.QtActivity;

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class DecenzaActivity extends QtActivity {

    private static final String TAG = "DecenzaActivity";
    private Thread.UncaughtExceptionHandler defaultHandler;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        // Install Java crash handler FIRST, before any Qt initialization
        installJavaCrashHandler();

        super.onCreate(savedInstanceState);
        StorageHelper.init(this);

        // Start the shutdown service so onTaskRemoved() will be called
        // when the app is swiped away from recent tasks
        try {
            Intent serviceIntent = new Intent(this, DeviceShutdownService.class);
            startService(serviceIntent);
        } catch (IllegalStateException e) {
            // Android may block startService() if app is considered "in background"
            // This can happen during certain wake scenarios - safe to ignore
            android.util.Log.w("DecenzaActivity", "Could not start shutdown service: " + e.getMessage());
        }
    }

    private void installJavaCrashHandler() {
        defaultHandler = Thread.getDefaultUncaughtExceptionHandler();

        Thread.setDefaultUncaughtExceptionHandler((thread, throwable) -> {
            try {
                // Get crash log path (same as C++ crash handler)
                File filesDir = getFilesDir();
                File crashLog = new File(filesDir, "crash.log");

                // Get stack trace as string
                StringWriter sw = new StringWriter();
                PrintWriter pw = new PrintWriter(sw);
                throwable.printStackTrace(pw);
                String stackTrace = sw.toString();

                // Build crash report
                StringBuilder report = new StringBuilder();
                SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US);
                report.append("=== JAVA CRASH REPORT ===\n");
                report.append("Time: ").append(sdf.format(new Date())).append("\n");
                report.append("Thread: ").append(thread.getName()).append("\n");
                report.append("Exception: ").append(throwable.getClass().getName()).append("\n");
                report.append("Message: ").append(throwable.getMessage()).append("\n");
                report.append("\n=== STACK TRACE ===\n");
                report.append(stackTrace);
                report.append("\n=== DEVICE INFO ===\n");
                report.append("Android: ").append(android.os.Build.VERSION.RELEASE)
                      .append(" (API ").append(android.os.Build.VERSION.SDK_INT).append(")\n");
                report.append("Device: ").append(android.os.Build.MANUFACTURER)
                      .append(" ").append(android.os.Build.MODEL).append("\n");

                // Write to file
                FileWriter fw = new FileWriter(crashLog);
                fw.write(report.toString());
                fw.close();

                Log.e(TAG, "Java crash logged to: " + crashLog.getAbsolutePath());
                Log.e(TAG, report.toString());

            } catch (Exception e) {
                Log.e(TAG, "Failed to write crash log: " + e.getMessage());
            }

            // Call default handler to show system crash dialog / terminate
            if (defaultHandler != null) {
                defaultHandler.uncaughtException(thread, throwable);
            }
        });

        Log.d(TAG, "Java crash handler installed");
    }
}
