import 'package:flutter/material.dart';

class AnimatedTitle extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;

  const AnimatedTitle({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 1,
  });

  @override
  State<AnimatedTitle> createState() => _AnimatedTitleState();
}

class _AnimatedTitleState extends State<AnimatedTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _needsAnimation = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    // Verificar si necesita animación después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNeedsAnimation();
    });
  }

  void _checkIfNeedsAnimation() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      // Primero verificar si el texto completo cabe sin restricciones
      final fullTextPainter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        textDirection: TextDirection.ltr,
      );
      fullTextPainter.layout();
      
      // Luego verificar si se corta con el ancho disponible
      final constrainedTextPainter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: widget.maxLines,
        textDirection: TextDirection.ltr,
      );
      constrainedTextPainter.layout(maxWidth: renderBox.size.width);
      
      setState(() {
        _needsAnimation = fullTextPainter.width > renderBox.size.width;
      });
      
      if (_needsAnimation) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsAnimation) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          height: (widget.style?.fontSize ?? 16) * 1.4 * widget.maxLines,
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(-_animation.value * 100, 0.0),
                child: Text(
                  widget.text,
                  style: widget.style,
                  maxLines: widget.maxLines,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
