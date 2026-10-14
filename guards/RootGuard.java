package com.protect;

import android.os.Build;
import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;

/** RootGuard — detects a rooted device (common su binaries, test-keys, which su). */
public final class RootGuard {
    private static final String[] PATHS = {
        "/system/app/Superuser.apk", "/sbin/su", "/system/bin/su", "/system/xbin/su",
        "/data/local/xbin/su", "/data/local/bin/su", "/system/sd/xbin/su",
        "/system/bin/failsafe/su", "/data/local/su", "/su/bin/su",
        "/system/xbin/daemonsu", "/system/etc/init.d/99SuperSUDaemon",
        "/system/app/Kinguser.apk", "/data/data/com.noshufou.android.su"
    };
    private RootGuard() {}

    public static boolean isRooted() {
        try {
            if (Build.TAGS != null && Build.TAGS.contains("test-keys")) return true;
            for (String p : PATHS) {
                try { if (new File(p).exists()) return true; } catch (Throwable ignored) {}
            }
            Process pr = Runtime.getRuntime().exec(new String[]{"which", "su"});
            BufferedReader br = new BufferedReader(new InputStreamReader(pr.getInputStream()));
            String line = br.readLine();
            br.close();
            if (line != null && line.length() > 0) return true;
        } catch (Throwable ignored) {}
        return false;
    }
}
