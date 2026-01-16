import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:uuid/uuid.dart';
import 'llama_inference.dart';
import '../simple_stream_manager.dart';

/// 简化的聊天消息结构（用于兼容简单场景）
class SimpleChatMessage {
  final String text;
  final String sender; // "user" 或 "assistant"

  const SimpleChatMessage({required this.text, required this.sender});
}

/// Qwen2.5 聊天助手工具类
/// 用于将聊天历史转换为 Qwen2.5 对话格式并调用本地推理
class QwenChatHelper {
  /// 系统提示词
  static const String _systemPrompt = 'You are a helpful assistant.';

  /// 将聊天历史转换为 Qwen2.5 对话格式的 prompt
  ///
  /// [messages] 聊天消息列表
  /// [currentUserId] 当前用户 ID，用于判断消息发送者（如果 authorId == currentUserId，则为用户消息，否则为 AI 消息）
  ///
  /// 返回符合 Qwen2.5 格式的 prompt 字符串
  static String _buildQwenPrompt(List<Message> messages, String currentUserId) {
    final buffer = StringBuffer();

    // 添加系统提示
    buffer.write('<|im_start|>system\n');
    buffer.write('$_systemPrompt<|im_end|>\n');

    // 遍历消息，构建对话
    for (final message in messages) {
      // 只处理文本消息
      if (message case TextMessage(text: final text)) {
        // 判断角色：如果 authorId 等于 currentUserId，则为用户消息，否则为 AI 消息
        final isUser = message.authorId == currentUserId;
        final role = isUser ? 'user' : 'assistant';

        // 添加消息
        buffer.write('<|im_start|>$role\n');
        buffer.write('$text<|im_end|>\n');
      }
    }

    // 最后追加 assistant 提示，表示期望 AI 回复
    buffer.write('<|im_start|>assistant\n');

    return buffer.toString();
  }

  /// 从聊天历史生成 AI 回复
  ///
  /// [messages] 聊天消息列表（包含历史对话）
  /// [currentUserId] 当前用户 ID，用于判断消息发送者
  ///
  /// 返回生成的文本回复，如果生成失败则返回空字符串
  static Future<String> generateResponse(
    List<Message> messages,
    String currentUserId,
  ) async {
    try {
      // 确保模型已加载（如果未加载，尝试加载）
      final modelLoaded = await LlamaInference.loadModel();
      if (!modelLoaded) {
        debugPrint('QwenChatHelper: 模型加载失败，无法生成回复');
        return '';
      }

      // 构建 Qwen2.5 格式的 prompt
      final prompt = _buildQwenPrompt(messages, currentUserId);

      // 调用本地推理生成回复
      final response = await LlamaInference.generate(prompt);

      // 过滤生成的文本，移除结束标记和系统提示词
      return _filterGeneratedText(response);
    } catch (e) {
      debugPrint('QwenChatHelper.generateResponse 错误: $e');
      return '';
    }
  }

  /// 从简化的 SimpleChatMessage 列表生成 AI 回复（兼容方法）
  ///
  /// [chatMessages] 简化的聊天消息列表
  ///
  /// 返回生成的文本回复，如果生成失败则返回空字符串
  static Future<String> generateResponseFromSimpleMessages(
    List<SimpleChatMessage> chatMessages,
  ) async {
    try {
      final buffer = StringBuffer();

      // 添加系统提示
      buffer.write('<|im_start|>system\n');
      buffer.write('$_systemPrompt<|im_end|>\n');

      // 遍历消息，构建对话
      for (final msg in chatMessages) {
        buffer.write('<|im_start|>${msg.sender}\n');
        buffer.write('${msg.text}<|im_end|>\n');
      }

      // 最后追加 assistant 提示
      buffer.write('<|im_start|>assistant\n');

      final prompt = buffer.toString();

      // 调用本地推理生成回复
      final response = await LlamaInference.generate(prompt);

      // 过滤生成的文本，移除结束标记和系统提示词
      return _filterGeneratedText(response);
    } catch (e) {
      print('QwenChatHelper.generateResponseFromSimpleMessages 错误: $e');
      return '';
    }
  }

