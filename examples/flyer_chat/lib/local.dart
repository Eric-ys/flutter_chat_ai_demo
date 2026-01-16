import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cross_cache/cross_cache.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:flyer_chat_file_message/flyer_chat_file_message.dart';
import 'package:flyer_chat_image_message/flyer_chat_image_message.dart';
import 'package:flyer_chat_system_message/flyer_chat_system_message.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'image_viewer.dart';
import 'rich_text_samples.dart';
import 'simple_stream_manager.dart';
import 'vosk_speech_recognition.dart';
import 'widgets/camera_page.dart';
import 'widgets/composer_action_bar.dart';
import 'widgets/native_chat_text_stream_message.dart';
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';
import 'widgets/selectable_text_message.dart';
import 'hive_chat_controller.dart';
import 'inference/qwen_chat_helper.dart';
import 'inference/llama_inference.dart';

class Local extends StatefulWidget {
  final Dio dio;

  const Local({super.key, required this.dio});

  @override
  LocalState createState() => LocalState();
}

class LocalState extends State<Local> {
  late final ChatController _chatController;
  final _uuid = const Uuid();
  final TextEditingController _composerController = TextEditingController();
  late VoskSpeechRecognition _voskRecognition;
  late CrossCache _crossCache;
  late SimpleStreamManager _streamManager;
  bool _speechAvailable = false;
  bool _isListeningToVoice = false;
  // 使用 ValueNotifier 管理按钮状态，避免触发整个 widget 重建
  final ValueNotifier<bool> _isListeningToVoiceNotifier = ValueNotifier<bool>(
    false,
  );
  bool _isMorePanelExpanded = false;
  bool _isVoiceMode = false; // 是否处于语音输入模式
  final _scrollController = ScrollController(); // 用于控制聊天列表滚动
  // 使用 GlobalKey 保持 ChatAnimatedList 的状态，避免重建时白屏
  final _chatListKey = GlobalKey();
  Timer? _scrollToBottomTimer; // 用于防抖滚动
  bool _scrollListenerAdded = false; // 标记是否已添加滚动监听器
  DateTime? _lastStreamScrollTime; // 上次流式滚动时间（用于节流）

  final _currentUser = const User(
    id: 'me',
    imageSource: 'assets/pattern.png', // 使用本地图片避免网络请求
    name: 'Jane Doe',
  );
  final _recipient = const User(
    id: 'recipient',
    imageSource: 'assets/pattern.png', // 使用本地图片避免网络请求
    name: 'John Doe',
  );
  final _systemUser = const User(id: 'system');

  bool _isTyping = false;
  String? _currentVoiceStreamId; // 当前语音识别的流式消息ID
  TextStreamMessage? _currentVoiceStreamMessage; // 当前语音识别的流式消息
  bool _isStreamingAI = false; // AI 是否正在流式输出
  StreamSubscription<String>? _aiStreamSubscription; // AI 流式输出的订阅

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 Local.initState 开始');
    final initStartTime = DateTime.now();

    // 初始化 HiveChatController 用于持久化聊天记录
    _chatController = HiveChatController();
    debugPrint('✅ HiveChatController 初始化完成');

