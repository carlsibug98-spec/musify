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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onSkip: () => _finish(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Stage(),
                    const SizedBox(height: 26),
                    Text(
                      context.l10n!.onboardingTitle,
                      style: Daylight.display(31, height: 1.0),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.l10n!.onboardingBody,
                      style: Daylight.ui(
                        12.5,
                        color: Daylight.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Point(
                      icon: FluentIcons.folder_24_regular,
                      title: context.l10n!.onboardingLocalTitle,
                      note: context.l10n!.onboardingLocalNote,
                    ),
                    _Point(
                      icon: FluentIcons.arrow_download_24_regular,
                      title: context.l10n!.onboardingDownloadsTitle,
                      note: context.l10n!.onboardingDownloadsNote,
                    ),
                  ],
                ),
              ),
            ),
            _Actions(onStart: () => _finish(context)),
          ],
        ),
      ),
    );
  }

  void _finish(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 14, 4),
      child: Row(
        children: [
          const DaylightBrandMark(size: 20),
          const SizedBox(width: 8),
          Text(
            'Musify',
            style: Daylight.display(15, letterSpacing: -0.3),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Daylight.muted,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              context.l10n!.skip,
              style: Daylight.ui(12, color: Daylight.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final artwork = snapshot.data?.artUri?.toString();
        return Center(
          child: SizedBox(
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DaylightHalo(
                  size: 206,
                  rings: 3,
                  child: DaylightCover(
                    size: 206,
                    imageUrl: artwork,
                    icon: FluentIcons.music_note_2_24_regular,
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 92,
                  child: _Chip(
                    icon: FluentIcons.clock_24_regular,
                    label: context.l10n!.recentlyPlayed,
                    background: Daylight.card,
                    color: Daylight.cobalt,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 78,
                  child: _Chip(
                    icon: FluentIcons.checkmark_circle_24_regular,
                    label: context.l10n!.downloaded,
                    background: Daylight.cobalt,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.background,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Daylight.ink.withValues(alpha: 0.05)),
        boxShadow: Daylight.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Daylight.ui(
              10.5,
              color: color,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({
    required this.icon,
    required this.title,
    required this.note,
  });

  final IconData icon;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Daylight.cobaltSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: Daylight.cobalt),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Daylight.ui(12.5, weight: FontWeight.w600),
                ),
                const SizedBox(height: 1),
                Text(note, style: Daylight.ui(11, color: Daylight.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: Daylight.cobaltGradient,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: Daylight.cobaltShadow,
                ),
                child: InkWell(
                  onTap: onStart,
                  borderRadius: BorderRadius.circular(99),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          FluentIcons.play_16_filled,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n!.startListening,
                          style: Daylight.ui(
                            13,
                            color: Colors.white,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              onPressed: () {
                onStart();
                context.push('/settings/import-spotify-playlist');
              },
              style: TextButton.styleFrom(
                foregroundColor: Daylight.cobalt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    FluentIcons.arrow_download_24_regular,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    context.l10n!.importFromSpotify,
                    style: Daylight.ui(
                      12,
                      color: Daylight.cobalt,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n!.freeOpenSource,
            style: Daylight.ui(9.5, color: Daylight.faint),
          ),
        ],
      ),
    );
  }
}
