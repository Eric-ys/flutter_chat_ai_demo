plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "flyer.chat.flyer_chat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "flyer.chat.flyer_chat"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // 配置 NDK 和原生代码编译
        // 注意：libllama.so 目前仅编译了 arm64-v8a 版本
        // 如果需要支持其他架构，需要编译相应架构的 libllama.so
        ndk {
            abiFilters.clear()
            abiFilters += listOf("arm64-v8a")
            // abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }


        // 配置 CMake
        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17")
                arguments += "-DANDROID_STL=c++_shared"
                abiFilters.clear()
                abiFilters.add("arm64-v8a")
//                abiFilters = listOf("arm64-v8a")  // ← 这里！
            }
        }
    }

    sourceSets {
        named("main") {
            jniLibs.srcDir("src/main/jniLibs")
        }
    }

    // 配置外部原生构建
    externalNativeBuild {
        cmake {
            path = file("CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// 【依赖冲突解决】统一 JetBrains Annotations 版本
configurations.all {
    resolutionStrategy {
        // 强制使用统一版本的 annotations，避免 Markwon 引入的版本冲突
        force("org.jetbrains:annotations:23.0.0")
    }
}

dependencies {
    implementation(files(project.file("libs/vosk-android-0.3.46.aar")))

    // Kotlin coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    
    // Gson for JSON parsing (词典文件解析)
    implementation("com.google.code.gson:gson:2.10.1")
    
    // ============ Markwon：Markdown 渲染库 ============
    // 【依赖冲突修复】排除冲突的 annotations 传递依赖
    // Markwon 核心库（必须）
    implementation("io.noties.markwon:core:4.6.2") {
        exclude(group = "org.jetbrains", module = "annotations-java5")
    }
    
    // Markwon 扩展模块（可选，按需启用）
    implementation("io.noties.markwon:ext-strikethrough:4.6.2") {
        exclude(group = "org.jetbrains", module = "annotations-java5")
    }
    implementation("io.noties.markwon:ext-tables:4.6.2") {
        exclude(group = "org.jetbrains", module = "annotations-java5")
    }
    implementation("io.noties.markwon:ext-tasklist:4.6.2") {
        exclude(group = "org.jetbrains", module = "annotations-java5")
    }
    implementation("io.noties.markwon:linkify:4.6.2") {
        exclude(group = "org.jetbrains", module = "annotations-java5")
    }
    implementation("io.noties.markwon:syntax-highlight:4.6.2") {
        exclude(group = "org.jetbrains", module = "annotations-java5")
    }
}

flutter {
    source = "../.."
}
