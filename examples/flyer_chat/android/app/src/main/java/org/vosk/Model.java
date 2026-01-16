package org.vosk;

import com.sun.jna.Pointer;
import com.sun.jna.PointerType;
import java.io.IOException;

/**
 * Custom Model class for Android JNI implementation.
 * This overrides the AAR's Model class to work with JNI (long) instead of JNA (Pointer).
 */
public class Model extends PointerType implements AutoCloseable {
    private long handle;
    
    public Model(String path) throws IOException {
        this.handle = LibVosk.vosk_model_new(path);
        if (this.handle == 0) {
            throw new IOException("Failed to create model from: " + path);
        }
        // Set the peer for PointerType compatibility
        setPointer(new Pointer(this.handle));
    }
    
    public long getHandle() {
        return handle;
    }
    
    @Override
    public void close() {
        if (handle != 0) {
            LibVosk.vosk_model_free(handle);
            handle = 0;
        }
    }
}