    // 消息加载改为异步执行，不阻塞 initState，让页面先显示
    // 消息会在列表首次构建时自动加载（HiveChatController 的 messages getter 会触发加载）
    // 这样页面可以立即显示，消息在后台加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final loadStartTime = DateTime.now();
        final messages = _chatController.messages; // 触发消息加载
        final loadDuration = DateTime.now().difference(loadStartTime);
        debugPrint(
          '📦 消息加载完成: ${messages.length} 条消息，耗时: ${loadDuration.inMilliseconds}ms',
        );
      }
    });
    // 初始化流式消息管理器（必须在 initState 中初始化，因为 build 方法中会用到）
    _streamManager = SimpleStreamManager(chatController: _chatController);
    debugPrint('✅ SimpleStreamManager 初始化完成');

    // 创建配置好的 CrossCache（必须在 initState 中初始化，因为 build 方法中会用到）
    final cacheDio = Dio();
    // 配置 Dio 以允许自签名证书（仅用于开发环境）
    if (Platform.isAndroid || Platform.isIOS) {
      (cacheDio.httpClientAdapter as IOHttpClientAdapter).createHttpClient =
          () {
            final client = HttpClient();
            client.badCertificateCallback =
                (X509Certificate cert, String host, int port) {
                  // 仅用于开发环境：允许自签名证书
                  // 生产环境应该返回 false 或进行正确的证书验证
                  return true;
                };
            return client;
          };
    }
    _crossCache = CrossCache(dio: cacheDio);

    // 延迟初始化 Vosk（非关键组件，不影响页面显示）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        if (!mounted) return;
        debugPrint('🎤 初始化 VoskSpeechRecognition，设置回调');
        _voskRecognition = VoskSpeechRecognition(
          onResult: _handleVoskResult,
          onPartialResult: _handleVoskPartialResult,
        );
        debugPrint('✅ VoskSpeechRecognition 初始化完成，回调已设置');
      });
    });

    // 延迟所有非关键初始化操作，确保页面立即显示
    // 使用 addPostFrameCallback 确保在页面第一帧渲染后再执行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 恢复未完成的流式消息（延迟执行，确保列表先定位到底部）
      // 延迟 500ms 以避免阻塞初始 UI 渲染，确保更快的聊天入口
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final restoreStartTime = DateTime.now();
          debugPrint('🔄 开始恢复流式消息...');
          _streamManager.restoreIncompleteStreams();
          final restoreDuration = DateTime.now().difference(restoreStartTime);
          debugPrint('✅ 流式消息恢复完成，耗时: ${restoreDuration.inMilliseconds}ms');
        }
      });

      // 初始化 Vosk（异步，延迟执行，不影响页面显示）
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _initializeVosk();
        }
      });

      // 初始化 Llama 模型（异步，延迟执行，不影响页面显示）
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _initializeLlama();
        }
      });
    });

    final initDuration = DateTime.now().difference(initStartTime);
    debugPrint('🎯 Local.initState 完成，总耗时: ${initDuration.inMilliseconds}ms');
  }

  // 滚动监听器，用于跟踪滚动位置
  // 使用节流（throttle）来减少执行频率，避免影响滚动性能
  DateTime? _lastScrollLogTime;
  static const _scrollLogThrottleMs = 500; // 每500ms最多记录一次日志

  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    // 节流日志输出，避免频繁打印影响性能
    final now = DateTime.now();
    final shouldLog =
        _lastScrollLogTime == null ||
        now.difference(_lastScrollLogTime!).inMilliseconds >
            _scrollLogThrottleMs;

    final position = _scrollController.position;
    if (position.maxScrollExtent > 0) {
      final distanceFromBottom = (position.maxScrollExtent - position.pixels)
          .abs();
      // 只有当接近底部时才打印日志，避免日志过多
      if (shouldLog && distanceFromBottom < 5.0) {
        debugPrint(
          '📍 滚动已定位到底部: offset=${position.pixels.toStringAsFixed(2)}, '
          'maxExtent=${position.maxScrollExtent.toStringAsFixed(2)}, '
          '距离=${distanceFromBottom.toStringAsFixed(2)}px',
        );
        _lastScrollLogTime = now;
      }
    }
  }

  // 不再监听 _streamManager 并触发整个 Local setState：
  // 流式消息的 UI 更新由 textStreamMessageBuilder 中的 AnimatedBuilder(animation: _streamManager) 局部完成，
  // 避免 1ms 级别流式更新导致整页频繁重建。

  Future<void> _initializeVosk() async {
    try {
      debugPrint('开始初始化 Vosk...');
      final success = await _voskRecognition.initialize();
      if (mounted) {
        setState(() {
          _speechAvailable = success;
        });
        if (success) {
          debugPrint('Vosk 初始化成功');
        } else {
          debugPrint('Vosk 初始化返回 false');
          _showVoiceInputMessage(
            'Vosk 语音识别初始化失败。\n'
            '请检查：\n'
            '1. 模型文件是否在 assets 目录\n'
            '2. 查看 logcat 日志获取详细错误信息',
          );
        }
      }
    } on PlatformException catch (e) {
      debugPrint('Vosk 初始化 PlatformException: ${e.code} - ${e.message}');
      debugPrint('详细信息: ${e.details}');
      if (mounted) {
        setState(() {
          _speechAvailable = false;
        });
        String message;
        switch (e.code) {
          case 'MODEL_NOT_FOUND':
            message =
                '模型文件未找到。\n'
                '请确保模型文件在：\n'
                'android/app/src/main/assets/vosk-model-small-cn-0.3/';
            break;
          case 'INIT_ERROR':
            message =
                'Vosk 初始化失败。\n'
                '错误：${e.message ?? "未知错误"}\n'
                '请查看 logcat 获取详细信息。';
            break;
          default:
            message = 'Vosk 初始化失败：${e.message ?? e.code}';
        }
        _showVoiceInputMessage(message);
      }
    } catch (e, stackTrace) {
      debugPrint('Vosk 初始化异常: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      if (mounted) {
        setState(() {
          _speechAvailable = false;
        });
        final errorMsg = e.toString();
        if (errorMsg.contains('MODEL_NOT_FOUND')) {
          _showVoiceInputMessage('模型文件未找到，请检查 assets 目录');
        } else {
          _showVoiceInputMessage('Vosk 初始化错误：$e');
        }
      }
    }
  }

  /// 初始化 Llama 模型
  Future<void> _initializeLlama() async {
    try {
      debugPrint('🤖 开始初始化 Llama 模型...');

      // 检查模型文件是否存在
      final modelExists = await LlamaInference.checkModelExists();
      if (!modelExists) {
        final modelPath = await LlamaInference.getModelPath();
        debugPrint('❌ Llama 模型文件不存在: $modelPath');
        debugPrint('请确保模型文件已放置在: $modelPath');
        return;
      }

      // 加载模型
      final success = await LlamaInference.loadModel();
      if (success) {
        debugPrint('✅ Llama 模型加载成功');
      } else {
        debugPrint('❌ Llama 模型加载失败');
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Llama 模型加载 PlatformException: ${e.code} - ${e.message}');
      debugPrint('详细信息: ${e.details}');
    } catch (e, stackTrace) {
      debugPrint('❌ Llama 模型加载异常: $e');
      debugPrint('堆栈跟踪: $stackTrace');
    }
  }

  /// 创建语音流式消息（仅在识别到语音内容时调用）
  Future<void> _createVoiceStreamMessage(String initialText) async {
    if (!mounted || !_isListeningToVoice) return;

    // 再次检查，避免重复创建
    if (_currentVoiceStreamId != null || _currentVoiceStreamMessage != null) {
      // 如果已经有消息了，直接更新
      if (_currentVoiceStreamId != null && _currentVoiceStreamMessage != null) {
        _streamManager.updateStreamText(_currentVoiceStreamId!, initialText);
      }
      return;
    }

    // 创建流式消息并插入
    final streamId = _uuid.v4();
    final streamMessage = TextStreamMessage(
      id: _uuid.v4(),
      authorId: _currentUser.id,
      createdAt: DateTime.now().toUtc(),
      streamId: streamId,
    );

    // 插入系统消息（如果是第一条消息）
    if (_chatController.messages.isEmpty) {
      final now = DateTime.now().toUtc();
      final formattedDate = DateFormat(
        'd MMMM yyyy, HH:mm',
      ).format(now.toLocal());
      await _chatController.insertMessage(
        SystemMessage(
          id: _uuid.v4(),
          authorId: _systemUser.id,
          text: formattedDate,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
        index: 0,
      );
    }

    // 插入流式消息
    _chatController.insertMessage(streamMessage);

    // 初始化流式管理器
    _streamManager.initializeStream(streamId, streamMessage);

    // 保存当前流式消息的引用
    _currentVoiceStreamId = streamId;
    _currentVoiceStreamMessage = streamMessage;

    // 更新流式消息内容
    debugPrint('📝 更新流式消息内容: streamId=$streamId, text="$initialText"');
    _streamManager.updateStreamText(streamId, initialText);

    // 验证文本是否已更新
    final verifyState = _streamManager.getState(streamId);
    if (verifyState is StreamStateStreaming) {
      debugPrint('✅ 流式消息已更新，当前文本: "${verifyState.accumulatedText}"');
    } else {
      debugPrint('⚠️ 流式消息状态异常: $verifyState');
    }

    // 滚动到底部
    // 在 reversed 模式下，底部是 0，顶部是 maxScrollExtent
    scheduleMicrotask(() {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    });
  }

  void _handleVoskResult(String text, bool isFinal) {
    if (!mounted || text.isEmpty) {
      debugPrint(
        '🎤 _handleVoskResult: mounted=$mounted, text.isEmpty=${text.isEmpty}',
      );
      return;
    }

    debugPrint(
      '🎤 _handleVoskResult: text="$text", isFinal=$isFinal, streamId=$_currentVoiceStreamId',
    );

    // 如果有流式消息，更新流式消息内容
    // 注意：不在这里完成流式消息，而是等待 _stopVoiceInput 来处理
    // 这样可以确保用户松手后才完成消息
    if (_currentVoiceStreamId != null && _currentVoiceStreamMessage != null) {
      debugPrint('✅ 更新流式消息内容: $_currentVoiceStreamId');
      _streamManager.updateStreamText(_currentVoiceStreamId!, text);
    } else {
      debugPrint(
        '⚠️ 没有流式消息，无法更新: streamId=$_currentVoiceStreamId, streamMessage=$_currentVoiceStreamMessage',
      );
    }
    // 不再更新输入框，语音输入结果只显示在流式消息中
  }

  void _handleVoskPartialResult(String text) {
    if (!mounted || text.isEmpty) {
      debugPrint(
        '🎤 _handleVoskPartialResult: mounted=$mounted, text.isEmpty=${text.isEmpty}',
      );
      return;
    }

    debugPrint(
      '🎤 _handleVoskPartialResult: text="$text", streamId=$_currentVoiceStreamId',
    );

    // 如果检测到有文字，但还没有流式消息，则自动创建一条消息并开始流式输出
    if (_currentVoiceStreamId == null || _currentVoiceStreamMessage == null) {
      debugPrint('📝 检测到语音内容，创建流式消息...');
      // 自动创建流式消息（异步执行，不阻塞UI）
      scheduleMicrotask(() => _createVoiceStreamMessage(text));
    } else {
      // 如果有流式消息，实时更新流式消息内容
      debugPrint('📝 更新现有流式消息: streamId=$_currentVoiceStreamId, text="$text"');
      _streamManager.updateStreamText(_currentVoiceStreamId!, text);

      // 验证文本是否已更新
      final verifyState = _streamManager.getState(_currentVoiceStreamId!);
      if (verifyState is StreamStateStreaming) {
        debugPrint('✅ 流式消息已更新，当前文本: "${verifyState.accumulatedText}"');
      } else {
        debugPrint('⚠️ 流式消息状态异常: $verifyState');
      }
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 Local.dispose 开始清理');
    _scrollToBottomTimer?.cancel();

    // 取消 AI 流式输出订阅
    _aiStreamSubscription?.cancel();
    _aiStreamSubscription = null;

    // 移除滚动监听器
    if (_scrollListenerAdded) {
      _scrollController.removeListener(_scrollListener);
      _scrollListenerAdded = false;
      debugPrint('👂 滚动监听器已移除');
    }

    _composerController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    try {
      _crossCache.dispose();
    } catch (e) {
      // 忽略 dispose 错误，可能已经被释放
    }
    super.dispose();
    debugPrint('✅ Local.dispose 清理完成');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Chat'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0, // 防止滚动时改变颜色
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        surfaceTintColor: Colors.transparent, // 防止Material 3的tint效果
      ),
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true, // 确保键盘显示/隐藏时平滑调整布局
      body: Chat(
        backgroundColor: Colors.white,
        crossCache: _crossCache, // 使用配置好的 CrossCache
        builders: Builders(
          emptyChatListBuilder: (context) => const SizedBox.shrink(),
          chatAnimatedListBuilder: (context, itemBuilder) {
            debugPrint('📋 ChatAnimatedList builder 被调用');
            final listBuildStartTime = DateTime.now();

            final list = ChatAnimatedList(
              key: _chatListKey, // 使用 GlobalKey 保持状态，避免重建时白屏
              itemBuilder: itemBuilder,
              reversed: true, // 使用 reversed 模式，列表自然从底部开始显示，无需滚动跳转
              initialScrollToEndMode:
                  InitialScrollToEndMode.none, // reversed 模式下不需要初始滚动
              scrollToEndAnimationDuration: Duration.zero, // 立即滚动，无动画延迟
              shouldScrollToEndWhenAtBottom: true,
              shouldScrollToEndWhenSendingMessage: true,
              scrollController: _scrollController, // 使用自定义 ScrollController
              physics:
                  const BouncingScrollPhysics(), // 使用 BouncingScrollPhysics，提供流畅的惯性滚动
              bottomPadding:
                  130.0, // 底部间距，略大于 ComposerActionBar 的高度（约68px），确保最后一条消息不被遮挡
              insertAnimationDurationResolver: (message) {
                // 禁用所有消息的插入动画，加快初始加载速度
                // 这样进入聊天界面时可以直接定位到最新消息，不会看到滚动过程
                return Duration.zero;
              },
            );

            WidgetsBinding.instance.addPostFrameCallback((_) {
              final listBuildDuration = DateTime.now().difference(
                listBuildStartTime,
              );
              debugPrint(
                '✅ ChatAnimatedList build 完成，耗时: ${listBuildDuration.inMilliseconds}ms',
              );

              // 添加滚动监听器来跟踪滚动定位
              if (!_scrollListenerAdded && _scrollController.hasClients) {
                _scrollListenerAdded = true;
                _scrollController.addListener(_scrollListener);
                debugPrint('👂 滚动监听器已添加');
              }

              // 在 reversed 模式下，列表自然从底部开始，不需要额外的滚动调整
              // 移除延迟调整逻辑，避免干扰 reversed 模式的正常行为
              //
              // 注意：不要在这里添加滚动监听器，因为它会在每次 build 时被调用
              // 滚动监听器已经在其他地方正确添加
            });

            return list;
          },
          customMessageBuilder:
              (
                context,
                message,
                index, {
                required bool isSentByMe,
                MessageGroupStatus? groupStatus,
              }) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? ChatColors.dark().surfaceContainer
                      : ChatColors.light().surfaceContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: IsTypingIndicator(),
              ),
          imageMessageBuilder:
              (
                context,
                message,
                index, {
                required bool isSentByMe,
                MessageGroupStatus? groupStatus,
              }) => GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ImageViewer(
                        imagePath: message.source,
                        imageProvider: message.source.startsWith('http')
                            ? null
                            : FileImage(File(message.source)),
                      ),
                    ),
                  );
                },
                child: FlyerChatImageMessage(message: message, index: index),
              ),
          systemMessageBuilder:
              (
                context,
                message,
                index, {
                required bool isSentByMe,
                MessageGroupStatus? groupStatus,
              }) => FlyerChatSystemMessage(message: message, index: index),
          composerBuilder: (context) => _CustomComposer(
            textEditingController: _composerController,
            isListeningToVoiceNotifier: _isListeningToVoiceNotifier,
            isMorePanelExpanded: _isMorePanelExpanded,
            isVoiceMode: _isVoiceMode,
            isStreamingAI: _isStreamingAI,
            onVoiceInputStart: _handleVoiceInputStart,
            onVoiceInputEnd: _handleVoiceInputEnd,
            onVoiceInputCancel: _handleVoiceInputCancel,
            onVoiceModeToggle: () {
              setState(() {
                _isVoiceMode = !_isVoiceMode;
                if (_isVoiceMode) {
                  // 切换到语音模式，收起键盘
                  FocusScope.of(context).unfocus();
                  // 不隐藏更多功能按钮
                } else {
                  // 切换到输入模式，收起功能面板
                  _isMorePanelExpanded = false;
                }
              });
            },
            onMoreButtonTap: () {
              setState(() {
                _isMorePanelExpanded = !_isMorePanelExpanded;
              });
            },
            onTextFieldTap: () {
              if (_isMorePanelExpanded) {
                setState(() {
                  _isMorePanelExpanded = false;
                });
              }
              // 当输入框获得焦点时（键盘出现），确保滚动到底部
              _scrollToBottomWhenKeyboardAppears();
            },
            onImageSelected: _handleImageSelected,
            onFileSelected: _handleFileSelected,
            onCameraSelected: _handleCameraSelected,
            onMessageSend: _addItem,
            onStopStreaming: () async {
              // 停止 AI 流式输出
              await LlamaInference.stopGeneration();
              _aiStreamSubscription?.cancel();
              _aiStreamSubscription = null;
              setState(() {
                _isStreamingAI = false;
              });
            },
            onToggleTyping: () async {
              await _toggleTyping();
            },
            onClearAll: () async {
              await _chatController.setMessages([]);
            },
            onScrollToBottom: _scrollToBottomWhenKeyboardAppears,
          ),
          linkPreviewBuilder: (context, message, isSentByMe) {
            // It's up to you to (optionally) implement the logic to avoid every
            // message to refetch the preview data
            //
            // For example, you can use a metadata to indicate if the preview
            // was already fetched (or null).
            //
            // Additionally, you can cache the data to avoid re-fetching across app restarts.
            return LinkPreview(
              text: message.text,
              linkPreviewData: message.linkPreviewData,
              onLinkPreviewDataFetched: (linkPreviewData) {
                _chatController.updateMessage(
                  message,
                  message.copyWith(linkPreviewData: linkPreviewData),
                );
              },
            );
          },
          textMessageBuilder:
              (
                context,
                message,
                index, {
                required bool isSentByMe,
                MessageGroupStatus? groupStatus,
              }) => SelectableTextMessage(
                message: message,
                index: index,
                sentBackgroundColor: Colors.blue.shade100, // 浅蓝色背景
              ),
          textStreamMessageBuilder:
              (
                context,
                message,
                index, {
                required bool isSentByMe,
                MessageGroupStatus? groupStatus,
              }) {
                // 使用 AnimatedBuilder 监听流式管理器状态变化，确保流式消息能够实时更新
                // 注意：AnimatedBuilder 的 builder 必须返回一个 widget，这个 widget 会被添加到 widget tree
                return AnimatedBuilder(
                  animation: _streamManager,
                  builder: (context, _) {
                    final streamState = _streamManager.getState(
                      message.streamId,
                    );

                    // 在流式输出过程中，如果用户已经在底部附近，自动滚动到底部
                    // 使用节流避免频繁滚动（通过 _scrollToBottomIfNeeded 内部节流）
                    if (streamState is StreamStateStreaming) {
                      // 使用 scheduleMicrotask 而不是 addPostFrameCallback，减少回调频率
                      scheduleMicrotask(() {
                        _scrollToBottomIfNeeded();
                      });
                    }

                    return NativeChatTextStreamMessage(
                      key: ValueKey(message.id),
                      message: message,
                      streamState: streamState,
                      index: index,
                      sentBackgroundColor: Colors.blue.shade100, // 浅蓝色背景
                      onDelete: (msg) => _removeItem(msg),
                      onLinkTap: (url, title) async {
                        // 处理超链接跳转：打开空白页面
                        try {
                          // 使用 data URI 创建一个空白 HTML 页面
                          final blankPageUri = Uri.parse(
                            'data:text/html;charset=utf-8,<!DOCTYPE html><html><head><meta charset="utf-8"><title>空白页面</title></head><body></body></html>',
                          );
                          final canLaunch = await canLaunchUrl(blankPageUri);
                          if (canLaunch) {
                            await launchUrl(
                              blankPageUri,
                              mode: LaunchMode.inAppWebView,
                            );
                          } else {
                            // 如果 data URI 不支持，尝试使用 about:blank
                            final uri = Uri.parse('about:blank');
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        } catch (e, stackTrace) {
                          debugPrint('[Local] StackTrace: $stackTrace');
                        }
                      },
                    );
                  },
                );
              },
          fileMessageBuilder:
              (
                context,
                message,
                index, {
                required bool isSentByMe,
                MessageGroupStatus? groupStatus,
              }) => FlyerChatFileMessage(message: message, index: index),
          chatMessageBuilder:
              (
                context,
                message,
                index,
                animation,
                child, {
                bool? isRemoved,
                required bool isSentByMe,
                MessageGroupStatus? groupStatus,
              }) {
                final isSystemMessage = message.authorId == 'system';
                final isFirstInGroup = groupStatus?.isFirst ?? true;
                final isLastInGroup = groupStatus?.isLast ?? true;
                final shouldShowAvatar =
                    !isSystemMessage && isLastInGroup && isRemoved != true;
                final isCurrentUser = message.authorId == _currentUser.id;
                final shouldShowUsername =
                    !isSystemMessage && isFirstInGroup && isRemoved != true;

                Widget? avatar;
                if (shouldShowAvatar) {
                  avatar = Padding(
                    padding: EdgeInsets.only(
                      left: isCurrentUser ? 8 : 0,
                      right: isCurrentUser ? 0 : 8,
                    ),
                    child: Avatar(userId: message.authorId),
                  );
                } else if (!isSystemMessage) {
                  avatar = const SizedBox(width: 40);
                }

                return ChatMessage(
                  message: message,
                  index: index,
                  animation: animation,
                  isRemoved: isRemoved,
                  groupStatus: groupStatus,
                  topWidget: shouldShowUsername
                      ? Padding(
                          padding: EdgeInsets.only(
                            bottom: 4,
                            left: isCurrentUser ? 0 : 48,
                            right: isCurrentUser ? 48 : 0,
                          ),
                          child: Username(userId: message.authorId),
                        )
                      : null,
                  leadingWidget: !isCurrentUser
                      ? avatar
                      : isSystemMessage
                      ? null
                      : const SizedBox(width: 40),
                  trailingWidget: isCurrentUser
                      ? avatar
                      : isSystemMessage
                      ? null
                      : const SizedBox(width: 40),
                  receivedMessageScaleAnimationAlignment:
                      (message is SystemMessage)
                      ? Alignment.center
                      : Alignment.centerLeft,
                  receivedMessageAlignment: (message is SystemMessage)
                      ? AlignmentDirectional.center
                      : AlignmentDirectional.centerStart,
                  horizontalPadding: (message is SystemMessage) ? 0 : 8,
                  child: child,
                );
              },
        ),
        chatController: _chatController,
        currentUserId: _currentUser.id,
        decoration: const BoxDecoration(color: Colors.white),
        // 直接使用 Flutter SelectionArea/SelectableText 的长按选中（高亮 + 手柄可拖拽扩大范围）
        onMessageLongPress: null,
        onMessageSend: _addItem,
        resolveUser: (id) => Future.value(switch (id) {
          'me' => _currentUser,
          'recipient' => _recipient,
          'system' => _systemUser,
          _ => null,
        }),
        theme: theme.brightness == Brightness.dark
            ? ChatTheme.dark()
            : ChatTheme.light(),
      ),
    );
  }

  // 已关闭消息长按菜单（Copy/Delete），以支持 Android 原生文本选择（选择手柄与系统一致）

  // 已移除长按弹窗：直接长按文本进入选择（高亮 + 手柄），更接近 Android 系统行为

  void _addItem(String? text) async {
    if (text == null || text.trim().isEmpty) {
      // send random 只显示富文本，不显示 typing loading
      // 使用 _recipient（AI）发送随机消息
      _handleSendRandomMessage(_recipient, null);
      return;
    }

    // 1. 异步停止所有正在进行的流式输出（不阻塞）
    // ignore: unawaited_futures
    _streamManager.stopAllStreams();

    // 用户输入的消息始终使用 _currentUser.id，显示在右边
    // 检查是否有 typing 消息，如果有则转换为流式消息
    Message? typingMessage;
    if (_isTyping) {
      try {
        typingMessage = _chatController.messages.firstWhere(
          (message) => message.metadata?['type'] == 'typing',
        );
      } catch (e) {
        typingMessage = null;
      }
    }

    // 使用流式效果发送用户文本消息（显示在右边）
    final userMessageTime = DateTime.now().toUtc();
    final streamId = _uuid.v4();
    final streamMessage = typingMessage != null
        ? TextStreamMessage(
            id: typingMessage.id, // 使用 typing 消息的 ID
            authorId: _currentUser.id, // 用户消息，显示在右边
            createdAt: typingMessage.createdAt, // 保持原时间
            streamId: streamId,
          )
        : TextStreamMessage(
            id: _uuid.v4(),
            authorId: _currentUser.id, // 用户消息，显示在右边
            createdAt: userMessageTime,
            streamId: streamId,
          );

    // 立即插入系统消息（如果是第一条消息）
    if (_chatController.messages.isEmpty) {
      final now = DateTime.now().toUtc();
      final formattedDate = DateFormat(
        'd MMMM yyyy, HH:mm',
      ).format(now.toLocal());
      await _chatController.insertMessage(
        SystemMessage(
          id: _uuid.v4(),
          authorId: _systemUser.id,
          text: formattedDate,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
        index: 0,
      );
    }

    // 如果有 typing 消息，更新它；否则插入新消息
    if (typingMessage != null) {
      await _chatController.updateMessage(typingMessage, streamMessage);
      _isTyping = false;
    } else {
      await _chatController.insertMessage(streamMessage);
    }

    // 消息插入后，立即滚动到底部，确保消息可见
    scheduleMicrotask(() {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    });

    // 2. 立即生成 AI 回复（不等待用户消息流式显示完成）
    // 这样 AI loading 消息会紧跟在用户消息后面
    _aiStreamSubscription = QwenChatHelper.generateAndStreamResponse(
      chatController: _chatController,
      streamManager: _streamManager,
      currentUserId: _currentUser.id,
      aiUserId: _recipient.id, // AI 消息，显示在左边
      onMessageInserted: () {
        // AI loading 消息插入后，立即滚动到底部
        scheduleMicrotask(() {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(0.0);
          }
        });
      },
      onStreamingStateChanged: (isStreaming) {
        // 更新流式输出状态，用于显示/隐藏停止按钮
        if (mounted) {
          setState(() {
            _isStreamingAI = isStreaming;
          });
        }
      },
    );

    // 3. 异步开始流式显示用户消息（不阻塞）
    // ignore: unawaited_futures
    _streamManager.streamText(streamId, streamMessage, text);
  }

  Future<void> _handleSendRandomMessage(
    User randomUser,
    Message? typingMessage,
  ) async {
    if (!mounted) return;

    // 使用固定的本地图片路径（从 assets）
    const selectedImagePath = 'assets/pattern.png';

    // 生成流式富文本消息
    var richText = RichTextSamples.getRandomSample();

    // 替换占位符为固定图片路径
    richText = richText.replaceAll('file:///placeholder', selectedImagePath);
    final streamId = _uuid.v4();
    final streamMessage = typingMessage != null
        ? TextStreamMessage(
            id: typingMessage.id, // 使用 typing 消息的 ID
            authorId: randomUser.id,
            createdAt: typingMessage.createdAt, // 保持原时间
            streamId: streamId,
          )
        : TextStreamMessage(
            id: _uuid.v4(),
            authorId: randomUser.id,
            createdAt: DateTime.now().toUtc(),
            streamId: streamId,
          );

    // 插入系统消息（如果是第一条消息）
    // 系统消息应该出现在第一条消息的上方，所以使用 index: 0 确保它插入到列表开头
    // 使用 await 确保系统消息先于第一条消息插入
    if (_chatController.messages.isEmpty) {
      final now = DateTime.now().toUtc();
      final formattedDate = DateFormat(
        'd MMMM yyyy, HH:mm',
      ).format(now.toLocal());
      await _chatController.insertMessage(
        SystemMessage(
          id: _uuid.v4(),
          authorId: _systemUser.id,
          text: formattedDate,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          ), // 使用最早的时间，确保它在列表开头
        ),
        index: 0, // 明确指定插入到列表开头
      );
    }

    // 如果有 typing 消息，更新它；否则插入新消息
    if (typingMessage != null) {
      _chatController.updateMessage(typingMessage, streamMessage);
      _isTyping = false;
    } else {
      _chatController.insertMessage(streamMessage);
    }

    // 开始流式显示
    _streamManager.streamText(streamId, streamMessage, richText);
  }

  Future<void> _handleVoiceInputStart() async {
    // 立即更新按钮状态，不等待任何异步操作，确保按钮立即显示"正在录音..."
    _isListeningToVoice = true;
    _isListeningToVoiceNotifier.value = true; // 立即更新按钮状态，不触发 widget 重建

    // 后台执行启动逻辑，不阻塞按钮状态更新
    _startVoiceInput();
  }

  Future<void> _handleVoiceInputEnd() async {
    debugPrint('🎤 _handleVoiceInputEnd: 开始停止语音输入');
    await _stopVoiceInput(sendRecognizedText: true);
  }

  Future<void> _handleVoiceInputCancel() async {
    if (!_isListeningToVoice) return;

    // 立即更新按钮状态，不等待任何异步操作
    _isListeningToVoice = false;
    _isListeningToVoiceNotifier.value = false; // 立即更新按钮状态，不触发 widget 重建
    _composerController.clear();

    // 后台执行清理操作，不阻塞按钮状态更新
    scheduleMicrotask(() async {
      try {
        await _voskRecognition.cancel();
      } catch (e) {
        debugPrint('取消语音识别失败：$e');
      }

      if (!mounted) return;

      // 删除流式消息
      if (_currentVoiceStreamId != null && _currentVoiceStreamMessage != null) {
        _streamManager.cancelStream(_currentVoiceStreamId!);
        try {
          await _chatController.removeMessage(_currentVoiceStreamMessage!);
        } catch (e) {
          debugPrint('删除语音流式消息失败：$e');
        }
        _currentVoiceStreamId = null;
        _currentVoiceStreamMessage = null;
      }

      // 移除 typing 指示器
      if (_isTyping) {
        await _toggleTyping();
      }
    });
  }

  Future<void> _startVoiceInput() async {
    debugPrint(
      '🎤 _startVoiceInput: 开始启动语音输入, _isListeningToVoice=$_isListeningToVoice',
    );

    // 注意：_isListeningToVoice 已经在 _handleVoiceInputStart 中设置为 true
    // 所以这里不应该检查 _isListeningToVoice，否则会提前返回
    // 状态已经在 _handleVoiceInputStart 中更新，这里只执行后续逻辑
    FocusScope.of(context).unfocus();
    _composerController.clear();

    // 后台检查权限和插入消息（不阻塞状态更新）
    scheduleMicrotask(() async {
      if (!mounted || !_isListeningToVoice) return;

      // 检查麦克风权限
      final permissionStatus = await Permission.microphone.status;
      if (!permissionStatus.isGranted) {
        // 请求权限
        final requestResult = await Permission.microphone.request();
        if (!requestResult.isGranted) {
          if (mounted) {
            _isListeningToVoice = false;
            _isListeningToVoiceNotifier.value =
                false; // 只更新 ValueNotifier，不触发 widget 重建
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('需要麦克风权限才能使用语音输入功能'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      // 权限检查通过后，继续执行后续逻辑
      if (!mounted || !_isListeningToVoice) return;

      // 不再在这里创建流式消息，而是等待识别到语音内容后再创建
      // 这样可以避免UI卡顿，并且只在有实际内容时才显示消息

      // 异步检查和启动语音识别
      if (!_speechAvailable) {
        // 如果未初始化，尝试重新初始化
        debugPrint('Vosk 未初始化，尝试重新初始化...');
        await _initializeVosk();

        if (!_speechAvailable) {
          if (mounted) {
            // 删除流式消息
            if (_currentVoiceStreamId != null &&
                _currentVoiceStreamMessage != null) {
              _streamManager.cancelStream(_currentVoiceStreamId!);
              try {
                await _chatController.removeMessage(
                  _currentVoiceStreamMessage!,
                );
              } catch (e) {
                debugPrint('删除语音流式消息失败：$e');
              }
              _currentVoiceStreamId = null;
              _currentVoiceStreamMessage = null;
            }
            // 移除 typing 指示器
            if (_isTyping) {
              await _toggleTyping();
            }
            _isListeningToVoice = false;
            _isListeningToVoiceNotifier.value =
                false; // 只更新 ValueNotifier，不触发 widget 重建
            _showVoiceInputMessage('Vosk 语音识别未初始化，请检查日志或稍后重试');
          }
          return;
        }
      }

      try {
        final started = await _voskRecognition.startListening();
        if (!started && mounted) {
          // 删除流式消息
          if (_currentVoiceStreamId != null &&
              _currentVoiceStreamMessage != null) {
            _streamManager.cancelStream(_currentVoiceStreamId!);
            try {
              await _chatController.removeMessage(_currentVoiceStreamMessage!);
            } catch (e) {
              debugPrint('删除语音流式消息失败：$e');
            }
            _currentVoiceStreamId = null;
            _currentVoiceStreamMessage = null;
          }
          // 移除 typing 指示器
          if (_isTyping) {
            await _toggleTyping();
          }
          _isListeningToVoice = false;
          _isListeningToVoiceNotifier.value =
              false; // 只更新 ValueNotifier，不触发 widget 重建
          _showVoiceInputMessage('无法启动语音识别，请重试');
          return;
        }
      } catch (e) {
        if (mounted) {
          // 删除流式消息
          if (_currentVoiceStreamId != null &&
              _currentVoiceStreamMessage != null) {
            _streamManager.cancelStream(_currentVoiceStreamId!);
            try {
              await _chatController.removeMessage(_currentVoiceStreamMessage!);
            } catch (e) {
              debugPrint('删除语音流式消息失败：$e');
            }
            _currentVoiceStreamId = null;
            _currentVoiceStreamMessage = null;
          }
          // 移除 typing 指示器
          if (_isTyping) {
            await _toggleTyping();
          }
          _isListeningToVoice = false;
          _isListeningToVoiceNotifier.value =
              false; // 只更新 ValueNotifier，不触发 widget 重建
          _showVoiceInputMessage('启动语音识别失败：$e');
        }
      }
    });
  }

  Future<void> _stopVoiceInput({required bool sendRecognizedText}) async {
    debugPrint('🛑 _stopVoiceInput: sendRecognizedText=$sendRecognizedText');

    // 保存当前状态，避免在异步操作中状态被重置
    final wasListening = _isListeningToVoice;
    final streamId = _currentVoiceStreamId;
    final streamMessage = _currentVoiceStreamMessage;

    debugPrint(
      '🛑 _stopVoiceInput: wasListening=$wasListening, streamId=$streamId, streamMessage=${streamMessage?.id}',
    );

    // 立即更新按钮状态，不等待任何异步操作
    _isListeningToVoice = false;
    _isListeningToVoiceNotifier.value = false; // 立即更新按钮状态，不触发 widget 重建

    // 后台执行停止和消息处理操作，不阻塞按钮状态更新
    scheduleMicrotask(() async {
      if (!wasListening) {
        debugPrint('⚠️ _stopVoiceInput: 本来就没有在录音，直接返回');
        return; // 如果本来就没有在录音，直接返回
      }

      try {
        debugPrint('🛑 调用 stopListening...');
        final stopResult = await _voskRecognition.stopListening();
        debugPrint('🛑 stopListening 返回: $stopResult');
      } catch (e) {
        debugPrint('停止语音识别失败：$e');
      }

      // 等待一小段时间，让语音识别结果回调有时间执行
      // onFinalResult 会在 stop() 后异步调用
      debugPrint('⏳ 等待语音识别结果回调...');
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint(
        '⏳ 等待后的状态: streamId=$streamId, streamMessage=${streamMessage?.id}',
      );

      if (!mounted) return;

      // 移除 typing 指示器
      if (_isTyping) {
        await _toggleTyping();
      }

      if (sendRecognizedText) {
        // 重新检查流式消息引用（可能在等待期间被创建）
        final currentStreamId = _currentVoiceStreamId ?? streamId;
        final currentStreamMessage =
            _currentVoiceStreamMessage ?? streamMessage;

        debugPrint(
          '📋 检查流式消息: currentStreamId=$currentStreamId, currentStreamMessage=${currentStreamMessage?.id}',
        );
        debugPrint(
          '📋 原始引用: streamId=$streamId, streamMessage=${streamMessage?.id}',
        );
        debugPrint(
          '📋 当前引用: _currentVoiceStreamId=$_currentVoiceStreamId, _currentVoiceStreamMessage=${_currentVoiceStreamMessage?.id}',
        );

        // 如果有流式消息，完成流式消息
        if (currentStreamId != null && currentStreamMessage != null) {
          // 使用最新的引用（确保非空）
          final finalStreamId = currentStreamId!;
          final finalStreamMessage = currentStreamMessage!;

          debugPrint(
            '📋 使用流式消息: streamId=$finalStreamId, messageId=${finalStreamMessage.id}',
          );

          // 获取当前累积的文本
          var currentText = _streamManager.getState(finalStreamId);
          String finalText = '';

          // 尝试从状态中获取文本
          if (currentText is StreamStateStreaming) {
            finalText = currentText.accumulatedText;
            debugPrint('✅ 从 StreamStateStreaming 获取文本: "$finalText"');
          } else if (currentText is StreamStateLoading) {
            // 如果还在加载状态，可能文本还没有更新，等待一下
            debugPrint('⚠️ 流式消息还在加载状态，等待文本更新...');
            // 等待一小段时间后重试
            await Future.delayed(const Duration(milliseconds: 300));
            currentText = _streamManager.getState(finalStreamId);
            if (currentText is StreamStateStreaming) {
              finalText = currentText.accumulatedText;
              debugPrint('✅ 重试后从 StreamStateStreaming 获取文本: "$finalText"');
            } else {
              debugPrint('⚠️ 重试后状态仍然是: ${currentText.runtimeType}');
            }
          } else {
            debugPrint('⚠️ 未知的流式消息状态: ${currentText.runtimeType}');
          }

          debugPrint('🎤 语音识别结束，检测到的文本: "$finalText"');
          debugPrint(
            '🎤 流式消息状态: $currentText (类型: ${currentText.runtimeType})',
          );
          debugPrint('🎤 流式消息ID: $finalStreamId');

          // 尝试完成流式消息，completeStream 会从 _accumulatedTexts 中获取文本
          // 即使 finalText 为空，也可能文本在 _accumulatedTexts 中
          debugPrint('🔄 尝试完成流式消息...');

          // 先检查当前状态，获取文本
          var stateBeforeComplete = _streamManager.getState(finalStreamId);
          String textBeforeComplete = '';
          if (stateBeforeComplete is StreamStateStreaming) {
            textBeforeComplete = stateBeforeComplete.accumulatedText;
            debugPrint(
              '📝 完成前状态: StreamStateStreaming, 文本: "$textBeforeComplete"',
            );
          } else if (stateBeforeComplete is StreamStateLoading) {
            debugPrint('📝 完成前状态: StreamStateLoading');
          } else {
            debugPrint('📝 完成前状态: ${stateBeforeComplete.runtimeType}');
          }

          // 调用 completeStream
          await _streamManager.completeStream(finalStreamId);

          // 检查完成后的状态和文本
          final completedState = _streamManager.getState(finalStreamId);
          String completedText = '';
          if (completedState is StreamStateCompleted) {
            completedText = completedState.finalText;
            debugPrint('✅ 流式消息已完成，最终文本: "$completedText"');
          } else if (completedState is StreamStateStreaming) {
            completedText = completedState.accumulatedText;
            debugPrint('✅ 流式消息仍在流式状态，当前文本: "$completedText"');
          } else if (completedState is StreamStateLoading) {
            // 如果状态仍然是 Loading，说明 completeStream 可能因为文本为空而提前返回
            debugPrint('⚠️ 完成后的状态仍然是 Loading，可能文本为空');
            // 使用完成前的文本
            completedText = textBeforeComplete;
          } else {
            debugPrint('⚠️ 完成后的状态: ${completedState.runtimeType}');
          }

          // 如果完成后的文本仍然为空，删除消息并提示
          if (completedText.trim().isEmpty) {
            debugPrint('⚠️ 完成后的文本仍然为空，删除消息并提示用户');
            debugPrint('⚠️ 完成前文本: "$textBeforeComplete"');
            debugPrint('⚠️ 完成后状态: ${completedState.runtimeType}');
            _streamManager.cancelStream(finalStreamId);
            try {
              await _chatController.removeMessage(finalStreamMessage);
            } catch (e) {
              debugPrint('删除语音流式消息失败：$e');
            }
            // 显示提示
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('未识别到语音内容，请重试'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            debugPrint('✅ 文本不为空，消息已成功发送: "$completedText"');
            // 语音消息完成后，生成 AI 回复（显示在左边）
            _aiStreamSubscription = QwenChatHelper.generateAndStreamResponse(
              chatController: _chatController,
              streamManager: _streamManager,
              currentUserId: _currentUser.id,
              aiUserId: _recipient.id, // AI 消息，显示在左边
              onMessageInserted: () {
                // AI loading 消息插入后，立即滚动到底部
                scheduleMicrotask(() {
                  if (mounted && _scrollController.hasClients) {
                    _scrollController.jumpTo(0.0);
                  }
                });
              },
              onStreamingStateChanged: (isStreaming) {
                // 更新流式输出状态，用于显示/隐藏停止按钮
                if (mounted) {
                  setState(() {
                    _isStreamingAI = isStreaming;
                  });
                }
              },
            );
          }
          // 清理引用
          if (_currentVoiceStreamId == streamId) {
            _currentVoiceStreamId = null;
          }
          if (_currentVoiceStreamMessage == streamMessage) {
            _currentVoiceStreamMessage = null;
          }
        } else {
          // 兼容旧逻辑：从输入框发送
          debugPrint('📝 没有流式消息，使用旧逻辑从输入框发送');
          final text = _composerController.text.trim();
          if (text.isEmpty) {
            // 如果输入框也没有文本，显示提示
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('未识别到语音内容，请重试'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            _sendRecognizedText();
          }
        }
      } else {
        // 取消发送，删除流式消息
        if (streamId != null && streamMessage != null) {
          _streamManager.cancelStream(streamId);
          try {
            await _chatController.removeMessage(streamMessage);
          } catch (e) {
            debugPrint('删除语音流式消息失败：$e');
          }
          // 清理引用
          if (_currentVoiceStreamId == streamId) {
            _currentVoiceStreamId = null;
          }
          if (_currentVoiceStreamMessage == streamMessage) {
            _currentVoiceStreamMessage = null;
          }
        }
        _composerController.clear();
      }
    });
  }

  void _sendRecognizedText() {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;

    _addItem(text);
    _composerController.clear();
  }

  void _showVoiceInputMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 如果用户在底部附近，滚动到底部（用于流式输出时自动跟随）
  /// 使用节流机制，避免频繁滚动导致卡顿
  void _scrollToBottomIfNeeded() {
    if (!mounted || !_scrollController.hasClients) return;

    // 节流：每 200ms 最多滚动一次（增加节流时间，减少滚动频率）
    final now = DateTime.now();
    if (_lastStreamScrollTime != null &&
        now.difference(_lastStreamScrollTime!).inMilliseconds < 200) {
      return;
    }
    _lastStreamScrollTime = now;

    final position = _scrollController.position;
    // 在 reversed 模式下，底部是 0.0
    // 如果距离底部小于 150px，认为用户在底部附近，自动滚动到底部
    if (position.pixels <= 150.0) {
      // 使用 jumpTo 而不是 animateTo，避免动画叠加导致卡顿
      _scrollController.jumpTo(0.0);
    }
  }

  /// 当键盘出现时，滚动到底部，确保最后一条消息可见
  void _scrollToBottomWhenKeyboardAppears() {
    // 延迟执行，等待键盘动画完成和布局更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 再次延迟，确保键盘完全出现和布局稳定
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted || !_scrollController.hasClients) return;

        // 在 reversed 模式下，底部是 0，顶部是 maxScrollExtent
        // 所以应该滚动到 0 来显示最后一条消息
        final targetPosition = 0.0;
        final currentPosition = _scrollController.position.pixels;

        // 只有当当前位置不在底部时才滚动
        // 允许 5px 的误差，避免频繁滚动
        if ((currentPosition - targetPosition).abs() > 5.0) {
          _scrollController.jumpTo(targetPosition);
        }
      });
    });
  }

  Future<void> _toggleTyping() async {
    if (!_isTyping) {
      await _chatController.insertMessage(
        CustomMessage(
          id: _uuid.v4(),
          authorId: _systemUser.id,
          metadata: {'type': 'typing'},
          createdAt: DateTime.now().toUtc(),
        ),
      );
      _isTyping = true;
    } else {
      try {
        final typingMessage = _chatController.messages.firstWhere(
          (message) => message.metadata?['type'] == 'typing',
        );

        await _chatController.removeMessage(typingMessage);
        _isTyping = false;
      } catch (e) {
        _isTyping = false;
        await _toggleTyping();
      }
    }
  }

  void _removeItem(Message item) async {
    await _chatController.removeMessage(item);
    if (_chatController.messages.length == 1) {
      await _chatController.removeMessage(_chatController.messages[0]);
    }
  }

  Future<void> _handleImageSelected() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      final imageMessage = ImageMessage(
        id: _uuid.v4(),
        authorId: _currentUser.id,
        createdAt: DateTime.now().toUtc(),
        sentAt: DateTime.now().toUtc(),
        source: image.path,
      );

      await _chatController.insertMessage(imageMessage);
    }
  }

  Future<void> _handleFileSelected() async {
    final result = await FilePicker.platform.pickFiles(
      withData: false,
      withReadStream: false,
    );

    if (result != null && result.files.isNotEmpty && mounted) {
      final file = result.files.first;
      final filePath = file.path!;
      final fileName = file.name;
      final fileSize = file.size;

      final fileMessage = FileMessage(
        id: _uuid.v4(),
        authorId: _currentUser.id,
        createdAt: DateTime.now().toUtc(),
        sentAt: DateTime.now().toUtc(),
        source: filePath,
        name: fileName,
        size: fileSize,
        mimeType: file.extension != null
            ? 'application/${file.extension}'
            : null,
      );

      await _chatController.insertMessage(fileMessage);
    }
  }

  Future<void> _handleCameraSelected() async {
    try {
      // 使用自定义相机页面，拍照后直接在预览页显示输入框
      final result = await Navigator.of(context).push<Map<String, dynamic?>>(
        MaterialPageRoute(builder: (context) => const CameraPage()),
      );

      // 用户从相机页面返回后，发送图片和文本消息
      if (mounted && result != null && result['imagePath'] != null) {
        final imagePath = result['imagePath'] as String;
        final text = result['text'] as String?;
        final now = DateTime.now().toUtc();

        // 先插入图片消息
        final imageMessage = ImageMessage(
          id: _uuid.v4(),
          authorId: _currentUser.id,
          createdAt: now,
          sentAt: now,
          source: imagePath,
        );
        await _chatController.insertMessage(imageMessage);

        // 如果有文本，再插入文本消息
        if (text != null && text.isNotEmpty) {
          final textMessage = TextMessage(
            id: _uuid.v4(),
            authorId: _currentUser.id,
            createdAt: now.add(const Duration(milliseconds: 1)),
            sentAt: now.add(const Duration(milliseconds: 1)),
            text: text,
          );
          await _chatController.insertMessage(textMessage);
        }
      }
    } catch (e) {
      debugPrint('打开相机失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('打开相机失败: $e')));
      }
    }
  }
}

