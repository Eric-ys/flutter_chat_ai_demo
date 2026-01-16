package flyer.chat.flyer_chat

import android.content.Context
import android.util.Log
import android.widget.Toast

/**
 * 翻译结果展示层（最小实现）
 *
 * 说明：
 * - 之前该文件被误删导致 QuickTranslateService 编译失败。
 * - 这里提供一个“无权限/无 WindowManager 依赖”的最小可用实现：用 Toast 展示/隐藏。
 * - 如果你后续需要真正的悬浮窗（WindowManager overlay），可以在此扩展。
 */
class TranslationOverlay(private val context: Context) {
  private val tag = "TranslationOverlay"

  private var toast: Toast? = null

  fun showTranslation(sourceText: String, translatedText: String) {
    val msg = "$sourceText\n$translatedText"
    Log.d(tag, "showTranslation: $msg")
    toast?.cancel()
    toast = Toast.makeText(context.applicationContext, msg, Toast.LENGTH_LONG)
    toast?.show()
  }

  fun hideTranslation() {
    Log.d(tag, "hideTranslation")
    toast?.cancel()
    toast = null
  }

  fun destroy() {
    Log.d(tag, "destroy")
    hideTranslation()
  }
}


