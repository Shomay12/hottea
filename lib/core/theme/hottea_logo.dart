import 'package:flutter/material.dart';
import 'glass_theme.dart';

/// The official HotTea logo widget.
///
/// Faithfully reproduces the exact SVG vector geometry from the official
/// HotTea website (`hottea-website/index.html`):
/// - Teacup body with rounded base
/// - Right-side circular handle
/// - Three rising steam lines
///
/// Renders as high-precision vector art with anti-aliasing on all displays.
class HotTeaLogo extends StatelessWidget {
  /// The width and height of the square logo bounds.
  final double size;

  /// The stroke color of the logo. Defaults to the official brand amber (#D48B47).
  final Color? color;

  /// Stroke width multiplier. Base is 2.0 on a 24x24 coordinate grid.
  final double strokeWidth;

  const HotTeaLogo({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? GlassTheme.accentTea;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HotTeaLogoPainter(
          color: effectiveColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _HotTeaLogoPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _HotTeaLogoPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.save();
    canvas.scale(scale, scale);

    // 1. Teacup Body: M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z
    final bodyPath = Path();
    bodyPath.moveTo(2, 8);
    bodyPath.lineTo(18, 8);
    bodyPath.lineTo(18, 17);
    bodyPath.arcToPoint(
      const Offset(14, 21),
      radius: const Radius.circular(4),
      clockwise: true,
    );
    bodyPath.lineTo(6, 21);
    bodyPath.arcToPoint(
      const Offset(2, 17),
      radius: const Radius.circular(4),
      clockwise: true,
    );
    bodyPath.close();
    canvas.drawPath(bodyPath, paint);

    // 2. Teacup Handle: M18 8h1a4 4 0 0 1 0 8h-1
    final handlePath = Path();
    handlePath.moveTo(18, 8);
    handlePath.lineTo(19, 8);
    handlePath.arcToPoint(
      const Offset(19, 16),
      radius: const Radius.circular(4),
      clockwise: true,
    );
    handlePath.lineTo(18, 16);
    canvas.drawPath(handlePath, paint);

    // 3. Three Steam Lines:
    // line x1="6" y1="1" x2="6" y2="4"
    // line x1="10" y1="1" x2="10" y2="4"
    // line x1="14" y1="1" x2="14" y2="4"
    canvas.drawLine(const Offset(6, 1), const Offset(6, 4), paint);
    canvas.drawLine(const Offset(10, 1), const Offset(10, 4), paint);
    canvas.drawLine(const Offset(14, 1), const Offset(14, 4), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HotTeaLogoPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Official brand header badge combining the HotTea logo, exact name, and glass styling.
class HotTeaBrandBadge extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final bool showBadge;
  final VoidCallback? onTap;

  const HotTeaBrandBadge({
    super.key,
    this.logoSize = 18.0,
    this.fontSize = 14.0,
    this.showBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: GlassTheme.accentTea.withAlpha(28),
        borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
        border: Border.all(color: GlassTheme.accentTea.withAlpha(90), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HotTeaLogo(size: logoSize),
          const SizedBox(width: 8),
          Text(
            'HotTea',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
              letterSpacing: -0.2,
              color: GlassTheme.textPrimary,
            ),
          ),
          if (showBadge) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: GlassTheme.accentTea.withAlpha(40),
                borderRadius: BorderRadius.circular(GlassTheme.radiusFull),
                border: Border.all(color: GlassTheme.accentTea.withAlpha(80), width: 0.8),
              ),
              child: const Text(
                'Open Source',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: GlassTheme.accentTea,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
        child: badge,
      );
    }
    return badge;
  }
}
