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
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/update_manager.dart';
import 'package:musify/theme/app_colors.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/language_utils.dart';
import 'package:musify/utilities/platform_utils.dart';
import 'package:musify/utilities/url_launcher.dart';
import 'package:musify/widgets/bottom_sheet_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/custom_bar.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/section_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final activatedColor = Theme.of(context).colorScheme.secondaryContainer;
    final inactivatedColor = Theme.of(context).colorScheme.surfaceContainerHigh;

    final content = Column(
      children: <Widget>[
        const SizedBox(height: 2),
        _buildPreferencesSection(
          context,
          primaryColor,
          activatedColor,
          inactivatedColor,
        ),
        if (!offlineMode.value) _buildOnlineFeaturesSection(context),
        _buildOthersSection(context),
        const SizedBox(height: 12),
        Text(
          'Resona · Daylight',
          style: Daylight.ui(9.5, color: Daylight.faint),
        ),
        const SizedBox(height: 16),
        const MiniPlayerBottomSpace(),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          DaylightAppBar(
            title: context.l10n!.settings,
            actions: [
              DaylightCircleButton(
                icon: FluentIcons.question_circle_24_regular,
                tooltip: context.l10n!.about,
                iconSize: 17,
                onTap: () => context.push('/settings/about'),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: isDesktopPlatform
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: content,
                      ),
                    )
                  : content,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(
    BuildContext context,
    Color primaryColor,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    final isOffline = offlineMode.value;

    return Column(
      children: [
        SectionHeader(
          title: context.l10n!.preferences,
          icon: FluentIcons.options_24_filled,
        ),
        CustomBar(
          context.l10n!.accentColor,
          FluentIcons.color_24_regular,
          borderRadius: commonCustomBarRadiusFirst,
          trailing: Container(
            width: isDesktopPlatform ? 26 : 22,
            height: isDesktopPlatform ? 26 : 22,
            decoration: BoxDecoration(
              color: Daylight.cobalt,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          onTap: () => _showAccentColorPicker(context),
        ),
        CustomBar(
          context.l10n!.themeMode,
          FluentIcons.weather_sunny_28_regular,
          onTap: () => _showThemeModePicker(context),
        ),
        CustomBar(
          context.l10n!.language,
          FluentIcons.translate_24_regular,
          onTap: () => _showLanguagePicker(context),
        ),
        CustomBar(
          context.l10n!.audioQuality,
          FluentIcons.music_note_1_24_regular,
          onTap: () => _showAudioQualityPicker(context),
        ),
        if (isAndroidPlatform)
          CustomBar(
            context.l10n!.equalizer,
            FluentIcons.data_histogram_24_regular,
            onTap: () => context.push('/settings/equalizer'),
          ),
        if (themeMode == ThemeMode.dark)
          CustomBar(
            context.l10n!.pureBlackTheme,
            FluentIcons.color_background_24_regular,
            description: context.l10n!.pureBlackThemeDescription,
            trailing: Switch(
              value: usePureBlackColor.value,
              onChanged: (value) => _togglePureBlack(context, value),
            ),
          ),
        if (isAndroidPlatform)
          CustomBar(
            context.l10n!.dynamicColor,
            FluentIcons.toggle_left_24_regular,
            description: context.l10n!.dynamicColorDescription,
            trailing: Switch(
              value: useSystemColor.value,
              onChanged: (value) => _toggleSystemColor(context, value),
            ),
          ),

        ValueListenableBuilder<bool>(
          valueListenable: showAudioQualityBadge,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.audioQualityBadge,
              FluentIcons.badge_24_regular,
              description: context.l10n!.audioQualityBadgeDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleAudioQualityBadge(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: useProxy,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.useProxy,
              FluentIcons.shield_24_regular,
              description: context.l10n!.useProxyDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) {
                  useProxy.value = value;
                  addOrUpdateData<bool>('settings', 'useProxy', value);
                  showToast(context, context.l10n!.settingChangedMsg);
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: wrappedEnabled,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.listeningStats,
              FluentIcons.clock_24_regular,
              description: context.l10n!.listeningStatsDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleWrapped(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: offlineMode,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.offlineMode,
              FluentIcons.cloud_off_24_regular,
              description: context.l10n!.offlineModeDescription,
              borderRadius: isOffline && isFdroidBuild
                  ? commonCustomBarRadiusLast
                  : BorderRadius.zero,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleOfflineMode(context, value),
              ),
            );
          },
        ),
        if (!isFdroidBuild && isMobilePlatform)
          ValueListenableBuilder<bool?>(
            valueListenable: shouldWeCheckUpdates,
            builder: (_, value, __) {
              return CustomBar(
                context.l10n!.automaticUpdateChecks,
                FluentIcons.arrow_sync_24_regular,
                description: context.l10n!.automaticUpdateChecksDescription,
                borderRadius: offlineMode.value
                    ? commonCustomBarRadiusLast
                    : BorderRadius.zero,
                trailing: Switch(
                  value: value ?? false,
                  onChanged: (value) =>
                      _toggleAutomaticUpdateChecks(context, value),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildOnlineFeaturesSection(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: sponsorBlockSupport,
          builder: (_, value, __) {
            return CustomBar(
              'SponsorBlock',
              FluentIcons.cut_24_regular,
              description: context.l10n!.sponsorBlockDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) => _toggleSponsorBlock(context, value),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: playNextSongAutomatically,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.automaticSongPicker,
              FluentIcons.music_note_2_play_20_regular,
              description: context.l10n!.automaticSongPickerDescription,
              trailing: Switch(
                value: value,
                onChanged: (value) {
                  _toggleAutoPlayNext(context, value);
                  showToast(context, context.l10n!.settingChangedMsg);
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: externalRecommendations,
          builder: (_, value, __) {
            return CustomBar(
              context.l10n!.externalRecommendations,
              FluentIcons.channel_share_24_regular,
              description: context.l10n!.externalRecommendationsDescription,
              borderRadius: commonCustomBarRadiusLast,
              trailing: Switch(
                value: value,
                onChanged: (value) =>
                    _toggleExternalRecommendations(context, value),
              ),
            );
          },
        ),

        _buildToolsSection(context),
        _buildSponsorSection(context),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: context.l10n!.tools,
          icon: FluentIcons.toolbox_24_filled,
        ),
        CustomBar(
          context.l10n!.downloads,
          FluentIcons.arrow_download_24_regular,
          description: context.l10n!.onThisPhone,
          borderRadius: commonCustomBarRadiusFirst,
          onTap: () => context.push('/library/downloads'),
        ),
        CustomBar(
          context.l10n!.chooseFavoriteArtists,
          FluentIcons.heart_24_regular,
          description: context.l10n!.chooseFavoriteArtistsNote,
          onTap: () => context.push('/pick-artists'),
        ),
        CustomBar(
          context.l10n!.startListening,
          FluentIcons.play_circle_24_regular,
          description: context.l10n!.onboardingTitle,
          onTap: () => context.push('/onboarding'),
        ),
        CustomBar(
          context.l10n!.clearCache,
          FluentIcons.broom_24_regular,
          onTap: () async {
            final cleared = await clearCache();
            showToast(
              context,
              cleared ? '${context.l10n!.cacheMsg}!' : context.l10n!.error,
            );
          },
        ),
        CustomBar(
          context.l10n!.clearSearchHistory,
          FluentIcons.history_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearSearchHistoryQuestion,
            onSubmit: () {
              searchHistoryNotifier.value = [];
              deleteData('user', 'searchHistory');
              showToast(context, '${context.l10n!.searchHistoryMsg}!');
            },
          ),
        ),
        CustomBar(
          context.l10n!.clearRecentlyPlayed,
          FluentIcons.receipt_play_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearRecentlyPlayedQuestion,
            onSubmit: () {
              userRecentlyPlayed.value = [];
              deleteData('user', 'recentlyPlayedSongs');
              showToast(context, '${context.l10n!.recentlyPlayedMsg}!');
            },
          ),
        ),
        CustomBar(
          context.l10n!.clearListeningStats,
          FluentIcons.clock_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearListeningStatsQuestion,
            submitMessage: context.l10n!.delete,
            isDangerous: true,
            onSubmit: () async {
              audioHandler.resetListeningStatsSession(flushStats: false);
              await listeningStatsService.clearStats();
              audioHandler.startListeningStatsSessionIfNeeded();
              if (context.mounted) {
                showToast(context, '${context.l10n!.listeningStatsCleared}!');
              }
            },
          ),
        ),
        CustomBar(
          context.l10n!.deleteDownloads,
          FluentIcons.delete_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.deleteDownloadsQuestion,
            submitMessage: context.l10n!.delete,
            isDangerous: true,
            onSubmit: () async {
              try {
                await offlinePlaylistService.deleteAllDownloads();
                if (context.mounted) {
                  showToast(context, context.l10n!.downloadsDeleted);
                }
              } catch (e) {
                if (context.mounted) {
                  showToast(context, context.l10n!.error);
                }
              }
            },
          ),
        ),
        CustomBar(
          context.l10n!.importSpotifyAlbum,
          FluentIcons.music_note_2_24_regular,
          onTap: () => context.push('/settings/import-spotify-album'),
        ),
        CustomBar(
          context.l10n!.importSpotifyPlaylist,
          FluentIcons.arrow_upload_24_regular,
          onTap: () => context.push('/settings/import-spotify-playlist'),
        ),
        CustomBar(
          context.l10n!.backupUserData,
          FluentIcons.cloud_sync_24_regular,
          onTap: () => _backupUserData(context),
        ),
        CustomBar(
          context.l10n!.restoreUserData,
          FluentIcons.cloud_add_24_regular,
          onTap: () async {
            try {
              final result = await restoreData(context);
              if (result.success) {
                reloadSettingsFromStorage();
                reloadSongLibraryStateFromStorage();
                reloadPlaylistLibraryStateFromStorage();
                reloadSearchHistoryFromStorage();
                listeningStatsService.reload();
                await audioHandler.setShuffleMode(
                  shuffleNotifier.value
                      ? AudioServiceShuffleMode.all
                      : AudioServiceShuffleMode.none,
                );
                await audioHandler.setRepeatMode(repeatNotifier.value);
                themeMode = getThemeMode(themeModeSetting);
                brightness = getBrightnessFromThemeMode(themeMode);
                if (context.mounted) {
                  await Musify.updateAppState(
                    context,
                    newThemeMode: themeMode,
                    newLocale: languageSetting,
                    newAccentColor: primaryColorSetting,
                    useSystemColor: useSystemColor.value,
                  );
                  NavigationManager.refreshRouter();
                }
              }
              if (context.mounted) {
                showToast(
                  context,
                  result.message,
                  icon: result.success
                      ? null
                      : FluentIcons.error_circle_24_regular,
                );
              }
            } catch (e, str) {
              logger.log('Error restoring data', error: e, stackTrace: str);
              if (context.mounted) {
                showToast(
                  context,
                  context.l10n!.error,
                  icon: FluentIcons.error_circle_24_regular,
                );
              }
            }
          },
        ),
        if (!isFdroidBuild && isMobilePlatform)
          CustomBar(
            context.l10n!.downloadAppUpdate,
            FluentIcons.arrow_download_24_regular,
            borderRadius: commonCustomBarRadiusLast,
            onTap: checkAppUpdates,
          ),
      ],
    );
  }

  Widget _buildSponsorSection(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: context.l10n!.becomeSponsor,
          icon: FluentIcons.heart_24_filled,
        ),
        DaylightCard(
          color: Daylight.cobaltSoft,
          border: false,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          onTap: () => launchURL(Uri.parse('https://ko-fi.com/gokadzev')),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FluentIcons.heart_24_filled,
                  color: Daylight.cobalt,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.l10n!.sponsorProject,
                  style: Daylight.ui(
                    13,
                    color: Daylight.ink,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOthersSection(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: context.l10n!.others,
          icon: FluentIcons.more_circle_24_filled,
        ),
        CustomBar(
          context.l10n!.licenses,
          FluentIcons.document_24_regular,
          borderRadius: commonCustomBarRadiusFirst,
          onTap: () => NavigationManager.router.go('/settings/license'),
        ),
        CustomBar(
          context.l10n!.translate,
          FluentIcons.translate_24_regular,
          description: context.l10n!.translateDescription,
          onTap: () =>
              launchURL(Uri.parse('https://crowdin.com/project/musify')),
        ),
        ValueListenableBuilder<int>(
          valueListenable: logger.logCount,
          builder: (context, logCount, _) => CustomBar(
            '${context.l10n!.copyLogs} ($logCount)',
            FluentIcons.error_circle_24_regular,
            onTap: () async =>
                showToast(context, await logger.copyLogs(context)),
          ),
        ),
        CustomBar(
          context.l10n!.about,
          FluentIcons.book_information_24_regular,
          borderRadius: commonCustomBarRadiusLast,
          onTap: () => NavigationManager.router.go('/settings/about'),
        ),
      ],
    );
  }

  void _showAccentColorPicker(BuildContext context) {
    if (isDesktopPlatform) {
      _showPickerDialog(
        context,
        title: context.l10n!.accentColor,
        content: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 10,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: availableColors.length + 1,
          itemBuilder: (context, index) {
            if (index == availableColors.length) {
              return InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _showCustomAccentColorDialog(context),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFFF44336),
                        Color(0xFFFFC107),
                        Color(0xFF4CAF50),
                        Color(0xFF2196F3),
                        Color(0xFF9C27B0),
                        Color(0xFFF44336),
                      ],
                    ),
                  ),
                  child: const Icon(
                    FluentIcons.add_24_regular,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              );
            }
            final color = availableColors[index];
            final isSelected = color == primaryColorSetting;

            return InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _selectAccentColor(context, color),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: 3,
                        )
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        FluentIcons.checkmark_20_filled,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          },
        ),
      );
      return;
    }

    final colorScheme = Theme.of(context).colorScheme;

    showCustomBottomSheet(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: availableColors.length + 1,
          itemBuilder: (context, index) {
            if (index == availableColors.length) {
              return GestureDetector(
                onTap: () => _showCustomAccentColorDialog(context),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFFF44336),
                        Color(0xFFFFC107),
                        Color(0xFF4CAF50),
                        Color(0xFF2196F3),
                        Color(0xFF9C27B0),
                        Color(0xFFF44336),
                      ],
                    ),
                  ),
                  child: const Icon(
                    FluentIcons.add_24_regular,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            }
            final color = availableColors[index];
            final isSelected = color == primaryColorSetting;

            return GestureDetector(
              onTap: () => _selectAccentColor(context, color),
              child: AnimatedContainer(
                duration: Daylight.motion(
                  context,
                  const Duration(milliseconds: 200),
                ),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: colorScheme.onSurface, width: 3)
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        FluentIcons.checkmark_20_filled,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  /// RGB picker so any accent color can be chosen, not only the swatches.
  void _showCustomAccentColorDialog(BuildContext context) {
    final pageContext = context;
    final argb = primaryColorSetting.toARGB32();
    var red = (argb >> 16) & 0xFF;
    var green = (argb >> 8) & 0xFF;
    var blue = argb & 0xFF;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final color = Color.fromARGB(255, red, green, blue);
            final hex =
                '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

            Widget channel({
              required String label,
              required int value,
              required Color channelColor,
              required ValueChanged<int> onChanged,
            }) {
              return Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      label,
                      style: Daylight.ui(
                        12,
                        color: Daylight.muted,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: channelColor,
                        inactiveTrackColor: Daylight.line,
                        thumbColor: channelColor,
                        overlayColor: channelColor.withValues(alpha: 0.12),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                      ),
                      child: Slider(
                        value: value.toDouble(),
                        max: 255,
                        divisions: 255,
                        onChanged: (next) =>
                            setDialogState(() => onChanged(next.round())),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '$value',
                      textAlign: TextAlign.right,
                      style: Daylight.ui(
                        12,
                        color: Daylight.ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              backgroundColor: Daylight.card,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                context.l10n!.accentColor,
                style: Daylight.display(
                  18,
                  color: Daylight.ink,
                  weight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.32),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hex,
                      style: Daylight.ui(
                        13,
                        color: Daylight.ink,
                        weight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    channel(
                      label: 'R',
                      value: red,
                      channelColor: const Color(0xFFE5484D),
                      onChanged: (value) => red = value,
                    ),
                    channel(
                      label: 'G',
                      value: green,
                      channelColor: const Color(0xFF2F9E44),
                      onChanged: (value) => green = value,
                    ),
                    channel(
                      label: 'B',
                      value: blue,
                      channelColor: const Color(0xFF1971C2),
                      onChanged: (value) => blue = value,
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    context.l10n!.cancel,
                    style: Daylight.ui(
                      13,
                      color: Daylight.muted,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: color.computeLuminance() > 0.52
                        ? Daylight.ink
                        : Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                  ),
                  onPressed: () {
                    addOrUpdateData<int>(
                      'settings',
                      'accentColor',
                      color.toARGB32(),
                    );
                    Musify.updateAppState(
                      pageContext,
                      newAccentColor: color,
                      useSystemColor: false,
                    );
                    Navigator.pop(dialogContext);
                    showToast(pageContext, pageContext.l10n!.accentChangeMsg);
                  },
                  child: Text(
                    context.l10n!.apply,
                    style: Daylight.ui(13, weight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _selectAccentColor(BuildContext context, Color color) {
    addOrUpdateData<int>('settings', 'accentColor', color.toARGB32());
    Musify.updateAppState(
      context,
      newAccentColor: color,
      useSystemColor: false,
    );
    showToast(context, context.l10n!.accentChangeMsg);
    Navigator.pop(context);
  }

  void _showThemeModePicker(BuildContext context) {
    final availableModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    final modeIcons = [
      if (isDesktopPlatform)
        FluentIcons.desktop_24_regular
      else
        FluentIcons.phone_24_regular,
      FluentIcons.weather_sunny_24_regular,
      FluentIcons.weather_moon_24_regular,
    ];
    final modeNames = [
      context.l10n!.themeModeSystem,
      context.l10n!.themeModeLight,
      context.l10n!.themeModeDark,
    ];

    Widget buildModeBar(int index) {
      final mode = availableModes[index];

      return BottomSheetBar(
        modeNames[index],
        () {
          addOrUpdateData<int>('settings', 'themeIndex', mode.index);
          Musify.updateAppState(context, newThemeMode: mode);
          Navigator.pop(context);
        },
        themeMode == mode,
        icon: modeIcons[index],
      );
    }

    if (isDesktopPlatform) {
      _showPickerDialog(
        context,
        title: context.l10n!.themeMode,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < availableModes.length; index++)
              buildModeBar(index),
          ],
        ),
      );
      return;
    }

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableModes.length,
        itemBuilder: (context, index) => buildModeBar(index),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final availableLanguages = appLanguages.toList();
    final activeLanguageCode = Localizations.localeOf(context).languageCode;
    final activeScriptCode = Localizations.localeOf(context).scriptCode;
    final activeLanguageFullCode = activeScriptCode != null
        ? '$activeLanguageCode-$activeScriptCode'
        : activeLanguageCode;

    Widget buildLanguageBar(int index) {
      final language = availableLanguages[index];
      final newLocale = getLocaleFromLanguageCode(language);
      final newLocaleFullCode = newLocale.scriptCode != null
          ? '${newLocale.languageCode}-${newLocale.scriptCode}'
          : newLocale.languageCode;

      return BottomSheetBar(getLanguageDisplayName(context, language), () {
        addOrUpdateData<String>('settings', 'languageCode', newLocaleFullCode);
        Musify.updateAppState(context, newLocale: newLocale);
        showToast(context, context.l10n!.languageMsg);
        Navigator.pop(context);
      }, activeLanguageFullCode == newLocaleFullCode);
    }

    if (isDesktopPlatform) {
      _showPickerDialog(
        context,
        title: context.l10n!.language,
        height: 460,
        content: ListView.builder(
          padding: commonListViewBottomPadding,
          itemCount: availableLanguages.length,
          itemBuilder: (context, index) => buildLanguageBar(index),
        ),
      );
      return;
    }

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableLanguages.length,
        itemBuilder: (context, index) => buildLanguageBar(index),
      ),
    );
  }

  void _showAudioQualityPicker(BuildContext context) {
    final availableQualities = ['low', 'medium', 'high'];
    final qualityNames = [
      context.l10n!.audioQualityLow,
      context.l10n!.audioQualityMedium,
      context.l10n!.audioQualityHigh,
    ];
    const qualityIcons = [
      FluentIcons.speaker_1_24_regular,
      FluentIcons.speaker_2_24_regular,
      FluentIcons.speaker_2_24_filled,
    ];

    Widget buildQualityBar(int index) {
      final quality = availableQualities[index];

      return BottomSheetBar(
        qualityNames[index],
        () {
          addOrUpdateData<String>('settings', 'audioQuality', quality);
          audioQualitySetting.value = quality;
          showToast(context, context.l10n!.audioQualityMsg);
          Navigator.pop(context);
        },
        audioQualitySetting.value == quality,
        icon: qualityIcons[index],
      );
    }

    if (isDesktopPlatform) {
      _showPickerDialog(
        context,
        title: context.l10n!.audioQuality,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < availableQualities.length; index++)
              buildQualityBar(index),
          ],
        ),
      );
      return;
    }

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableQualities.length,
        itemBuilder: (context, index) => buildQualityBar(index),
      ),
    );
  }

  void _showPickerDialog(
    BuildContext context, {
    required String title,
    required Widget content,
    double? height,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: SizedBox(width: 420, height: height, child: content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleSystemColor(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'useSystemColor', value);
    useSystemColor.value = value;
    Musify.updateAppState(
      context,
      newAccentColor: primaryColorSetting,
      useSystemColor: value,
    );
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _togglePureBlack(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'usePureBlackColor', value);
    usePureBlackColor.value = value;
    Musify.updateAppState(context);
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAudioQualityBadge(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'showAudioQualityBadge', value);
    showAudioQualityBadge.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  Future<void> _toggleWrapped(BuildContext context, bool value) async {
    if (!value) {
      audioHandler.resetListeningStatsSession(
        countCurrentTick: true,
        flushStats: false,
      );
      await listeningStatsService.flush();
    }

    await addOrUpdateData<bool>('settings', 'wrappedEnabled', value);
    wrappedEnabled.value = value;
    listeningStatsService.reload();
    if (value) {
      audioHandler.startListeningStatsSessionIfNeeded();
    }
    if (context.mounted) {
      showToast(context, context.l10n!.settingChangedMsg);
    }
  }

  void _toggleOfflineMode(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'offlineMode', value);
    offlineMode.value = value;

    // Trigger router refresh and notify about the change
    NavigationManager.refreshRouter();

    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleSponsorBlock(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'sponsorBlockSupport', value);
    sponsorBlockSupport.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAutoPlayNext(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'playNextSongAutomatically', value);
    playNextSongAutomatically.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAutomaticUpdateChecks(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', value);
    shouldWeCheckUpdates.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleExternalRecommendations(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'externalRecommendations', value);
    externalRecommendations.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String confirmationMessage,
    required VoidCallback onSubmit,
    String? submitMessage,
    bool isDangerous = false,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          submitMessage: submitMessage ?? context.l10n!.clear,
          confirmationMessage: confirmationMessage,
          isDangerous: isDangerous,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: () {
            Navigator.of(context).pop();
            onSubmit();
          },
        );
      },
    );
  }

  Future<void> _backupUserData(BuildContext context) async {
    try {
      final result = await backupData(context);
      if (context.mounted) {
        showToast(
          context,
          result.message,
          icon: result.success ? null : FluentIcons.error_circle_24_regular,
        );
      }
    } catch (e, stackTrace) {
      logger.log('Error backing up data', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        showToast(
          context,
          context.l10n!.error,
          icon: FluentIcons.error_circle_24_regular,
        );
      }
    }
  }
}
