import 'package:flutter/material.dart';

/// 全局可拖动的悬浮按钮（类似 iPhone AssistiveTouch）
///
/// 特性：
/// - 可在整个 App 内的任何页面显示
/// - 支持自由拖动
/// - 拖动结束后自动吸附到屏幕边缘
/// - 半透明设计，不影响内容查看
///
/// 使用方式：
/// ```dart
/// // 在 MaterialApp 外层包裹
/// DraggableFloatingButton(
///   child: MaterialApp(...),
///   button: FloatingButton(
///     icon: Icons.translate,
///     onTap: () => print('翻译'),
///   ),
/// )
/// ```
class DraggableFloatingButton extends StatefulWidget {
  /// 主应用内容
  final Widget child;

  /// 悬浮按钮配置
  final FloatingButton button;

  /// 初始位置（相对于屏幕右侧的偏移）
  final Offset? initialPosition;

  const DraggableFloatingButton({
    super.key,
    required this.child,
    required this.button,
    this.initialPosition,
  });

  @override
  State<DraggableFloatingButton> createState() =>
      _DraggableFloatingButtonState();
}

class _DraggableFloatingButtonState extends State<DraggableFloatingButton> {
  @override
  Widget build(BuildContext context) {
    // 直接使用 Stack 叠加，避免使用 Positioned.fill 导致 parent data dirty 错误
    return Stack(
      fit: StackFit.expand,
      children: [
        // 主应用内容（MaterialApp）
        widget.child,
        // 悬浮按钮覆盖层 - 不使用 Positioned，让它自然布局
        IgnorePointer(
          ignoring: true, // 默认忽略触摸，让事件传递到下层
          child: ExcludeSemantics(
            child: Stack(
              children: [
                IgnorePointer(
                  ignoring: false, // 悬浮按钮本身接收触摸
                  child: _DraggableButton(
                    button: widget.button,
                    initialPosition: widget.initialPosition,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 可拖动的悬浮按钮实现
class _DraggableButton extends StatefulWidget {
  final FloatingButton button;
  final Offset? initialPosition;

  const _DraggableButton({required this.button, this.initialPosition});

  @override
  State<_DraggableButton> createState() => _DraggableButtonState();
}

class _DraggableButtonState extends State<_DraggableButton>
    with SingleTickerProviderStateMixin {
  static const double _buttonSize = 56.0;
  Offset? _basePosition; // 基础位置（固定不变），null 表示尚未初始化
  Offset _dragOffset = Offset.zero; // 拖动偏移量
  bool _isDragging = false;
  late AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化吸附动画控制器
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在这里初始化位置，此时可以安全访问 MediaQuery
    if (_basePosition == null) {
      _initializePosition();
    }
  }

  void _initializePosition() {
    final screenSize = MediaQuery.of(context).size;
    final initialPos =
        widget.initialPosition ??
        Offset(screenSize.width - _buttonSize - 16.0, 100);

    setState(() {
      _basePosition = initialPos;
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  /// 开始拖动
  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      // 取消正在进行的动画
      _snapController.stop();
    });
  }

  /// 拖动中 - 只更新偏移量，不改变基础位置
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  /// 拖动结束 - 吸附到边缘
  void _onPanEnd(DragEndDetails details) {
    if (_basePosition == null) return;
    final currentPosition = _basePosition! + _dragOffset;

    setState(() {
      _isDragging = false;
    });

    // 计算屏幕尺寸
    final screenSize = MediaQuery.of(context).size;

    // 计算目标位置（吸附到最近的边缘）
    final targetX = currentPosition.dx < screenSize.width / 2
        ? 16.0 // 左边缘
        : screenSize.width - _buttonSize - 16.0; // 右边缘

    // 限制 Y 轴范围
    final targetY = currentPosition.dy.clamp(
      MediaQuery.of(context).padding.top + 16.0,
      screenSize.height -
          _buttonSize -
          MediaQuery.of(context).padding.bottom -
          16.0,
    );

    final targetPosition = Offset(targetX, targetY);

    // 创建吸附动画 - 从当前偏移量动画到目标位置
    _snapAnimation =
        Tween<Offset>(
            begin: _dragOffset,
            end: targetPosition - _basePosition!,
          ).animate(
            CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
          )
          ..addListener(() {
            if (mounted) {
              setState(() {
                _dragOffset = _snapAnimation!.value;
              });
            }
          });

    // 动画结束后更新基础位置
    _snapController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _basePosition = targetPosition;
          _dragOffset = Offset.zero;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 等待位置初始化完成
    if (_basePosition == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Positioned(
        left: _basePosition!.dx,
        top: _basePosition!.dy,
        child: RepaintBoundary(
          child: Transform.translate(
            offset: _dragOffset,
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onTap: widget.button.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _buttonSize,
                height: _buttonSize,
                decoration: BoxDecoration(
                  color: widget.button.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isDragging ? 0.4 : 0.2),
                      blurRadius: _isDragging ? 12 : 8,
                      spreadRadius: _isDragging ? 2 : 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    widget.button.icon,
                    color: widget.button.iconColor,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 悬浮按钮配置
class FloatingButton {
  /// 按钮图标
  final IconData icon;

  /// 点击回调
  final VoidCallback onTap;

  /// 按钮颜色
  final Color color;

  /// 图标颜色
  final Color iconColor;

  const FloatingButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.blue,
    this.iconColor = Colors.white,
  });
}
