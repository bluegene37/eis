// Gene - Nov, 20, 2026: Reusable Soft UI 2.0 neumorphic containers, recessed wells, icon squircles, and tactile pills.
import 'package:material_ui/material_ui.dart';
import '../theme/eis_neumorphic_theme.dart';

/// Elevation profile for [NeumorphicSurface].
enum NeumorphicDepth { raised, subtle, inset, flat }

/// Builds a [BoxDecoration] using [EisNeumorphicTokens] for a given [depth].
BoxDecoration buildNeumorphicDecoration({
  required EisNeumorphicTokens tokens,
  NeumorphicDepth depth = NeumorphicDepth.raised,
  double borderRadius = 18.0,
  Color? tintColor,
  Color? borderColor,
}) {
  final radius = BorderRadius.circular(borderRadius);

  Color blendTint(Color base, double amount) {
    if (tintColor == null) return base;
    return Color.lerp(base, tintColor, amount) ?? base;
  }

  switch (depth) {
    case NeumorphicDepth.raised:
      return BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            blendTint(tokens.surfaceElevated, 0.06),
            blendTint(tokens.surface, 0.04),
          ],
        ),
        border: Border.all(color: borderColor ?? tokens.borderHighlight),
        boxShadow: [
          BoxShadow(
            color: tokens.shadowLight,
            offset: const Offset(-6, -6),
            blurRadius: 14,
          ),
          BoxShadow(
            color: tokens.shadowDark,
            offset: const Offset(6, 6),
            blurRadius: 14,
          ),
        ],
      );
    case NeumorphicDepth.subtle:
      return BoxDecoration(
        borderRadius: radius,
        color: blendTint(tokens.surface, 0.06),
        border: Border.all(color: borderColor ?? tokens.borderHighlight),
        boxShadow: [
          BoxShadow(
            color: tokens.shadowLight,
            offset: const Offset(-3, -3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: tokens.shadowDark,
            offset: const Offset(3, 3),
            blurRadius: 8,
          ),
        ],
      );
    case NeumorphicDepth.inset:
      final topDark =
          Color.lerp(tokens.surfaceRecessed, tokens.shadowDark, 0.14) ??
              tokens.surfaceRecessed;
      final bottomLight =
          Color.lerp(tokens.surfaceRecessed, tokens.shadowLight, 0.12) ??
              tokens.surfaceRecessed;
      return BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            blendTint(topDark, 0.05),
            blendTint(tokens.surfaceRecessed, 0.04),
            blendTint(bottomLight, 0.04),
          ],
        ),
        border: Border.all(color: borderColor ?? tokens.borderSubtle),
      );
    case NeumorphicDepth.flat:
      return BoxDecoration(
        borderRadius: radius,
        color: blendTint(tokens.surface, 0.05),
        border: Border.all(color: borderColor ?? tokens.borderSubtle),
      );
  }
}

/// Tactile neumorphic surface container supporting raised, subtle, inset, and flat profiles.
class NeumorphicSurface extends StatelessWidget {
  final Widget child;
  final NeumorphicDepth depth;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? tintColor;
  final Color? borderColor;

  const NeumorphicSurface({
    super.key,
    required this.child,
    this.depth = NeumorphicDepth.raised,
    this.borderRadius = 18.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tintColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = EisNeumorphicTokens.of(context);
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: buildNeumorphicDecoration(
        tokens: tokens,
        depth: depth,
        borderRadius: borderRadius,
        tintColor: tintColor,
        borderColor: borderColor,
      ),
      child: child,
    );
  }
}

/// Recessed debossed container for data tables, code consoles, and summary metrics.
class NeumorphicWell extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? tintColor;

  const NeumorphicWell({
    super.key,
    required this.child,
    this.borderRadius = 14.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicSurface(
      depth: NeumorphicDepth.inset,
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      tintColor: tintColor,
      child: child,
    );
  }
}

/// Sculpted squircle icon badge with soft accent tint and subtle neumorphic depth.
class NeumorphicIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double iconSize;

  const NeumorphicIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = EisNeumorphicTokens.of(context);
    final accent = color ?? tokens.accentPrimary;
    return NeumorphicSurface(
      depth: NeumorphicDepth.subtle,
      width: size,
      height: size,
      borderRadius: size * 0.32,
      tintColor: accent,
      borderColor: accent.withValues(alpha: 0.25),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: accent,
        ),
      ),
    );
  }
}

/// Interactive pill that animates from subtle raised elevation to inset depth on press.
class NeumorphicTapPill extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? tintColor;

  const NeumorphicTapPill({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.borderRadius = 14,
    this.tintColor,
  });

  @override
  State<NeumorphicTapPill> createState() => _NeumorphicTapPillState();
}

class _NeumorphicTapPillState extends State<NeumorphicTapPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = EisNeumorphicTokens.of(context);
    final pill = MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.onTap != null
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel: widget.onTap != null
            ? () => setState(() => _pressed = false)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: buildNeumorphicDecoration(
            tokens: tokens,
            depth: _pressed ? NeumorphicDepth.inset : NeumorphicDepth.subtle,
            borderRadius: widget.borderRadius,
            tintColor: widget.tintColor,
          ),
          child: widget.child,
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      return Tooltip(message: widget.tooltip!, child: pill);
    }
    return pill;
  }
}
