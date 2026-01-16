import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';

/// 简单的流式消息管理器
/// 用于模拟文本流式显示效果
class SimpleStreamManager extends ChangeNotifier {
  // 保留 _chatController 以保持 API 兼容性，虽然现在不再使用它
  // ignore: unused_field
  final ChatController _chatController;
  final Duration _chunkAnimationDuration;

  // State storage for stream messages
  final Map<String, StreamState> _streamStates = {};
  // Store the original TextStreamMessage
  final Map<String, TextStreamMessage> _originalMessages = {};
  // Store accumulated text
  final Map<String, String> _accumulatedTexts = {};
  // Track which streams should be stopped
  final Set<String> _stoppedStreams = {};
  // Track full text for each stream (needed for resuming)
  final Map<String, String> _fullTexts = {};
  // Counter for periodic saves during streaming
  int _saveCounter = 0;
  // Track active streaming tasks to allow background continuation
  final Map<String, Future<void>> _activeStreamingTasks = {};

  SimpleStreamManager({
    required ChatController chatController,
    Duration? chunkAnimationDuration,
  }) : _chatController = chatController,
       _chunkAnimationDuration =
           chunkAnimationDuration ?? const Duration(milliseconds: 300);

  /// Gets the current state for a given stream ID.
  StreamState getState(String streamId) {
    return _streamStates[streamId] ?? const StreamStateLoading();
  }

  /// Starts streaming a text message
  /// 逐个字符流式输出，让效果更明显
  /// 只有在第一个字符出现前才显示 loading 状态
  /// 在流式输出过程中定期保存当前内容到 Hive
  /// 退出聊天界面后，流式输出会在后台继续运行
  Future<void> streamText(
    String streamId,
    TextStreamMessage originalMessage,
    String fullText,
  ) async {
    _originalMessages[streamId] = originalMessage;
    _fullTexts[streamId] = fullText;
    // 不立即设置 loading 状态，而是直接开始流式输出
    // 只有在第一个字符出现前才显示 loading
    _accumulatedTexts[streamId] = '';

    // 启动后台流式输出任务
    final task = _streamTextInBackground(streamId, originalMessage, fullText);
    _activeStreamingTasks[streamId] = task;

    // 等待任务完成（但不阻塞，允许后台继续）
    task
        .then((_) {
          _activeStreamingTasks.remove(streamId);
        })
        .catchError((e) {
          debugPrint(
            'SimpleStreamManager: Stream task error for $streamId: $e',
          );
          _activeStreamingTasks.remove(streamId);
        });

    // 不等待任务完成，立即返回，让流式输出在后台继续
    // 这样即使退出聊天界面，流式输出也会继续
  }

