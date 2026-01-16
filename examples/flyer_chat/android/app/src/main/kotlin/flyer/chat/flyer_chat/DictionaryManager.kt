package flyer.chat.flyer_chat

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.InputStream

/**
 * 词典管理器 - 单例模式
 * 负责加载和查询 ECDICT 英汉词典
 */
object DictionaryManager {
    private const val TAG = "DictionaryManager"
    private const val DICT_FILE_NAME = "dict_en_zh.json"
    
    private var dictionary: Map<String, String>? = null
    private var isLoading = false
    private val gson = Gson()
    
    /**
     * 初始化词典（异步加载）
     * @param context 应用上下文
     * @return 是否加载成功
     */
    suspend fun initialize(context: Context): Boolean {
        if (dictionary != null) {
            Log.d(TAG, "词典已加载，跳过重复加载")
            return true
        }
        
        if (isLoading) {
            Log.d(TAG, "词典正在加载中，等待完成...")
            // 等待加载完成
            while (isLoading) {
                kotlinx.coroutines.delay(100)
            }
            return dictionary != null
        }
        
        return withContext(Dispatchers.IO) {
            isLoading = true
            try {
                Log.d(TAG, "开始加载词典文件: $DICT_FILE_NAME")
                
                // 从 assets 读取词典文件
                val inputStream: InputStream = context.assets.open(DICT_FILE_NAME)
                val jsonString = inputStream.bufferedReader().use { it.readText() }
                
                // 使用 Gson 解析 JSON
                val type = object : TypeToken<Map<String, String>>() {}.type
                dictionary = gson.fromJson(jsonString, type)
                
                val size = dictionary?.size ?: 0
                Log.d(TAG, "词典加载成功，共 $size 条词条")
                
                true
            } catch (e: Exception) {
                Log.e(TAG, "加载词典失败", e)
                false
            } finally {
                isLoading = false
            }
        }
    }
    
    /**
     * 查询翻译
     * @param text 要查询的文本
     * @return 翻译结果，如果未找到则返回 null
     */
    fun translate(text: String): String? {
        if (dictionary == null) {
            Log.w(TAG, "词典未初始化，无法查询")
            return null
        }
        
        // 将文本转为小写并去除首尾空格
        val key = text.lowercase().trim()
        
        if (key.isEmpty()) {
            return null
        }
        
        // 尝试精确匹配
        val translation = dictionary?.get(key)
        
        if (translation != null) {
            Log.d(TAG, "找到翻译: $key -> $translation")
            return translation
        }
        
        // 如果未找到，尝试匹配单词（去除标点符号）
        val wordOnly = key.replace(Regex("[^a-z]"), "")
        if (wordOnly.isNotEmpty() && wordOnly != key) {
            val wordTranslation = dictionary?.get(wordOnly)
            if (wordTranslation != null) {
                Log.d(TAG, "找到单词翻译: $wordOnly -> $wordTranslation")
                return wordTranslation
            }
        }
        
        Log.d(TAG, "未找到翻译: $key")
        return null
    }
    
    /**
     * 【关键修复点22】检查文本是否为英文（英文字符占比 ≥ 70%）
     * 排除中文、数字、URL 等
     * @param text 要检查的文本
     * @return 是否为英文
     */
    fun isEnglishText(text: String): Boolean {
        if (text.isEmpty()) {
            return false
        }
        
        val trimmedText = text.trim()
        if (trimmedText.isEmpty()) {
            return false
        }
        
        // 排除明显的 URL
        if (trimmedText.contains("http://", ignoreCase = true) || 
            trimmedText.contains("https://", ignoreCase = true) || 
            trimmedText.contains("www.", ignoreCase = true) || 
            trimmedText.contains(".com", ignoreCase = true) ||
            trimmedText.contains(".org", ignoreCase = true) || 
            trimmedText.contains(".net", ignoreCase = true) ||
            trimmedText.contains(".io", ignoreCase = true)) {
            return false
        }
        
        // 排除纯数字或数字为主的文本
        val digitCount = trimmedText.count { it.isDigit() }
        val letterCount = trimmedText.count { it.isLetter() }
        if (digitCount > letterCount && letterCount < 3) {
            return false
        }
        
        // 计算英文字符（ASCII 字母）和总字母字符数
        var englishCharCount = 0
        var totalLetterCount = 0
        
        for (char in trimmedText) {
            if (char.isLetter()) {
                totalLetterCount++
                // 检查是否为 ASCII 字母（英文字母）
                if (char.code in 65..90 || char.code in 97..122) {
                    englishCharCount++
                }
            }
        }
        
        // 如果没有字母，不是英文
        if (totalLetterCount == 0) {
            return false
        }
        
        // 【关键修复点23】英文字符占比 ≥ 70%（包含等于）
        val englishRatio = englishCharCount.toFloat() / totalLetterCount
        val isEnglish = englishRatio >= 0.7f
        
        Log.d(TAG, "文本检测: '$trimmedText' - 英文字符: $englishCharCount/$totalLetterCount, 占比: ${englishRatio * 100}%, 结果: $isEnglish")
        
        return isEnglish
    }
    
    /**
     * 检查词典是否已加载
     */
    fun isInitialized(): Boolean {
        return dictionary != null
    }
    
    /**
     * 获取词典大小
     */
    fun getDictionarySize(): Int {
        return dictionary?.size ?: 0
    }
}

