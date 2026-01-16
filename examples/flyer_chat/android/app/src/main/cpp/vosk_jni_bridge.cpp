#include <jni.h>
#include <dlfcn.h>
#include <android/log.h>

#define LOG_TAG "VoskJniBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Vosk C 函数类型定义
typedef void* (*vosk_model_new_func)(const char*);
typedef void (*vosk_model_free_func)(void*);
typedef void* (*vosk_spk_model_new_func)(const char*);
typedef void (*vosk_spk_model_free_func)(void*);
typedef void* (*vosk_recognizer_new_func)(void*, float);
typedef void* (*vosk_recognizer_new_spk_func)(void*, float, void*);
typedef void* (*vosk_recognizer_new_grm_func)(void*, float, const char*);
typedef void (*vosk_recognizer_set_max_alternatives_func)(void*, int);
typedef void (*vosk_recognizer_set_words_func)(void*, int);
typedef void (*vosk_recognizer_set_partial_words_func)(void*, int);
typedef void (*vosk_recognizer_set_spk_model_func)(void*, void*);
typedef int (*vosk_recognizer_accept_waveform_func)(void*, const char*, int);
typedef int (*vosk_recognizer_accept_waveform_s_func)(void*, const short*, int);
typedef int (*vosk_recognizer_accept_waveform_f_func)(void*, const float*, int);
typedef const char* (*vosk_recognizer_result_func)(void*);
typedef const char* (*vosk_recognizer_final_result_func)(void*);
typedef const char* (*vosk_recognizer_partial_result_func)(void*);
typedef void (*vosk_recognizer_set_grm_func)(void*, const char*);
typedef void (*vosk_recognizer_reset_func)(void*);
typedef void (*vosk_recognizer_free_func)(void*);
typedef void (*vosk_set_log_level_func)(int);

// 全局函数指针
static void* vosk_handle = nullptr;
static vosk_model_new_func vosk_model_new_ptr = nullptr;
static vosk_model_free_func vosk_model_free_ptr = nullptr;
static vosk_spk_model_new_func vosk_spk_model_new_ptr = nullptr;
static vosk_spk_model_free_func vosk_spk_model_free_ptr = nullptr;
static vosk_recognizer_new_func vosk_recognizer_new_ptr = nullptr;
static vosk_recognizer_new_spk_func vosk_recognizer_new_spk_ptr = nullptr;
static vosk_recognizer_new_grm_func vosk_recognizer_new_grm_ptr = nullptr;
static vosk_recognizer_set_max_alternatives_func vosk_recognizer_set_max_alternatives_ptr = nullptr;
static vosk_recognizer_set_words_func vosk_recognizer_set_words_ptr = nullptr;
static vosk_recognizer_set_partial_words_func vosk_recognizer_set_partial_words_ptr = nullptr;
static vosk_recognizer_set_spk_model_func vosk_recognizer_set_spk_model_ptr = nullptr;
static vosk_recognizer_accept_waveform_func vosk_recognizer_accept_waveform_ptr = nullptr;
static vosk_recognizer_accept_waveform_s_func vosk_recognizer_accept_waveform_s_ptr = nullptr;
static vosk_recognizer_accept_waveform_f_func vosk_recognizer_accept_waveform_f_ptr = nullptr;
static vosk_recognizer_result_func vosk_recognizer_result_ptr = nullptr;
static vosk_recognizer_final_result_func vosk_recognizer_final_result_ptr = nullptr;
static vosk_recognizer_partial_result_func vosk_recognizer_partial_result_ptr = nullptr;
static vosk_recognizer_set_grm_func vosk_recognizer_set_grm_ptr = nullptr;
static vosk_recognizer_reset_func vosk_recognizer_reset_ptr = nullptr;
static vosk_recognizer_free_func vosk_recognizer_free_ptr = nullptr;
static vosk_set_log_level_func vosk_set_log_level_ptr = nullptr;