  /// 在后台执行流式输出，即使 widget 被 dispose 也会继续
  Future<void> _streamTextInBackground(
    String streamId,
    TextStreamMessage originalMessage,
    String fullText,
  ) async {
    // 逐个字符流式输出，让效果更明显
    // 对于中文字符和表情符号，需要特殊处理
    final runes = fullText.runes.toList();
    const chunkSize = 1; // 每次输出1个字符，让流式效果更明显

    // 在第一个字符出现前，显示 loading 状态
    bool firstChunk = true;

    for (int i = 0; i < runes.length; i += chunkSize) {
      // 检查流是否应该停止
      if (_stoppedStreams.contains(streamId)) {
        // 立即完成当前流，保留已输出的内容
        final currentText = _accumulatedTexts[streamId] ?? '';
        if (currentText.isNotEmpty) {
          // 保存当前进度并完成流式输出（会移除流式标记）
          await _saveStreamingProgress(
            streamId,
            originalMessage,
            currentText,
            fullText,
          );
          // 完成流式输出，将其转换为 TextMessage
          await completeStream(streamId);
        } else {
          _cleanupStream(streamId);
        }
        _stoppedStreams.remove(streamId);
        return;
      }

      // 获取当前块
      final chunkRunes = runes.skip(i).take(chunkSize);
      final chunk = String.fromCharCodes(chunkRunes);

      // 如果是第一个字符，在显示前先设置 loading 状态
      if (firstChunk) {
        try {
          _streamStates[streamId] = const StreamStateLoading();
          notifyListeners();
          // 短暂延迟，让 loading 状态可见
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          // 如果在后台运行，忽略 UI 更新错误
          debugPrint(
            'SimpleStreamManager: Failed to update UI state (likely in background): $e',
          );
        }
        firstChunk = false;
      }

      _accumulatedTexts[streamId] = (_accumulatedTexts[streamId] ?? '') + chunk;

      // 更新 UI 状态（如果 listeners 可用）
      try {
        _streamStates[streamId] = StreamStateStreaming(
          _accumulatedTexts[streamId]!,
        );
        notifyListeners();
      } catch (e) {
        // 如果在后台运行且 listeners 已失效，忽略错误
        // 但流式输出仍然继续，并保存到 Hive
      }

      // 定期保存流式进度到 Hive（每 50 个字符保存一次）
      // 这是关键：即使 UI 不可用，也要保存进度
      _saveCounter++;
      if (_saveCounter % 50 == 0) {
        await _saveStreamingProgress(
          streamId,
          originalMessage,
          _accumulatedTexts[streamId]!,
          fullText,
        );
      }

      // 根据字符类型调整延迟时间（加快速度）
      // 中文字符、表情符号、换行符等稍微延迟长一点
      // 按需求：极限加速（每 1ms 输出一个"字符"）
      // 说明：Dart/Flutter 的 timer 精度在不同设备上可能做不到严格 1ms，
      // 但这里会尽可能快地推进流式状态。
      await Future.delayed(const Duration(milliseconds: 1));
    }

    // Complete the stream
    await completeStream(streamId);
  }

  /// Save streaming progress to Hive
  /// 将流式输出过程中的当前文本保存到 Hive，使用 metadata 标记为流式消息
  Future<void> _saveStreamingProgress(
    String streamId,
    Message originalMessage,
    String currentText,
    String fullText,
  ) async {
    try {
      // 获取当前消息（可能是 TextStreamMessage 或已经转换的 TextMessage）
      final currentMessages = _chatController.messages;
      final existingMessage = currentMessages.firstWhere(
        (m) => m.id == originalMessage.id,
        orElse: () => originalMessage,
      );

      // 创建一个临时的 TextMessage，包含当前累积的文本
      // 在 metadata 中标记这是流式消息，并保存完整文本和 streamId
      final existingMetadata = existingMessage.metadata ?? <String, dynamic>{};
      final tempMessage = TextMessage(
        id: existingMessage.id,
        authorId: existingMessage.authorId,
        replyToMessageId: existingMessage.replyToMessageId,
        createdAt: existingMessage.createdAt,
        deletedAt: existingMessage.deletedAt,
        failedAt: existingMessage.failedAt,
        sentAt: existingMessage.sentAt,
        deliveredAt: existingMessage.deliveredAt,
        seenAt: existingMessage.seenAt,
        updatedAt: existingMessage.updatedAt,
        editedAt: existingMessage is TextMessage
            ? existingMessage.editedAt
            : null,
        reactions: existingMessage.reactions,
        pinned: existingMessage.pinned,
        metadata: {
          ...existingMetadata,
          '_streaming': true,
          '_streamId': streamId,
          '_fullText': fullText,
          '_currentText': currentText,
        },
        status: existingMessage.status,
        text: currentText, // 保存当前累积的文本
      );

      // 更新到 ChatController（会保存到 Hive）
      await _chatController.updateMessage(existingMessage, tempMessage);
    } catch (e) {
      // 忽略错误，不影响流式输出继续
      // 错误可能由于消息已被删除或类型不匹配导致
    }
  }

