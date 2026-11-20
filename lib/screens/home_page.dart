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

import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/listening_stats_utils.dart';
import 'package:musify/screens/search_page.dart' show genreSearchRequest;
import 'package:musify/widgets/announcement_box.dart';
import 'package:musify/widgets/daylight/browse_tile.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/daylight/genre_grid.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/recommended_songs_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

/// Spotify-style home filters. They change which shelves render, not the data
/// source: every shelf is still backed by real Musify services.
enum _HomeFilter { all, playlists, songs }

class _HomePageState extends State<HomePage> {
  late final Future<List> _suggestedPlaylistsFuture;
  late Future<List> _recommendedSongsFuture;
  _HomeFilter _filter = _HomeFilter.all;

  @override
  void initState() {
    super.initState();
    _suggestedPlaylistsFuture = getPlaylists(
      playlistsNum: recommendedCubesNumber,
    );
    _recommendedSongsFuture = getRecommendedSongs();
    externalRecommendations.addListener(_refreshRecommendedSongs);
  }

  @override
  void dispose() {
    externalRecommendations.removeListener(_refreshRecommendedSongs);
    super.dispose();
  }

  void _refreshRecommendedSongs() {
    if (!mounted) return;
    setState(() {
      _recommendedSongsFuture = getRecommendedSongs();
    });
  }