// 初始化函数：加载 vosk 库并获取函数指针
static bool init_vosk_functions() {
    if (vosk_handle != nullptr) {
        return true; // 已经初始化
    }
    
    // 尝试加载 libvosk.so（应该已经被 System.loadLibrary 加载）
    vosk_handle = dlopen("libvosk.so", RTLD_LAZY);
    if (vosk_handle == nullptr) {
        LOGE("Failed to load libvosk.so: %s", dlerror());
        return false;
    }
    
    // 获取函数指针
    vosk_model_new_ptr = (vosk_model_new_func)dlsym(vosk_handle, "vosk_model_new");
    vosk_model_free_ptr = (vosk_model_free_func)dlsym(vosk_handle, "vosk_model_free");
    vosk_spk_model_new_ptr = (vosk_spk_model_new_func)dlsym(vosk_handle, "vosk_spk_model_new");
    vosk_spk_model_free_ptr = (vosk_spk_model_free_func)dlsym(vosk_handle, "vosk_spk_model_free");
    vosk_recognizer_new_ptr = (vosk_recognizer_new_func)dlsym(vosk_handle, "vosk_recognizer_new");
    vosk_recognizer_new_spk_ptr = (vosk_recognizer_new_spk_func)dlsym(vosk_handle, "vosk_recognizer_new_spk");
    vosk_recognizer_new_grm_ptr = (vosk_recognizer_new_grm_func)dlsym(vosk_handle, "vosk_recognizer_new_grm");
    vosk_recognizer_set_max_alternatives_ptr = (vosk_recognizer_set_max_alternatives_func)dlsym(vosk_handle, "vosk_recognizer_set_max_alternatives");
    vosk_recognizer_set_words_ptr = (vosk_recognizer_set_words_func)dlsym(vosk_handle, "vosk_recognizer_set_words");
    vosk_recognizer_set_partial_words_ptr = (vosk_recognizer_set_partial_words_func)dlsym(vosk_handle, "vosk_recognizer_set_partial_words");
    vosk_recognizer_set_spk_model_ptr = (vosk_recognizer_set_spk_model_func)dlsym(vosk_handle, "vosk_recognizer_set_spk_model");
    vosk_recognizer_accept_waveform_ptr = (vosk_recognizer_accept_waveform_func)dlsym(vosk_handle, "vosk_recognizer_accept_waveform");
    vosk_recognizer_accept_waveform_s_ptr = (vosk_recognizer_accept_waveform_s_func)dlsym(vosk_handle, "vosk_recognizer_accept_waveform_s");
    vosk_recognizer_accept_waveform_f_ptr = (vosk_recognizer_accept_waveform_f_func)dlsym(vosk_handle, "vosk_recognizer_accept_waveform_f");
    vosk_recognizer_result_ptr = (vosk_recognizer_result_func)dlsym(vosk_handle, "vosk_recognizer_result");
    vosk_recognizer_final_result_ptr = (vosk_recognizer_final_result_func)dlsym(vosk_handle, "vosk_recognizer_final_result");
    vosk_recognizer_partial_result_ptr = (vosk_recognizer_partial_result_func)dlsym(vosk_handle, "vosk_recognizer_partial_result");
    vosk_recognizer_set_grm_ptr = (vosk_recognizer_set_grm_func)dlsym(vosk_handle, "vosk_recognizer_set_grm");
    vosk_recognizer_reset_ptr = (vosk_recognizer_reset_func)dlsym(vosk_handle, "vosk_recognizer_reset");
    vosk_recognizer_free_ptr = (vosk_recognizer_free_func)dlsym(vosk_handle, "vosk_recognizer_free");
    vosk_set_log_level_ptr = (vosk_set_log_level_func)dlsym(vosk_handle, "vosk_set_log_level");
    
    // 检查关键函数是否加载成功
    if (vosk_model_new_ptr == nullptr || vosk_recognizer_new_ptr == nullptr) {
        LOGE("Failed to load critical vosk functions");
        return false;
    }
    
    LOGI("Vosk functions loaded successfully");
    return true;
}

// JNI function: Java_org_vosk_LibVosk_vosk_1model_1new
extern "C" JNIEXPORT jlong JNICALL
Java_org_vosk_LibVosk_vosk_1model_1new(JNIEnv *env, jclass clazz, jstring path) {
    if (!init_vosk_functions()) {
        LOGE("Failed to initialize vosk functions");
        return 0;
    }
    
    const char* model_path = env->GetStringUTFChars(path, nullptr);
    if (model_path == nullptr) {
        return 0;
    }
    
    void* model = vosk_model_new_ptr(model_path);
    env->ReleaseStringUTFChars(path, model_path);
    
    return reinterpret_cast<jlong>(model);
}

// JNI function: Java_org_vosk_LibVosk_vosk_1model_1free
extern "C" JNIEXPORT void JNICALL
Java_org_vosk_LibVosk_vosk_1model_1free(JNIEnv *env, jclass clazz, jlong ptr) {
    if (vosk_model_free_ptr == nullptr) return;
    void* model = reinterpret_cast<void*>(ptr);
    if (model != nullptr) {
        vosk_model_free_ptr(model);
    }
}

// JNI function: Java_org_vosk_LibVosk_vosk_1spk_1model_1new
extern "C" JNIEXPORT jlong JNICALL
Java_org_vosk_LibVosk_vosk_1spk_1model_1new(JNIEnv *env, jclass clazz, jstring path) {
    const char* model_path = env->GetStringUTFChars(path, nullptr);
    if (model_path == nullptr) {
        return 0;
    }
    
    if (!init_vosk_functions()) return 0;
    void* spk_model = vosk_spk_model_new_ptr(model_path);
    env->ReleaseStringUTFChars(path, model_path);
    
    return reinterpret_cast<jlong>(spk_model);
}

