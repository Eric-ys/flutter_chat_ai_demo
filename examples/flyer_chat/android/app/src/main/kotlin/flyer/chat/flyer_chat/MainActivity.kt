package flyer.chat.flyer_chat

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.accessibilityservice.AccessibilityService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec

class MainActivity : FlutterActivity() {
    private val VOSK_CHANNEL = "flyer.chat.flyer_chat/vosk_speech"
    private val TRANSLATE_CHANNEL = "flyer.chat.flyer_chat/translate"
    private val SYSTEM_ACTIONS_CHANNEL = "flyer.chat.flyer_chat/system_actions"
    private val LLAMA_CHANNEL = "flyer.chat.flyer_chat/llama"
    private var voskRecognition: VoskSpeechRecognition? = null
    
    companion object {
        private const val TAG = "MainActivity"
        
        init {
            // 提前加载 Vosk 原生库，确保在使用前已加载
            try {
                System.loadLibrary("vosk")
                Log.d(TAG, "Vosk native library loaded in MainActivity")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load vosk native library", e)
                // 继续执行，AAR 可能已经自动加载了库
            }
            
            // 提前加载 Llama 相关库
            try {
                // 先尝试加载 libllama.so（如果还未自动加载）
                try {
                    System.loadLibrary("llama")
                    Log.d(TAG, "libllama.so loaded in MainActivity")
                } catch (e: UnsatisfiedLinkError) {
                    Log.d(TAG, "libllama.so may already be loaded or not in jniLibs: ${e.message}")
                }
                
                // 加载 llama_jni 库
                System.loadLibrary("llama_jni")
                Log.d(TAG, "Llama JNI library loaded in MainActivity")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load llama_jni library: ${e.message}", e)
                // 继续执行，库可能在后续加载
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 已移除所有原生 PlatformView（native_chat_text / native_markdown_text）
        
        // Vosk 语音识别通道
        val voskChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOSK_CHANNEL)
        voskRecognition = VoskSpeechRecognition(voskChannel, this)
        
        voskChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val modelPath = call.argument<String>("modelPath")
                    voskRecognition?.initialize(modelPath, result)
                }
                "startListening" -> {
                    voskRecognition?.startListening(result)
                }
                "stopListening" -> {
                    voskRecognition?.stopListening(result)
                }
                "cancel" -> {
                    voskRecognition?.cancel(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 翻译服务通道
        val translateChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRANSLATE_CHANNEL)
        translateChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityServiceEnabled" -> {
                    val enabled = QuickTranslateService.isAccessibilityServiceEnabled(this)
                    result.success(enabled)
                }
                "canDrawOverlays" -> {
                    val canDraw = canDrawOverlays()
                    result.success(canDraw)
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "openOverlayPermissionSettings" -> {
                    openOverlayPermissionSettings()
                    result.success(null)
                }
                "setServiceEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    QuickTranslateService.getInstance()?.setServiceEnabled(enabled)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 系统功能通道（截图、通知中心、锁屏等）
        val systemActionsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_ACTIONS_CHANNEL)
        systemActionsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityServiceEnabled" -> {
                    val enabled = QuickTranslateService.isAccessibilityServiceEnabled(this)
                    result.success(enabled)
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "takeScreenshot" -> {
                    val service = QuickTranslateService.getInstance()
                    if (service != null && QuickTranslateService.isAccessibilityServiceEnabled(this)) {
                        service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_TAKE_SCREENSHOT)
                        result.success(true)
                    } else {
                        result.error("ACCESSIBILITY_NOT_ENABLED", "无障碍服务未启用", null)
                    }
                }
                "openNotificationPanel" -> {
                    val service = QuickTranslateService.getInstance()
                    if (service != null && QuickTranslateService.isAccessibilityServiceEnabled(this)) {
                        service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS)
                        result.success(true)
                    } else {
                        result.error("ACCESSIBILITY_NOT_ENABLED", "无障碍服务未启用", null)
                    }
                }
                "lockScreen" -> {
                    val service = QuickTranslateService.getInstance()
                    if (service != null && QuickTranslateService.isAccessibilityServiceEnabled(this)) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_LOCK_SCREEN)
                            result.success(true)
                        } else {
                            result.error("NOT_SUPPORTED", "锁屏功能需要 Android 9.0 及以上版本", null)
                        }
                    } else {
                        result.error("ACCESSIBILITY_NOT_ENABLED", "无障碍服务未启用", null)
                    }
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Llama 推理通道
        val llamaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LLAMA_CHANNEL)
        
        // Llama 流式输出 EventChannel
        var llamaEventSink: EventChannel.EventSink? = null
        val llamaStreamChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "flyer.chat.flyer_chat/llama_stream"
        )
        
        llamaStreamChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                llamaEventSink = events
                Log.d(TAG, "Llama stream listener attached")
            }
            
            override fun onCancel(arguments: Any?) {
                llamaEventSink = null
                Log.d(TAG, "Llama stream listener cancelled")
            }
        })
        
        llamaChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath == null) {
                        result.error("INVALID_ARGUMENT", "模型路径不能为空", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val success = LlamaInference.loadModel(modelPath)
                        if (success) {
                            Log.d(TAG, "模型加载成功: $modelPath")
                            result.success(true)
                        } else {
                            Log.e(TAG, "模型加载失败: $modelPath")
                            result.error("LOAD_FAILED", "模型加载失败", null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "加载模型时发生异常", e)
                        result.error("EXCEPTION", "加载模型异常: ${e.message}", null)
                    }
                }
                "generate" -> {
                    val prompt = call.argument<String>("prompt")
                    if (prompt == null) {
                        result.error("INVALID_ARGUMENT", "prompt 不能为空", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val response = LlamaInference.generate(prompt)
                        Log.d(TAG, "生成完成，长度: ${response.length}")
                        result.success(response)
                    } catch (e: Exception) {
                        Log.e(TAG, "生成文本时发生异常", e)
                        result.error("EXCEPTION", "生成文本异常: ${e.message}", null)
                    }
                }
                "generateStream" -> {
                    val prompt = call.argument<String>("prompt")
                    if (prompt == null) {
                        result.error("INVALID_ARGUMENT", "prompt 不能为空", null)
                        return@setMethodCallHandler
                    }
                    // 立即返回，不等待生成完成
                    result.success(null)
                    // 在后台线程执行，避免阻塞
                    Thread {
                        try {
                            val callback = object : StreamCallback {
                                override fun onToken(token: String) {
                                    // EventChannel 必须在主线程调用，使用 Handler 切换到主线程
                                    runOnUiThread {
                                        llamaEventSink?.success(token)
                                    }
                                }
                            }
                            LlamaInference.generateStream(prompt, callback)
                            // 发送结束标记（null 表示结束），必须在主线程
                            runOnUiThread {
                                llamaEventSink?.success(null)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "流式生成文本时发生异常", e)
                            // 错误处理也必须在主线程
                            runOnUiThread {
                                llamaEventSink?.error("EXCEPTION", "流式生成文本异常: ${e.message}", null)
                            }
                        }
                    }.start()
                }
                "stopGeneration" -> {
                    try {
                        LlamaInference.stopGeneration()
                        Log.d(TAG, "停止生成成功")
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "停止生成时发生异常", e)
                        result.error("EXCEPTION", "停止生成异常: ${e.message}", null)
                    }
                }
                "unloadModel" -> {
                    try {
                        LlamaInference.unloadModel()
                        Log.d(TAG, "模型卸载成功")
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "卸载模型时发生异常", e)
                        result.error("EXCEPTION", "卸载模型异常: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    /**
     * 检查是否有悬浮窗权限
     */
    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true // Android 6.0 以下默认有权限
        }
    }
    
    /**
     * 打开无障碍设置页面
     */
    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "打开无障碍设置失败", e)
        }
    }
    
    /**
     * 打开悬浮窗权限设置页面
     */
    private fun openOverlayPermissionSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
            } else {
                // Android 6.0 以下不需要此权限
                Log.d(TAG, "当前 Android 版本不需要悬浮窗权限")
            }
        } catch (e: Exception) {
            Log.e(TAG, "打开悬浮窗权限设置失败", e)
        }
    }
    
    /**
     * 打开应用设置页面
     */
    private fun openAppSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "打开应用设置失败", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        voskRecognition?.dispose()
        voskRecognition = null
    }
}

