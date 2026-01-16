import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'basic.dart';
import 'inference/model_file_setup.dart';
import 'local.dart';
import 'pagination_newer.dart';
import 'pagination_older.dart';
import 'widgets/simple_draggable_button.dart';
import 'widgets/function_menu_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 确保Flutter绑定已初始化
  await initializeDateFormatting(); // 日期本地化
  await dotenv.load(); // 加载环境变量
  await Hive.initFlutter();
  await Hive.openBox('chat');

  // 检查并准备模型文件（仅 Android 平台）
  if (Platform.isAndroid) {
    try {
      await ModelFileSetup.ensureModelFile();
    } catch (e) {
      print('❌ 模型文件设置失败: $e');
      // 注意：这里可以选择是否阻止应用启动
      // 如果模型文件是必需的，可以取消注释下面的代码以阻止启动
      // throw e;
    }
  }

  runApp(FlyerChat());
}

class FlyerChat extends StatefulWidget {
  const FlyerChat({super.key});

  @override
  State<FlyerChat> createState() => _FlyerChatState();
}

class _FlyerChatState extends State<FlyerChat> {
  Offset? _savedFloatingButtonPosition; // 保存的悬浮球位置
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey _floatingButtonKey = GlobalKey(); // 悬浮球的 GlobalKey，确保状态保持
  OverlayEntry? _floatingButtonOverlay; // Overlay 入口
  bool _overlayInserted = false; // 是否已插入 Overlay
  final ValueNotifier<bool> _showFloatingButtonNotifier = ValueNotifier<bool>(
    true,
  );

  // 聊天页面缓存，避免每次进入都重新创建
  Local? _cachedChatPage;
  Dio? _cachedDio;
  final GlobalKey _cachedChatPageKey = GlobalKey(); // 用于保持页面状态
  bool _isPreloadingChatPage = false; // 是否正在预加载聊天页面

  @override
  void dispose() {
    _removeFloatingButton();
    _showFloatingButtonNotifier.dispose();
    super.dispose();
  }

