# Vosk ProGuard rules (pure JNI, no JNA)
# 使用官方 vosk-android AAR，纯 JNI 实现，不依赖 JNA

# Keep all Vosk classes from AAR
-keep class org.vosk.** { *; }
-dontwarn org.vosk.**

# Keep native methods (JNI bindings)
-keepclasseswithmembernames class * {
    native <methods>;
}

## Keep our Vosk wrapper classes
#-keep class flyer.chat.flyer_chat.VoskSpeechRecognition { *; }
#-keep class flyer.chat.flyer_chat.MainActivity { *; }

# Keep JSON parsing classes used by Vosk
-keep class org.json.** { *; }

# Ensure native library loading works
-keepclassmembers class * {
    native <methods>;
}

