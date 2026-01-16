基于 https://github.com/flyerhq/flutter_chat_ui 实现以下功能，该项目仅作为个人学习demo使用

本项目 是一个开源的 Flutter 聊天 UI 框架，专为性能、定制化和易集成而设计。它提供了完整的聊天界面组件，支持多种消息类型、流式输出、语音识别等高级功能。

## ✨ 核心特性

### 🎯 基础功能

- **🔄 后端无关**: 可连接到任何后端服务，不绑定特定的聊天服务提供商
- **🧬 高度适配**: 完美适用于实时通讯、生成式 AI 助手、LLM 应用、客服平台等多种场景
- **🎨 高度可定制**: 通过丰富的主题选项和构建器函数，完全定制 UI 外观和行为
- **🧩 模块化设计**: 按需选择功能，可以替换任何 UI 组件或使用自定义实现
- **⚡ 性能优化**: 专为速度和流畅动画而构建，支持大量消息的高效渲染
- **🌐 跨平台支持**: 支持 iOS、Android、Web、macOS、Windows 和 Linux 全平台

### 🚀 高级功能

- **📝 流式文本消息**: 支持实时流式输出文本，带有淡入动画效果，完美适配 AI 助手场景
- **🎤 语音识别**: 集成离线语音识别（Vosk），支持实时语音转文字
- **🖼️ 富文本支持**: 支持 Markdown 渲染，包括表格、代码块、图片、超链接等
- **📷 图片预览**: 支持图片大图预览，手势缩放和滑动关闭
- **🔗 链接预览**: 自动生成链接预览卡片
- **💬 多种消息类型**: 文本、图片、文件、视频、音频、位置、系统消息等
- **⌨️ 智能输入框**: 支持多行输入、语音输入、附件上传、快捷功能面板
- **📊 消息状态**: 支持发送中、已发送、已送达、已读等状态显示
- **🔄 消息分组**: 自动将连续消息分组显示，优化界面布局

## 🚀 快速开始

### 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  flutter_chat_core: ^2.8.0
  flutter_chat_ui: ^2.9.1
```

然后运行：

```bash
flutter pub get
```

### 基础使用

## 📦 项目结构

本项目采用 [Melos](https://melos.invertase.dev/) 管理的 monorepo 结构：

```
flutter_chat_ui/
├── packages/              # 核心和扩展包
│   ├── flutter_chat_core/      # 核心数据模型、控制器、主题
│   ├── flutter_chat_ui/        # 主 UI 组件
│   ├── cross_cache/             # 跨平台图片缓存
│   └── flyer_chat_*/           # 各种消息类型组件
└── examples/             # 示例应用
    └── flyer_chat/       # 完整功能演示应用
```

### 核心包

这些是安装 `flutter_chat_ui` 时包含的基础包：

- **`flutter_chat_ui`**: 主 UI 包，包含 `Chat` 组件和核心 UI 元素
- **`flutter_chat_core`**: 核心包，包含数据模型、控制器接口、主题系统等
- **`cross_cache`**: 跨平台（IO & Web）图片缓存解决方案

### 可选消息类型包

按需安装，只包含你需要的消息类型：

- **`flyer_chat_text_message`**: 文本消息，支持 Markdown
- **`flyer_chat_text_stream_message`**: 流式文本消息，支持实时输出和淡入动画
- **`flyer_chat_image_message`**: 图片消息，支持预览和缩放
- **`flyer_chat_file_message`**: 文件消息
- **`flyer_chat_video_message`**: 视频消息
- **`flyer_chat_audio_message`**: 音频消息
- **`flyer_chat_location_message`**: 位置消息
- **`flyer_chat_system_message`**: 系统消息（如用户加入/离开）
- **`flyer_chat_custom_message`**: 自定义消息类型

### 工具包

- **`flutter_link_previewer`**: 链接预览生成器

## 🎨 主要功能详解

### 流式文本消息

支持实时流式输出文本内容，常用于 AI 助手场景：


特性：
- 实时字符流式输出
- 淡入动画效果
- Markdown 实时渲染
- 支持图片和超链接
- 可停止和恢复流式输出

### 语音识别

集成 Vosk 离线语音识别引擎：

- 完全离线工作，无需网络
- 支持实时语音转文字
- 支持长按录音和手势取消
- 自动将识别结果转换为流式消息

### 富文本支持

基于 `gpt_markdown` 的 Markdown 渲染：

- 支持标题、列表、代码块、表格
- 支持图片内嵌（assets、网络、本地文件）
- 支持超链接（可点击跳转）
- 支持表情符号
- 实时渲染和样式定制

### 图片预览

- 点击图片查看大图
- 手势缩放（双指捏合）
- 滑动关闭动画
- 支持 assets、网络和本地图片

### 智能输入框

- 多行文本输入（最多 5 行）
- 语音输入模式切换
- 附件上传（图片、文件）
- 快捷功能面板
- 键盘和面板平滑切换动画
- Enter 发送，长按 Enter 换行

## 📚 文档和示例

### 完整文档

详细的用法、定制选项、不同消息类型、控制器和更复杂的场景，请参考：

➡️ **[flyer.chat/docs/flutter/introduction](https://flyer.chat/docs/flutter/introduction)** ⬅️

### 示例应用

查看 [`examples/flyer_chat`](examples/flyer_chat) 目录下的完整示例应用，包含：

- 基础聊天界面
- 流式文本消息演示
- 语音识别集成
- 富文本消息示例
- 图片预览功能
- 自定义主题和样式
- 多种消息类型展示

运行示例：

```bash
cd examples/flyer_chat
flutter run
```

### 本地开发

如果你想在本地开发并测试修改：

1. Fork 本仓库
2. 克隆到本地
3. 运行 `melos bootstrap` 安装依赖
4. 在 `examples/flyer_chat` 中测试你的修改

