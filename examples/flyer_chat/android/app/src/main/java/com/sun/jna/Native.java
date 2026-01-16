package com.sun.jna;

/**
 * Stub class to satisfy runtime class loading of Vosk classes.
 * LibVosk uses Native.register() in static initializer, but this is not needed
 * for Android JNI implementation. This stub provides empty implementations.
 */
public class Native {
    /**
     * Register a native library. Not used in Android JNI implementation.
     */
    public static void register(Class<?> cls) {
        // No-op for Android JNI stub
    }
    
    /**
     * Register a native library with a specific name. Not used in Android JNI implementation.
     */
    public static void register(String name) {
        // No-op for Android JNI stub
    }
    
    /**
     * Register a native library for a class with a specific name.
     * This is the method called by LibVosk.<clinit>
     */
    public static void register(Class<?> cls, String name) {
        // No-op for Android JNI stub
        // In Android, native libraries are loaded via System.loadLibrary() in the AAR
    }
    
    /**
     * Get library instance. Not used in Android JNI implementation.
     */
    public static <T extends Library> T load(String name, Class<T> interfaceClass) {
        return null; // Not used in Android
    }
    
    /**
     * Get library instance with options. Not used in Android JNI implementation.
     */
    public static <T extends Library> T load(String name, Class<T> interfaceClass, java.util.Map<String, ?> options) {
        return null; // Not used in Android
    }
}