  /// Finalizes the stream with the complete text
  /// 将 TextStreamMessage 转换为 TextMessage 以持久化到 Hive
  Future<void> completeStream(String streamId) async {
    final finalText = _accumulatedTexts[streamId];

    if (finalText == null) {
      debugPrint(
        'SimpleStreamManager: Cannot complete stream, missing accumulated text for $streamId',
      );
      _cleanupStream(streamId);
      return;
    }

    // Allow time for the last chunk animation
    await Future.delayed(_chunkAnimationDuration);

    final originalMessage = _originalMessages[streamId];
    if (originalMessage == null) {
      debugPrint(
        'SimpleStreamManager: State for $streamId was cleaned up during delay.',
      );
      return;
    }

    // 将状态设置为 StreamStateCompleted，以便 UI 可以显示最终文本
    // 注意：这需要在转换为 TextMessage 之前设置，这样 UI 可以看到最终状态
    try {
      _streamStates[streamId] = StreamStateCompleted(finalText);
      notifyListeners();
    } catch (e) {
      // 如果在后台运行，忽略错误
      debugPrint(
        'SimpleStreamManager: Failed to update stream state (likely in background): $e',
      );
    }

    // 将 TextStreamMessage 转换为 TextMessage 以持久化到 Hive
    // 移除流式标记，保存为最终消息
    try {
      // 获取当前消息（可能是 TextStreamMessage 或已经转换的 TextMessage）
      final currentMessages = _chatController.messages;
      final existingMessage = currentMessages.firstWhere(
        (m) => m.id == originalMessage.id,
        orElse: () => originalMessage,
      );

      // 如果 metadata 中有流式标记，移除它
      final existingMetadata = existingMessage.metadata ?? <String, dynamic>{};
      final cleanMetadata = Map<String, dynamic>.from(existingMetadata);
      cleanMetadata.remove('_streaming');
      cleanMetadata.remove('_streamId');
      cleanMetadata.remove('_fullText');
      cleanMetadata.remove('_currentText');

      final finalTextMessage = TextMessage(
        id: existingMessage.id,
        authorId: existingMessage.authorId,
        replyToMessageId: existingMessage.replyToMessageId,
        createdAt: existingMessage.createdAt,
        deletedAt: existingMessage.deletedAt,
        failedAt: existingMessage.failedAt,
        sentAt: existingMessage.sentAt,
        deliveredAt: existingMessage.deliveredAt,
        seenAt: existingMessage.seenAt,
        updatedAt: existingMessage.updatedAt,
        editedAt: existingMessage is TextMessage
            ? existingMessage.editedAt
            : null,
        reactions: existingMessage.reactions,
        pinned: existingMessage.pinned,
        metadata: cleanMetadata.isEmpty ? null : cleanMetadata,
        status: existingMessage.status,
        text: finalText,
      );

      // 使用 existingMessage 而不是 originalMessage 来更新
      await _chatController.updateMessage(existingMessage, finalTextMessage);
      debugPrint(
        'SimpleStreamManager: Stream $streamId completed and saved to Hive',
      );
    } catch (e) {
      debugPrint(
        'SimpleStreamManager: Failed to update message $streamId to TextMessage: $e',
      );
      // 即使更新失败，也继续清理流状态
    }
  }

