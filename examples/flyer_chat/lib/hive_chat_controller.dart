import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:hive_ce/hive.dart';

class HiveChatController
    with UploadProgressMixin, ScrollToMessageMixin
    implements ChatController {
  final _box = Hive.box('chat');
  final _operationsController = StreamController<ChatOperation>.broadcast();

  // Cache for performance - invalidated when data changes
  List<Message>? _cachedMessages;

  @override
  Future<void> insertMessage(
    Message message, {
    int? index,
    bool animated = true,
  }) async {
    if (_box.containsKey(message.id)) return;

    try {
      // Calculate insert index BEFORE saving to Hive
      // This ensures we get the correct position in the current list state
      final currentMessages = List.from(messages);
      int insertIndex;

      if (index != null) {
        // Use provided index, but clamp to valid range
        insertIndex = index.clamp(0, currentMessages.length);
      } else {
        // For append, find the correct sorted position based on createdAt
        final messageTime = message.createdAt?.millisecondsSinceEpoch ?? 0;
        insertIndex = currentMessages.length; // Default to end

        // Find the correct position to maintain chronological order
        for (int i = 0; i < currentMessages.length; i++) {
          final msgTime =
              currentMessages[i].createdAt?.millisecondsSinceEpoch ?? 0;
          if (messageTime < msgTime) {
            insertIndex = i;
            break;
          }
        }
      }

      // Now save to Hive
      await _box.put(message.id, message.toJson());
      _invalidateCache();

      // Emit the insert operation with the calculated index
      _operationsController.add(
        ChatOperation.insert(message, insertIndex, animated: animated),
      );
    } catch (e) {
      debugPrint('HiveChatController: Failed to insert message: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeMessage(Message message, {bool animated = true}) async {
    final sortedMessages = List.from(messages);
    final index = sortedMessages.indexWhere((m) => m.id == message.id);

    if (index != -1) {
      final messageToRemove = sortedMessages[index];
      await _box.delete(messageToRemove.id);
      _invalidateCache();
      _operationsController.add(
        ChatOperation.remove(messageToRemove, index, animated: animated),
      );
    }
  }

  @override
  Future<void> updateMessage(Message oldMessage, Message newMessage) async {
    final sortedMessages = List.from(messages);
    final index = sortedMessages.indexWhere((m) => m.id == oldMessage.id);

    if (index != -1) {
      final actualOldMessage = sortedMessages[index];

      if (actualOldMessage == newMessage) {
        return;
      }

      await _box.put(actualOldMessage.id, newMessage.toJson());
      _invalidateCache();
      _operationsController.add(
        ChatOperation.update(actualOldMessage, newMessage, index),
      );
    }
  }

  @override
  Future<void> setMessages(
    List<Message> messages, {
    bool animated = true,
  }) async {
    await _box.clear();
    if (messages.isEmpty) {
      _invalidateCache();
      _operationsController.add(ChatOperation.set([], animated: false));
      return;
    } else {
      await _box.putAll(
        messages
            .map((message) => {message.id: message.toJson()})
            .toList()
            .reduce((acc, map) => {...acc, ...map}),
      );
      _invalidateCache();
      _operationsController.add(
        ChatOperation.set(messages, animated: animated),
      );
    }
  }

  @override
  Future<void> insertAllMessages(
    List<Message> messages, {
    int? index,
    bool animated = true,
  }) async {
    if (messages.isEmpty) return;

    // Index is ignored because Hive does not maintain order
    final originalLength = _box.length;
    await _box.putAll(
      messages
          .map((message) => {message.id: message.toJson()})
          .toList()
          .reduce((acc, map) => {...acc, ...map}),
    );
    _invalidateCache();
    _operationsController.add(
      ChatOperation.insertAll(messages, originalLength, animated: animated),
    );
  }

  /// Invalidates the cached messages list
  void _invalidateCache() {
    _cachedMessages = null;
  }

  @override
  List<Message> get messages {
    if (_cachedMessages != null) {
      debugPrint(
        '💾 HiveChatController.messages: 使用缓存，${_cachedMessages!.length} 条消息',
      );
      return _cachedMessages!;
    }

    final loadStartTime = DateTime.now();
    debugPrint('📥 HiveChatController.messages: 开始从 Hive 加载消息...');

    try {
      final boxValuesStartTime = DateTime.now();
      final boxValues = _box.values.toList();
      final boxValuesDuration = DateTime.now().difference(boxValuesStartTime);
      debugPrint(
        '📦 从 Hive box 读取数据完成: ${boxValues.length} 条，耗时: ${boxValuesDuration.inMilliseconds}ms',
      );

      final deserializeStartTime = DateTime.now();
      _cachedMessages = boxValues
          .map((json) {
            try {
              return Message.fromJson(_convertMap(json));
            } catch (e) {
              debugPrint('❌ HiveChatController: 反序列化消息失败: $e');
              debugPrint('Message JSON: $json');
              return null;
            }
          })
          .whereType<Message>()
          .toList();
      final deserializeDuration = DateTime.now().difference(
        deserializeStartTime,
      );
      debugPrint(
        '🔄 消息反序列化完成: ${_cachedMessages!.length} 条，耗时: ${deserializeDuration.inMilliseconds}ms',
      );

      final sortStartTime = DateTime.now();
      _cachedMessages!.sort(
        (a, b) => (a.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          b.createdAt?.millisecondsSinceEpoch ?? 0,
        ),
      );
      final sortDuration = DateTime.now().difference(sortStartTime);
      debugPrint('🔢 消息排序完成，耗时: ${sortDuration.inMilliseconds}ms');

      final totalDuration = DateTime.now().difference(loadStartTime);
      debugPrint(
        '✅ HiveChatController: 成功加载 ${_cachedMessages!.length} 条消息，总耗时: ${totalDuration.inMilliseconds}ms',
      );
    } catch (e) {
      final totalDuration = DateTime.now().difference(loadStartTime);
      debugPrint(
        '❌ HiveChatController: 从 Hive 加载消息失败，耗时: ${totalDuration.inMilliseconds}ms, 错误: $e',
      );
      _cachedMessages = [];
    }

    return _cachedMessages!;
  }

  @override
  Stream<ChatOperation> get operationsStream => _operationsController.stream;

  /// 加载更旧的消息（用于分页加载）
  ///
  /// [beforeMessageId] 当前最旧的消息 ID，将加载比这条消息更旧的消息
  /// [limit] 最多加载的消息数量，默认 20 条
  ///
  /// 返回按时间排序的消息列表（从旧到新）
  Future<List<Message>> loadOlderMessages({
    required String beforeMessageId,
    int limit = 20,
  }) async {
    try {
      // 获取所有消息的键（ID）
      final allKeys = _box.keys.toList();

      // 找到 beforeMessageId 的索引
      final beforeIndex = allKeys.indexOf(beforeMessageId);

      // 如果没有找到或已经是第一条，返回空列表
      if (beforeIndex == -1 || beforeIndex == 0) {
        debugPrint('📭 HiveChatController: 没有更旧的消息了');
        return [];
      }

      // 计算要加载的消息范围
      final startIndex = (beforeIndex - limit).clamp(0, beforeIndex);
      final keysToLoad = allKeys.sublist(startIndex, beforeIndex);

      if (keysToLoad.isEmpty) {
        debugPrint('📭 HiveChatController: 没有更旧的消息了');
        return [];
      }

      debugPrint('📥 HiveChatController: 准备加载 ${keysToLoad.length} 条更旧的消息');

      // 从 Hive 加载消息
      final loadedMessages = keysToLoad
          .map((key) {
            try {
              final json = _box.get(key);
              if (json == null) return null;
              return Message.fromJson(_convertMap(json));
            } catch (e) {
              debugPrint('❌ HiveChatController: 反序列化消息失败: $e');
              return null;
            }
          })
          .whereType<Message>()
          .toList();

      // 按时间排序（从旧到新）
      loadedMessages.sort(
        (a, b) => (a.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          b.createdAt?.millisecondsSinceEpoch ?? 0,
        ),
      );

      debugPrint('✅ HiveChatController: 成功加载 ${loadedMessages.length} 条更旧的消息');
      return loadedMessages;
    } catch (e) {
      debugPrint('❌ HiveChatController: 加载更旧的消息失败: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _operationsController.close();
    disposeUploadProgress();
    disposeScrollMethods();
  }
}

/// Recursively converts a map with dynamic keys and values to a map with String keys.
/// It's optimized to avoid creating new maps if no conversion is needed.
Map<String, dynamic> _convertMap(dynamic map) {
  if (map is Map<String, dynamic>) {
    Map<String, dynamic>? newMap;
    for (final entry in map.entries) {
      final value = entry.value;
      if (value is Map) {
        final convertedValue = _convertMap(value);
        if (convertedValue != value) {
          newMap ??= Map<String, dynamic>.of(map);
          newMap[entry.key] = convertedValue;
        }
      }
    }
    return newMap ?? map;
  }

  final convertedMap = Map<String, dynamic>.from(map as Map);

  for (final key in convertedMap.keys) {
    final value = convertedMap[key];
    if (value is Map) {
      convertedMap[key] = _convertMap(value);
    }
  }

  return convertedMap;
}
