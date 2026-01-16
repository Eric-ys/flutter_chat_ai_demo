import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';

/// 图片预览页面，支持手势放大和下滑关闭
class ImageViewer extends StatefulWidget {
  final String imagePath;
  final ImageProvider? imageProvider;

  const ImageViewer({super.key, required this.imagePath, this.imageProvider});

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer>
    with SingleTickerProviderStateMixin {
  late PhotoViewController _controller;
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = PhotoViewController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) {
      _isDragging = true;
    }
    setState(() {
      _dragOffset += details.delta.dy;
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final shouldDismiss =
        _dragOffset.abs() > 100 || details.velocity.pixelsPerSecond.dy > 500;

    if (shouldDismiss) {
      _animationController.reverse().then((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } else {
      setState(() {
        _dragOffset = 0;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider =
        widget.imageProvider ??
        (widget.imagePath.startsWith('http')
            ? NetworkImage(widget.imagePath)
            : FileImage(File(widget.imagePath)) as ImageProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final opacity = 1.0 - (_dragOffset.abs() / 300).clamp(0.0, 1.0);
            final scale = 1.0 - (_dragOffset.abs() / 500).clamp(0.0, 0.3);

            return Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity * _animation.value,
                  child: Stack(
                    children: [
                      Center(
                        child: PhotoView(
                          imageProvider: imageProvider,
                          controller: _controller,
                          backgroundDecoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 2,
                          initialScale: PhotoViewComputedScale.contained,
                        ),
                      ),
                      // 顶部关闭按钮
                      SafeArea(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              _animationController.reverse().then((_) {
                                if (mounted) {
                                  Navigator.of(context).pop();
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
