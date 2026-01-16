import 'package:flutter/material.dart';

/// 简单的可拖动悬浮按钮
///
/// 直接渲染在屏幕上，不依赖 Overlay
class SimpleDraggableButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;
  final Offset? initialPosition; // 初始位置（用于恢复上次位置）
  final ValueChanged<Offset>? onPositionChanged; // 位置变化回调

  const SimpleDraggableButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = Colors.blue,
    this.iconColor = Colors.white,
    this.initialPosition,
    this.onPositionChanged,
  });

  @override
  State<SimpleDraggableButton> createState() => _SimpleDraggableButtonState();
}

class _SimpleDraggableButtonState extends State<SimpleDraggableButton>
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

    debugPrint('🎈 SimpleDraggableButton initState - initialPosition: ${widget.initialPosition}');

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
      debugPrint('🎈 SimpleDraggableButton 初始化位置...');
      _initializePosition();
    }
  }

  void _initializePosition() {
    final screenSize = MediaQuery.of(context).size;
    
    // 如果提供了初始位置，使用它；否则使用默认右侧位置
    final initialPos = widget.initialPosition ??
        Offset(screenSize.width - _buttonSize - 16.0, 100);

    debugPrint('🎈 初始化位置为: $initialPos');

    if (mounted) {
      setState(() {
        _basePosition = initialPos;
      });
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  /// 获取当前位置（用于保存）
  Offset get currentPosition =>
      _basePosition != null ? _basePosition! + _dragOffset : Offset.zero;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _snapController.stop(); // 取消正在进行的动画
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_basePosition == null) return;
    
    final currentPosition = _basePosition! + _dragOffset;

    setState(() {
      _isDragging = false;
    });

    final screenSize = MediaQuery.of(context).size;

    // 吸附到最近的边缘
    final targetX = currentPosition.dx < screenSize.width / 2
        ? 16.0
        : screenSize.width - _buttonSize - 16.0;

    final targetY = currentPosition.dy.clamp(
      MediaQuery.of(context).padding.top + 16.0,
      screenSize.height -
          _buttonSize -
          MediaQuery.of(context).padding.bottom -
          16.0,
    );

    final targetPosition = Offset(targetX, targetY);

    _snapAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: targetPosition - _basePosition!,
    ).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
    )..addListener(() {
        if (mounted) {
          setState(() {
            _dragOffset = _snapAnimation!.value;
          });
        }
      });

    _snapController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _basePosition = targetPosition;
          _dragOffset = Offset.zero;
        });
        // 吸附完成后，通知父组件位置变化
        widget.onPositionChanged?.call(_basePosition!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 等待位置初始化完成
    if (_basePosition == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _basePosition!.dx,
      top: _basePosition!.dy,
      child: RepaintBoundary(
        child: Transform.translate(
          offset: _dragOffset,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _buttonSize,
              height: _buttonSize,
              decoration: BoxDecoration(
                color: widget.color,
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
                child: Icon(widget.icon, color: widget.iconColor, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
