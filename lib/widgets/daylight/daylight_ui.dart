/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/daylight.dart';

/// The daylight ground that sits behind every route.
class DaylightBackdrop extends StatelessWidget {
  const DaylightBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: Daylight.screenGradient),
      child: child,
    );
  }
}

/// Concentric-circle brand mark from the concept board.
class DaylightBrandMark extends StatelessWidget {
  const DaylightBrandMark({this.size = 20, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BrandMarkPainter(color ?? Daylight.cobalt),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075;
    final inner = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055;
    final dot = Paint()..color = color;

    canvas.drawCircle(center, size.width / 2 - 1, outer);
    canvas.drawCircle(center, size.width * 0.28, inner);
    canvas.drawCircle(center, size.width * 0.09, dot);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// App bar used across the daylight screens.
class DaylightAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DaylightAppBar({
    this.title,
    this.overline,
    this.brand = false,
    this.actions,
    this.showBack = false,
    this.onBack,
    this.height = 62,
    super.key,
  });

  final String? title;
  final String? overline;
  final bool brand;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final leading = <Widget>[];
    if (showBack) {
      leading.add(
        DaylightCircleButton(
          icon: FluentIcons.chevron_left_24_regular,
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          size: 36,
          iconSize: 19,
        ),
      );
      leading.add(const SizedBox(width: 10));
    }

    Widget heading;
    if (brand) {
      heading = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DaylightBrandMark(size: 20),
          const SizedBox(width: 7),
          Text(
            'Musify',
            style: Daylight.display(20, height: 1, letterSpacing: -0.4),
          ),
        ],
      );
    } else if (title != null) {
      heading = Text(
        title!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Daylight.display(24, height: 1.05),
      );
    } else if (overline != null) {
      heading = Text(
        overline!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Daylight.ui(
          11,
          color: Daylight.muted,
          weight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      );
    } else {
      heading = const SizedBox.shrink();
    }

    // Detail pages use a small centred label between a circular back button
    // and its actions, matching the album/playlist/artist sheets.
    final isDetail = showBack && title == null && overline != null;

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: isDetail
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: leading),
                    heading,
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions ?? [],
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    ...leading,
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: heading,
                      ),
                    ),
                    if (actions != null) ...actions!,
                  ],
                ),
        ),
      ),
    );
  }
}

/// A white circular button with the daylight floating shadow.
class DaylightCircleButton extends StatelessWidget {
  const DaylightCircleButton({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 38,
    this.iconSize = 18,
    this.color,
    this.background,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? background;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? Daylight.cobalt : (background ?? Daylight.card),
        shape: BoxShape.circle,
        border: filled ? null : Daylight.hairline,
        boxShadow: filled ? Daylight.cobaltShadow : Daylight.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(
            icon,
            size: iconSize,
            color: filled ? Daylight.onAccent : (color ?? Daylight.ink),
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Section title with the concept's underlined text action.
class DaylightSectionHeader extends StatelessWidget {
  const DaylightSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 10),
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Daylight.display(16, height: 1.1, letterSpacing: -0.25),
            ),
          ),
          if (trailing != null) trailing!,
          if (actionLabel != null) ...[
            const SizedBox(width: 8),
            DaylightPill(
              label: actionLabel!,
              onTap: onAction,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            ),
          ],
        ],
      ),
    );
  }
}