  /// 插入悬浮球到 Overlay（如果需要）
  void _insertFloatingButtonIfNeeded() {
    if (_overlayInserted || !mounted) return;

    // 使用 navigatorKey.currentState 直接获取 NavigatorState
    final navigatorState = _navigatorKey.currentState;

    if (navigatorState == null) {
      // 如果 NavigatorState 还未准备好，延迟重试
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_overlayInserted) {
          _insertFloatingButtonIfNeeded();
        }
      });
      return;
    }

    // 直接访问 NavigatorState.overlay
    final overlay = navigatorState.overlay;
    if (overlay == null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_overlayInserted) {
          _insertFloatingButtonIfNeeded();
        }
      });
      return;
    }

    try {
      _floatingButtonOverlay = OverlayEntry(
        builder: (context) => _FloatingButtonWidget(
          buttonKey: _floatingButtonKey,
          showNotifier: _showFloatingButtonNotifier,
          initialPosition: _savedFloatingButtonPosition,
          onTap: _openFunctionMenu,
          onPositionChanged: _saveFloatingButtonPosition,
        ),
      );

      overlay.insert(_floatingButtonOverlay!);
      _overlayInserted = true;
      debugPrint('✅ 悬浮球已插入到 Overlay');
    } catch (e) {
      debugPrint('❌ 插入悬浮球失败: $e');
    }
  }

  /// 移除悬浮球
  void _removeFloatingButton() {
    if (_overlayInserted && _floatingButtonOverlay != null) {
      _floatingButtonOverlay?.remove();
      _floatingButtonOverlay?.dispose();
      _floatingButtonOverlay = null;
      _overlayInserted = false;
      debugPrint('✅ 悬浮球已移除');
    }
  }

  /// 切换悬浮球显示/隐藏
  void _toggleFloatingButton() {
    _showFloatingButtonNotifier.value = !_showFloatingButtonNotifier.value;
  }

  /// 保存悬浮球位置
  void _saveFloatingButtonPosition(Offset position) {
    _savedFloatingButtonPosition = position;
  }

  /// 打开功能菜单
  void _openFunctionMenu() {
    // 获取当前 context（从 MaterialApp 的 navigatorKey）
    final context = _navigatorKey.currentContext;
    if (context != null) {
      // 打开菜单时隐藏悬浮球
      _showFloatingButtonNotifier.value = false;

      showDialog(
        context: context,
        builder: (context) => const FunctionMenuDialog(),
      ).then((_) {
        // 关闭菜单后恢复显示悬浮球
        _showFloatingButtonNotifier.value = true;
      });
    }
  }

  /// 预加载聊天页面（在应用启动后立即执行，提前准备页面）
  void _preloadChatPage() {
    if (_isPreloadingChatPage || _cachedChatPage != null) return;

    _isPreloadingChatPage = true;
    // 立即开始预加载，不延迟
    // 使用微任务确保不阻塞当前帧
    Future.microtask(() {
      if (!mounted) {
        _isPreloadingChatPage = false;
        return;
      }

      // 创建一个临时的 Dio 实例用于预加载（实际使用时会被替换）
      final tempDio = Dio();
      if (Platform.isAndroid || Platform.isIOS) {
        (tempDio.httpClientAdapter as IOHttpClientAdapter).createHttpClient =
            () {
              final client = HttpClient();
              client.badCertificateCallback = (_, __, ___) => true;
              return client;
            };
      }

      // 预创建页面实例
      _cachedDio = tempDio;
      _cachedChatPage = Local(key: _cachedChatPageKey, dio: tempDio);
      debugPrint('✅ 聊天页面预加载完成（提前准备）');
      _isPreloadingChatPage = false;
    });
  }

  /// 导航到聊天页面（使用缓存的页面实例）
  void _navigateToChat(Dio dio) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    // 如果 Dio 实例变化，需要更新缓存的页面
    if (_cachedDio != dio) {
      _cachedDio = dio;
      // 如果页面已存在，需要重新创建（因为 Dio 变化了）
      if (_cachedChatPage != null) {
        _cachedChatPage = Local(key: _cachedChatPageKey, dio: dio);
        debugPrint('✅ 重新创建聊天页面实例（Dio 变化）');
      } else {
        _cachedChatPage = Local(key: _cachedChatPageKey, dio: dio);
        debugPrint('✅ 创建新的聊天页面实例（首次使用）');
      }
    } else if (_cachedChatPage == null) {
      // 如果页面未创建，立即创建
      _cachedChatPage = Local(key: _cachedChatPageKey, dio: dio);
      debugPrint('✅ 创建新的聊天页面实例（预加载未完成）');
    } else {
      debugPrint('✅ 复用缓存的聊天页面实例（快速打开）');
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _cachedChatPage!,
        transitionDuration: Duration.zero, // 禁用页面切换动画，立即显示
        reverseTransitionDuration: Duration.zero, // 禁用返回动画
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Flyer Chat',
      theme:
          ThemeData.from(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
              brightness: Brightness.light,
            ),
          ).copyWith(
            textSelectionTheme: const TextSelectionThemeData(
              selectionColor: Color(0x660000FF),
              cursorColor: Color(0xFF0000FF),
              selectionHandleColor: Color(0xFF0000FF),
            ),
          ),
      darkTheme:
          ThemeData.from(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
              brightness: Brightness.dark,
            ),
          ).copyWith(
            textSelectionTheme: const TextSelectionThemeData(
              selectionColor: Color(0x660000FF),
              cursorColor: Color(0xFF0000FF),
              selectionHandleColor: Color(0xFF0000FF),
            ),
          ),
      home: ValueListenableBuilder<bool>(
        valueListenable: _showFloatingButtonNotifier,
        builder: (context, showFloatingButton, child) {
          return FlyerChatHomePage(
            onFloatingButtonToggle: _toggleFloatingButton,
            showFloatingButton: showFloatingButton,
            onNavigateToChat: _navigateToChat,
          );
        },
      ),
      // 使用 builder 注入悬浮球管理器
      builder: (context, child) {
        // 立即预加载聊天页面（不等待 postFrameCallback）
        _preloadChatPage();

        if (!_overlayInserted) {
          // 在首次构建后插入悬浮球到 Overlay（所有平台）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _insertFloatingButtonIfNeeded();
          });
        }
        return child!;
      },
    );
  }
}

