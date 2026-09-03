import 'dart:math';
import 'package:flutter/material.dart';

class ShakeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;
  final Curve curve;
  final ShakeController controller;

  const ShakeWidget({
    super.key,
    required this.child,
    required this.controller,
    this.duration = const Duration(milliseconds: 500),
    this.offset = 10.0,
    this.curve = Curves.bounceOut,
  });

  @override
  ShakeWidgetState createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: widget.curve))
        .animate(_controller);
    
    widget.controller.addListener(_shake);
  }

  void _shake() {
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_shake);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final double sineValue = sin(4 * pi * _animation.value);
        return Transform.translate(
          offset: Offset(sineValue * widget.offset, 0),
          child: child,
        );
      },
    );
  }
}

class ShakeController extends ChangeNotifier {
  void shake() {
    notifyListeners();
  }
}