/// 自定义 Composer，布局为：语音按钮 | 输入框 | 更多按钮
/// 点击更多按钮会展开功能面板
/// 点击语音按钮切换到语音模式，显示【按住说话】模块
class _CustomComposer extends StatefulWidget {
  final TextEditingController textEditingController;
  final ValueNotifier<bool> isListeningToVoiceNotifier;
  final bool isMorePanelExpanded;
  final bool isVoiceMode;
  final bool isStreamingAI;
  final Future<void> Function() onVoiceInputStart;
  final Future<void> Function() onVoiceInputEnd;
  final Future<void> Function() onVoiceInputCancel;
  final VoidCallback onVoiceModeToggle;
  final VoidCallback onMoreButtonTap;
  final VoidCallback onTextFieldTap;
  final Future<void> Function() onImageSelected;
  final Future<void> Function() onFileSelected;
  final Future<void> Function() onCameraSelected;
  final Function(String?) onMessageSend;
  final VoidCallback onStopStreaming;
  final VoidCallback onToggleTyping;
  final VoidCallback onClearAll;
  final VoidCallback? onScrollToBottom; // 滚动到底部的回调

  const _CustomComposer({
    required this.textEditingController,
    required this.isListeningToVoiceNotifier,
    required this.isMorePanelExpanded,
    required this.isVoiceMode,
    required this.isStreamingAI,
    required this.onVoiceInputStart,
    required this.onVoiceInputEnd,
    required this.onVoiceInputCancel,
    required this.onVoiceModeToggle,
    required this.onMoreButtonTap,
    required this.onTextFieldTap,
    required this.onImageSelected,
    required this.onFileSelected,
    required this.onCameraSelected,
    required this.onMessageSend,
    required this.onStopStreaming,
    required this.onToggleTyping,
    required this.onClearAll,
    this.onScrollToBottom,
  });

