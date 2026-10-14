package com.protect;

import android.content.Context;
import android.util.Log;

/**
 * Guard — orchestrator. Call ONCE from your Application or main Activity:
 *
 *     public void onCreate(Bundle b) {
 *         super.onCreate(b);
 *         Guard.init(this);      // <-- add this line
 *         ...
 *     }
 *
 * All checks are wrapped in try/catch, so Guard can never crash your app.
 * Set ENFORCE = true to make the app exit when tampering is detected.
 */
public final class Guard {
    public static boolean ENFORCE = false;
    private static final String TAG = "Guard";
    private Guard() {}

    public static void init(Context ctx) {
        boolean hooked = false, genuine = true, dbg = false, rooted = false, emu = false;
        try {
            rooted = RootGuard.isRooted();
            emu = EmuGuard.isEmulator();
            hooked = HookGuard.isHooked();
            dbg = DebugGuard.isDebuggerConnected() || DebugGuard.isDebuggable(ctx);
            genuine = IntegrityGuard.isGenuine(ctx);

            if (rooted) Log.w(TAG, "root detected");
            if (emu) Log.w(TAG, "emulator detected");
            if (hooked) Log.w(TAG, "hooking framework detected");
            if (dbg) Log.w(TAG, "debugger detected");
            if (!genuine) Log.w(TAG, "signature mismatch (repackaged?)");

            if (ENFORCE && (hooked || !genuine || dbg)) {
                System.exit(0);
            }
        } catch (Throwable t) {
            // never crash the host app
        }
    }
}
