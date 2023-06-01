import 'dart:ui';
import 'package:flutter/material.dart';

class BlockingOverlay extends StatefulWidget {
  const BlockingOverlay({
    Key? key,
    required this.child,
    this.delay = const Duration(milliseconds: 500),
    this.progressIndicator = const CircularProgressIndicator(),
  }) : super(key: key);

  final Widget child;
  final Duration delay;
  final Widget progressIndicator;

  static BlockingOverlayState of(BuildContext context) {
    return context.findAncestorStateOfType<BlockingOverlayState>()!;
  }

  @override
  State<BlockingOverlay> createState() => BlockingOverlayState();
}

class BlockingOverlayState extends State<BlockingOverlay> {
  bool _isLoading = false;
  Widget _progressIndicator = const CircularProgressIndicator();
  Duration _delay = const Duration(milliseconds: 500);

  void show(Widget? progressIndicator, Duration? delay) {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _progressIndicator = progressIndicator ?? widget.progressIndicator;
        _delay = delay ?? widget.delay;
      });
    }
  }

  void hide() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLoading)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: const Opacity(
              opacity: 0.3,
              child: ModalBarrier(dismissible: false, color: Colors.black),
            ),
          ),
        if (_isLoading)
          Center(
            child: FutureBuilder(
              future: Future.delayed(_delay),
              builder: (context, snapshot) {
                return snapshot.connectionState == ConnectionState.done ? _progressIndicator : const SizedBox();
              },
            ),
          ),
      ],
    );
  }
}