/// 悬浮球 Widget（使用 StatelessWidget，完全由 SimpleDraggableButton 管理状态）
class _FloatingButtonWidget extends StatelessWidget {
  final GlobalKey buttonKey;
  final ValueNotifier<bool> showNotifier;
  final Offset? initialPosition;
  final VoidCallback onTap;
  final ValueChanged<Offset> onPositionChanged;

  const _FloatingButtonWidget({
    required this.buttonKey,
    required this.showNotifier,
    required this.initialPosition,
    required this.onTap,
    required this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 使用 ValueListenableBuilder 监听显示状态
    return ValueListenableBuilder<bool>(
      valueListenable: showNotifier,
      builder: (context, show, child) {
        // 使用 Visibility 保持 widget 状态，只是隐藏/显示
        return Visibility(
          visible: show,
          maintainState: true, // 保持状态
          maintainAnimation: true,
          maintainSize: false,
          child: child!,
        );
      },
      child: RepaintBoundary(
        child: ExcludeSemantics(
          child: Stack(
            children: [
              SimpleDraggableButton(
                key: buttonKey, // 使用 GlobalKey 确保状态永久保持
                icon: Icons.apps,
                onTap: onTap,
                color: Colors.blue,
                iconColor: Colors.white,
                initialPosition: initialPosition,
                onPositionChanged: onPositionChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FlyerChatHomePage extends StatefulWidget {
  /// 悬浮球切换回调
  final VoidCallback onFloatingButtonToggle;

  /// 悬浮球是否显示
  final bool showFloatingButton;

  /// 导航到聊天页面的回调
  final void Function(Dio dio) onNavigateToChat;

  const FlyerChatHomePage({
    super.key,
    required this.onFloatingButtonToggle,
    required this.showFloatingButton,
    required this.onNavigateToChat,
  });

  @override
  State<FlyerChatHomePage> createState() => _FlyerChatHomePageState();
}

class _FlyerChatHomePageState extends State<FlyerChatHomePage> {
  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = Dio();
    // 配置 Dio 以允许自签名证书（仅用于开发环境）
    // 注意：生产环境应该使用正确的证书验证
    if (Platform.isAndroid || Platform.isIOS) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
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
  }

  final _chatIdController = TextEditingController(
    text: dotenv.env['DEFAULT_CHAT_ID'] ?? '',
  );
  final _geminiApiKeyController = TextEditingController(
    text: dotenv.env['GEMINI_API_KEY'] ?? '',
  );

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _chatIdController.dispose();
    _dio.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  // 使用缓存的页面实例，避免每次重新创建
                  widget.onNavigateToChat(_dio);
                },
                child: const Text("Let's begin"),
              ),
              const SizedBox(
                width: 200,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Colors.grey, thickness: 1),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PaginationOlder(),
                    ),
                  );
                },
                child: const Text('pagination (get older)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PaginationNewer(),
                  ),
                ),
                child: const Text('pagination (get newer)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (context) => Basic()));
                },
                child: const Text('basic'),
              ),
              // 【新增】悬浮球显示控制（Android 专用）
              if (Platform.isAndroid) ...[
                const SizedBox(
                  width: 200,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Colors.grey, thickness: 1),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onFloatingButtonToggle,
                  icon: Icon(
                    widget.showFloatingButton
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: widget.showFloatingButton
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  label: Text(widget.showFloatingButton ? '隐藏悬浮球' : '显示悬浮球'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '💡 提示：悬浮球可拖动到任意位置',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
      // 【已移除】原有的 FloatingActionButton
      // 改用全局可拖动的悬浮球（在 FlyerChat 中实现）
    );
  }
}
