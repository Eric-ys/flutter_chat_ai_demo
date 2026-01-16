package org.vosk;

/**
 * Custom LibVosk wrapper for Android JNI implementation.
 * 
 * This class provides JNI bindings to call vosk C functions.
 * Native methods return long (pointer address) which is converted to Pointer
 * in the custom Model/Recognizer classes.
 */
public class LibVosk {
    
    static {
        try {
            // 先加载 vosk 库（从 AAR）
            System.loadLibrary("vosk");
        } catch (UnsatisfiedLinkError e) {
            // Library may already be loaded
        }
        try {
            // 然后加载 JNI 桥接库
            System.loadLibrary("vosk_jni_bridge");
        } catch (UnsatisfiedLinkError e) {
            throw new RuntimeException("Failed to load vosk_jni_bridge library", e);
        }
    }
    
    // Native methods returning long (matching JNI implementation)
    // Method names match JNI functions: Java_org_vosk_LibVosk_vosk_1model_1new
    static native long vosk_model_new(String path);
    static native void vosk_model_free(long ptr);
    static native long vosk_spk_model_new(String path);
    static native void vosk_spk_model_free(long ptr);
    static native long vosk_recognizer_new(long modelPtr, float sampleRate);
    static native long vosk_recognizer_new_spk(long modelPtr, float sampleRate, long spkPtr);
    static native long vosk_recognizer_new_grm(long modelPtr, float sampleRate, String grammar);
    static native void vosk_recognizer_set_max_alternatives(long ptr, int maxAlternatives);
    static native void vosk_recognizer_set_words(long ptr, boolean words);
    static native void vosk_recognizer_set_partial_words(long ptr, boolean partialWords);
    static native void vosk_recognizer_set_spk_model(long ptr, long spkPtr);
    static native boolean vosk_recognizer_accept_waveform(long ptr, byte[] data, int len);
    static native boolean vosk_recognizer_accept_waveform_s(long ptr, short[] data, int len);
    static native boolean vosk_recognizer_accept_waveform_f(long ptr, float[] data, int len);
    static native String vosk_recognizer_result(long ptr);
    static native String vosk_recognizer_final_result(long ptr);
    static native String vosk_recognizer_partial_result(long ptr);
    static native void vosk_recognizer_set_grm(long ptr, String grammar);
    static native void vosk_recognizer_reset(long ptr);
    static native void vosk_recognizer_free(long ptr);
    public static native void vosk_set_log_level(int level);
    
    public static void setLogLevel(LogLevel level) {
        vosk_set_log_level(level.ordinal());
    }
}
