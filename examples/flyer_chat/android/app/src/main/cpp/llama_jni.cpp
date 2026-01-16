#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <cstring>
#include <cstdio>
#include <cerrno>

extern "C" {
#include "llama.h"
}

#define LOG_TAG "LlamaJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static struct llama_model* g_model = nullptr;
static struct llama_context* g_ctx = nullptr;
static volatile bool g_should_stop = false; // 停止标志

static void llama_log_callback(ggml_log_level level, const char * text, void * user_data) {
    switch (level) {
        case GGML_LOG_LEVEL_ERROR:
        case GGML_LOG_LEVEL_WARN:
            LOGE("%s", text);
            break;
        case GGML_LOG_LEVEL_INFO:
        case GGML_LOG_LEVEL_DEBUG:
        default:
            LOGI("%s", text);
            break;
    }
}

void ensure_llama_initialized() {
    static bool initialized = false;
    if (!initialized) {
        llama_log_set(llama_log_callback, nullptr); // 👈 关键！
        llama_backend_init();
        initialized = true;
    }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_flyer_chat_flyer_1chat_LlamaInference_loadModel(JNIEnv *env, jclass clazz, jstring modelPath) {
    if (g_model && g_ctx) {
        LOGI("Model already loaded!");
        return JNI_TRUE;
    }
    ensure_llama_initialized();
    const char* path = env->GetStringUTFChars(modelPath, nullptr);
    LOGI("Loading model: %s", path);

    // 验证文件是否存在且可读
    FILE* test_file = fopen(path, "rb");
    if (!test_file) {
        LOGE("Cannot open model file: %s (errno: %d)", path, errno);
        env->ReleaseStringUTFChars(modelPath, path);
        return JNI_FALSE;
    }
    fclose(test_file);
    LOGI("Model file is accessible");

    struct llama_model_params model_params = llama_model_default_params();
    // 对于 Android 内部目录，使用 mmap 通常更可靠
    // Direct I/O 在某些 Android 版本/设备上可能不稳定
    model_params.use_mmap = true;           // 启用内存映射（Android 内部目录支持）
    model_params.use_mlock = false;         // 禁用内存锁定（Android 上通常不需要）
    model_params.use_direct_io = false;     // 禁用 Direct I/O（避免在某些设备上失败）
    model_params.no_alloc = false;

    LOGI("Model params: use_mmap=%d, use_direct_io=%d", model_params.use_mmap, model_params.use_direct_io);
    g_model = llama_model_load_from_file(path, model_params);
    env->ReleaseStringUTFChars(modelPath, path);

    if (!g_model) {
        LOGE("Failed to load model");
        return JNI_FALSE;
    }

    struct llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048;
    ctx_params.n_threads = 4;
//    ctx_params.n_threads = 1;          // 推理线程
//    ctx_params.n_threads_batch = 1;    // 批处理线程

    g_ctx = llama_new_context_with_model(g_model, ctx_params);
    if (!g_ctx) {
        LOGE("Failed to create context");
        llama_free_model(g_model);
        g_model = nullptr;
        return JNI_FALSE;
    }

    LOGI("Model loaded successfully");
    return JNI_TRUE;
}

// 流式回调函数指针和 JNI 环境
static JavaVM* g_jvm = nullptr;
static jobject g_callback_obj = nullptr;
static jmethodID g_callback_method = nullptr;
static jclass g_callback_class = nullptr;

// 初始化 JNI 回调
extern "C" JNIEXPORT void JNICALL
Java_flyer_chat_flyer_1chat_LlamaInference_initStreamCallback(JNIEnv *env, jclass clazz, jobject callback) {
    if (g_callback_obj) {
        env->DeleteGlobalRef(g_callback_obj);
    }
    if (g_callback_class) {
        env->DeleteGlobalRef(g_callback_class);
    }
    g_callback_obj = env->NewGlobalRef(callback);
    jclass callback_class = env->GetObjectClass(callback);
    g_callback_class = (jclass)env->NewGlobalRef(callback_class);
    g_callback_method = env->GetMethodID(callback_class, "onToken", "(Ljava/lang/String;)V");
    env->GetJavaVM(&g_jvm);
    LOGI("Stream callback initialized");
}

// 清理回调
extern "C" JNIEXPORT void JNICALL
Java_flyer_chat_flyer_1chat_LlamaInference_cleanupStreamCallback(JNIEnv *env, jclass clazz) {
    if (g_callback_obj) {
        env->DeleteGlobalRef(g_callback_obj);
        g_callback_obj = nullptr;
    }
    if (g_callback_class) {
        env->DeleteGlobalRef(g_callback_class);
        g_callback_class = nullptr;
    }
    g_callback_method = nullptr;
    LOGI("Stream callback cleaned up");
}

// 发送 token 到 Java 层
static void send_token_to_java(const char* piece, int piece_len) {
    if (!g_callback_obj || !g_callback_method || !g_jvm || piece_len <= 0) {
        return;
    }
    
    JNIEnv* env = nullptr;
    int get_env_result = g_jvm->GetEnv((void**)&env, JNI_VERSION_1_6);
    bool attached = false;
    
    if (get_env_result == JNI_EDETACHED) {
        // 如果当前线程未附加到 JVM，需要附加
        if (g_jvm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
            LOGE("Failed to attach thread for callback");
            return;
        }
        attached = true;
    } else if (get_env_result != JNI_OK) {
        LOGE("Failed to get JNI environment for callback");
        return;
    }
    
    if (env) {
        std::string piece_str(piece, piece_len);
        jstring j_piece = env->NewStringUTF(piece_str.c_str());
        env->CallVoidMethod(g_callback_obj, g_callback_method, j_piece);
        env->DeleteLocalRef(j_piece);
    }
    
    // 如果之前附加了线程，现在需要分离
    if (attached && env) {
        g_jvm->DetachCurrentThread();
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_flyer_chat_flyer_1chat_LlamaInference_generate(JNIEnv *env, jclass clazz, jstring prompt) {
    if (!g_model || !g_ctx) {
        LOGE("Model not loaded!");
        return env->NewStringUTF("");
    }

    // 清除之前的 KV cache，确保每次生成都从干净的状态开始
    llama_memory_t mem = llama_get_memory(g_ctx);
    llama_memory_seq_rm(mem, 0, -1, -1);  // 清除序列 0 的所有 KV cache
    LOGI("Cleared KV cache for sequence 0");

    const char* prompt_str = env->GetStringUTFChars(prompt, nullptr);
    std::string prompt_cpp(prompt_str);
    env->ReleaseStringUTFChars(prompt, prompt_str);

    // Get vocab from model
    const struct llama_vocab* vocab = llama_model_get_vocab(g_model);
    if (!vocab) {
        LOGE("Failed to get vocab from model");
        return env->NewStringUTF("");
    }

    // Use vocab for tokenize
    std::vector<llama_token> tokens(prompt_cpp.length() + 256);
    int n_tokens = llama_tokenize(vocab, prompt_cpp.c_str(), prompt_cpp.length(), tokens.data(), tokens.size(), true, false);

    if (n_tokens < 0) {
        tokens.resize(-n_tokens);
        n_tokens = llama_tokenize(vocab, prompt_cpp.c_str(), prompt_cpp.length(), tokens.data(), tokens.size(), true, false);
    }

    if (n_tokens <= 0) {
        LOGE("Tokenization failed with error code: %d", n_tokens);
        return env->NewStringUTF("");
    }

    tokens.resize(n_tokens);

    // Prepare batch for processing prompt
    // 注意：由于我们已清空 KV cache，位置从 0 开始
    llama_batch batch = llama_batch_init(tokens.size(), 0, 1);
    batch.n_tokens = static_cast<int32_t>(tokens.size());
    for (int i = 0; i < batch.n_tokens; i++) {
        batch.token[i] = tokens[i];
        batch.pos[i] = i;  // 从位置 0 开始
        batch.n_seq_id[i] = 1;
        batch.seq_id[i][0] = 0;
        batch.logits[i] = (i == batch.n_tokens - 1) ? 1 : 0;  // 最后一个 token 需要 logits
    }

    // Process prompt using llama_decode
    int decode_result = llama_decode(g_ctx, batch);
    if (decode_result != 0) {
        LOGE("llama_decode failed on prompt with code: %d", decode_result);
        llama_batch_free(batch);
        return env->NewStringUTF("");
    }
    llama_batch_free(batch);

    // 记录当前已处理的 token 数量（用于后续生成的位置）
    int n_past = n_tokens;

    // Get vocab properties using new functions (non-deprecated)
    int n_vocab = llama_vocab_n_tokens(vocab);

    // Use new function for EOS token (non-deprecated)
    llama_token eos_token = llama_vocab_eos(vocab);

    // Generate tokens
    std::string result;
    const int max_tokens = 256;

    for (int i = 0; i < max_tokens; ++i) {
        // Get logits of the last processed token
        float* logits = llama_get_logits(g_ctx);
        if (!logits) {
            LOGE("Failed to get logits");
            break;
        }

        // Greedy sampling
        llama_token next_token = 0;
        float max_logit = logits[0];
        for (int j = 1; j < n_vocab; ++j) {
            if (logits[j] > max_logit) {
                max_logit = logits[j];
                next_token = j;
            }
        }

        if (next_token == eos_token) {
            break;
        }

        // Convert token to piece using vocab
        char piece[128];
        int n_piece = llama_token_to_piece(vocab, next_token, piece, sizeof(piece), 0, false);

        if (n_piece > 0) {
            // 立即发送到 Java 层（流式输出）
            send_token_to_java(piece, n_piece);
            result.append(piece, n_piece);
        } else if (n_piece < 0) {
            // Need larger buffer
            std::vector<char> large_piece(-n_piece + 1);
            n_piece = llama_token_to_piece(vocab, next_token, large_piece.data(), large_piece.size(), 0, false);
            if (n_piece > 0) {
                // 立即发送到 Java 层（流式输出）
                send_token_to_java(large_piece.data(), n_piece);
                result.append(large_piece.data(), n_piece);
            }
        } else {
            LOGE("llama_token_to_piece returned %d", n_piece);
        }

        // Create batch for the new token
        llama_batch single_batch = llama_batch_init(1, 0, 1);
        single_batch.n_tokens = 1;
        single_batch.token[0] = next_token;
        single_batch.pos[0] = n_past + i;  // 连续的位置：prompt tokens + 已生成的 tokens
        single_batch.n_seq_id[0] = 1;
        single_batch.seq_id[0][0] = 0;
        single_batch.logits[0] = 1; // Need logits for next iteration

        // Decode the new token
        decode_result = llama_decode(g_ctx, single_batch);
        if (decode_result != 0) {
            LOGE("llama_decode failed on generated token with code: %d", decode_result);
            llama_batch_free(single_batch);
            break;
        }
        llama_batch_free(single_batch);

        // Add token to history for potential future use
        tokens.push_back(next_token);
    }

    return env->NewStringUTF(result.c_str());
}

// 停止流式生成
extern "C" JNIEXPORT void JNICALL
Java_flyer_chat_flyer_1chat_LlamaInference_stopGeneration(JNIEnv *env, jclass clazz) {
    g_should_stop = true;
    LOGI("Stop generation requested");
}

// 流式生成函数（异步，通过回调返回）
extern "C" JNIEXPORT void JNICALL
Java_flyer_chat_flyer_1chat_LlamaInference_generateStream(JNIEnv *env, jclass clazz, jstring prompt) {
    if (!g_model || !g_ctx) {
        LOGE("Model not loaded!");
        return;
    }

    // 重置停止标志
    g_should_stop = false;

    // 清除之前的 KV cache，确保每次生成都从干净的状态开始
    llama_memory_t mem = llama_get_memory(g_ctx);
    llama_memory_seq_rm(mem, 0, -1, -1);  // 清除序列 0 的所有 KV cache
    LOGI("Cleared KV cache for sequence 0 (stream)");

    const char* prompt_str = env->GetStringUTFChars(prompt, nullptr);
    std::string prompt_cpp(prompt_str);
    env->ReleaseStringUTFChars(prompt, prompt_str);

    // Get vocab from model
    const struct llama_vocab* vocab = llama_model_get_vocab(g_model);
    if (!vocab) {
        LOGE("Failed to get vocab from model");
        return;
    }

    // Use vocab for tokenize
    std::vector<llama_token> tokens(prompt_cpp.length() + 256);
    int n_tokens = llama_tokenize(vocab, prompt_cpp.c_str(), prompt_cpp.length(), tokens.data(), tokens.size(), true, false);

    if (n_tokens < 0) {
        tokens.resize(-n_tokens);
        n_tokens = llama_tokenize(vocab, prompt_cpp.c_str(), prompt_cpp.length(), tokens.data(), tokens.size(), true, false);
    }

    if (n_tokens <= 0) {
        LOGE("Tokenization failed with error code: %d", n_tokens);
        return;
    }

    tokens.resize(n_tokens);

    // Prepare batch for processing prompt
    llama_batch batch = llama_batch_init(tokens.size(), 0, 1);
    batch.n_tokens = static_cast<int32_t>(tokens.size());
    for (int i = 0; i < batch.n_tokens; i++) {
        batch.token[i] = tokens[i];
        batch.pos[i] = i;
        batch.n_seq_id[i] = 1;
        batch.seq_id[i][0] = 0;
        batch.logits[i] = (i == batch.n_tokens - 1) ? 1 : 0;
    }

    // Process prompt using llama_decode
    int decode_result = llama_decode(g_ctx, batch);
    if (decode_result != 0) {
        LOGE("llama_decode failed on prompt with code: %d", decode_result);
        llama_batch_free(batch);
        return;
    }
    llama_batch_free(batch);

    int n_past = n_tokens;
    int n_vocab = llama_vocab_n_tokens(vocab);
    llama_token eos_token = llama_vocab_eos(vocab);
    const int max_tokens = 256;

    for (int i = 0; i < max_tokens; ++i) {
        // 检查停止标志
        if (g_should_stop) {
            LOGI("Generation stopped by user");
            break;
        }

        float* logits = llama_get_logits(g_ctx);
        if (!logits) {
            LOGE("Failed to get logits");
            break;
        }

        // Greedy sampling
        llama_token next_token = 0;
        float max_logit = logits[0];
        for (int j = 1; j < n_vocab; ++j) {
            if (logits[j] > max_logit) {
                max_logit = logits[j];
                next_token = j;
            }
        }

        if (next_token == eos_token) {
            break;
        }

        // Convert token to piece and immediately send to Java
        char piece[128];
        int n_piece = llama_token_to_piece(vocab, next_token, piece, sizeof(piece), 0, false);

        if (n_piece > 0) {
            send_token_to_java(piece, n_piece);
        } else if (n_piece < 0) {
            std::vector<char> large_piece(-n_piece + 1);
            n_piece = llama_token_to_piece(vocab, next_token, large_piece.data(), large_piece.size(), 0, false);
            if (n_piece > 0) {
                send_token_to_java(large_piece.data(), n_piece);
            }
        }

        // Create batch for the new token
        llama_batch single_batch = llama_batch_init(1, 0, 1);
        single_batch.n_tokens = 1;
        single_batch.token[0] = next_token;
        single_batch.pos[0] = n_past + i;
        single_batch.n_seq_id[0] = 1;
        single_batch.seq_id[0][0] = 0;
        single_batch.logits[0] = 1;

        decode_result = llama_decode(g_ctx, single_batch);
        if (decode_result != 0) {
            LOGE("llama_decode failed on generated token with code: %d", decode_result);
            llama_batch_free(single_batch);
            break;
        }
        llama_batch_free(single_batch);

        tokens.push_back(next_token);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_flyer_chat_flyer_1chat_LlamaInference_unloadModel(JNIEnv *env, jclass clazz) {
    if (g_ctx) {
        llama_free(g_ctx);
        g_ctx = nullptr;
    }
    if (g_model) {
        llama_free_model(g_model);
        g_model = nullptr;
    }
}