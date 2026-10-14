package com.protect;

import android.util.Base64;

/**
 * StringGuard — runtime string decryptor.
 * The tool rewrites encoded strings in the dex to call u().
 * Fails safe: returns the input unchanged on any error.
 */
public final class StringGuard {
    private static final byte[] K = { 80, 114, 48, 116, 101, 99, 116, 33, 83, 104, 51, 108, 108, 35, 50, 54 };
    private StringGuard() {}
    public static String u(String s) {
        if (s == null) return null;
        try {
            byte[] b = Base64.decode(s, 0);
            for (int i = 0; i < b.length; i++) b[i] = (byte) (b[i] ^ K[i % K.length]);
            return new String(b, "UTF-8");
        } catch (Throwable t) { return s; }
    }
}
