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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/daylight.dart';

class CustomBar extends StatelessWidget {
  CustomBar(
    this.tileName,
    this.tileIcon, {
    this.description,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final String tileName;
  final IconData tileIcon;
  final String? description;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? Daylight.cobalt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? Daylight.card,
          borderRadius: BorderRadius.circular(14),
          border: Daylight.hairline,
          boxShadow: [
            BoxShadow(
              color: Daylight.ink.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            splashColor: Colors.transparent,
            highlightColor: Daylight.cobalt.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Daylight.cobaltSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(tileIcon, size: 17, color: effectiveIconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Daylight.ui(
                            13,
                            color: textColor ?? Daylight.ink,
                            weight: FontWeight.w600,
                          ),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Daylight.ui(
                              10.5,
                              color: textColor?.withValues(alpha: 0.75) ??
                                  Daylight.muted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ] else if (onTap != null)
                    Icon(
                      FluentIcons.chevron_right_20_regular,
                      size: 17,
                      color: Daylight.faint,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
