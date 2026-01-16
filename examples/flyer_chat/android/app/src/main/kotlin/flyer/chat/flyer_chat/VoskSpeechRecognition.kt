package flyer.chat.flyer_chat

import android.content.Context
import android.content.pm.PackageManager
import android.content.res.AssetManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/**
 * Vosk 语音识别实现（使用官方 Android AAR）
 *
 * 使用官方 vosk-android AAR 提供的 SpeechService 进行录音和识别。
 * 依赖本地 JNA 存根 (com.sun.jna.PointerType) 解决编译依赖问题。
 */
class VoskSpeechRecognition(
    private val channel: MethodChannel,
    private val context: android.content.Context
) : RecognitionListener {

    private var model: Model? = null
    private var speechService: SpeechService? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    companion object {
        private const val TAG = "VoskSpeechRecognition"
        private const val SAMPLE_RATE = 16000.0f
        private const val DEFAULT_MODEL_NAME = "vosk-model-small-cn-0.3"
        
        init {
            // 确保 Vosk 原生库已加载
            // AAR 中的原生库应该自动加载，但显式加载更安全
            try {
                System.loadLibrary("vosk")
                Log.d(TAG, "Vosk native library loaded successfully")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load vosk native library", e)
                // 继续执行，因为 AAR 可能已经加载了库
            }
        }
    }

    /**
     * 初始化 Vosk 模型
     */
    fun initialize(modelPath: String?, result: MethodChannel.Result) {
        scope.launch {
            try {
                Log.d(TAG, "Initializing Vosk (SpeechService implementation)...")

                val modelName = modelPath ?: DEFAULT_MODEL_NAME
                Log.d(TAG, "Model name: $modelName")

                // 从 assets 复制模型到内部存储
                val internalModelPath = copyModelFromAssets(modelName)

                if (internalModelPath == null) {
                    withContext(Dispatchers.Main) {
                        result.error(
                            "MODEL_ERROR",
                            "Failed to copy model from assets. Please check logs.",
                            null
                        )
                    }
                    return@launch
                }

                // 确保原生库已加载（在创建 Model 之前）
                try {
                    System.loadLibrary("vosk")
                    Log.d(TAG, "Vosk native library loaded before Model creation")
                } catch (e: UnsatisfiedLinkError) {
                    Log.w(TAG, "Vosk library may already be loaded: ${e.message}")
                }
                
                // 加载模型 (使用自定义 org.vosk.Model，直接调用 JNI)
                try {
                    Log.d(TAG, "Creating Model with path: $internalModelPath")
                    model = Model(internalModelPath)
                    Log.d(TAG, "Model loaded successfully (handle: ${model?.getHandle()})")
                    
                    withContext(Dispatchers.Main) {
                        result.success(true)
                    }
                } catch (e: IOException) {
                    Log.e(TAG, "Failed to load model", e)
                    withContext(Dispatchers.Main) {
                        result.error("LOAD_ERROR", "Failed to load model: ${e.message}", null)
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "Unexpected initialization error", e)
                withContext(Dispatchers.Main) {
                    result.error("INIT_ERROR", e.message, null)
                }
            }
        }
    }

    /**
     * 检查麦克风权限
     */
    private fun checkMicrophonePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Android 6.0 以下默认有权限
        }
    }

    /**
     * 开始语音识别
     */
    fun startListening(result: MethodChannel.Result) {
        if (model == null) {
            result.error("NOT_INITIALIZED", "Model not initialized", null)
            return
        }

        // 检查权限
        if (!checkMicrophonePermission()) {
            Log.e(TAG, "Microphone permission not granted")
            result.error("PERMISSION_DENIED", "Microphone permission not granted", null)
            return
        }

        // 在主线程上执行，确保 AudioRecord 正确初始化
        mainHandler.post {
            try {
                // 如果 SpeechService 已存在，先停止并释放它，避免资源冲突
                if (speechService != null) {
                    Log.d(TAG, "Stopping existing SpeechService before creating new one")
                    try {
                        speechService?.stop()
                    } catch (e: Exception) {
                        Log.w(TAG, "Error stopping existing SpeechService: ${e.message}")
                    }
                    try {
                        speechService?.shutdown()
                    } catch (e: Exception) {
                        Log.w(TAG, "Error shutting down existing SpeechService: ${e.message}")
                    }
                    speechService = null
                    // 等待更长时间，确保 AudioRecord 资源完全释放
                    Thread.sleep(500)
                }

                // 创建新的 SpeechService（必须在主线程上创建）
                Log.d(TAG, "Creating new SpeechService on main thread")
                val recognizer = Recognizer(model, SAMPLE_RATE)
                speechService = SpeechService(recognizer, SAMPLE_RATE)

                // 开始监听
                // SpeechService.startListening() 通常返回 void，开始异步录音
                speechService?.startListening(this)
                Log.d(TAG, "SpeechService started listening")
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start listening", e)
                // 如果启动失败，清理资源
                try {
                    speechService?.shutdown()
                } catch (cleanupError: Exception) {
                    Log.w(TAG, "Error cleaning up after start failure: ${cleanupError.message}")
                }
                speechService = null
                result.error("START_ERROR", e.message ?: "Unknown error", null)
            }
        }
    }

    /**
     * 停止语音识别
     */
    fun stopListening(result: MethodChannel.Result) {
        try {
            speechService?.stop()
            Log.d(TAG, "SpeechService stopped")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop listening", e)
            result.error("STOP_ERROR", e.message, null)
        }
    }

    /**
     * 取消语音识别
     */
    fun cancel(result: MethodChannel.Result) {
        try {
            speechService?.cancel()
            Log.d(TAG, "SpeechService cancelled")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel", e)
            result.error("CANCEL_ERROR", e.message, null)
        }
    }

    /**
     * 释放资源
     */
    fun dispose() {
        try {
            speechService?.shutdown()
            speechService = null
            // Model 可能实现了 AutoCloseable，尝试安全关闭
            try {
                (model as? AutoCloseable)?.close()
            } catch (e: Exception) {
                // 如果 Model 没有 close 方法，忽略错误
                Log.d(TAG, "Model does not support close() or already closed")
            }
            model = null
            scope.cancel()
            Log.d(TAG, "Vosk resources disposed")
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing resources", e)
        }
    }

    // --- RecognitionListener Implementation ---

    override fun onResult(hypothesis: String) {
        // 最终结果 (一段话结束)
        // json: {"text": "识别结果"}
        notifyResult(hypothesis, true)
    }

    override fun onPartialResult(hypothesis: String) {
        // 部分结果 (实时)
        // json: {"partial": "正在识别..."}
        notifyResult(hypothesis, false)
    }

    override fun onFinalResult(hypothesis: String) {
        // 最终结果 (停止后)
        notifyResult(hypothesis, true)
    }

    override fun onError(exception: Exception) {
        Log.e(TAG, "Recognition error", exception)
        mainHandler.post {
            channel.invokeMethod("onError", exception.message)
        }
    }

    override fun onTimeout() {
        Log.d(TAG, "Recognition timeout")
        mainHandler.post {
            channel.invokeMethod("onTimeout", null)
        }
    }

    private fun notifyResult(json: String, isFinal: Boolean) {
        try {
            val jsonObject = JSONObject(json)
            val text = if (isFinal) {
                jsonObject.optString("text", "")
            } else {
                jsonObject.optString("partial", "")
            }

            // 只有非空结果才通知 Flutter
            if (text.isNotEmpty()) {
                mainHandler.post {
                    val method = if (isFinal) "onResult" else "onPartialResult"
                    channel.invokeMethod(method, mapOf(
                        "text" to text,
                        "isFinal" to isFinal
                    ))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing result JSON: $json", e)
        }
    }

    // --- Helper Methods ---

    /**
     * 从 assets 复制模型到内部存储
     */
    private suspend fun copyModelFromAssets(modelName: String): String? = withContext(Dispatchers.IO) {
        try {
            val internalModelDir = File(context.filesDir, modelName)
            
            if (internalModelDir.exists() && internalModelDir.isDirectory) {
                val files = internalModelDir.listFiles()
                if (files != null && files.isNotEmpty()) {
                    Log.d(TAG, "Model exists: ${internalModelDir.absolutePath}")
                    return@withContext internalModelDir.absolutePath
                }
            }
            
            val assetManager = context.assets
            try {
                val assetFiles = assetManager.list("") ?: emptyArray()
                if (!assetFiles.contains(modelName)) {
                    Log.e(TAG, "Model not found in assets: $modelName")
                    return@withContext null
                }
                
                internalModelDir.mkdirs()
                copyAssetsRecursive(assetManager, modelName, internalModelDir)
                
                Log.d(TAG, "Model copied to: ${internalModelDir.absolutePath}")
                return@withContext internalModelDir.absolutePath
            } catch (e: Exception) {
                Log.e(TAG, "Failed to copy model", e)
                return@withContext null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error preparing model", e)
            return@withContext null
        }
    }

    private fun copyAssetsRecursive(
        assetManager: AssetManager,
        assetPath: String,
        targetDir: File
    ) {
        val files = assetManager.list(assetPath) ?: return
        
        for (file in files) {
            val fullAssetPath = if (assetPath.isEmpty()) file else "$assetPath/$file"
            val targetFile = File(targetDir, file)
            
            try {
                val list = assetManager.list(fullAssetPath)
                if (list != null && list.isNotEmpty()) {
                    targetFile.mkdirs()
                    copyAssetsRecursive(assetManager, fullAssetPath, targetFile)
                } else {
                    targetFile.parentFile?.mkdirs()
                    assetManager.open(fullAssetPath).use { input ->
                        FileOutputStream(targetFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error copying asset: $fullAssetPath", e)
            }
        }
    }
}
