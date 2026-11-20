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

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/playlist_page.dart';
import 'package:musify/services/artist_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/widgets/artist_shelf.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/overflow_menu_button.dart';
import 'package:musify/widgets/playlist_page/download_button.dart';
import 'package:musify/widgets/playlist_page/empty_playlist_state.dart';
import 'package:musify/widgets/playlist_page/like_button.dart';
import 'package:musify/widgets/popup_menu_item.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:musify/widgets/spinner.dart';

/// The page an artist opens on: a full-bleed portrait, the actions that play
/// or keep the artist, its ranked songs, its releases and related artists.
class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.artistId, this.artistData});

  final String artistId;
  final Map? artistData;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  static const _popularPreviewCount = 5;
  static const _releasePreviewCount = 4;

  /// Read the first time the page is shown online, and left alone offline,
  /// where the artist is its downloaded songs and there is nothing to read.
  Future<Map<String, dynamic>?>? _artistFuture;

  Map<String, dynamic>? _artist;
  Map<String, dynamic>? _catalog;
  Future<Map?>? _catalogFuture;
  List<Map<String, dynamic>> _topSongs = const [];
  List<String?> _topSongPlayCounts = const [];
  List<Map<String, dynamic>> _releases = const [];
  List<Map<String, dynamic>> _relatedArtists = const [];

  bool _showAllPopular = false;
  bool _showAllReleases = false;

  /// Whether the songs of the artist are being read for the play buttons.
  final _isLoadingCatalog = ValueNotifier<bool>(false);

  /// Cache for the resolved artist ID to avoid repeated lookups.
  String? _cachedResolvedArtistId;

  /// Cache for the artist title to avoid repeated lookups.
  String? _cachedArtistTitle;

  int _artistLoadGeneration = 0;

  /// Refresh artist data, preserving current state on failure.
  Future<void> _refresh() async {
    final generation = ++_artistLoadGeneration;
    final loaded = _artistFuture;
    _catalogFuture = null;
    final refreshed = _loadArtist(forceRefresh: true, refreshCatalog: true);
    // Block syntax: setState doesn't accept Future-returning callbacks
    setState(() {
      _artistFuture = refreshed;
    });

    Map<String, dynamic>? refreshedArtist;
    try {
      refreshedArtist = await refreshed;
    } catch (_) {
      refreshedArtist = null;
    }
    if (!mounted ||
        generation != _artistLoadGeneration ||
        refreshedArtist != null) {
      return;
    }
    setState(() {
      _artistFuture = loaded;
    });
    showToast(context, context.l10n!.error);
  }

  @override
  void didUpdateWidget(covariant ArtistPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Artist identity is determined by ID only (data seed changes on rebuild)
    if (oldWidget.artistId != widget.artistId) {
      _artistLoadGeneration++;
      _artistFuture = null;
      _catalog = null;
      _catalogFuture = null;
      _cachedResolvedArtistId = null;
      _cachedArtistTitle = null;
      _showAllPopular = false;
      _showAllReleases = false;
    }
  }

  @override
  void dispose() {
    _isLoadingCatalog.dispose();
    super.dispose();
  }

  String get _resolvedArtistId =>
      _cachedResolvedArtistId ??= _artist?['ytid']?.toString() ?? widget.artistId;

  String get _artistTitle =>
      _cachedArtistTitle ??=
          _artist?['title']?.toString() ??
          widget.artistData?['title']?.toString() ??
          '';

  String? get _artistImage {
    final image =
        _artist?['image']?.toString() ??
        widget.artistData?['image']?.toString();
    return image == null || image.trim().isEmpty ? null : image.trim();
  }

  Future<Map<String, dynamic>?> _loadArtist({
    bool forceRefresh = false,
    bool refreshCatalog = false,
  }) async {
    final generation = _artistLoadGeneration;
    final artistData = widget.artistData;
    final artist = await getArtistProfile(
      widget.artistId,
      forceRefresh: forceRefresh,
      cacheResult: !refreshCatalog,
      preferredName: artistData?['title']?.toString(),
      preferredImage: artistData?['image']?.toString(),
      sourceSongId: artistData?['sourceSongId']?.toString(),
      sourceVideoAuthor: artistData?['videoAuthor']?.toString(),
      preferredVerified: artistData?['isVerifiedArtist'] == true,
    );
    if (artist == null || !mounted || generation != _artistLoadGeneration) {
      return null;
    }

    Map<String, dynamic>? catalog;
    if (refreshCatalog) {
      catalog = await getArtistCatalogFromProfile(artist, forceRebuild: true);
      if (catalog == null ||
          catalog['catalogStatus'] == 'failed' ||
          !mounted ||
          generation != _artistLoadGeneration) {
        return null;
      }
      cacheArtistProfileInBackground(artist);
    }

    _artist = artist;
    if (refreshCatalog) {
      _catalog = catalog;
      _catalogFuture = null;
    }
    // Clear caches when artist data updates
    _cachedResolvedArtistId = null;
    _cachedArtistTitle = null;
    _showAllPopular = false;
    _showAllReleases = false;
    // Each entry of the shelf is a song and its play count, side by side.
    final topSongs = asMapList(artist['topSongs'])
        .where((entry) => entry['song'] is Map)
        .toList();
    _topSongs = [
      for (final entry in topSongs)
        Map<String, dynamic>.from(entry['song'] as Map),
    ];
    _topSongPlayCounts = [
      for (final entry in topSongs) entry['playCount']?.toString(),
    ];
    _releases = asMapList(artist['releases']);
    _relatedArtists = asMapList(artist['relatedArtists']);
    return artist;
  }

  @override
  Widget build(BuildContext context) {
    // Offline: show downloaded songs only; online: fetch full profile
    if (offlineMode.value) return _buildAllSongsPage();

    return AsyncLoader<Map<String, dynamic>?>(
      future: _artistFuture ??= _loadArtist(),
      loadingWidget: Scaffold(appBar: AppBar(), body: const Spinner()),
      emptyWidget: _buildNotFoundPage(),
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            _buildHero(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthlyListeners(context),
                    const SizedBox(height: 16),
                    _buildActions(context),
                    if (_topSongs.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _buildPopular(context),
                    ],
                    if (_releases.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      _buildReleases(context),
                    ],
                    if (_relatedArtists.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      ArtistShelf(
                        title: context.l10n!.fansAlsoLike,
                        icon: FluentIcons.person_24_regular,
                        items: _relatedArtists,
                        cubeIcon: FluentIcons.person_24_filled,
                        circular: true,
                        onTap: _openArtist,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: MiniPlayerBottomSpace()),
          ],
        ),
      ),
    );
  }

  /// The artist as its song list, which offline is the whole page.
  Widget _buildAllSongsPage() {
    return PlaylistPage(
      playlistId: widget.artistId,
      playlistData: artistPlaylistData({
        'ytid': widget.artistId,
        'title': _artistTitle,
        'image': _artist?['image'] ?? widget.artistData?['image'],
      }),
      cubeIcon: FluentIcons.person_24_filled,
      isArtist: true,
    );
  }

  Widget _buildNotFoundPage() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(context.l10n!.artist)),
      body: CustomScrollView(
        slivers: [
          // Not finding an artist is an answer, not a failure of the app.
          EmptyPlaylistState(
            icon: FluentIcons.person_24_filled,
            message: context.l10n!.artistNotFound,
          ),
          const SliverMiniPlayerBottomSpace(),
        ],
      ),
    );
  }

  /// Full-bleed portrait with the name and verified mark laid over a scrim.
  Widget _buildHero(BuildContext context) {
    final l10n = context.l10n!;
    final isVerified = _artist?['isVerifiedArtist'] == true;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 328,
      backgroundColor: Daylight.groundTop,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 66,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: DaylightCircleButton(
            icon: FluentIcons.arrow_left_24_regular,
            iconSize: 17,
            tooltip: l10n.back,
            onTap: () => context.pop(),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(child: _buildHeroMenu(context)),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildHeroImage(context),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x59000000), Color(0x00000000)],
                    stops: [0.0, 0.32],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xD10B0D12)],
                    stops: [0.42, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _artistTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Daylight.display(
                        37,
                        color: Colors.white,
                        height: 1.02,
                        letterSpacing: -1.3,
                      ).copyWith(
                        shadows: const [
                          Shadow(
                            color: Color(0x55000000),
                            blurRadius: 18,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            FluentIcons.checkmark_circle_24_filled,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            l10n.verifiedArtist,
                            style: Daylight.ui(
                              11,
                              color: Colors.white.withValues(alpha: 0.92),
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    final image = _artistImage;
    if (image == null) return _buildHeroFallback();

    return Image(
      image: ArtworkProvider.get(image),
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.22),
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _buildHeroFallback(),
    );
  }

  Widget _buildHeroFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: Daylight.softCobaltGradient),
      child: Center(
        child: Icon(
          FluentIcons.person_24_filled,
          size: 78,
          color: Daylight.cobalt.withValues(alpha: 0.26),
        ),
      ),
    );
  }

  /// Add-to-playlist and refresh are rare on an artist, so they sit behind the
  /// title while the actions people actually use stay on the page.
  Widget _buildHeroMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: Daylight.cardShadow,
      ),
      child: OverflowMenuButton<String>(
        iconSize: 18,
        color: Daylight.ink,
        tooltip: context.l10n!.moreOptions,
        onSelected: (value) => unawaited(_handleHeroMenu(context, value)),
        itemBuilder: (context) => [
          buildPopupMenuItem<String>(
            value: 'add',
            icon: FluentIcons.album_add_24_regular,
            label: context.l10n!.addToPlaylist,
            colorScheme: colorScheme,
          ),
          buildPopupMenuItem<String>(
            value: 'update',
            icon: FluentIcons.arrow_sync_24_filled,
            label: context.l10n!.update,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyListeners(BuildContext context) {
    final listeners = _artist?['monthlyListeners']?.toString().trim() ?? '';
    if (listeners.isEmpty) return const SizedBox.shrink();

    return Text(
      '$listeners ${context.l10n!.monthlyListeners}',
      style: Daylight.ui(
        12.5,
        color: Daylight.muted,
        weight: FontWeight.w500,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final l10n = context.l10n!;
    final likeButton = PlaylistLikeButton(
      playlistId: _resolvedArtistId,
      playlistData: () => artistPlaylistData(_artist!, songs: const []),
      asPill: true,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The pill is allowed to take the space left by the fixed circles and
        // the portrait, so a narrow phone drops the label instead of the row.
        const fixedWidth = 46 + 10 + 8 + 42 + 2 + 44 + 10 + 56;
        final pillMaxWidth = (constraints.maxWidth - fixedWidth)
            .clamp(64.0, 220.0)
            .toDouble();

        return Row(
          children: [
            _ArtistAvatar(image: _artistImage),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: pillMaxWidth),
              child: likeButton,
            ),
            const Spacer(),
            PlaylistDownloadButton(
              playlistId: _resolvedArtistId,
              resolvePlaylist: _loadCatalog,
              songs: _catalog?['list'] as List?,
              requireSnapshotMatch: true,
            ),
            const SizedBox(width: 2),
            DaylightCircleButton(
              icon: FluentIcons.arrow_shuffle_24_filled,
              iconSize: 19,
              size: 44,
              color: Daylight.cobalt,
              tooltip: l10n.shuffle,
              onTap: () => unawaited(_playArtist(shuffle: true)),
            ),
            const SizedBox(width: 10),
            _buildPlayButton(context),
          ],
        );
      },
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n!.play,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: Daylight.cobaltShadow,
        ),
        child: Material(
          color: Daylight.cobalt,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _isLoadingCatalog.value
                ? null
                : () => unawaited(_playArtist()),
            child: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: _isLoadingCatalog,
                builder: (_, isLoading, __) => isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Daylight.onAccent,
                        ),
                      )
                    : Icon(
                        FluentIcons.play_24_filled,
                        size: 25,
                        color: Daylight.onAccent,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopular(BuildContext context) {
    final l10n = context.l10n!;
    final visible = _showAllPopular
        ? _topSongs
        : _topSongs.take(_popularPreviewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: l10n.popular),
        const SizedBox(height: 6),
        for (var index = 0; index < visible.length; index++)
          RepaintBoundary(
            key: listItemKey('artist_top_song', index, visible[index]),
            child: SongBar(
              visible[index],
              true,
              rank: index + 1,
              playCount: _topSongPlayCounts[index],
              barPadding: const EdgeInsetsDirectional.symmetric(vertical: 6),
              artworkBorderRadius: BorderRadius.circular(8),
              onPlay: () => audioHandler.playPlaylistSong(
                playlist: {'title': _artistTitle, 'list': _topSongs},
                songIndex: index,
              ),
            ),
          ),
        if (_topSongs.length > _popularPreviewCount) ...[
          const SizedBox(height: 12),
          Center(
            child: _OutlinePill(
              label: _showAllPopular ? l10n.showLess : l10n.showAll,
              onTap: () => setState(() => _showAllPopular = !_showAllPopular),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReleases(BuildContext context) {
    final l10n = context.l10n!;
    final hasMore = _releases.length > _releasePreviewCount;
    final visible = _showAllReleases
        ? _releases
        : _releases.take(_releasePreviewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: l10n.popularReleases,
          action: hasMore
              ? _SectionAction(
                  label: _showAllReleases ? l10n.showLess : l10n.showAll,
                  onTap: () =>
                      setState(() => _showAllReleases = !_showAllReleases),
                )
              : null,
        ),
        const SizedBox(height: 8),
        for (final release in visible)
          _ReleaseRow(
            release: release,
            subtitle: _releaseSubtitle(release),
            onTap: () => _openRelease(release),
          ),
        const SizedBox(height: 18),
        Center(
          child: _OutlinePill(
            label: l10n.allSongs,
            icon: FluentIcons.arrow_right_24_regular,
            onTap: _openAllSongs,
          ),
        ),
      ],
    );
  }

  String _releaseSubtitle(Map<String, dynamic> release) {
    final year = release['year']?.toString();
    final type = switch (release['releaseType']?.toString()) {
      'single' => context.l10n!.single,
      'ep' => 'EP',
      _ => context.l10n!.album,
    };
    return year == null || year.isEmpty ? type : '$type • $year';
  }

  // Shares the complete catalog with "All songs" and keeps it after the first
  // action so play, add and download cannot resolve different song snapshots.
  Future<Map?> _loadCatalog() async {
    final loadedCatalog = _catalog;
    if (loadedCatalog != null) return loadedCatalog;

    final inFlight = _catalogFuture;
    if (inFlight != null) return inFlight;

    final generation = _artistLoadGeneration;
    final artistId = _resolvedArtistId;
    final future = _resolveCatalog();
    _catalogFuture = future;
    final catalog = await future;

    final ownsFuture = identical(_catalogFuture, future);
    final isCurrent =
        mounted &&
        generation == _artistLoadGeneration &&
        artistId == _resolvedArtistId &&
        ownsFuture;
    if (ownsFuture) _catalogFuture = null;
    if (!isCurrent) return null;

    if (catalog != null && catalog['catalogStatus'] != 'failed') {
      setState(() {
        _catalog = Map<String, dynamic>.from(catalog);
      });
    }
    return catalog;
  }

  Future<Map?> _resolveCatalog() {
    final artist = _artist;
    if (artist != null) return getArtistCatalogFromProfile(artist);

    return getPlaylistInfoForWidget(
      _resolvedArtistId,
      isArtist: true,
      artistName: _artistTitle,
      artistImage: _artist?['image']?.toString(),
      preferredVerified: _artist?['isVerifiedArtist'] == true,
    );
  }

  Future<void> _handleHeroMenu(BuildContext context, String value) async {
    switch (value) {
      case 'add':
        final catalog = await _loadCatalog();
        if (!mounted) return;
        final songs = catalog?['list'];
        if (songs is! List || songs.isEmpty) {
          showToast(context, context.l10n!.noSongsInPlaylist);
          return;
        }
        await showAddToPlaylistDialog(context, songs: songs);
        break;
      case 'update':
        await _refresh();
        break;
    }
  }

  Future<void> _playArtist({bool shuffle = false}) async {
    if (_isLoadingCatalog.value) return;
    _isLoadingCatalog.value = true;
    try {
      final catalog = await _loadCatalog();
      if (!mounted) return;

      final songs = catalog?['list'] as List? ?? const [];
      if (songs.isEmpty) {
        showToast(context, context.l10n!.error);
        return;
      }

      if (shuffle) {
        await audioHandler.addPlaylistToQueue(
          List<Map>.from(songs.whereType<Map>()),
          replace: true,
          shuffle: true,
        );
      } else {
        await audioHandler.playPlaylistSong(
          playlist: catalog,
          songIndex: 0,
          shuffle: false,
        );
      }
    } finally {
      if (mounted) _isLoadingCatalog.value = false;
    }
  }

  void _openAllSongs() {
    context.push(
      NavigationManager.artistSongsPath(context, _resolvedArtistId),
      extra: artistPlaylistData(_artist!),
    );
  }

  void _openArtist(Map<String, dynamic> artist) {
    final artistId = artist['ytid']?.toString();
    if (artistId == null || artistId.isEmpty) return;

    context.push(
      NavigationManager.artistPath(context, artistId),
      extra: artist,
    );
  }

  void _openRelease(Map<String, dynamic> release) {
    final releaseId = release['ytid']?.toString();
    if (releaseId == null || releaseId.isEmpty) return;

    context.push(
      NavigationManager.albumPath(context, releaseId),
      extra: release,
    );
  }
}

/// A square artist portrait with the floating-edge treatment of the header.
class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({required this.image});

  final String? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: Daylight.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _Artwork(image: image),
      ),
    );
  }
}

