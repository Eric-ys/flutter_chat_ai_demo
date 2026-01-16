package flyer.chat.flyer_chat

import android.content.Context
import android.util.Log
import java.io.File

/**
 * 流式回调接口
 * 注意：这个接口需要在同一个包中，以便 MainActivity 可以访问
 */
interface StreamCallback {
    fun onToken(token: String)
}

/**
 * Llama 模型推理类
 * 通过 JNI 调用原生 C++ 代码，使用 llama.cpp 进行本地 LLM 推理
 */
object LlamaInference {
    private const val TAG = "LlamaInference"
    private var currentCallback: StreamCallback? = null
    
    init {
        try {
            System.loadLibrary("llama")        // 5. 最后加载主库 libllama.so
            System.loadLibrary("ggml");

            Log.d(TAG, "libllama.so 加载成功")
        } catch (e: Throwable) {
            Log.e("LlamaInference", "❌ 加载失败: " + e.message);
            // 继续执行，库可能已被自动加载
        }
    }
    
    /**
     * 加载模型
     * @param modelPath 模型文件路径
     * @return 是否加载成功
     */
    @JvmStatic
    external fun loadModel(modelPath: String): Boolean
    
    /**
     * 生成文本回复（同步，返回完整结果）
     * @param prompt 输入的提示文本
     * @return 生成的文本回复
     */
    @JvmStatic
    external fun generate(prompt: String): String
    
    /**
     * 流式生成文本回复（异步，通过回调返回）
     * @param prompt 输入的提示文本
     */
    @JvmStatic
    external fun generateStream(prompt: String)
    
    /**
     * 初始化流式回调
     */
    @JvmStatic
    private external fun initStreamCallback(callback: StreamCallback)
    
    /**
     * 清理流式回调
     */
    @JvmStatic
    private external fun cleanupStreamCallback()
    
    /**
     * 设置流式回调并开始生成
     */
    @JvmStatic
    fun generateStream(prompt: String, callback: StreamCallback) {
        currentCallback = callback
        initStreamCallback(callback)
        try {
            generateStream(prompt)
        } finally {
            cleanupStreamCallback()
            currentCallback = null
        }
    }
    
    /**
     * 停止当前正在进行的流式生成
     */
    @JvmStatic
    external fun stopGeneration()
    
    /**
     * 卸载模型，释放资源
     */
    @JvmStatic
    external fun unloadModel()
}