  /// 构建 Qwen2.5 格式的 prompt（仅构建，不生成）
  ///
  /// 用于调试或自定义使用场景
  static String buildPrompt(List<Message> messages, String currentUserId) {
    return _buildQwenPrompt(messages, currentUserId);
  }

  /// 构建 Qwen2.5 格式的 prompt（从简化消息）
  ///
  /// 用于调试或自定义使用场景
  static String buildPromptFromSimpleMessages(
    List<SimpleChatMessage> chatMessages,
  ) {
    final buffer = StringBuffer();

    buffer.write('<|im_start|>system\n');
    buffer.write('$_systemPrompt<|im_end|>\n');

    for (final msg in chatMessages) {
      buffer.write('<|im_start|>${msg.sender}\n');
      buffer.write('${msg.text}<|im_end|>\n');
    }

    buffer.write('<|im_start|>assistant\n');

    return buffer.toString();
  }

  /// 在用户发送消息后，自动生成 AI 回复并流式输出
  ///
  /// [chatController] 聊天控制器
  /// [streamManager] 流式消息管理器
  /// [currentUserId] 当前用户 ID（用户消息的 authorId）
  /// [aiUserId] AI 用户 ID（AI 消息的 authorId）
  /// [onMessageInserted] 可选回调，在消息插入后调用（用于滚动到底部）
  /// [onStreamingStateChanged] 可选回调，在流式状态改变时调用（用于更新 UI，如停止按钮）
  ///
  /// 此方法会：
  /// 1. 获取当前聊天历史
  /// 2. 创建 TextStreamMessage 并插入到列表最下方（显示在左侧）
  /// 3. 调用本地 LLM 生成完整回复
  /// 4. 使用 streamManager 流式输出回复内容（逐个字符显示）
  /// 5. 最终展示富文本效果
  ///
  /// 返回一个 StreamSubscription，可以用于取消流式生成
  static StreamSubscription<String>? generateAndStreamResponse({
    required ChatController chatController,
    required SimpleStreamManager streamManager,
    required String currentUserId,
    required String aiUserId,
    VoidCallback? onMessageInserted,
    ValueChanged<bool>? onStreamingStateChanged,
  }) {
    try {
      // 获取当前聊天历史
      final messages = chatController.messages;

      // 创建流式消息 ID
      const uuid = Uuid();
      final streamId = uuid.v4();

      // 创建 TextStreamMessage（AI 消息，显示在左侧）
      // 使用稍晚的时间戳，确保显示在用户消息之后（最新一条）
      final aiMessageTime = DateTime.now().toUtc().add(
        const Duration(milliseconds: 1),
      );
      final streamMessage = TextStreamMessage(
        id: streamId,
        authorId: aiUserId, // AI 用户 ID，确保显示在左侧
        createdAt: aiMessageTime, // 稍晚的时间戳，确保在用户消息之后
        streamId: streamId,
      );

      // 立即插入流式消息到列表最下方（显示 loading 状态）
      // 使用 Future.microtask 异步执行，避免阻塞
      Future.microtask(() async {
        await chatController.insertMessage(streamMessage);

        // 初始化流式状态（会显示 loading）
        streamManager.initializeStream(streamId, streamMessage);

        // 通知消息已插入，可以滚动到底部
        onMessageInserted?.call();

        // 通知开始流式输出
        onStreamingStateChanged?.call(true);
      });

      // 异步生成回复（不阻塞 UI）
      StreamSubscription<String>? subscription;
      subscription = _generateAndStreamInBackground(
        chatController: chatController,
        streamManager: streamManager,
        messages: messages,
        currentUserId: currentUserId,
        streamId: streamId,
        streamMessage: streamMessage,
        onDone: () {
          // 通知流式输出结束
          onStreamingStateChanged?.call(false);
        },
        onError: (error) {
          debugPrint('QwenChatHelper.generateAndStreamResponse 后台任务错误: $error');
          onStreamingStateChanged?.call(false);
        },
      );

      return subscription;
    } catch (e) {
      debugPrint('QwenChatHelper.generateAndStreamResponse 错误: $e');
      onStreamingStateChanged?.call(false);
      return null;
    }
  }

