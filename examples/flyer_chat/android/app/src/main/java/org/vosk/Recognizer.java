package org.vosk;

import com.sun.jna.Pointer;
import com.sun.jna.PointerType;
import java.io.IOException;

/**
 * Custom Recognizer class for Android JNI implementation.
 * This overrides the AAR's Recognizer class to work with JNI (long) instead of JNA (Pointer).
 */
public class Recognizer extends PointerType implements AutoCloseable {
    private long handle;
    
    public Recognizer(Model model, float sampleRate) throws IOException {
        this.handle = LibVosk.vosk_recognizer_new(model.getHandle(), sampleRate);
        if (this.handle == 0) {
            throw new IOException("Failed to create recognizer");
        }
        // Set the peer for PointerType compatibility
        setPointer(new Pointer(this.handle));
    }
    
    public Recognizer(Model model, float sampleRate, SpeakerModel speakerModel) throws IOException {
        this.handle = LibVosk.vosk_recognizer_new_spk(model.getHandle(), sampleRate, speakerModel.getHandle());
        if (this.handle == 0) {
            throw new IOException("Failed to create recognizer with speaker model");
        }
        setPointer(new Pointer(this.handle));
    }
    
    public Recognizer(Model model, float sampleRate, String grammar) throws IOException {
        this.handle = LibVosk.vosk_recognizer_new_grm(model.getHandle(), sampleRate, grammar);
        if (this.handle == 0) {
            throw new IOException("Failed to create recognizer with grammar");
        }
        setPointer(new Pointer(this.handle));
    }
    
    public long getHandle() {
        return handle;
    }
    
    public void setMaxAlternatives(int maxAlternatives) {
        LibVosk.vosk_recognizer_set_max_alternatives(handle, maxAlternatives);
    }
    
    public void setWords(boolean words) {
        LibVosk.vosk_recognizer_set_words(handle, words);
    }
    
    public void setPartialWords(boolean partialWords) {
        LibVosk.vosk_recognizer_set_partial_words(handle, partialWords);
    }
    
    public void setSpeakerModel(SpeakerModel speakerModel) {
        LibVosk.vosk_recognizer_set_spk_model(handle, speakerModel.getHandle());
    }
    
    public boolean acceptWaveForm(byte[] data, int len) {
        return LibVosk.vosk_recognizer_accept_waveform(handle, data, len);
    }
    
    public boolean acceptWaveForm(short[] data, int len) {
        return LibVosk.vosk_recognizer_accept_waveform_s(handle, data, len);
    }
    
    public boolean acceptWaveForm(float[] data, int len) {
        return LibVosk.vosk_recognizer_accept_waveform_f(handle, data, len);
    }
    
    public String getResult() {
        return LibVosk.vosk_recognizer_result(handle);
    }
    
    public String getFinalResult() {
        return LibVosk.vosk_recognizer_final_result(handle);
    }
    
    public String getPartialResult() {
        return LibVosk.vosk_recognizer_partial_result(handle);
    }
    
    public void reset() {
        LibVosk.vosk_recognizer_reset(handle);
    }
    
    @Override
    public void close() {
        if (handle != 0) {
            LibVosk.vosk_recognizer_free(handle);
            handle = 0;
        }
    }
}

