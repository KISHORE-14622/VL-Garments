import 'package:flutter/material.dart';

class VLLoadingIndicator extends StatefulWidget {
  final String message;
  
  const VLLoadingIndicator({
    super.key, 
    this.message = 'Loading...',
  });

  @override
  State<VLLoadingIndicator> createState() => _VLLoadingIndicatorState();
}

class _VLLoadingIndicatorState extends State<VLLoadingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withOpacity(0.4 * _opacityAnimation.value),
                          blurRadius: 30 * _scaleAnimation.value,
                          spreadRadius: 8 * _scaleAnimation.value,
                          offset: const Offset(-5, 5),
                        ),
                        BoxShadow(
                          color: const Color(0xFF9B59B6).withOpacity(0.4 * _opacityAnimation.value),
                          blurRadius: 30 * _scaleAnimation.value,
                          spreadRadius: 8 * _scaleAnimation.value,
                          offset: const Offset(5, -5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          // Animated gradient text
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    foreground: Paint()..shader = const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF9B59B6)],
                    ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
