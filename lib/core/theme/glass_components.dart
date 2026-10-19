import 'dart:ui';
import 'package:flutter/material.dart';
import 'glass_theme.dart';

/// Reusable glassmorphic surface with backdrop blur, semi-transparent background,
/// thin border, and soft inner highlights.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color? color;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const GlassSurface({
    super.key,
    required this.child,
    this.blur = GlassTheme.blurStandard,
    this.color,
    this.borderRadius,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.constraints,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(GlassTheme.radiusMd);
    final effectiveColor = color ?? GlassTheme.surfaceGlass;
    final effectiveBorder = borderColor ?? GlassTheme.borderSubtle;

    Widget surface = ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          constraints: constraints,
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: effectiveRadius,
            border: Border.all(color: effectiveBorder, width: borderWidth),
            boxShadow: shadows ?? [
              BoxShadow(
                color: Colors.black.withAlpha(45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        child: surface,
      );
    }

    return surface;
  }
}

/// A horizontal glass toolbar for browser navigation bars, tab bars, and control headers.
class GlassToolbar extends StatelessWidget implements PreferredSizeWidget {
  final Widget child;
  final double height;
  final Color? color;
  final double blur;
  final bool borderBottom;
  final bool borderTop;
  final EdgeInsetsGeometry padding;

  const GlassToolbar({
    super.key,
    required this.child,
    this.height = 54.0,
    this.color,
    this.blur = GlassTheme.blurStandard,
    this.borderBottom = true,
    this.borderTop = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? GlassTheme.surfaceGlassDense,
            border: Border(
              bottom: borderBottom
                  ? const BorderSide(color: GlassTheme.borderSubtle, width: 1.0)
                  : BorderSide.none,
              top: borderTop
                  ? const BorderSide(color: GlassTheme.borderSubtle, width: 1.0)
                  : BorderSide.none,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A refined glass icon button with hover highlight and compact touch target.
class GlassIconButton extends StatefulWidget {
  final Widget icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? hoverColor;
  final bool isActive;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.size = 32.0,
    this.iconSize = 18.0,
    this.color,
    this.hoverColor,
    this.isActive = false,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    final backgroundColor = widget.isActive
        ? GlassTheme.accentTea.withAlpha(45)
        : (_isHovered
            ? (widget.hoverColor ?? GlassTheme.surfaceGlassHover)
            : (widget.color ?? Colors.transparent));

    final borderColor = widget.isActive
        ? GlassTheme.accentTea.withAlpha(120)
        : (_isHovered ? GlassTheme.borderHighlight : Colors.transparent);

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: GlassTheme.animFast,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
          child: Center(
            child: IconTheme(
              data: IconThemeData(
                size: widget.iconSize,
                color: isEnabled
                    ? (widget.isActive
                        ? GlassTheme.accentTea
                        : (_isHovered ? Colors.white : GlassTheme.textPrimary))
                    : GlassTheme.textMuted.withAlpha(120),
              ),
              child: widget.icon,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      button = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: button,
      );
    }

    return button;
  }
}

/// A glassmorphic card for quick access links, evidence records, and settings cards.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double blur;
  final BorderRadius? borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    this.blur = GlassTheme.blurLow,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      onTap: onTap,
      margin: margin,
      padding: padding,
      color: color ?? GlassTheme.surfaceGlass,
      borderColor: borderColor ?? GlassTheme.borderSubtle,
      blur: blur,
      borderRadius: borderRadius ?? BorderRadius.circular(GlassTheme.radiusMd),
      child: child,
    );
  }
}

/// Ambient mesh canvas background with deep obsidian base and subtle glowing orbs.
/// Gives true translucent glass surfaces rich light refraction and high-end depth.
class AmbientCanvasBackground extends StatelessWidget {
  final Widget child;

  const AmbientCanvasBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GlassTheme.backgroundDeep,
        gradient: RadialGradient(
          center: Alignment(-0.8, -0.9),
          radius: 1.4,
          colors: [
            Color(0x1F7DD3FC), // Subtle icy blue ambient glow
            Color(0x000C0D11), // Fades to deep obsidian
          ],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.9, -0.7),
            radius: 1.2,
            colors: [
              Color(0x1AD48B47), // Soft brand tea-amber ambient glow
              Color(0x000C0D11),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A floating frosted glass dock for iOS and Android mobile navigation.
class GlassDock extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final double height;

  const GlassDock({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(left: 14, right: 14, bottom: 12),
    this.height = 58.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassTheme.blurHeavy,
            sigmaY: GlassTheme.blurHeavy,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: GlassTheme.surfaceGlassDense,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: GlassTheme.borderHighlight,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(70),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

