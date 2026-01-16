package com.sun.jna;

/**
 * Stub class to satisfy compilation and runtime of Vosk classes that extend PointerType.
 * Model and Recognizer extend this class, but in Android JNI implementation,
 * the actual native pointer handling is done through JNI, not JNA.
 */
public class PointerType {
    protected Pointer peer;
    
    public PointerType() {
        this(null);
    }
    
    public PointerType(Pointer peer) {
        this.peer = peer;
    }
    
    public Pointer getPointer() {
        return peer;
    }
    
    public void setPointer(Pointer peer) {
        this.peer = peer;
    }
}