  int _monthMinutes() {
    final key = listeningStatsMonthKey(DateTime.now());
    return monthDisplayMinutes(listeningStatsService.monthStats(key));
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _monthMinutes();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DaylightAppBar(
              brand: true,
              actions: [
                if (minutes > 0)
                  DayLightDurationPill(
                    minutes: minutes,
                    onTap: () => context.push('/home/timeMachine'),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ValueListenableBuilder<String?>(
                  valueListenable: announcementURL,
                  builder: (_, url, __) {
                    if (url == null) return const SizedBox.shrink();
                    final isSponsorship = isSponsorshipAnnouncementUrl(url);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AnnouncementBox(
                        message: isSponsorship
                            ? context.l10n!.sponsorProject
                            : context.l10n!.newAnnouncement,
                        url: url,
                        icon: isSponsorship
                            ? FluentIcons.heart_24_filled
                            : FluentIcons.megaphone_24_filled,
                        onDismiss: () async {
                          announcementURL.value = null;
                        },
                      ),
                    );
                  },
                ),
                _buildQuickAccess(context),
                const SizedBox(height: 14),
                _buildFilterChips(context),
                const SizedBox(height: 18),
                if (_filter != _HomeFilter.songs)
                  GenreGrid(
                    title: context.l10n!.genres,
                    actionLabel: context.l10n!.seeAll,
                    onAction: () {
                      genreSearchRequest.value = 'pop songs';
                      context.go('/search');
                    },
                  ),
                if (_filter != _HomeFilter.songs) const SizedBox(height: 18),
                if (_filter != _HomeFilter.playlists) _buildJumpBackIn(),
                if (_filter != _HomeFilter.playlists)
                  const SizedBox(height: 18),
                if (_filter != _HomeFilter.songs) _buildSuggestedPlaylists(),
                if (_filter != _HomeFilter.songs) const SizedBox(height: 16),
                if (_filter != _HomeFilter.songs) _buildLikedPlaylists(),
                if (_filter != _HomeFilter.playlists) _buildMonthRecap(),
                if (_filter != _HomeFilter.playlists)
                  _buildRecommendedSongsSection(),
                const MiniPlayerBottomSpace(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Spotify's home opens with a compact wall of things you keep returning to.
  /// Every tile is real: liked songs, downloads, recents and actual playlists.
  Widget _buildQuickAccess(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        userCustomPlaylists,
        userLikedPlaylists,
        userRecentlyPlayed,
        userOfflineSongs,
        userLikedSongsList,
      ]),
      builder: (context, _) {
        final tiles = <Widget>[
          _QuickAccessTile(
            label: context.l10n!.likedSongs,
            caption: '${userLikedSongsList.value.length}',
            icon: FluentIcons.heart_24_filled,
            color: BrowseColors.rose,
            onTap: () => context.push('/library/userSongs/liked'),
          ),
          _QuickAccessTile(
            label: context.l10n!.downloads,
            caption: '${userOfflineSongs.value.length}',
            icon: FluentIcons.arrow_download_24_regular,
            color: BrowseColors.pine,
            onTap: () => context.push('/library/downloads'),
          ),
          _QuickAccessTile(
            label: context.l10n!.recentlyPlayed,
            caption: '${userRecentlyPlayed.value.length}',
            icon: FluentIcons.history_24_regular,
            color: BrowseColors.teal,
            onTap: () => context.push('/library/userSongs/recents'),
          ),
        ];

        final playlists = getPlaylistsNotInFolders()
            .where((playlist) => playlist['ytid'] != null)
            .take(3)
            .toList();
        for (var index = 0; index < playlists.length; index++) {
          final playlist = playlists[index];
          tiles.add(
            _QuickAccessTile(
              label: playlist['title']?.toString() ?? '',
              imageUrl: playlist['image']?.toString(),
              color: BrowseColors.forIndex(index + 3),
              onTap: () => context.push(
                '/library/playlist/${playlist['ytid']}',
                extra: playlist,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DaylightSectionHeader(title: context.l10n!.yourLibrary),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.1,
              children: tiles,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final filters = <_HomeFilter, String>{
      _HomeFilter.all: context.l10n!.all,
      _HomeFilter.playlists: context.l10n!.playlists,
      _HomeFilter.songs: context.l10n!.songs,
    };

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = filters.entries.elementAt(index);
          return DaylightPill(
            label: entry.value,
            selected: _filter == entry.key,
            onTap: () => setState(() => _filter = entry.key),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          );
        },
      ),
    );
  }

  /// Recently played songs as horizontal cards with a play affordance.
  Widget _buildJumpBackIn() {
    return ValueListenableBuilder<List>(
      valueListenable: userRecentlyPlayed,
      builder: (context, songs, _) {
        if (songs.isEmpty) return const SizedBox.shrink();
        final visible = songs.take(8).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DaylightSectionHeader(title: context.l10n!.jumpBackIn),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final song = visible[index] as Map;
                  return _RecentSongCard(
                    song: song,
                    onTap: () => audioHandler.playPlaylistSong(
                      playlist: {
                        'title': context.l10n!.jumpBackIn,
                        'list': visible,
                      },
                      songIndex: index,
                      shuffle: false,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuggestedPlaylists() {
    return AsyncLoader<List<dynamic>>(
      future: _suggestedPlaylistsFuture,
      builder: (context, playlists) {
        if (playlists.isEmpty) return const SizedBox.shrink();
        return _PlaylistShelf(
          title: context.l10n!.inRotation,
          playlists: playlists.take(recommendedCubesNumber).toList(),
          onSeeAll: () => context.go('/library'),
        );
      },
    );
  }

  Widget _buildLikedPlaylists() {
    return ValueListenableBuilder<List<Map>>(
      valueListenable: userLikedPlaylists,
      builder: (context, liked, _) {
        final items = liked
            .where((playlist) => !isArtistPlaylist(playlist))
            .take(recommendedCubesNumber)
            .toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _PlaylistShelf(
            title: context.l10n!.backToFavorites,
            playlists: items,
          ),
        );
      },
    );
  }

  Widget _buildMonthRecap() {
    return ValueListenableBuilder<bool>(
      valueListenable: wrappedEnabled,
      builder: (context, isEnabled, _) {
        if (!isEnabled) return const SizedBox.shrink();

        final key = listeningStatsMonthKey(DateTime.now());
        final stats = listeningStatsService.monthStats(key);
        final songs = listeningStatsService.monthTopSongs(key, limit: 7);
        final minutes = monthDisplayMinutes(stats);
        if (minutes <= 0 && songs.isEmpty) return const SizedBox.shrink();

        final periodLabel = formatMonthPeriodLabel(
          Localizations.localeOf(context),
          key,
        );
        final maxPlays = songs.fold<int>(
          1,
          (max, song) =>
              math.max(max, (song['playCount'] as num?)?.toInt() ?? 1),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DaylightSectionHeader(title: context.l10n!.yourMonth),
              DaylightCard(
                onTap: () => context.push('/home/timeMachine'),
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$minutes',
                                style: Daylight.display(
                                  32,
                                  color: Daylight.cobalt,
                                  height: 0.95,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                context.l10n!.minutesListened,
                                style: Daylight.ui(
                                  10,
                                  color: Daylight.muted,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DaylightPill(
                          label: periodLabel,
                          icon: FluentIcons.data_trending_24_regular,
                        ),
                      ],
                    ),
                    if (songs.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < songs.length; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        height:
                                            8 +
                                            32 *
                                                (((songs[i]['playCount']
                                                                    as num?)
                                                                ?.toInt() ??
                                                            1) /
                                                        maxPlays)
                                                    .clamp(0.18, 1.0),
                                        decoration: BoxDecoration(
                                          color: i == songs.length - 2
                                              ? Daylight.cobalt
                                              : Daylight.cobaltSoft,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(4),
                                                bottom: Radius.circular(2),
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Text(
                          '${songs.length} ${context.l10n!.topSongs}',
                          style: Daylight.ui(10, color: Daylight.muted),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n!.timeMachine,
                              style: Daylight.ui(
                                10,
                                color: Daylight.cobalt,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              FluentIcons.arrow_right_16_regular,
                              size: 14,
                              color: Daylight.cobalt,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendedSongsSection() {
    return AsyncLoader<List<dynamic>>(
      future: _recommendedSongsFuture,
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return RecommendedSongsSection(
          title: context.l10n!.recommendedForYou,
          songs: data,
          listKeyPrefix: 'home_recommended',
        );
      },
    );
  }
}

/// Compact duration chip in the home app bar.
class DayLightDurationPill extends StatelessWidget {
  const DayLightDurationPill({required this.minutes, this.onTap, super.key});

  final int minutes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final label = hours > 0
        ? '${hours}h ${rest.toString().padLeft(2, '0')}m'
        : '${rest}m';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Daylight.cobaltSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.timer_16_regular,
              size: 12,
              color: Daylight.cobalt,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Daylight.ui(
                10,
                color: Daylight.cobalt,
                weight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.label,
    required this.onTap,
    this.caption,
    this.imageUrl,
    this.icon,
    this.color = BrowseColors.cobalt,
  });

  final String label;
  final String? caption;
  final String? imageUrl;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Daylight.line.withValues(alpha: 0.9)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: double.infinity,
              child: hasImage
                  ? Image(
                      image: ArtworkProvider.get(imageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    )
                  : _fallback(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Daylight.ui(
                      11,
                      weight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (caption != null && caption!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      caption!,
                      style: Daylight.ui(9, color: Daylight.faint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.24) ?? color],
        ),
      ),
      child: Center(
        child: Icon(
          icon ?? FluentIcons.music_note_2_24_filled,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RecentSongCard extends StatelessWidget {
  const _RecentSongCard({required this.song, required this.onTap});

  final Map song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (song['highResImage'] ?? song['image'])?.toString();
    return SizedBox(
      width: 116,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 116,
                    height: 116,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image(
                            image: ArtworkProvider.get(imageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _artFallback(),
                          )
                        : _artFallback(),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: Daylight.cobaltGradient,
                      shape: BoxShape.circle,
                      boxShadow: Daylight.cobaltShadow,
                    ),
                    child: const Icon(
                      FluentIcons.play_24_filled,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              song['title']?.toString() ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Daylight.ui(11.5, weight: FontWeight.w600),
            ),
            const SizedBox(height: 1),
            Text(
              song['artist']?.toString() ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Daylight.ui(9.5, color: Daylight.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: Daylight.softCobaltGradient),
      child: Center(
        child: Icon(
          FluentIcons.music_note_2_24_filled,
          size: 28,
          color: Daylight.cobalt,
        ),
      ),
    );
  }
}

class _PlaylistShelf extends StatelessWidget {
  const _PlaylistShelf({
    required this.title,
    required this.playlists,
    this.onSeeAll,
  });

  final String title;
  final List<dynamic> playlists;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DaylightSectionHeader(
          title: title,
          actionLabel: onSeeAll == null ? null : l10n.seeAll,
          onAction: onSeeAll,
        ),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (context, index) {
              final playlist = playlists[index] as Map;
              final isAlbum = playlist['isAlbum'] == true;
              return SizedBox(
                width: 94,
                child: GestureDetector(
                  onTap: () =>
                      context.push('/home/playlist/${playlist['ytid']}'),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: DaylightCover(
                          size: 88,
                          imageUrl: playlist['image']?.toString(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        playlist['title']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Daylight.ui(
                          11.5,
                          weight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAlbum ? l10n.album : l10n.playlist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Daylight.ui(9.5, color: Daylight.muted),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
