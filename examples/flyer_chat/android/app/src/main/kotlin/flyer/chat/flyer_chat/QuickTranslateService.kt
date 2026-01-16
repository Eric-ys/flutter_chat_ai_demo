package flyer.chat.flyer_chat

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 快速翻译无障碍服务
 * 监听文本选择事件，自动显示翻译结果
 */
class QuickTranslateService : AccessibilityService() {
    private val TAG = "QuickTranslateService"
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    
    private var translationOverlay: TranslationOverlay? = null
    private var isServiceEnabled = false
    private var lastProcessedText: String? = null
    private var lastProcessedTime: Long = 0
    
    companion object {
        private const val PREFS_NAME = "translate_service_prefs"
        // 【关键修复】使用 quick_translate_enabled 作为 key，与 Flutter 侧保持一致
        private const val KEY_SERVICE_ENABLED = "quick_translate_enabled"
        private const val DEBOUNCE_DELAY_MS = 500L // 防抖延迟
        
        @Volatile
        private var instance: QuickTranslateService? = null
        
        fun getInstance(): QuickTranslateService? {
            return instance
        }
        
        /**
         * 检查无障碍服务是否已启用
         */
        fun isAccessibilityServiceEnabled(context: Context): Boolean {
            val serviceName = "${context.packageName}/${QuickTranslateService::class.java.canonicalName}"
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            
            return !TextUtils.isEmpty(enabledServices) && enabledServices.contains(serviceName)
        }
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "无障碍服务已连接")
        
        translationOverlay = TranslationOverlay(this)
        
        // 初始化词典（异步加载）
        serviceScope.launch {
            val success = DictionaryManager.initialize(this@QuickTranslateService)
            if (success) {
                Log.d(TAG, "词典初始化成功")
            } else {
                Log.e(TAG, "词典初始化失败")
            }
        }
        
        // 加载服务状态
        loadServiceState()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "无障碍服务已销毁")
        translationOverlay?.destroy()
        translationOverlay = null
        instance = null
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // 【关键修复点1】检查服务是否启用
        if (!isServiceEnabled) {
            return
        }
        
        // 【关键修复点2】只处理文本选择变化事件
        if (event.eventType != AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED) {
            return
        }
        
        // 【关键修复点3】从多个来源提取选中文本（优先使用 source.text）
        val selectedText = extractSelectedText(event)
        if (selectedText.isNullOrEmpty()) {
            return
        }
        
        // 【关键修复】检查文本长度 ≥ 2
        if (selectedText.length < 2) {
            Log.d(TAG, "文本长度不足，跳过: $selectedText")
            return
        }
        
        // 防抖处理：避免频繁触发
        val currentTime = System.currentTimeMillis()
        if (selectedText == lastProcessedText && 
            currentTime - lastProcessedTime < DEBOUNCE_DELAY_MS) {
            return
        }
        
        lastProcessedText = selectedText
        lastProcessedTime = currentTime
        
        // 【关键修复点4】检查是否为英文文本（英文字符占比 ≥ 70%）
        if (!DictionaryManager.isEnglishText(selectedText)) {
            Log.d(TAG, "文本不是英文，跳过: $selectedText")
            return
        }
        
        // 【关键修复点5】在后台线程处理翻译（避免阻塞 Accessibility 主线程）
        serviceScope.launch {
            processTranslation(selectedText)
        }
    }
    
    /**
     * 【关键修复点6】提取选中文本的多种方式
     * 优先从 event.source 获取，其次从 event.text 获取
     */
    private fun extractSelectedText(event: AccessibilityEvent): String? {
        // 方法1：从 event.source 获取选中文本（最准确）
        event.source?.let { source ->
            val selectionStart = source.textSelectionStart
            val selectionEnd = source.textSelectionEnd
            if (selectionStart >= 0 && selectionEnd > selectionStart) {
                val text = source.text?.toString()
                if (!text.isNullOrEmpty() && selectionEnd <= text.length) {
                    val selected = text.substring(selectionStart, selectionEnd).trim()
                    if (selected.isNotEmpty()) {
                        Log.d(TAG, "从 source 提取文本: $selected")
                        return selected
                    }
                }
            }
        }
        
        // 方法2：从 event.text 获取（备用方案）
        val textFromEvent = event.text?.firstOrNull()?.toString()?.trim()
        if (!textFromEvent.isNullOrEmpty()) {
            Log.d(TAG, "从 event.text 提取文本: $textFromEvent")
            return textFromEvent
        }
        
        // 方法3：从 event.getText() 获取
        if (event.text != null && event.text.isNotEmpty()) {
            val text = event.text[0]?.toString()?.trim()
            if (!text.isNullOrEmpty()) {
                Log.d(TAG, "从 getText() 提取文本: $text")
                return text
            }
        }
        
        return null
    }
    
    /**
     * 【关键修复点7】处理翻译（在后台线程执行，避免 ANR）
     */
    private suspend fun processTranslation(text: String) {
        // 确保词典已加载
        if (!DictionaryManager.isInitialized()) {
            Log.d(TAG, "词典未初始化，开始加载...")
            val success = DictionaryManager.initialize(this@QuickTranslateService)
            if (!success) {
                Log.e(TAG, "词典加载失败，无法翻译")
                // 在主线程显示错误提示
                kotlinx.coroutines.withContext(Dispatchers.Main) {
                    translationOverlay?.showTranslation(text, "词典加载失败")
                }
                return
            }
        }
        
        // 【关键修复点8】在后台线程查询翻译（避免阻塞）
        val translation: String? = withContext(Dispatchers.Default) {
            DictionaryManager.translate(text)
        }
        
        // 【关键修复点9】在主线程显示悬浮窗（UI 操作必须在主线程）
        withContext(Dispatchers.Main) {
            if (translation != null) {
                translationOverlay?.showTranslation(text, translation)
            } else {
                Log.d(TAG, "未找到翻译: $text")
                translationOverlay?.showTranslation(text, "未收录")
            }
        }
    }
    
    override fun onInterrupt() {
        Log.w(TAG, "无障碍服务被中断")
    }
    
    /**
     * 加载服务启用状态
     */
    private fun loadServiceState() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        isServiceEnabled = prefs.getBoolean(KEY_SERVICE_ENABLED, false)
        Log.d(TAG, "服务状态: ${if (isServiceEnabled) "已启用" else "已禁用"}")
    }
    
    /**
     * 设置服务启用状态（供外部调用）
     */
    fun setServiceEnabled(enabled: Boolean) {
        isServiceEnabled = enabled
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_SERVICE_ENABLED, enabled).apply()
        Log.d(TAG, "服务状态已更新: ${if (enabled) "已启用" else "已禁用"}")
        
        // 如果禁用，隐藏悬浮窗
        if (!enabled) {
            translationOverlay?.hideTranslation()
        }
    }
    
    /**
     * 检查服务是否已启用（供外部调用）
     */
    fun isServiceEnabled(): Boolean {
        return isServiceEnabled
    }
    
    init {
        instance = this
    }
}