/// White floating card.
class DaylightCard extends StatelessWidget {
  const DaylightCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 14,
    this.color,
    this.onTap,
    this.shadow = true,
    this.border = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final bool shadow;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Daylight.card,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Daylight.hairline : null,
        boxShadow: shadow ? Daylight.cardShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small white pill, cobalt when active.
class DaylightPill extends StatelessWidget {
  const DaylightPill({
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Daylight.motion(context, const Duration(milliseconds: 180)),
        curve: Curves.easeOut,
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? Daylight.cobalt : Daylight.card,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Daylight.hairline,
          boxShadow: selected
              ? Daylight.cobaltShadow
              : [
                  BoxShadow(
                    color: Daylight.ink.withValues(alpha: 0.07),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    spreadRadius: -3,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Daylight.onAccent : Daylight.muted,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: Daylight.ui(
                11,
                color: selected ? Daylight.onAccent : const Color(0xFF3C4250),
                weight: selected ? FontWeight.w600 : FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny tinted label such as "Offline" or "Shared".
class DaylightBadge extends StatelessWidget {
  const DaylightBadge({
    required this.label,
    this.icon,
    this.color,
    this.background,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? Daylight.cobaltSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color ?? Daylight.cobalt),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Daylight.ui(
              9.5,
              color: color ?? Daylight.cobalt,
              weight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular artwork with the concept's concentric halo rings.
class DaylightHalo extends StatelessWidget {
  const DaylightHalo({
    required this.size,
    required this.child,
    this.rings = 2,
    this.color,
    super.key,
  });

  final double size;
  final Widget child;
  final int rings;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? Daylight.cobalt;
    final outer = size + (rings * 18);
    return SizedBox(
      key: const ValueKey('daylight-halo'),
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = rings; i >= 1; i--)
            Container(
              width: size + i * 18,
              height: size + i * 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ringColor.withValues(alpha: 0.10 / i),
                  width: 1.2,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Circular cover art with a tinted fallback.
class DaylightCover extends StatelessWidget {
  const DaylightCover({
    required this.size,
    this.imageUrl,
    this.localPath,
    this.halo = false,
    this.icon = FluentIcons.music_note_2_24_filled,
    this.border = false,
    super.key,
  });

  final double size;
  final String? imageUrl;
  final String? localPath;
  final bool halo;
  final IconData icon;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final cover = ClipOval(
      child: SizedBox(width: size, height: size, child: _buildImage()),
    );

    final decorated = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Daylight.ink.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: -8,
          ),
        ],
      ),
      child: cover,
    );

    if (!halo) return decorated;
    return DaylightHalo(size: size, child: decorated);
  }

  Widget _buildImage() {
    final path = localPath;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    final url = imageUrl;
    if (url == null || url.isEmpty) return _fallback();

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => _fallback(loading: true),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback({bool loading = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: Daylight.softCobaltGradient),
      child: Center(
        child: Icon(
          loading ? FluentIcons.music_note_2_24_regular : icon,
          color: Daylight.cobalt.withValues(alpha: 0.65),
          size: size * 0.34,
        ),
      ),
    );
  }
}

/// The concept's slim cobalt progress bar.
class DaylightProgressBar extends StatelessWidget {
  const DaylightProgressBar({
    required this.value,
    this.height = 4,
    this.background,
    this.color,
    this.radius = 999,
    super.key,
  });

  final double value;
  final double height;
  final Color? background;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: background ?? Daylight.line),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: color ?? Daylight.cobalt),
            ),
          ],
        ),
      ),
    );
  }
}

/// Daylight switch used on settings, downloads and onboarding.
class DaylightToggle extends StatelessWidget {
  const DaylightToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: Daylight.motion(context, const Duration(milliseconds: 180)),
        curve: Curves.easeOut,
        width: 42,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? Daylight.cobalt : const Color(0xFFD6DAE3),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: Daylight.motion(context, const Duration(milliseconds: 180)),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Daylight.ink.withValues(alpha: 0.18),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty / offline state in the daylight language.
class DaylightEmptyState extends StatelessWidget {
  const DaylightEmptyState({
    required this.title,
    required this.message,
    this.icon = FluentIcons.music_note_2_24_regular,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DaylightHalo(
              size: 76,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Daylight.card,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A16181D),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: Icon(icon, color: Daylight.cobalt, size: 30),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Daylight.display(19, height: 1.15),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Daylight.ui(12.5, color: Daylight.muted, height: 1.45),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
