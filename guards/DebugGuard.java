package com.protect;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Debug;

/** DebugGuard — detects attached debugger / debuggable build. */
public final class DebugGuard {
    private DebugGuard() {}

    public static boolean isDebuggerConnected() {
        try { return Debug.isDebuggerConnected() || Debug.waitingForDebugger(); }
        catch (Throwable t) { return false; }
    }

    public static boolean isDebuggable(Context c) {
        try {
            ApplicationInfo ai = c.getApplicationInfo();
            return (ai.flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        } catch (Throwable t) { return false; }
    }
}