// JNI function: Java_org_vosk_LibVosk_vosk_1spk_1model_1free
extern "C" JNIEXPORT void JNICALL
Java_org_vosk_LibVosk_vosk_1spk_1model_1free(JNIEnv *env, jclass clazz, jlong ptr) {
    void* spk_model = reinterpret_cast<void*>(ptr);
    if (spk_model != nullptr) {
        if (vosk_spk_model_free_ptr != nullptr) {
            vosk_spk_model_free_ptr(spk_model);
        }
    }
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1new
extern "C" JNIEXPORT jlong JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1new(JNIEnv *env, jclass clazz, jlong model_ptr, jfloat sample_rate) {
    void* model = reinterpret_cast<void*>(model_ptr);
    if (!init_vosk_functions()) return 0;
    void* recognizer = vosk_recognizer_new_ptr(model, sample_rate);
    return reinterpret_cast<jlong>(recognizer);
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1new_1spk
extern "C" JNIEXPORT jlong JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1new_1spk(JNIEnv *env, jclass clazz, jlong model_ptr, jfloat sample_rate, jlong spk_ptr) {
    void* model = reinterpret_cast<void*>(model_ptr);
    void* spk_model = reinterpret_cast<void*>(spk_ptr);
    if (!init_vosk_functions()) return 0;
    void* recognizer = vosk_recognizer_new_spk_ptr(model, sample_rate, spk_model);
    return reinterpret_cast<jlong>(recognizer);
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1new_1grm
extern "C" JNIEXPORT jlong JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1new_1grm(JNIEnv *env, jclass clazz, jlong model_ptr, jfloat sample_rate, jstring grammar) {
    void* model = reinterpret_cast<void*>(model_ptr);
    const char* grammar_str = env->GetStringUTFChars(grammar, nullptr);
    if (grammar_str == nullptr) {
        return 0;
    }
    
    if (!init_vosk_functions()) return 0;
    void* recognizer = vosk_recognizer_new_grm_ptr(model, sample_rate, grammar_str);
    env->ReleaseStringUTFChars(grammar, grammar_str);
    
    return reinterpret_cast<jlong>(recognizer);
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1set_1max_1alternatives
extern "C" JNIEXPORT void JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1set_1max_1alternatives(JNIEnv *env, jclass clazz, jlong ptr, jint max_alternatives) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer != nullptr) {
        if (vosk_recognizer_set_max_alternatives_ptr != nullptr) {
            vosk_recognizer_set_max_alternatives_ptr(recognizer, max_alternatives);
        }
    }
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1set_1words
extern "C" JNIEXPORT void JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1set_1words(JNIEnv *env, jclass clazz, jlong ptr, jboolean words) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer != nullptr) {
        if (vosk_recognizer_set_words_ptr != nullptr) {
            vosk_recognizer_set_words_ptr(recognizer, words ? 1 : 0);
        }
    }
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1set_1partial_1words
extern "C" JNIEXPORT void JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1set_1partial_1words(JNIEnv *env, jclass clazz, jlong ptr, jboolean partial_words) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer != nullptr) {
        if (vosk_recognizer_set_partial_words_ptr != nullptr) {
            vosk_recognizer_set_partial_words_ptr(recognizer, partial_words ? 1 : 0);
        }
    }
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1set_1spk_1model
extern "C" JNIEXPORT void JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1set_1spk_1model(JNIEnv *env, jclass clazz, jlong ptr, jlong spk_ptr) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    void* spk_model = reinterpret_cast<void*>(spk_ptr);
    if (recognizer != nullptr) {
        if (vosk_recognizer_set_spk_model_ptr != nullptr) {
            vosk_recognizer_set_spk_model_ptr(recognizer, spk_model);
        }
    }
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1accept_1waveform
extern "C" JNIEXPORT jboolean JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1accept_1waveform(JNIEnv *env, jclass clazz, jlong ptr, jbyteArray data, jint len) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer == nullptr) {
        return JNI_FALSE;
    }
    
    jbyte* data_ptr = env->GetByteArrayElements(data, nullptr);
    if (data_ptr == nullptr) {
        return JNI_FALSE;
    }
    
    if (vosk_recognizer_accept_waveform_ptr == nullptr) return JNI_FALSE;
    int result = vosk_recognizer_accept_waveform_ptr(recognizer, reinterpret_cast<const char*>(data_ptr), len);
    env->ReleaseByteArrayElements(data, data_ptr, JNI_ABORT);
    
    return result ? JNI_TRUE : JNI_FALSE;
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1accept_1waveform_1s
extern "C" JNIEXPORT jboolean JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1accept_1waveform_1s(JNIEnv *env, jclass clazz, jlong ptr, jshortArray data, jint len) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer == nullptr) {
        return JNI_FALSE;
    }
    
    jshort* data_ptr = env->GetShortArrayElements(data, nullptr);
    if (data_ptr == nullptr) {
        return JNI_FALSE;
    }
    
    if (vosk_recognizer_accept_waveform_s_ptr == nullptr) return JNI_FALSE;
    int result = vosk_recognizer_accept_waveform_s_ptr(recognizer, data_ptr, len);
    env->ReleaseShortArrayElements(data, data_ptr, JNI_ABORT);
    
    return result ? JNI_TRUE : JNI_FALSE;
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1accept_1waveform_1f
extern "C" JNIEXPORT jboolean JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1accept_1waveform_1f(JNIEnv *env, jclass clazz, jlong ptr, jfloatArray data, jint len) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer == nullptr) {
        return JNI_FALSE;
    }
    
    jfloat* data_ptr = env->GetFloatArrayElements(data, nullptr);
    if (data_ptr == nullptr) {
        return JNI_FALSE;
    }
    
    if (vosk_recognizer_accept_waveform_f_ptr == nullptr) return JNI_FALSE;
    int result = vosk_recognizer_accept_waveform_f_ptr(recognizer, data_ptr, len);
    env->ReleaseFloatArrayElements(data, data_ptr, JNI_ABORT);
    
    return result ? JNI_TRUE : JNI_FALSE;
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1result
extern "C" JNIEXPORT jstring JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1result(JNIEnv *env, jclass clazz, jlong ptr) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer == nullptr) {
        return nullptr;
    }
    
    if (vosk_recognizer_result_ptr == nullptr) return nullptr;
    const char* result = vosk_recognizer_result_ptr(recognizer);
    if (result == nullptr) {
        return nullptr;
    }
    
    return env->NewStringUTF(result);
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1final_1result
extern "C" JNIEXPORT jstring JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1final_1result(JNIEnv *env, jclass clazz, jlong ptr) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer == nullptr) {
        return nullptr;
    }
    
    if (vosk_recognizer_final_result_ptr == nullptr) return nullptr;
    const char* result = vosk_recognizer_final_result_ptr(recognizer);
    if (result == nullptr) {
        return nullptr;
    }
    
    return env->NewStringUTF(result);
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1partial_1result
extern "C" JNIEXPORT jstring JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1partial_1result(JNIEnv *env, jclass clazz, jlong ptr) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer == nullptr) {
        return nullptr;
    }
    
    if (vosk_recognizer_partial_result_ptr == nullptr) return nullptr;
    const char* result = vosk_recognizer_partial_result_ptr(recognizer);
    if (result == nullptr) {
        return nullptr;
    }
    
    return env->NewStringUTF(result);
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1set_1grm
extern "C" JNIEXPORT void JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1set_1grm(JNIEnv *env, jclass clazz, jlong ptr, jstring grammar) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer == nullptr) {
        return;
    }
    
    const char* grammar_str = env->GetStringUTFChars(grammar, nullptr);
    if (grammar_str == nullptr) {
        return;
    }
    
    if (vosk_recognizer_set_grm_ptr != nullptr) {
        vosk_recognizer_set_grm_ptr(recognizer, grammar_str);
    }
    env->ReleaseStringUTFChars(grammar, grammar_str);
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1reset
extern "C" JNIEXPORT void JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1reset(JNIEnv *env, jclass clazz, jlong ptr) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer != nullptr) {
        if (vosk_recognizer_reset_ptr != nullptr) {
            vosk_recognizer_reset_ptr(recognizer);
        }
    }
}

// JNI function: Java_org_vosk_LibVosk_vosk_1recognizer_1free
extern "C" JNIEXPORT void JNICALL
Java_org_vosk_LibVosk_vosk_1recognizer_1free(JNIEnv *env, jclass clazz, jlong ptr) {
    void* recognizer = reinterpret_cast<void*>(ptr);
    if (recognizer != nullptr) {
        if (vosk_recognizer_free_ptr != nullptr) {
            vosk_recognizer_free_ptr(recognizer);
        }
    }
}

// JNI function: Java_org_vosk_LibVosk_vosk_1set_1log_1level
extern "C" JNIEXPORT void JNICALL
Java_org_vosk_LibVosk_vosk_1set_1log_1level(JNIEnv *env, jclass clazz, jint level) {
    if (!init_vosk_functions()) return;
    if (vosk_set_log_level_ptr != nullptr) {
        vosk_set_log_level_ptr(level);
    }
}