  /// 在后台生成回复并流式输出
  static StreamSubscription<String>? _generateAndStreamInBackground({
    required ChatController chatController,
    required SimpleStreamManager streamManager,
    required List<Message> messages,
    required String currentUserId,
    required String streamId,
    required TextStreamMessage streamMessage,
    VoidCallback? onDone,
    Function(Object)? onError,
  }) {
    StreamSubscription<String>? subscription;

    // 异步执行，避免阻塞
    Future.microtask(() async {
      try {
        // 确保模型已加载
        final modelLoaded = await LlamaInference.loadModel();
        if (!modelLoaded) {
          debugPrint('QwenChatHelper: 模型加载失败，无法生成回复');
          final errorMessage = TextMessage(
            id: streamMessage.id,
            authorId: streamMessage.authorId,
            createdAt: streamMessage.createdAt,
            text: '抱歉，模型加载失败。',
          );
          await chatController.updateMessage(streamMessage, errorMessage);
          streamManager.cancelStream(streamId);
          onError?.call('模型加载失败');
          return;
        }

        // 构建 Qwen2.5 格式的 prompt
        final prompt = _buildQwenPrompt(messages, currentUserId);

        // 使用流式生成，逐个字符接收并实时更新 UI
        final stream = LlamaInference.generateStream(prompt);
        String accumulatedText = '';
        bool shouldStop = false;

        subscription = stream.listen(
          (token) {
            if (token.isEmpty || shouldStop) return;

            // 累积文本
            accumulatedText += token;

            // 检查是否包含结束标记（完整或不完整），如果包含则停止并过滤
            // 使用辅助函数检查并处理结束标记
            final endMarkerResult = _checkAndRemoveEndMarker(accumulatedText);
            if (endMarkerResult != null) {
              shouldStop = true;
              accumulatedText = endMarkerResult;
              // 取消订阅以停止接收更多 token
              subscription?.cancel();
              // 完成流式输出
              Future.microtask(() async {
                if (accumulatedText.trim().isNotEmpty) {
                  await streamManager.completeStream(streamId);
                  onDone?.call();
                } else {
                  final errorMessage = TextMessage(
                    id: streamMessage.id,
                    authorId: streamMessage.authorId,
                    createdAt: streamMessage.createdAt,
                    text: '抱歉，生成回复时出现错误。',
                  );
                  await chatController.updateMessage(
                    streamMessage,
                    errorMessage,
                  );
                  streamManager.cancelStream(streamId);
                  onError?.call('生成的回复为空');
                }
              });
              return;
            }

            // 检查是否包含系统提示词（可能是模型回显了 prompt）
            // 如果检测到系统提示词，只保留之前的内容
            final systemPromptMarkers = [
              '<|im_start|>system',
              'You are a helpful assistant',
              'You are an ai assistant',
            ];
            for (final marker in systemPromptMarkers) {
              if (accumulatedText.toLowerCase().contains(
                marker.toLowerCase(),
              )) {
                final markerIndex = accumulatedText.toLowerCase().indexOf(
                  marker.toLowerCase(),
                );
                // 检查是否在文本末尾附近（可能是新生成的系统提示词）
                if (markerIndex > accumulatedText.length * 0.5) {
                  // 可能是回显，只保留之前的内容
                  accumulatedText = accumulatedText
                      .substring(0, markerIndex)
                      .trim();
                  shouldStop = true;
                  subscription?.cancel();
                  Future.microtask(() async {
                    if (accumulatedText.trim().isNotEmpty) {
                      await streamManager.completeStream(streamId);
                      onDone?.call();
                    } else {
                      final errorMessage = TextMessage(
                        id: streamMessage.id,
                        authorId: streamMessage.authorId,
                        createdAt: streamMessage.createdAt,
                        text: '抱歉，生成回复时出现错误。',
                      );
                      await chatController.updateMessage(
                        streamMessage,
                        errorMessage,
                      );
                      streamManager.cancelStream(streamId);
                      onError?.call('生成的回复为空');
                    }
                  });
                  return;
                }
              }
            }

            // 实时更新流式消息（使用过滤后的文本）
            streamManager.updateStreamText(streamId, accumulatedText);
          },
          onDone: () async {
            if (shouldStop) {
              // 已经在监听回调中处理了
              return;
            }

            // 最终过滤：移除结束标记和系统提示词
            String finalText = _filterGeneratedText(accumulatedText);

            // 如果最终文本为空，显示错误消息
            if (finalText.trim().isEmpty) {
              debugPrint('QwenChatHelper: 生成的回复为空');
              final errorMessage = TextMessage(
                id: streamMessage.id,
                authorId: streamMessage.authorId,
                createdAt: streamMessage.createdAt,
                text: '抱歉，生成回复时出现错误。',
              );
              await chatController.updateMessage(streamMessage, errorMessage);
              streamManager.cancelStream(streamId);
              onError?.call('生成的回复为空');
            } else {
              // 如果过滤后的文本与当前不同，更新一次
              if (finalText != accumulatedText) {
                streamManager.updateStreamText(streamId, finalText);
              }
              // 完成流式输出
              await streamManager.completeStream(streamId);
              onDone?.call();
            }
          },
          onError: (e) {
            debugPrint('QwenChatHelper._generateAndStreamInBackground 流错误: $e');
            // 更新为错误消息
            chatController
                .updateMessage(
                  streamMessage,
                  TextMessage(
                    id: streamMessage.id,
                    authorId: streamMessage.authorId,
                    createdAt: streamMessage.createdAt,
                    text: '抱歉，生成回复时出现错误: ${e.toString()}',
                  ),
                )
                .then((_) {
                  streamManager.cancelStream(streamId);
                  onError?.call(e);
                });
          },
          cancelOnError: false,
        );
      } catch (e) {
        debugPrint('QwenChatHelper._generateAndStreamInBackground 错误: $e');
        // 更新为错误消息
        try {
          final errorMessage = TextMessage(
            id: streamMessage.id,
            authorId: streamMessage.authorId,
            createdAt: streamMessage.createdAt,
            text: '抱歉，生成回复时出现错误: ${e.toString()}',
          );
          await chatController.updateMessage(streamMessage, errorMessage);
          streamManager.cancelStream(streamId);
          onError?.call(e);
        } catch (updateError) {
          debugPrint('QwenChatHelper: 更新错误消息失败: $updateError');
          onError?.call(updateError);
        }
      }
    });

    return subscription;
  }

