import 'package:flutter/material.dart';

/// Shared "liquid glass" design primitives: an ambient gradient backdrop,
/// a translucent glowing-edge card surface, a tactile press wrapper, and a
/// glass-styled toast/snackbar helper. Every screen composes from these
/// instead of plain Scaffold/Card so the whole app reads as one system.
///
/// Perf note: this deliberately avoids `BackdropFilter` (live blur)
/// everywhere. A handful of them stacked (icon row + card + sheet, all
/// animating at once during a sheet-open + keyboard transition) caused a
/// real ANR on-device. "Glass" here comes entirely from a translucent
/// tinted fill + a bright 1px border over the gradient [AppBackground],
/// which reads as glass without live-blurring anything every frame.
class AppGradients {
  AppGradients._();

  static const violet = Color(0xFF6366F1);
  static const purple = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);

  static const accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, purple, cyan],
  );
}

/// Fixed ambient gradient blobs painted behind a screen's scrollable
/// content. Cheap — soft radial-gradient stops, no live blur.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: base),
        Positioned(
          top: -140,
          left: -90,
          child: _Blob(color: AppGradients.violet, opacity: isDark ? 0.32 : 0.22, size: 340),
        ),
        Positioned(
          top: -70,
          right: -110,
          child: _Blob(color: AppGradients.cyan, opacity: isDark ? 0.26 : 0.18, size: 300),
        ),
        Positioned(
          bottom: -160,
          left: -70,
          child: _Blob(color: AppGradients.purple, opacity: isDark ? 0.22 : 0.14, size: 320),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double opacity;
  final double size;
  const _Blob({required this.color, required this.opacity, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// The default surface for content: a translucent, glowing-edge panel.
/// No live blur (see perf note above) — the tinted fill over
/// [AppBackground] is what reads as glass.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool blur;
  final double radius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.blur = true,
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.62);
    final border = isDark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.75);
    final shadow = isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.07);

    final decoration = BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: 1),
      boxShadow: [BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 10))],
    );

    final card = Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(padding: padding, decoration: decoration, child: child),
    );

    if (onTap == null) return card;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Container(padding: padding, decoration: decoration, child: child),
        ),
      ),
    );
  }
}

/// A translucent frosted app bar — the ONE `BackdropFilter` allowed per
/// screen (see perf note above).
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;

  const GlassAppBar({super.key, required this.title, this.actions, this.leading});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
      backgroundColor: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    );
  }
}

/// A pill-shaped, gradient-filled button used for primary CTAs.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: loading ? null : onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: onPressed == null ? null : AppGradients.accent,
          color: onPressed == null ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
          borderRadius: BorderRadius.circular(26),
          boxShadow: onPressed == null
              ? null
              : [BoxShadow(color: AppGradients.purple.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: Colors.white), const SizedBox(width: 8)],
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A small translucent circular glass button — used for the top icon row
/// and the secondary "Ingreso" FAB. No live blur (see perf note above).
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 38,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: isDark ? 0.09 : 0.65),
          border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.8)),
        ),
        child: Icon(icon, size: iconSize),
      ),
    );
  }
}

/// Wraps [child] with a tactile 0.94 scale-down on press, matching the
/// web app's `active:scale-[0.94]` button feedback.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const PressableScale({super.key, required this.child, required this.onTap});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 75),
        child: widget.child,
      ),
    );
  }
}

/// Glass-styled toast helper for confirming mutations across the app.
/// No live blur — see perf note above.
class AppToast {
  AppToast._();

  static void success(BuildContext context, String message) => _show(context, message, isError: false);
  static void error(BuildContext context, String message) => _show(context, message, isError: true);

  static void _show(BuildContext context, String message, {required bool isError}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: isDark ? 0.92 : 0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isError
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                size: 20,
                color: isError ? Colors.redAccent : AppGradients.purple,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a modal bottom sheet with a frosted-look glass container. No live
/// blur — see perf note above; the sheet opens over the dimmed barrier so
/// a solid tinted fill already reads as a distinct glass panel.
Future<T?> showGlassSheet<T>({required BuildContext context, required WidgetBuilder builder}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: isDark ? 0.97 : 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
        ),
      ),
      child: builder(ctx),
    ),
  );
}
