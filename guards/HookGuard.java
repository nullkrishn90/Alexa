package com.protect;

import java.io.File;
import java.net.InetSocketAddress;
import java.net.Socket;

/** HookGuard — basic detection of Frida (ports) and Xposed/Substrate (classes + files). */
public final class HookGuard {
    private static final String[][] CLASS_SIGS = {
        {"de.robv.android.xposed.XposedBridge", "Xposed"},
        {"de.robv.android.xposed.XC_MethodHook", "Xposed"},
        {"com.saurik.substrate.MS", "Substrate"}
    };
    private static final String[] FILES = {
        "/system/lib/libxposed_art.so", "/system/lib64/libxposed_art.so",
        "/system/framework/XposedBridge.jar", "/data/local/tmp/frida-server",
        "/data/local/tmp/re.frida.server"
    };
    private HookGuard() {}

    public static boolean isHooked() {
        try {
            for (String[] s : CLASS_SIGS) {
                try { Class.forName(s[0]); return true; } catch (Throwable ignored) {}
            }
            for (String f : FILES) {
                try { if (new File(f).exists()) return true; } catch (Throwable ignored) {}
            }
            if (portOpen(27042) || portOpen(27043)) return true;
        } catch (Throwable ignored) {}
        return false;
    }

    private static boolean portOpen(int port) {
        Socket s = null;
        try {
            s = new Socket();
            s.connect(new InetSocketAddress("127.0.0.1", port), 150);
            return true;
        } catch (Throwable t) { return false; }
        finally { try { if (s != null) s.close(); } catch (Throwable ignored) {} }
    }
}
