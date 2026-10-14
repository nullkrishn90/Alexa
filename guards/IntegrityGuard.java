package com.protect;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import java.security.MessageDigest;

/**
 * IntegrityGuard — verifies the app's signing certificate.
 * Detects repackaged / resigned APKs (someone re-signed your app).
 *
 * HOW TO USE:
 *  1. Build & sign your app once.
 *  2. Run this to get your certificate SHA-256, or read it from apksigner output.
 *  3. Paste it into EXPECTED_SHA256 below (lowercase, no colons) and rebuild.
 *  Leave it empty ("") to disable the check.
 */
public final class IntegrityGuard {
    public static final String EXPECTED_SHA256 = ""; // <-- paste your cert SHA-256 here
    private IntegrityGuard() {}

    public static String signatureSha256(Context c) {
        try {
            PackageInfo pi = c.getPackageManager()
                    .getPackageInfo(c.getPackageName(), PackageManager.GET_SIGNATURES);
            if (pi.signatures == null || pi.signatures.length == 0) return null;
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] d = md.digest(pi.signatures[0].toByteArray());
            StringBuilder sb = new StringBuilder();
            for (byte b : d) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Throwable t) { return null; }
    }

    public static boolean isGenuine(Context c) {
        if (EXPECTED_SHA256 == null || EXPECTED_SHA256.length() == 0) return true; // not configured
        String got = signatureSha256(c);
        return got != null && got.equalsIgnoreCase(EXPECTED_SHA256);
    }
}
