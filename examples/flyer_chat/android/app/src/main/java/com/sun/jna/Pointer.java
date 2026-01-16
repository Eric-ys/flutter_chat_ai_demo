package com.sun.jna;

/**
 * Stub class for JNA Pointer.
 * Not used in Android JNI implementation, but required for PointerType.
 */
public class Pointer {
    public static final Pointer NULL = new Pointer(0);
    private long peer;
    
    public Pointer(long peer) {
        this.peer = peer;
    }
    
    public long peer() {
        return peer;
    }
}