  /// Updates the streaming text directly (for real-time updates like voice recognition)
  /// Appends new text to the existing accumulated text
  /// 对于语音识别，在长按期间，每次收到新的识别结果时，应该追加到现有文本后面
  void updateStreamText(String streamId, String newText) {
    if (!_streamStates.containsKey(streamId)) {
      return; // Stream doesn't exist
    }

    final currentText = _accumulatedTexts[streamId] ?? '';

    // 在长按语音输入期间，Vosk 会返回多个识别结果
    // Vosk 的 partial 结果是完整的当前识别结果，不是增量
    // 如果新文本包含当前文本，说明是扩展（比如 "你好" -> "你好世界"），使用新文本
    // 如果新文本不包含当前文本，说明是新的识别片段（比如 "你好" -> "世界"），应该追加
    String updatedText;
    if (currentText.isEmpty) {
      // 当前文本为空，直接使用新文本
      updatedText = newText;
    } else if (newText.startsWith(currentText) &&
        newText.length > currentText.length) {
      // 新文本是当前文本的扩展，使用新文本（完整结果）
      // 例如：当前文本是"你好"，新文本是"你好世界"
      updatedText = newText;
    } else if (currentText.contains(newText) &&
        newText.length < currentText.length) {
      // 新文本是当前文本的一部分，说明可能是识别结果回退，保持当前文本
      // 例如：当前文本是"你好世界"，新文本是"你好"
      updatedText = currentText;
    } else {
      // 如果新文本不包含当前文本，说明是新的识别片段，追加到现有文本后面
      // 例如：当前文本是"你好"，新文本是"世界"
      if (newText.isNotEmpty) {
        // 追加新文本，用空格分隔（如果当前文本不以空格结尾且新文本不以空格开头）
        final separator =
            (currentText.endsWith(' ') ||
                currentText.endsWith('，') ||
                currentText.endsWith('。') ||
                currentText.endsWith('！') ||
                currentText.endsWith('？') ||
                newText.startsWith(' ') ||
                newText.startsWith('，') ||
                newText.startsWith('。') ||
                newText.startsWith('！') ||
                newText.startsWith('？'))
            ? ''
            : ' ';
        updatedText = currentText + separator + newText;
      } else {
        updatedText = currentText;
      }
    }

    _accumulatedTexts[streamId] = updatedText;
    _streamStates[streamId] = StreamStateStreaming(updatedText);
    notifyListeners();
  }

  /// Initializes a stream message for real-time updates (like voice recognition)
  void initializeStream(String streamId, TextStreamMessage message) {
    _originalMessages[streamId] = message;
    _streamStates[streamId] = const StreamStateLoading();
    _accumulatedTexts[streamId] = '';
    notifyListeners();
  }

  /// Cancels and removes a stream message
  void cancelStream(String streamId) {
    _cleanupStream(streamId);
  }

  /// Stops all active streams immediately
  /// Completes each stream with its current accumulated text instead of cancelling
  Future<void> stopAllStreams() async {
    final streamIds = _streamStates.keys.toList();
    // 标记所有流为停止状态（不立即移除，让 streamText 循环检查到并自己移除）
    for (final streamId in streamIds) {
      _stoppedStreams.add(streamId);
      // 立即完成流式消息，保留已输出的内容
      final currentText = _accumulatedTexts[streamId];
      if (currentText != null && currentText.isNotEmpty) {
        _streamStates[streamId] = StreamStateCompleted(currentText);
      } else {
        // 如果没有内容，直接清理
        _cleanupStream(streamId);
        _stoppedStreams.remove(streamId);
      }
    }
    notifyListeners();
  }

  /// Removes state associated with a stream ID
  void _cleanupStream(String streamId) {
    _streamStates.remove(streamId);
    _originalMessages.remove(streamId);
    _accumulatedTexts.remove(streamId);
    _fullTexts.remove(streamId);
    _stoppedStreams.remove(streamId);
    _activeStreamingTasks.remove(streamId);
    try {
      notifyListeners();
    } catch (e) {
      // 如果在后台运行，忽略错误
    }
  }