/// A release in the vertical "Popular releases" list.
class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({
    required this.release,
    required this.subtitle,
    required this.onTap,
  });

  final Map<String, dynamic> release;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = release['image']?.toString();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: _Artwork(image: image),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      release['title']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Daylight.ui(
                        13,
                        color: Daylight.ink,
                        weight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Daylight.ui(11, color: Daylight.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The square artwork shared by the avatar and the release rows.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.image});

  final String? image;

  @override
  Widget build(BuildContext context) {
    final url = image?.trim();
    if (url == null || url.isEmpty) return const _ArtworkFallback();

    return Image(
      image: ArtworkProvider.get(url),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const _ArtworkFallback(),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Daylight.cardTintStrong,
      child: Center(
        child: Icon(
          FluentIcons.music_note_2_24_filled,
          size: 20,
          color: Daylight.faint,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Daylight.display(21, letterSpacing: -0.5),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _SectionAction extends StatelessWidget {
  const _SectionAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Daylight.cobalt,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Daylight.ui(11.5, weight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

/// The quiet outlined pill used for "Show all" and "All songs".
class _OutlinePill extends StatelessWidget {
  const _OutlinePill({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: Daylight.lineStrong)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Daylight.ui(
                  11.5,
                  color: Daylight.ink,
                  weight: FontWeight.w600,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 5),
                Icon(icon, size: 14, color: Daylight.ink),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
