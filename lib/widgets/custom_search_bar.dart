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

class CustomSearchBar extends StatefulWidget {
  const CustomSearchBar({
    super.key,
    required this.onSubmitted,
    required this.controller,
    required this.focusNode,
    required this.labelText,
    this.onChanged,
    this.loadingProgressNotifier,
  });
  final Function(String) onSubmitted;
  final ValueNotifier<bool>? loadingProgressNotifier;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelText;
  final Function(String)? onChanged;

  @override
  _CustomSearchBarState createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Daylight.card,
          borderRadius: BorderRadius.circular(14),
          border: Daylight.hairline,
          boxShadow: [
            BoxShadow(
              color: Daylight.ink.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
              spreadRadius: -8,
            ),
          ],
        ),
        child: SearchBar(
          elevation: WidgetStateProperty.all(0),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          overlayColor: WidgetStateProperty.all(
            Daylight.cobalt.withValues(alpha: 0.05),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12),
          ),
          hintText: widget.labelText,
          hintStyle: WidgetStateProperty.all(
            Daylight.ui(12.5, color: Daylight.faint),
          ),
          textStyle: WidgetStateProperty.all(
            Daylight.ui(12.5, color: Daylight.ink),
          ),
          leading: Icon(
            FluentIcons.search_24_regular,
            color: Daylight.muted,
            size: 18,
          ),
          onSubmitted: (String value) {
            widget.onSubmitted(value);
            widget.focusNode.unfocus();
          },
          onChanged: widget.onChanged != null
              ? (value) async {
                  widget.onChanged!(value);
                  setState(() {});
                }
              : null,
          textInputAction: TextInputAction.search,
          controller: widget.controller,
          focusNode: widget.focusNode,
          trailing: [
            if (widget.controller.text.isNotEmpty)
              IconButton(
                icon: Icon(
                  FluentIcons.dismiss_circle_16_filled,
                  color: Daylight.faint,
                  size: 16,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged?.call('');
                  setState(() {});
                },
              ),
            if (widget.loadingProgressNotifier != null)
              ValueListenableBuilder<bool>(
                valueListenable: widget.loadingProgressNotifier!,
                builder: (_, value, __) {
                  if (value) {
                    return Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        height: 15,
                        width: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Daylight.cobalt,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }
}
