package com.protect;

import android.os.Build;
import java.io.File;

/** EmuGuard — detects emulators (fingerprint/model/manufacturer/product + known files). */
public final class EmuGuard {
    private EmuGuard() {}

    public static boolean isEmulator() {
        try {
            String fp = low(Build.FINGERPRINT);
            String model = low(Build.MODEL);
            String manu = low(Build.MANUFACTURER);
            String prod = low(Build.PRODUCT);
            String hw = low(Build.HARDWARE);

            if (fp.contains("generic") || fp.contains("unknown") || fp.contains("emulator")
                || fp.contains("sdk") || fp.startsWith("vbox") || fp.contains("test-keys")) return true;
            if (model.contains("google_sdk") || model.contains("emulator") || model.contains("droid4x")
                || model.contains("vbox86") || model.contains("nox") || model.contains("x86")) return true;
            if (manu.contains("genymotion") || manu.contains("unknown")) return true;
            if (prod.contains("sdk") || prod.contains("google_sdk") || prod.contains("vbox86p")
                || prod.contains("nox")) return true;
            if (hw.contains("goldfish") || hw.contains("ranchu") || hw.contains("vbox")) return true;
            if (new File("/dev/socket/genyd").exists()) return true;
            if (new File("/dev/socket/qemud").exists()) return true;
        } catch (Throwable ignored) {}
        return false;
    }

    private static String low(String s) { return s == null ? "" : s.toLowerCase(); }
}
