package org.vosk;

import com.sun.jna.Pointer;
import com.sun.jna.PointerType;
import java.io.IOException;

/**
 * Custom SpeakerModel class for Android JNI implementation.
 */
public class SpeakerModel extends PointerType implements AutoCloseable {
    private long handle;
    
    public SpeakerModel(String path) throws IOException {
        this.handle = LibVosk.vosk_spk_model_new(path);
        if (this.handle == 0) {
            throw new IOException("Failed to create speaker model from: " + path);
        }
        setPointer(new Pointer(this.handle));
    }
    
    public long getHandle() {
        return handle;
    }
    
    @Override
    public void close() {
        if (handle != 0) {
            LibVosk.vosk_spk_model_free(handle);
            handle = 0;
        }
    }
}