  /// Restore incomplete streaming messages from Hive
  /// 从 Hive 中恢复未完成的流式消息
  /// 当重新进入聊天界面时调用此方法
  Future<void> restoreIncompleteStreams() async {
    try {
      final messages = _chatController.messages;

      for (final message in messages) {
        // 只处理 TextMessage，因为 TextStreamMessage 应该通过正常的流式逻辑处理
        if (message is TextMessage) {
          final metadata = message.metadata;
          // 检查是否有流式标记（说明这是未完成的流式消息）
          if (metadata != null &&
              metadata['_streaming'] == true &&
              metadata['_streamId'] != null &&
              metadata['_fullText'] != null) {
            final streamId = metadata['_streamId'] as String;
            final fullText = metadata['_fullText'] as String;
            final currentText =
                metadata['_currentText'] as String? ?? message.text;

            debugPrint(
              'SimpleStreamManager: Found incomplete stream $streamId, currentText length: ${currentText.length}, fullText length: ${fullText.length}',
            );

            // 恢复流式状态
            _accumulatedTexts[streamId] = currentText;
            _fullTexts[streamId] = fullText;

            // 如果当前文本等于完整文本，说明流式已完成，需要完成流式输出并移除流式标记
            if (currentText == fullText ||
                currentText.length >= fullText.length) {
              debugPrint(
                'SimpleStreamManager: Stream $streamId is already complete, finalizing...',
              );
              // 先设置完成状态，确保 UI 可以显示最终文本
              _streamStates[streamId] = StreamStateCompleted(currentText);
              try {
                notifyListeners();
              } catch (e) {
                // 忽略错误
              }
              // 完成流式输出（会移除流式标记并转换为最终的 TextMessage）
              await completeStream(streamId);
            } else {
              // 否则继续流式输出剩余部分（在后台运行）
              _originalMessages[streamId] = TextStreamMessage(
                id: message.id,
                authorId: message.authorId,
                replyToMessageId: message.replyToMessageId,
                createdAt: message.createdAt,
                deletedAt: message.deletedAt,
                failedAt: message.failedAt,
                sentAt: message.sentAt,
                deliveredAt: message.deliveredAt,
                seenAt: message.seenAt,
                updatedAt: message.updatedAt,
                reactions: message.reactions,
                pinned: message.pinned,
                metadata: metadata,
                status: message.status,
                streamId: streamId,
              );

              // 在后台继续流式输出剩余部分
              final task = _continueStreamFromPosition(
                streamId,
                currentText,
                fullText,
              );
              _activeStreamingTasks[streamId] = task;
              task
                  .then((_) {
                    _activeStreamingTasks.remove(streamId);
                  })
                  .catchError((e) {
                    debugPrint(
                      'SimpleStreamManager: Continue stream task error for $streamId: $e',
                    );
                    _activeStreamingTasks.remove(streamId);
                  });
            }
          }
        }
      }
    } catch (e) {
      debugPrint(
        'SimpleStreamManager: Failed to restore incomplete streams: $e',
      );
    }
  }

  /// Continue streaming from a specific position
  /// 从指定位置继续流式输出（可以在后台运行）
  Future<void> _continueStreamFromPosition(
    String streamId,
    String currentText,
    String fullText,
  ) async {
    // 找到当前文本在完整文本中的位置
    final currentLength = currentText.length;
    final remainingText = fullText.substring(currentLength);

    if (remainingText.isEmpty) {
      // 如果剩余文本为空，直接完成
      await completeStream(streamId);
      return;
    }

    // 从剩余文本继续流式输出
    final runes = remainingText.runes.toList();
    const chunkSize = 1;

    for (int i = 0; i < runes.length; i += chunkSize) {
      if (_stoppedStreams.contains(streamId)) {
        final current = _accumulatedTexts[streamId] ?? currentText;
        if (current.isNotEmpty) {
          // 保存当前进度并完成流式输出（会移除流式标记）
          await _saveStreamingProgress(
            streamId,
            _originalMessages[streamId]!,
            current,
            fullText,
          );
          await completeStream(streamId);
        } else {
          _cleanupStream(streamId);
        }
        _stoppedStreams.remove(streamId);
        return;
      }

      final chunkRunes = runes.skip(i).take(chunkSize);
      final chunk = String.fromCharCodes(chunkRunes);

      _accumulatedTexts[streamId] =
          (_accumulatedTexts[streamId] ?? currentText) + chunk;

      // 更新 UI 状态（如果 listeners 可用）
      try {
        _streamStates[streamId] = StreamStateStreaming(
          _accumulatedTexts[streamId]!,
        );
        notifyListeners();
      } catch (e) {
        // 如果在后台运行且 listeners 已失效，忽略错误
        // 但流式输出仍然继续，并保存到 Hive
      }

      // 定期保存进度到 Hive（关键：即使 UI 不可用也要保存）
      _saveCounter++;
      if (_saveCounter % 50 == 0) {
        await _saveStreamingProgress(
          streamId,
          _originalMessages[streamId]!,
          _accumulatedTexts[streamId]!,
          fullText,
        );
      }

      await Future.delayed(const Duration(milliseconds: 1));
    }

    // 完成流式输出
    await completeStream(streamId);
  }
}