  /// 检查并移除结束标记（如果存在）
  /// 返回过滤后的文本，如果未找到结束标记则返回 null
  static String? _checkAndRemoveEndMarker(String text) {
    if (text.isEmpty) return null;

    // 检查所有可能的结束标记变体（从最完整到最不完整）
    final endMarkers = [
      '<|im_end|>', // 完整标记
      '<|im_end|', // 缺少 >
      '<|im_end', // 缺少 |>
      '<|im_en', // 更不完整
      '<|im_e', // 更不完整
    ];

    for (final marker in endMarkers) {
      if (text.contains(marker)) {
        final endIndex = text.indexOf(marker);
        return text.substring(0, endIndex);
      }
    }

    return null;
  }

  /// 过滤生成的文本，移除结束标记和系统提示词
  static String _filterGeneratedText(String text) {
    if (text.isEmpty) return text;

    String filtered = text;

    // 1. 移除所有可能的结束标记变体
    final endMarkerResult = _checkAndRemoveEndMarker(filtered);
    if (endMarkerResult != null) {
      filtered = endMarkerResult;
    }

    // 2. 移除可能回显的系统提示词
    // 检查是否包含系统提示词标记
    final systemMarkers = [
      '<|im_start|>system',
      'You are a helpful assistant',
      'You are an ai assistant',
      'user will you give you commands',
      'you must follow',
    ];

    for (final marker in systemMarkers) {
      final lowerText = filtered.toLowerCase();
      final lowerMarker = marker.toLowerCase();
      if (lowerText.contains(lowerMarker)) {
        final markerIndex = lowerText.indexOf(lowerMarker);
        // 如果标记出现在文本的后半部分（可能是回显），移除它及其之后的内容
        if (markerIndex > filtered.length * 0.3) {
          filtered = filtered.substring(0, markerIndex).trim();
          break;
        }
      }
    }

    // 3. 移除末尾的空白字符
    filtered = filtered.trim();

    return filtered;
  }
}