  @override
  State<_CustomComposer> createState() => _CustomComposerState();
}

class _CustomComposerState extends State<_CustomComposer> {
  final _focusNode = FocusNode();
  String _previousText = '';

  @override
  void initState() {
    super.initState();
    // 监听文本变化，用于检测换行
    widget.textEditingController.addListener(_handleTextChange);
    // 设置键盘事件处理（主要用于桌面端）
    _focusNode.onKeyEvent = _handleKeyEvent;
    // 监听焦点变化，当键盘出现时滚动到底部
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    // 当输入框获得焦点时（键盘出现），滚动到底部
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 延迟执行，等待键盘动画完成和布局稳定
        // 增加延迟时间，确保键盘完全出现后再滚动
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          // 通过回调通知父组件滚动到底部
          widget.onScrollToBottom?.call();
        });
      });
    }
  }

  void _handleTextChange() {
    final currentText = widget.textEditingController.text;
    // 检测是否刚添加了换行符（文本长度增加且包含换行符）
    if (currentText.length > _previousText.length &&
        currentText.contains('\n') &&
        !_previousText.contains('\n')) {
      // 用户手动插入了换行符，不做处理
    }
    _previousText = currentText;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // 处理回车键事件（主要用于桌面端）
    // 禁用回车键发送，只允许 Shift+Enter 换行
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      // 如果按住了 Shift 键，允许换行
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      // 普通回车键也允许换行（不发送消息）
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(_CustomComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当功能面板展开时，平滑隐藏键盘
    // 修复：只有在键盘显示时才隐藏键盘，确保高度平滑减小
    if (widget.isMorePanelExpanded && !oldWidget.isMorePanelExpanded) {
      // 检查键盘是否显示
      if (_focusNode.hasFocus) {
        // 立即开始隐藏键盘，让动画与面板展开同步
        // 不使用延迟，确保动画流畅
        _focusNode.unfocus();
      }
    }
    // 当切换到语音模式时，隐藏键盘
    if (widget.isVoiceMode && !oldWidget.isVoiceMode) {
      _focusNode.unfocus();
    }
    // 当切换到输入模式时，显示键盘
    if (!widget.isVoiceMode && oldWidget.isVoiceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.isVoiceMode) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.textEditingController.removeListener(_handleTextChange);
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TopWidget: ComposerActionBar（白色背景）
          Container(
            color: Colors.white,
            child: ComposerActionBar(
              buttons: [
                ComposerActionButton(
                  icon: Icons.type_specimen,
                  title: 'Toggle typing',
                  onPressed: widget.onToggleTyping,
                ),
                ComposerActionButton(
                  icon: Icons.shuffle,
                  title: 'Send random',
                  onPressed: () {
                    widget.onMessageSend(null);
                  },
                ),
                ComposerActionButton(
                  icon: Icons.delete_sweep,
                  title: 'Clear all',
                  onPressed: widget.onClearAll,
                  destructive: true,
                ),
              ],
            ),
          ),
          // Composer 主体
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: 8 + bottomSafeArea,
            ),
            child: Row(
              children: [
                // 语音识别按钮 / 切换键盘按钮
                widget.isVoiceMode
                    ? IconButton(
                        icon: Icon(
                          Icons.keyboard,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        onPressed: widget.onVoiceModeToggle,
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.mic_none,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        onPressed: widget.onVoiceModeToggle,
                      ),
                const SizedBox(width: 8),
                // 输入框 或 【按住说话】模块
                Expanded(
                  child: widget.isVoiceMode
                      ? ValueListenableBuilder<bool>(
                          valueListenable: widget.isListeningToVoiceNotifier,
                          builder: (context, isListening, child) {
                            return _HoldToSpeakButton(
                              isListening: isListening,
                              onLongPressStart: widget.onVoiceInputStart,
                              onLongPressEnd: widget.onVoiceInputEnd,
                              onLongPressCancel: widget.onVoiceInputCancel,
                            );
                          },
                        )
                      : GestureDetector(
                          onTap: widget.onTextFieldTap,
                          child: TextField(
                            controller: widget.textEditingController,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: 'Type a message',
                              hintStyle: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHigh
                                  .withOpacity(0.8),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            style: TextStyle(color: colorScheme.onSurface),
                            maxLines: 5,
                            minLines: 1,
                            textInputAction:
                                TextInputAction.newline, // 改为 newline，禁用键盘发送
                            keyboardType: TextInputType.multiline,
                            onTap: widget.onTextFieldTap,
                            onChanged: (value) {
                              // 文本变化监听，用于更新发送按钮状态
                              setState(() {});
                            },
                            // 移除 onSubmitted，禁用键盘发送功能
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                // 更多按钮
                IconButton(
                  icon: Icon(
                    widget.isMorePanelExpanded
                        ? Icons.close
                        : Icons.add_circle_outline,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onPressed: widget.onMoreButtonTap,
                ),
                // 发送/停止按钮（在更多按钮右边）
                _SendButton(
                  textEditingController: widget.textEditingController,
                  colorScheme: colorScheme,
                  isStreamingAI: widget.isStreamingAI,
                  onSend: () {
                    final text = widget.textEditingController.text.trim();
                    if (text.isNotEmpty) {
                      widget.textEditingController.clear();
                      widget.onMessageSend(text);
                      _focusNode.unfocus();
                    }
                  },
                  onStop: widget.onStopStreaming,
                ),
              ],
            ),
          ),
          // 功能面板（在 composer 下方，宽度为屏幕宽度）
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: widget.isMorePanelExpanded
                ? Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: EdgeInsets.only(
                      top: 12,
                      bottom: 12 + bottomSafeArea,
                      left: 16,
                      right: 16,
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _FunctionButton(
                          icon: Icons.camera_alt,
                          label: '相机',
                          onTap: () async {
                            widget.onMoreButtonTap();
                            await Future.delayed(
                              const Duration(milliseconds: 150),
                            );
                            await widget.onCameraSelected();
                          },
                        ),
                        _FunctionButton(
                          icon: Icons.image,
                          label: '图片',
                          onTap: () async {
                            widget.onMoreButtonTap();
                            await Future.delayed(
                              const Duration(milliseconds: 150),
                            );
                            await widget.onImageSelected();
                          },
                        ),
                        _FunctionButton(
                          icon: Icons.file_present,
                          label: '文件',
                          onTap: () async {
                            widget.onMoreButtonTap();
                            await Future.delayed(
                              const Duration(milliseconds: 150),
                            );
                            await widget.onFileSelected();
                          },
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _FunctionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FunctionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.onSurface, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 【按住说话】按钮，用于语音输入模式
/// 支持长按拖拽，向上拖拽显示取消提示
class _HoldToSpeakButton extends StatefulWidget {
  final bool isListening;
  final Future<void> Function() onLongPressStart;
  final Future<void> Function() onLongPressEnd;
  final Future<void> Function() onLongPressCancel;

  const _HoldToSpeakButton({
    required this.isListening,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
  });

  @override
  State<_HoldToSpeakButton> createState() => _HoldToSpeakButtonState();
}

class _HoldToSpeakButtonState extends State<_HoldToSpeakButton> {
  final GlobalKey _buttonKey = GlobalKey();
  bool _isDraggingUp = false; // 是否拖拽到上方区域
  bool _hasPanned = false; // 是否进行过拖拽（用于区分 tap 和 pan）

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Listener(
          key: _buttonKey,
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            _hasPanned = false; // 重置拖拽标志
            widget.onLongPressStart();
          },
          onPointerUp: (_) {
            // 如果进行过拖拽，不处理（由 onPanEnd 处理）
            if (_hasPanned) return;

            if (widget.isListening) {
              widget.onLongPressEnd();
            }
          },
          onPointerCancel: (_) {
            // 如果进行过拖拽，不处理（由 onPanCancel 处理）
            if (_hasPanned) return;

            if (widget.isListening) {
              widget.onLongPressCancel();
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 拖拽开始
            onPanStart: (_) {
              _hasPanned = true; // 标记已开始拖拽
            },
            // 拖拽检测
            onPanUpdate: (details) {
              if (!widget.isListening) return;

              // 获取按钮的位置信息
              final RenderBox? renderBox =
                  _buttonKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox == null) return;

              // 获取按钮大小
              final buttonSize = renderBox.size;

              // 计算手指位置相对于按钮的位置
              final localPosition = details.localPosition;

              // 如果手指移动到按钮上方区域（向上拖拽超过按钮高度的一半），显示取消提示
              final isAboveButton = localPosition.dy < -buttonSize.height * 0.5;

              if (isAboveButton != _isDraggingUp) {
                setState(() {
                  _isDraggingUp = isAboveButton;
                });
              }
            },
            onPanEnd: (_) {
              // 拖拽结束时，根据是否在取消区域决定是否取消
              if (widget.isListening) {
                if (_isDraggingUp) {
                  // 在取消区域，取消录音
                  widget.onLongPressCancel();
                } else {
                  // 不在取消区域，正常结束录音
                  widget.onLongPressEnd();
                }
              }
              setState(() {
                _isDraggingUp = false;
                _hasPanned = false;
              });
            },
            onPanCancel: () {
              // 拖拽被取消（比如被其他手势拦截），重置状态但不处理录音
              // 注意：onPanCancel 通常不应该处理录音结束，因为可能是系统手势冲突
              // 只有在明确在取消区域时才取消
              if (widget.isListening && _isDraggingUp) {
                // 如果在取消区域，取消录音
                widget.onLongPressCancel();
              }
              // 如果不在取消区域，不处理（让 onPointerUp 处理）
              setState(() {
                _isDraggingUp = false;
                _hasPanned = false;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: 48,
              decoration: BoxDecoration(
                color: widget.isListening
                    ? (_isDraggingUp ? colorScheme.error : colorScheme.primary)
                    : colorScheme.surfaceContainerHigh.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  widget.isListening
                      ? (_isDraggingUp ? '松开取消录音' : '正在录音...')
                      : '按住说话',
                  style: TextStyle(
                    color: widget.isListening
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 发送/停止按钮组件
/// 根据输入框文本状态和流式输出状态显示发送按钮或停止按钮
class _SendButton extends StatefulWidget {
  final TextEditingController textEditingController;
  final ColorScheme colorScheme;
  final bool isStreamingAI;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _SendButton({
    required this.textEditingController,
    required this.colorScheme,
    required this.isStreamingAI,
    required this.onSend,
    required this.onStop,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.textEditingController.text.trim().isNotEmpty;
    widget.textEditingController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.textEditingController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.textEditingController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在流式输出，显示停止按钮
    if (widget.isStreamingAI) {
      return IconButton(
        icon: Icon(Icons.stop_circle, color: widget.colorScheme.error),
        onPressed: widget.onStop,
      );
    }

    // 否则显示发送按钮
    return IconButton(
      icon: Icon(
        Icons.send,
        color: _hasText
            ? widget.colorScheme.primary
            : widget.colorScheme.onSurface.withOpacity(0.3),
      ),
      onPressed: _hasText ? widget.onSend : null,
    );
  }
}
