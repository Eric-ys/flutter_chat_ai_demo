import 'dart:io';
import 'package:cross_cache/cross_cache.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'stream_state.dart';
import 'text_segment.dart';

/// 创建一个可点击预览的图片 Widget
Widget _buildClickableImage(
  BuildContext context,
  String imageUrl,
  Widget imageWidget,
) {
  return GestureDetector(
    onTap: () async {
      // 创建 ImageProvider
      ImageProvider? imageProvider;
      if (imageUrl.startsWith('assets/')) {
        final assetPath = imageUrl.replaceFirst('assets/', '');
        // 明确指定不使用 package，从应用 assets 加载
        // 注意：AssetImage 的路径应该是相对于 pubspec.yaml 中 assets 部分的路径
        // 如果 pubspec.yaml 中声明的是 assets/pattern.png，那么 AssetImage 应该使用 pattern.png
        imageProvider = AssetImage(assetPath, package: null);

        debugPrint(
          '[FlyerChatTextStreamMessage] Creating AssetImage for preview: assetPath=$assetPath, imageUrl=$imageUrl',
        );

        // 预加载 assets 图片，确保 PhotoView 可以正确加载
        try {
          await precacheImage(imageProvider, context);
          debugPrint(
            '[FlyerChatTextStreamMessage] Successfully precached asset image: $assetPath',
          );
        } catch (e, stackTrace) {
          debugPrint(
            '[FlyerChatTextStreamMessage] Failed to precache asset image: $assetPath, error: $e',
          );
          debugPrint('[FlyerChatTextStreamMessage] StackTrace: $stackTrace');
          // 如果预加载失败，尝试使用完整路径（包含 assets/）
          try {
            final fullPathImageProvider = AssetImage(imageUrl, package: null);
            await precacheImage(fullPathImageProvider, context);
            imageProvider = fullPathImageProvider;
            debugPrint(
              '[FlyerChatTextStreamMessage] Successfully precached asset image with full path: $imageUrl',
            );
          } catch (e2) {
            debugPrint(
              '[FlyerChatTextStreamMessage] Failed to precache asset image with full path: $imageUrl, error: $e2',
            );
            // 如果都失败，仍然尝试显示原始路径
          }
        }
      } else if (imageUrl.startsWith('http')) {
        imageProvider = NetworkImage(imageUrl);
      } else {
        imageProvider = FileImage(File(imageUrl));
      }

      // 打开图片预览页面
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => Scaffold(
                backgroundColor: Colors.black,
                body: SafeArea(
                  child: Stack(
                    children: [
                      Center(
                        child:
                            imageUrl.startsWith('assets/')
                                ? PhotoView.customChild(
                                  // 对于 assets 图片，使用 customChild 直接显示 Image.asset
                                  minScale: PhotoViewComputedScale.contained,
                                  maxScale: PhotoViewComputedScale.covered * 2,
                                  initialScale:
                                      PhotoViewComputedScale.contained,
                                  // 对于 assets 图片，使用 customChild 直接显示 Image.asset
                                  child: Image.asset(
                                    imageUrl, // 使用完整路径，包含 assets/
                                    package: null,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint(
                                        '[FlyerChatTextStreamMessage] Image.asset error: $imageUrl, error: $error',
                                      );
                                      // 尝试去掉 assets/ 前缀
                                      final assetPath = imageUrl.replaceFirst(
                                        'assets/',
                                        '',
                                      );
                                      return Image.asset(
                                        assetPath,
                                        package: null,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error2, _) {
                                          debugPrint(
                                            '[FlyerChatTextStreamMessage] Image.asset error (retry): $assetPath, error: $error2',
                                          );
                                          return Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  '图片加载失败',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'URL: $imageUrl',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8,
                                                      ),
                                                  child: Text(
                                                    'Path: $assetPath',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                )
                                : PhotoView(
                                  // 对于网络图片和本地文件，使用 imageProvider
                                  imageProvider: imageProvider,
                                  minScale: PhotoViewComputedScale.contained,
                                  maxScale: PhotoViewComputedScale.covered * 2,
                                  initialScale:
                                      PhotoViewComputedScale.contained,
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint(
                                      '[FlyerChatTextStreamMessage] PhotoView error: $imageUrl, error: $error',
                                    );
                                    debugPrint(
                                      '[FlyerChatTextStreamMessage] PhotoView stackTrace: $stackTrace',
                                    );
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.broken_image,
                                            color: Colors.white,
                                            size: 48,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            '图片加载失败',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'URL: $imageUrl',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, event) {
                                    if (event == null) {
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      );
                                    }
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            event.expectedTotalBytes != null
                                                ? event.cumulativeBytesLoaded /
                                                    event.expectedTotalBytes!
                                                : null,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      );
    },
    child: imageWidget,
  );
}

// This can be removed when this issue is resolved https://github.com/Infinitix-LLC/gpt_markdown/issues/85
InlineSpan _applyLinkStyle(
  InlineSpan original,
  TextStyle? paragraphStyle,
  Color? color,
  TextDecoration? decoration,
  Color? decorationColor,
) {
  if (original is TextSpan) {
    // 强制应用超链接样式，确保颜色和下划线都正确显示
    // 完全覆盖原有样式，确保超链接样式可见
    final linkColor = color ?? Colors.red;
    final linkDecoration = decoration ?? TextDecoration.underline;
    final linkDecorationColor = decorationColor ?? linkColor;

    // 递归处理子节点
    final processedChildren =
        original.children
            ?.map(
              (child) => _applyLinkStyle(
                child,
                paragraphStyle,
                linkColor,
                linkDecoration,
                linkDecorationColor,
              ),
            )
            .toList();

    // 获取基础样式，优先使用 original.style，然后使用 paragraphStyle
    final baseStyle = original.style ?? paragraphStyle ?? const TextStyle();

    final finalStyle = baseStyle.copyWith(
      color: linkColor, // 强制使用蓝色，覆盖原有颜色
      decoration: linkDecoration, // 强制使用下划线，覆盖原有装饰
      decorationColor: linkDecorationColor, // 装饰颜色
      decorationStyle: TextDecorationStyle.solid, // 确保装饰样式为实线
      // 保留原有的其他属性（字体大小、行高等）
    );

    return TextSpan(
      text: original.text,
      children: processedChildren,
      style: finalStyle,
    );
  }
  return original;
}

/// Theme values for [FlyerChatTextStreamMessage].
typedef _LocalTheme =
    ({
      TextStyle bodyMedium,
      TextStyle labelSmall,
      Color onPrimary,
      Color onSurface,
      Color primary,
      BorderRadiusGeometry shape,
      Color surfaceContainer,
    });

/// Defines how the text stream message content is rendered.
enum TextStreamMessageMode {
  /// Renders text using [RichText] with per-chunk fade-in animations.
  ///
  /// This provides a dynamic visual effect as text arrives.
  animatedOpacity,

  /// Renders the entire accumulated text using [GptMarkdown] instantly on each update.
  ///
  /// This ensures rendering consistency with the final `TextMessage` (if it also
  /// uses Markdown), but lacks the chunk-by-chunk animation.
  instantMarkdown,
}

/// A widget that displays a text message which is being streamed incrementally.
///
/// This widget expects a [TextStreamMessage] and the current [StreamState]
/// (managed externally) to render the incoming text dynamically.
///
/// It supports two rendering modes via [TextStreamMessageMode]:
/// - `animatedOpacity`: Fades in each new chunk of text.
/// - `instantMarkdown`: Renders the full accumulated text with Markdown on each update.
class FlyerChatTextStreamMessage extends StatefulWidget {
  /// The underlying `TextStreamMessage` data model.
  final TextStreamMessage message;

  /// The index of the message in the list.
  final int index;

  /// The current state of the stream, determining what to display (loading,
  /// streaming text, completed text, error).
  final StreamState streamState;

  /// Padding around the message bubble content.
  final EdgeInsetsGeometry? padding;

  /// Border radius of the message bubble.
  final BorderRadiusGeometry? borderRadius;

  /// Background color for messages sent by the current user.
  final Color? sentBackgroundColor;

  /// Background color for messages received from other users.
  final Color? receivedBackgroundColor;

  /// Text style for messages sent by the current user.
  final TextStyle? sentTextStyle;

  /// Text style for messages received from other users.
  final TextStyle? receivedTextStyle;

  /// Text style for the message timestamp.
  final TextStyle? timeStyle;

  /// Whether to display the message timestamp.
  final bool showTime;

  /// Whether to display the message status (sent, delivered, seen) for sent messages.
  final bool showStatus;

  /// Position of the timestamp and status indicator relative to the text.
  final TimeAndStatusPosition timeAndStatusPosition;

  /// Duration for the fade-in animation of each text chunk when
  /// `mode` is [TextStreamMessageMode.animatedOpacity].
  final Duration chunkAnimationDuration;

  /// The rendering mode for the text content.
  final TextStreamMessageMode mode;

  /// The callback function to handle link clicks.
  final void Function(String url, String title)? onLinkTap;

  /// The color of the links in the sent messages.
  final Color? sentLinksColor;

  /// The color of the links in the received messages.
  final Color? receivedLinksColor;

  /// The color of the links decoration in the sent messages.
  final Color? sentLinksDecorationColor;

  /// The color of the links decoration in the received messages.
  final Color? receivedLinksDecorationColor;

  /// The decoration of the links.
  final TextDecoration? linksDecoration;

  /// The text to display while in the loading state. Defaults to "Thinking".
  final String loadingText;

  /// The base color for the shimmer loading animation.
  final Color? shimmerBaseColor;

  /// The highlight color for the shimmer loading animation.
  final Color? shimmerHighlightColor;

  /// The period of the shimmer loading animation.
  final Duration shimmerPeriod;

  /// A builder to completely override the default loading widget.
  /// If provided, `loadingText`, `shimmerBaseColor`, and `shimmerHighlightColor` are ignored.
  final Widget Function(BuildContext context, TextStyle? paragraphStyle)?
  loadingBuilder;

  /// Creates a widget to display a streaming text message.
  const FlyerChatTextStreamMessage({
    super.key,
    required this.message,
    required this.index,
    required this.streamState,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.borderRadius,
    this.sentBackgroundColor,
    this.receivedBackgroundColor,
    this.sentTextStyle,
    this.receivedTextStyle,
    this.timeStyle,
    this.showTime = true,
    this.showStatus = true,
    this.timeAndStatusPosition = TimeAndStatusPosition.end,
    this.chunkAnimationDuration = const Duration(milliseconds: 350),
    this.mode = TextStreamMessageMode.animatedOpacity,
    this.onLinkTap,
    this.sentLinksColor,
    this.receivedLinksColor,
    this.sentLinksDecorationColor,
    this.receivedLinksDecorationColor,
    this.linksDecoration,
    this.loadingText = '......',
    this.shimmerBaseColor,
    this.shimmerHighlightColor,
    this.shimmerPeriod = const Duration(milliseconds: 1000),
    this.loadingBuilder,
  });

  @override
  State<FlyerChatTextStreamMessage> createState() {
    return _FlyerChatTextStreamMessageState();
  }
}

class _FlyerChatTextStreamMessageState extends State<FlyerChatTextStreamMessage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  List<TextSegment> _segments = [];
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _updateSegmentsFromState(widget.streamState, isInitial: true);
  }

  @override
  void dispose() {
    _disposeAllSegmentControllers();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FlyerChatTextStreamMessage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.streamState == oldWidget.streamState) return;

    _updateSegmentsFromState(
      widget.streamState,
      oldState: oldWidget.streamState,
    );
  }

  void _updateSegmentsFromState(
    StreamState newState, {
    StreamState? oldState,
    bool isInitial = false,
  }) {
    if (isInitial) {
      _disposeAllSegmentControllers();

      var initialText = '';
      if (newState is StreamStateStreaming) {
        initialText = newState.accumulatedText;
      } else if (newState is StreamStateCompleted) {
        initialText = newState.finalText;
      } else if (newState is StreamStateError) {
        initialText = newState.accumulatedText ?? '';
      }

      _segments = [if (initialText.isNotEmpty) StaticSegment(initialText)];
    } else {
      if (newState is StreamStateStreaming) {
        final newText = newState.accumulatedText;
        final currentSegmentText = _segments.map((s) => s.text).join('');

        if (newText.length > currentSegmentText.length &&
            newText.startsWith(currentSegmentText)) {
          final newChunk = newText.substring(currentSegmentText.length);

          _addNewAnimatingChunk(newChunk);
        } else if (newText != currentSegmentText) {
          _disposeAllSegmentControllers();
          setState(() {
            _segments = [if (newText.isNotEmpty) StaticSegment(newText)];
          });
        }
      } else {
        // Transitioning to a final state (Completed, Error, or back to Loading)
        _disposeAllSegmentControllers();

        var finalText = '';
        if (newState is StreamStateCompleted) {
          finalText = newState.finalText;
        } else if (newState is StreamStateError) {
          finalText = newState.accumulatedText ?? '';
        }

        // Reconstruct the full string currently represented by all segments.
        final currentText = _segments.map((s) => s.text).join('');

        // Update the UI only if necessary:
        // 1. If the final text differs from the text currently shown (including partially animated parts).
        // 2. OR if there are still segments animating (even if text matches, animations need removal).
        if (finalText != currentText ||
            _segments.any((s) => s is AnimatingSegment)) {
          setState(() {
            // Replace all existing segments with a single StaticSegment containing the final text.
            // This ensures any leftover animations are stopped and the correct final content is displayed.
            _segments = [if (finalText.isNotEmpty) StaticSegment(finalText)];
          });
        }
      }
    }
  }

  void _addNewAnimatingChunk(String chunk) {
    final controller = AnimationController(
      duration: widget.chunkAnimationDuration,
      vsync: this,
    );
    final fadeAnimation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInToLinear,
    );

    final newSegment = AnimatingSegment(chunk, controller, fadeAnimation);

    // Add listener to trigger setState on animation ticks
    // ignore: prefer_function_declarations_over_variables
    final listener = () {
      if (mounted) {
        setState(() {});
      }
    };

    controller.addListener(listener);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.removeListener(listener);
        _finalizeChunkAnimation(newSegment);
      }
    });

    setState(() {
      _segments.add(newSegment);
    });

    controller.forward(from: 0);
  }

  void _disposeAllSegmentControllers() {
    for (final segment in _segments) {
      if (segment is AnimatingSegment) {
        // Disposing the AnimationController also automatically removes its listeners.
        // While explicitly calling controller.removeListener(listener) before dispose()
        // is the most defensive approach, it requires storing the listener reference
        // within the AnimatingSegment, adding complexity. Relying on dispose() is standard
        // practice and sufficient here.
        segment.dispose();
      }
    }
  }

  void _finalizeChunkAnimation(AnimatingSegment completedSegment) {
    if (!mounted) return;
    setState(() {
      final index = _segments.indexOf(completedSegment);
      if (index != -1) {
        // Replace animating segment with static segment
        _segments[index] = StaticSegment(completedSegment.text);
        // No need to remove listener explicitly here if controller is disposed
        completedSegment.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以支持 AutomaticKeepAliveClientMixin
    
    final theme = context.select(
      (ChatTheme t) => (
        bodyMedium: t.typography.bodyMedium,
        labelSmall: t.typography.labelSmall,
        onPrimary: t.colors.onPrimary,
        onSurface: t.colors.onSurface,
        primary: t.colors.primary,
        shape: t.shape,
        surfaceContainer: t.colors.surfaceContainer,
      ),
    );
    final isSentByMe = context.read<UserID>() == widget.message.authorId;
    final backgroundColor = _resolveBackgroundColor(isSentByMe, theme);
    final paragraphStyle = _resolveParagraphStyle(isSentByMe, theme);
    final timeStyle = _resolveTimeStyle(isSentByMe, theme);

    final linksColor =
        isSentByMe ? widget.sentLinksColor : widget.receivedLinksColor;
    final linksDecorationColor = _resolveLinksDecorationColor(
      isSentByMe,
      theme,
    );

    final timeAndStatus =
        widget.showTime || (isSentByMe && widget.showStatus)
            ? TimeAndStatus(
              time: widget.message.resolvedTime,
              status: widget.message.resolvedStatus,
              showTime: widget.showTime,
              showStatus: isSentByMe && widget.showStatus,
              textStyle: timeStyle,
            )
            : null;

    // Build text content based on segments
    final textContent = _buildTextContent(
      paragraphStyle,
      theme,
      linksColor,
      linksDecorationColor,
    );

    // Build the message container and layout
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: widget.borderRadius ?? theme.shape,
      ),
      child: _buildContentBasedOnPosition(
        context: context,
        textContent: textContent,
        timeAndStatus: timeAndStatus,
        paragraphStyle: paragraphStyle,
      ),
    );
  }

  Widget _buildTextContent(
    TextStyle? paragraphStyle,
    _LocalTheme theme,
    Color? linksColor,
    Color? linksDecorationColor,
  ) {
    if (widget.streamState is StreamStateLoading) {
      if (widget.loadingBuilder != null) {
        return widget.loadingBuilder!(context, paragraphStyle);
      }

      return Shimmer.fromColors(
        baseColor:
            widget.shimmerBaseColor ?? theme.onSurface.withValues(alpha: 0.3),
        highlightColor:
            widget.shimmerHighlightColor ??
            theme.onSurface.withValues(alpha: 0.8),
        period: widget.shimmerPeriod,
        child: Text(widget.loadingText, style: paragraphStyle),
      );
    }

    if (widget.streamState is StreamStateError) {
      final state = widget.streamState as StreamStateError;
      final errorText =
          state.accumulatedText != null
              ? '${state.accumulatedText}\n\nError: ${state.error}'
              : 'Error: ${state.error}';
      return Text(
        errorText,
        style: paragraphStyle?.copyWith(color: Colors.red),
      );
    }

    if (widget.streamState is StreamStateCompleted) {
      final state = widget.streamState as StreamStateCompleted;

      debugPrint(
        '[FlyerChatTextStreamMessage] Rendering completed markdown, text length: ${state.finalText.length}',
      );
      debugPrint(
        '[FlyerChatTextStreamMessage] Markdown preview (first 200 chars): ${state.finalText.substring(0, state.finalText.length > 200 ? 200 : state.finalText.length)}',
      );

      // 使用 AnimatedSize 来平滑处理高度变化（从 streaming 到 completed 状态）
      return AnimatedSize(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          child: GptMarkdownTheme(
            gptThemeData: GptMarkdownTheme.of(context),
            child: GptMarkdown(
              // 使用消息 ID 作为 key，确保 widget 实例稳定
              key: ValueKey('markdown_completed_${widget.message.id}'),
              state.finalText,
              style: paragraphStyle,
            onLinkTap: (url, title) {
              debugPrint(
                '[FlyerChatTextStreamMessage] onLinkTap called (completed): url=$url, title=$title',
              );
              if (widget.onLinkTap != null) {
                debugPrint(
                  '[FlyerChatTextStreamMessage] Calling widget.onLinkTap callback',
                );
                widget.onLinkTap!(url, title);
              } else {
                debugPrint(
                  '[FlyerChatTextStreamMessage] WARNING: widget.onLinkTap is null!',
                );
              }
            },
            linkBuilder: (context, span, url, style) {
            // 确保超链接有红色和下划线样式
            // 注意：linkBuilder 返回的 Widget 会被 gpt_markdown 包裹在 GestureDetector 中
            // 所以不需要再添加 GestureDetector，直接返回 Text.rich 即可
            final linkColor = linksColor ?? Colors.red;
            final decoration =
                widget.linksDecoration ?? TextDecoration.underline;
            final decorationColor = linksDecorationColor ?? linkColor;

            debugPrint(
              '[FlyerChatTextStreamMessage] linkBuilder called: url=$url, span.text=${span.toPlainText()}',
            );

            // 直接返回 Text.rich，gpt_markdown 会处理点击事件
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Text.rich(
                _applyLinkStyle(
                  span,
                  paragraphStyle,
                  linkColor,
                  decoration,
                  decorationColor,
                ),
              ),
            );
          },
          imageBuilder: (context, imageUrl) {
            // 使用 CrossCache 加载图片，支持 assets、网络图片和本地文件
            // 参考 FlyerChatImageMessage 的实现方式

            debugPrint(
              '[FlyerChatTextStreamMessage] imageBuilder called: imageUrl=$imageUrl',
            );

            // 首先检查是否是 assets 路径
            if (imageUrl.startsWith('assets/')) {
              // 对于 assets 路径，直接使用 Image.asset
              // 注意：Image.asset 需要使用 pubspec.yaml 中声明的完整路径（包含 assets/）
              debugPrint(
                '[FlyerChatTextStreamMessage] Loading asset image: $imageUrl',
              );
              return _buildClickableImage(
                context,
                imageUrl,
                Image.asset(
                  imageUrl, // 使用完整路径，包含 assets/
                  package: null, // 明确指定不使用 package，从应用 assets 加载
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint(
                      '[FlyerChatTextStreamMessage] Asset image error: $imageUrl, error: $error',
                    );
                    debugPrint(
                      '[FlyerChatTextStreamMessage] Asset image stackTrace: $stackTrace',
                    );
                    // 尝试去掉 assets/ 前缀
                    final assetPath = imageUrl.replaceFirst('assets/', '');
                    return Image.asset(
                      assetPath,
                      package: null,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error2, _) {
                        debugPrint(
                          '[FlyerChatTextStreamMessage] Asset image error (retry without assets/ prefix): $assetPath, error: $error2',
                        );
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[300],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image),
                              const SizedBox(height: 4),
                              Text(
                                'Asset Error',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            }

            // 对于网络图片和本地文件，使用 CrossCache
            try {
              final crossCache = context.read<CrossCache>();
              debugPrint(
                '[FlyerChatTextStreamMessage] Loading image with CrossCache: $imageUrl',
              );
              final imageProvider = CachedNetworkImage(imageUrl, crossCache);
              return RepaintBoundary(
                child: _buildClickableImage(
                  context,
                  imageUrl,
                  Image(
                    image: imageProvider,
                    fit: BoxFit.contain,
                    // 静默处理图片错误，避免触发整个 Markdown 重建
                    errorBuilder: (context, error, stackTrace) {
                      // 只记录错误，不打印（减少日志噪音）
                      if (kDebugMode) {
                        debugPrint(
                          '[FlyerChatTextStreamMessage] Image error (silent): $imageUrl',
                        );
                      }
                      // 返回占位符，保持稳定的布局
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: Colors.grey,
                            size: 32,
                          ),
                        ),
                      );
                    },
                    // 加载进度指示器，保持稳定的大小
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[100],
                        child: Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            } catch (e, stackTrace) {
              debugPrint(
                '[FlyerChatTextStreamMessage] Exception in imageBuilder: $imageUrl, error: $e',
              );
              debugPrint(
                '[FlyerChatTextStreamMessage] StackTrace: $stackTrace',
              );
              // 如果 CrossCache 不可用，回退到直接加载网络图片
              return _buildClickableImage(
                context,
                imageUrl,
                Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, _) {
                    debugPrint(
                      '[FlyerChatTextStreamMessage] Network image error: $imageUrl, error: $error',
                    );
                    return Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[300],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image),
                          const SizedBox(height: 4),
                          Text(
                            'Network Error',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                        ),
                      ),
                    );
                  },
                ),
              );
            }
          },
        ),
          ),
        ),
      );
    }

    // Build RichText from segments for Streaming state
    if (widget.streamState is StreamStateStreaming) {
      if (_segments.isEmpty) {
        // Show placeholder if streaming hasn't produced any segments yet
        return Text(
          '...',
          style: paragraphStyle?.copyWith(
            color: paragraphStyle.color?.withValues(alpha: 0.5),
          ),
        );
      }

      if (widget.mode == TextStreamMessageMode.instantMarkdown) {
        final combinedText = _segments.map((s) => s.text).join('');

        debugPrint(
          '[FlyerChatTextStreamMessage] Rendering streaming markdown, text length: ${combinedText.length}',
        );
        debugPrint(
          '[FlyerChatTextStreamMessage] Markdown preview (first 200 chars): ${combinedText.substring(0, combinedText.length > 200 ? 200 : combinedText.length)}',
        );

        // 使用 AnimatedSize 来平滑处理高度变化
        return AnimatedSize(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            child: GptMarkdownTheme(
              gptThemeData: GptMarkdownTheme.of(context),
              child: GptMarkdown(
                // 使用消息 ID 作为 key，确保 widget 实例稳定，避免反复重建
                key: ValueKey('markdown_stream_${widget.message.id}'),
                combinedText,
                style: paragraphStyle,
              onLinkTap: (url, title) {
                debugPrint(
                  '[FlyerChatTextStreamMessage] onLinkTap called (streaming): url=$url, title=$title',
                );
                if (widget.onLinkTap != null) {
                  debugPrint(
                    '[FlyerChatTextStreamMessage] Calling widget.onLinkTap callback (streaming)',
                  );
                  widget.onLinkTap!(url, title);
                } else {
                  debugPrint(
                    '[FlyerChatTextStreamMessage] WARNING: widget.onLinkTap is null! (streaming)',
                  );
                }
              },
              linkBuilder: (context, span, url, style) {
              // 确保超链接有红色和下划线样式
              // 注意：linkBuilder 返回的 Widget 会被 gpt_markdown 包裹在 GestureDetector 中
              // 所以不需要再添加 GestureDetector，直接返回 Text.rich 即可
              final linkColor = linksColor ?? Colors.red;
              final decoration =
                  widget.linksDecoration ?? TextDecoration.underline;
              final decorationColor = linksDecorationColor ?? linkColor;

              debugPrint(
                '[FlyerChatTextStreamMessage] linkBuilder called (streaming): url=$url, span.text=${span.toPlainText()}',
              );

              // 直接返回 Text.rich，gpt_markdown 会处理点击事件
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: Text.rich(
                  _applyLinkStyle(
                    span,
                    paragraphStyle,
                    linkColor,
                    decoration,
                    decorationColor,
                  ),
                ),
              );
            },
            imageBuilder: (context, imageUrl) {
              // 使用 CrossCache 加载图片，支持 assets、网络图片和本地文件
              // 参考 FlyerChatImageMessage 的实现方式

              debugPrint(
                '[FlyerChatTextStreamMessage] imageBuilder called (streaming): imageUrl=$imageUrl',
              );

              // 首先检查是否是 assets 路径
              if (imageUrl.startsWith('assets/')) {
                // 对于 assets 路径，直接使用 Image.asset
                // 注意：Image.asset 需要使用 pubspec.yaml 中声明的完整路径（包含 assets/）
                debugPrint(
                  '[FlyerChatTextStreamMessage] Loading asset image (streaming): $imageUrl',
                );
                return _buildClickableImage(
                  context,
                  imageUrl,
                  Image.asset(
                    imageUrl, // 使用完整路径，包含 assets/
                    package: null, // 明确指定不使用 package，从应用 assets 加载
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint(
                        '[FlyerChatTextStreamMessage] Asset image error (streaming): $imageUrl, error: $error',
                      );
                      debugPrint(
                        '[FlyerChatTextStreamMessage] Asset image stackTrace (streaming): $stackTrace',
                      );
                      // 尝试去掉 assets/ 前缀
                      final assetPath = imageUrl.replaceFirst('assets/', '');
                      return Image.asset(
                        assetPath,
                        package: null,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error2, _) {
                          debugPrint(
                            '[FlyerChatTextStreamMessage] Asset image error (retry without assets/ prefix, streaming): $assetPath, error: $error2',
                          );
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[300],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image),
                                const SizedBox(height: 4),
                                Text(
                                  'Asset Error',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              }

              // 对于网络图片和本地文件，使用 CrossCache
              try {
                final crossCache = context.read<CrossCache>();
                final imageProvider = CachedNetworkImage(imageUrl, crossCache);
                return RepaintBoundary(
                  child: _buildClickableImage(
                  context,
                  imageUrl,
                  Image(
                    image: imageProvider,
                    fit: BoxFit.contain,
                    // 静默处理图片错误，避免触发整个 Markdown 重建
                    errorBuilder: (context, error, stackTrace) {
                      if (kDebugMode) {
                        debugPrint(
                          '[FlyerChatTextStreamMessage] Image error (silent, streaming): $imageUrl',
                        );
                      }
                      // 返回占位符，保持稳定的布局
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: Colors.grey,
                            size: 32,
                          ),
                        ),
                      );
                    },
                    // 加载进度指示器，保持稳定的大小
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[100],
                        child: Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
              } catch (e, stackTrace) {
                debugPrint(
                  '[FlyerChatTextStreamMessage] Exception in imageBuilder (streaming): $imageUrl, error: $e',
                );
                debugPrint(
                  '[FlyerChatTextStreamMessage] StackTrace (streaming): $stackTrace',
                );
                // 如果 CrossCache 不可用，回退到直接加载网络图片
                return _buildClickableImage(
                  context,
                  imageUrl,
                  Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, _) {
                      debugPrint(
                        '[FlyerChatTextStreamMessage] Network image error (streaming): $imageUrl, error: $error',
                      );
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image),
                            const SizedBox(height: 4),
                            Text(
                              'Network Error',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
      } else {
      return RichText(
          text: TextSpan(
            style: paragraphStyle,
            children:
                _segments.map<InlineSpan>((segment) {
                  if (segment is StaticSegment) {
                    return TextSpan(text: segment.text);
                  } else if (segment is AnimatingSegment) {
                    final currentOpacity = segment.fadeAnimation.value;
                    final animatingStyle = paragraphStyle?.copyWith(
                      color: paragraphStyle.color?.withValues(
                        alpha: currentOpacity,
                      ),
                    );
                    return TextSpan(text: segment.text, style: animatingStyle);
                  }
                  return const TextSpan();
                }).toList(),
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildContentBasedOnPosition({
    required BuildContext context,
    required Widget textContent,
    TimeAndStatus? timeAndStatus,
    TextStyle? paragraphStyle,
  }) {
    if (timeAndStatus == null) {
      return textContent;
    }

    final textDirection = Directionality.of(context);

    switch (widget.timeAndStatusPosition) {
      case TimeAndStatusPosition.start:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [textContent, timeAndStatus],
        );
      case TimeAndStatusPosition.inline:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: textContent),
            const SizedBox(width: 4),
            timeAndStatus,
          ],
        );
      case TimeAndStatusPosition.end:
        return RepaintBoundary(
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: paragraphStyle?.lineHeight ?? 0),
                child: textContent,
              ),
              Opacity(opacity: 0, child: timeAndStatus),
              Positioned.directional(
                textDirection: textDirection,
                end: 0,
                bottom: 0,
                child: RepaintBoundary(
                  child: ExcludeSemantics(
                    child: timeAndStatus,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Color? _resolveBackgroundColor(bool isSentByMe, _LocalTheme theme) {
    if (isSentByMe) {
      return widget.sentBackgroundColor ?? theme.primary;
    }
    return widget.receivedBackgroundColor ?? theme.surfaceContainer;
  }

  TextStyle? _resolveParagraphStyle(bool isSentByMe, _LocalTheme theme) {
    if (isSentByMe) {
      return widget.sentTextStyle ??
          theme.bodyMedium.copyWith(color: theme.onPrimary);
    }
    return widget.receivedTextStyle ??
        theme.bodyMedium.copyWith(color: theme.onSurface);
  }

  TextStyle? _resolveTimeStyle(bool isSentByMe, _LocalTheme theme) {
    if (isSentByMe) {
      return widget.timeStyle ??
          theme.labelSmall.copyWith(color: theme.onPrimary);
    }
    return widget.timeStyle ??
        theme.labelSmall.copyWith(color: theme.onSurface);
  }

  Color? _resolveLinksDecorationColor(bool isSentByMe, _LocalTheme theme) {
    if (isSentByMe) {
      return widget.sentLinksDecorationColor ??
          widget.sentLinksColor ??
          theme.onPrimary;
    }
    return widget.receivedLinksDecorationColor ??
        widget.receivedLinksColor ??
        theme.onSurface;
  }
}

/// Internal extension for calculating the visual line height of a TextStyle.
extension on TextStyle {
  /// Calculates the line height based on the style's `height` and `fontSize`.
  double get lineHeight => (height ?? 1) * (fontSize ?? 0);
}

/// A widget to display the message timestamp and status indicator.
class TimeAndStatus extends StatelessWidget {
  /// The time the message was created.
  final DateTime? time;

  /// The status of the message.
  final MessageStatus? status;

  /// Whether to display the timestamp.
  final bool showTime;

  /// Whether to display the status indicator.
  final bool showStatus;

  /// The text style for the time and status.
  final TextStyle? textStyle;

  /// Creates a widget for displaying time and status.
  const TimeAndStatus({
    super.key,
    required this.time,
    this.status,
    this.showTime = true,
    this.showStatus = true,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = context.watch<DateFormat>();

    return Row(
      spacing: 2,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTime && time != null)
          Text(timeFormat.format(time!.toLocal()), style: textStyle),
        if (showStatus && status != null)
          if (status == MessageStatus.sending)
            SizedBox(
              width: 6.0,
              height: 6.0,
              child: CircularProgressIndicator(
                color: textStyle?.color,
                strokeWidth: 2,
              ),
            )
          else
            Icon(getIconForStatus(status!), color: textStyle?.color, size: 12),
      ],
    );
  }
}
