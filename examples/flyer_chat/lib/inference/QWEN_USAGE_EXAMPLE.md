# Qwen 本地 LLM 集成使用示例

## 📋 概述

本文档展示如何在 Flutter 聊天应用中集成本地 Qwen2.5-3B 模型，实现用户消息在右侧、AI 回复在左侧，并支持流式输出。

## 🔧 集成步骤

### 1. 在 `onMessageSend` 回调中调用

在您的聊天页面（如 `local.dart`）的 `onMessageSend` 回调中，在插入用户消息后，调用 `QwenChatHelper.generateAndStreamResponse`：

```dart
void _handleMessageSend(String text) async {
  // 1. 先插入用户消息（显示在右侧）
  await _chatController.insertMessage(
    TextMessage(
      id: _uuid.v4(),
      authorId: _currentUser.id, // 用户 ID，消息显示在右侧
      createdAt: DateTime.now().toUtc(),
      text: text,
    ),
  );

  // 2. 调用本地 LLM 生成 AI 回复（显示在左侧，流式输出）
  await QwenChatHelper.generateAndStreamResponse(
    chatController: _chatController,
    streamManager: _streamManager,
    currentUserId: _currentUser.id, // 用户 ID
    aiUserId: _recipient.id, // AI 用户 ID（消息会显示在左侧）
  );
}
```

### 2. 确保 UI 配置正确

在 `Chat` widget 的配置中，确保 `textStreamMessageBuilder` 已配置：

```dart
Chat(
  chatController: _chatController,
  currentUserId: _currentUser.id,
  onMessageSend: _handleMessageSend,
  // ... 其他配置
  textStreamMessageBuilder: (context, message, index, {required bool isSentByMe, MessageGroupStatus? groupStatus}) {
    // 获取流式状态
    final streamState = Provider.of<SimpleStreamManager>(context).getState(message.streamId);
    
    // 返回流式消息组件
    return FlyerChatTextStreamMessage(
      message: message,
      index: index,
      streamState: streamState,
      chunkAnimationDuration: const Duration(milliseconds: 300),
      // ... 其他样式配置
    );
  },
  // ... 其他配置
)
```

### 3. 确保 SimpleStreamManager 已提供

使用 `Provider` 或 `ChangeNotifierProvider` 提供 `SimpleStreamManager`：

```dart
ChangeNotifierProvider(
  create: (_) => SimpleStreamManager(
    chatController: _chatController,
    chunkAnimationDuration: const Duration(milliseconds: 300),
  ),
  child: Chat(...),
)
```

## 🎯 完整示例

以下是一个完整的 `local.dart` 文件片段示例：

```dart
import 'package:flyer_chat/inference/qwen_chat_helper.dart';
import 'package:provider/provider.dart';

class LocalState extends State<Local> {
  late final ChatController _chatController;
  late final SimpleStreamManager _streamManager;
  final _uuid = const Uuid();
  
  final _currentUser = const User(
    id: 'me',
    name: 'Jane Doe',
  );
  
  final _recipient = const User(
    id: 'ai',
    name: 'AI Assistant',
  );

  @override
  void initState() {
    super.initState();
    _chatController = HiveChatController();
    _streamManager = SimpleStreamManager(
      chatController: _chatController,
    );
    
    // 确保模型已加载
    _loadModelIfNeeded();
  }

  Future<void> _loadModelIfNeeded() async {
    // 检查并加载模型
    final modelExists = await LlamaInference.checkModelExists();
    if (modelExists) {
      await LlamaInference.loadModel();
    }
  }

  void _handleMessageSend(String text) async {
    // 1. 插入用户消息（右侧）
    await _chatController.insertMessage(
      TextMessage(
        id: _uuid.v4(),
        authorId: _currentUser.id,
        createdAt: DateTime.now().toUtc(),
        text: text,
      ),
    );

    // 2. 生成 AI 回复（左侧，流式输出）
    await QwenChatHelper.generateAndStreamResponse(
      chatController: _chatController,
      streamManager: _streamManager,
      currentUserId: _currentUser.id,
      aiUserId: _recipient.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _streamManager,
      child: Chat(
        chatController: _chatController,
        currentUserId: _currentUser.id,
        onMessageSend: _handleMessageSend,
        resolveUser: (id) => Future.value(
          id == _currentUser.id ? _currentUser : _recipient,
        ),
        textStreamMessageBuilder: (context, message, index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) {
          final streamState = context
              .watch<SimpleStreamManager>()
              .getState(message.streamId);
          return FlyerChatTextStreamMessage(
            message: message,
            index: index,
            streamState: streamState,
            chunkAnimationDuration: const Duration(milliseconds: 300),
          );
        },
      ),
    );
  }
}
```

## ✨ 功能特性

- ✅ **用户消息在右侧**：通过 `authorId == currentUserId` 判断
- ✅ **AI 消息在左侧**：通过 `authorId == aiUserId` 判断
- ✅ **Loading 状态**：在生成回复前显示 loading 指示器
- ✅ **流式输出**：使用 `SimpleStreamManager` 实现逐字符流式显示
- ✅ **自动转换**：流式输出完成后自动转换为普通 `TextMessage` 并保存

## 🚨 注意事项

1. **模型加载**：确保在使用前调用 `LlamaInference.loadModel()`
2. **错误处理**：如果生成失败，会显示错误消息
3. **异步执行**：生成过程在后台执行，不会阻塞 UI
4. **资源管理**：应用退出时调用 `LlamaInference.unloadModel()` 释放资源

