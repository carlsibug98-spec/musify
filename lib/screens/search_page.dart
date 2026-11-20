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
import 'package:hive_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/widgets/artist_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/custom_bar.dart';
import 'package:musify/widgets/custom_search_bar.dart';
import 'package:musify/widgets/daylight/browse_tile.dart';
import 'package:musify/widgets/daylight/daylight_ui.dart';
import 'package:musify/widgets/daylight/genre_grid.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/section_title.dart';
import 'package:musify/widgets/song_bar.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

// Global ValueNotifier for search history to make it reactive
final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>(
  Hive.box('user').get('searchHistory', defaultValue: []),
);

/// Set by the Home/Search genre cards so tapping "Pop" or "OPM" opens Search
/// with that genre already queried — real songs, not a dead category page.
final ValueNotifier<String?> genreSearchRequest = ValueNotifier<String?>(null);

void reloadSearchHistoryFromStorage() {
  searchHistoryNotifier.value = Hive.box('user')
      .get('searchHistory', defaultValue: []);
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  int maxSongsInList = 15;
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSuggestionRequest = 0;
  int _latestSearchRequest = 0;

  @override
  void initState() {
    super.initState();
    genreSearchRequest.addListener(_onGenreRequest);
    // The branch may have been created after a genre card set the request.
    if (genreSearchRequest.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onGenreRequest());
    }
  }

  void _onGenreRequest() {
    final query = genreSearchRequest.value;
    if (query == null || query.isEmpty) return;
    genreSearchRequest.value = null;
    _submitSearch(query);
  }

  Future<void> _submitSearch([String? query]) async {
    if (query != null) {
      _searchBar.text = query;
      _searchBar.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchBar.text.length),
      );
    }

    _latestSuggestionRequest++;
    _debounce?.cancel();
    _suggestionsList = [];
    if (mounted) setState(() {});

    await search();
    _inputNode.unfocus();
  }

  @override
  void dispose() {
    genreSearchRequest.removeListener(_onGenreRequest);
    _searchBar.dispose();
    _inputNode.dispose();
    _fetchingSongs.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> search() async {
    final query = _searchBar.text.trim();
    final requestId = ++_latestSearchRequest;

    if (query.isEmpty) {
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _albumsSearchResult = [];
      _playlistsSearchResult = [];
      _suggestionsList = [];
      _fetchingSongs.value = false;
      if (mounted) setState(() {});
      return;
    }
    _fetchingSongs.value = true;

    _songsSearchResult = [];
    _artistsSearchResult = [];
    _albumsSearchResult = [];
    _playlistsSearchResult = [];
    if (mounted) setState(() {});

    if (!searchHistoryNotifier.value.contains(query)) {
      final updatedHistory = List.from(searchHistoryNotifier.value)
        ..insert(0, query);
      searchHistoryNotifier.value = updatedHistory;
      unawaited(addOrUpdateData<List>('user', 'searchHistory', updatedHistory));
    }

    try {
      final artistsFuture = searchArtists(query);

      Future<void> publishSongs() async {
        try {
          var songs = await fetchSongsList(query);
          if (!mounted || requestId != _latestSearchRequest) return;

          if (songs.isEmpty) {
            final artists = await artistsFuture;
            if (!mounted || requestId != _latestSearchRequest) return;
            if (_artistsSearchResult.isEmpty) {
              _artistsSearchResult = artists
                  .whereType<Map>()
                  .map(Map<String, dynamic>.from)
                  .toList();
            }
            if (_artistsSearchResult.isNotEmpty) {
              songs = await _fetchSongsForResolvedArtist(query);
            }
          }

          if (!mounted || requestId != _latestSearchRequest) return;
          setState(() => _songsSearchResult = songs);
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online songs',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      Future<void> publishArtists() async {
        try {
          final artists = await artistsFuture;
          if (!mounted || requestId != _latestSearchRequest) return;
          setState(() {
            _artistsSearchResult = artists
                .whereType<Map>()
                .map(Map<String, dynamic>.from)
                .toList();
          });
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online artists',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      Future<void> publishAlbums() async {
        try {
          final albums = await getPlaylists(query: query, type: 'album');
          if (!mounted || requestId != _latestSearchRequest) return;
          setState(() => _albumsSearchResult = albums);
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online albums',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      Future<void> publishPlaylists() async {
        try {
          final playlists = await getPlaylists(query: query, type: 'playlist');
          if (!mounted || requestId != _latestSearchRequest) return;
          setState(() => _playlistsSearchResult = playlists);
        } catch (e, stackTrace) {
          logger.log(
            'Error while searching online playlists',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      await Future.wait([
        publishSongs(),
        publishArtists(),
        publishAlbums(),
        publishPlaylists(),
      ]);
    } catch (e, stackTrace) {
      logger.log(
        'Error while searching online songs',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (requestId == _latestSearchRequest) {
        _fetchingSongs.value = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<List<dynamic>> _fetchSongsForResolvedArtist(String query) async {
    final artistName = _artistsSearchResult.first['title']?.toString().trim();
    if (artistName == null || artistName.isEmpty) return [];

    final fallbackQueries = <String>{
      if (artistName.toLowerCase() != query.trim().toLowerCase()) artistName,
      '$artistName songs',
      '$artistName music',
    };

    for (final fallbackQuery in fallbackQueries) {
      final songs = await fetchSongsList(fallbackQuery);
      if (songs.isNotEmpty) return songs;
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: <Widget>[
          DaylightAppBar(title: context.l10n!.search),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final bar = ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 600 : double.infinity,
                  ),
                  child: CustomSearchBar(
                    loadingProgressNotifier: _fetchingSongs,
                    controller: _searchBar,
                    focusNode: _inputNode,
                    labelText: '${context.l10n!.search}...',
                    onChanged: (value) {
                      // debounce suggestions to avoid rapid API calls
                      _debounce?.cancel();
                      final query = value;
                      final requestId = ++_latestSuggestionRequest;

                      // An emptied field goes back to the search history, and
                      // the history only shows while nothing has been found
                      // yet. Dropping the suggestions is not enough: the
                      // results of the last search have to go with them.
                      if (query.isEmpty) {
                        unawaited(search());
                        return;
                      }

                      _debounce = Timer(
                        const Duration(milliseconds: 300),
                        () async {
                          final searchSuggestions = await getSearchSuggestions(
                            query,
                          );

                          if (!mounted ||
                              requestId != _latestSuggestionRequest ||
                              _searchBar.text != query) {
                            return;
                          }

                          _suggestionsList = List<String>.from(
                            searchSuggestions,
                          );
                          if (mounted) setState(() {});
                        },
                      );
                    },
                    onSubmitted: (String value) {
                      _submitSearch();
                    },
                  ),
                );
                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [bar],
                  );
                } else {
                  return bar;
                }
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: Daylight.motion(
                      context,
                      const Duration(milliseconds: 200),
                    ),
                    child:
                        (_suggestionsList.isNotEmpty ||
                            (_songsSearchResult.isEmpty &&
                                _artistsSearchResult.isEmpty &&
                                _albumsSearchResult.isEmpty &&
                                _playlistsSearchResult.isEmpty))
                        ? ValueListenableBuilder<List>(
                            valueListenable: searchHistoryNotifier,
                            builder: (context, searchHistory, _) {
                              final items = _suggestionsList.isEmpty
                                  ? searchHistory
                                  : _suggestionsList;

                              return Column(
                                key: ValueKey(
                                  'history-${_suggestionsList.length}-${_searchBar.text}-${searchHistory.length}',
                                ),
                                children: [
                                  if (items.isNotEmpty) ...[
                                    if (_suggestionsList.isEmpty)
                                      DaylightSectionHeader(
                                        title: context.l10n!.recentSearches,
                                        actionLabel: context.l10n!.clear,
                                        onAction: () {
                                          searchHistoryNotifier.value = [];
                                          unawaited(
                                            addOrUpdateData<List>(
                                              'user',
                                              'searchHistory',
                                              [],
                                            ),
                                          );
                                        },
                                      )
                                    else
                                      DaylightSectionHeader(
                                        title: context.l10n!.search,
                                      ),
                                  ],
                                  for (
                                    int index = 0;
                                    index < items.length;
                                    index++
                                  )
                                    Builder(
                                      builder: (context) {
                                        final query = items[index];
                                        final borderRadius =
                                            getItemBorderRadius(
                                              index,
                                              items.length,
                                            );

                                        return CustomBar(
                                          query.toString(),
                                          FluentIcons.search_24_regular,
                                          borderRadius: borderRadius,
                                          onTap: () async {
                                            await _submitSearch(
                                              query.toString(),
                                            );
                                          },
                                          onLongPress: () async {
                                            final confirm =
                                                await _showConfirmationDialog(
                                                  context,
                                                ) ??
                                                false;
                                            if (confirm &&
                                                searchHistory.contains(query)) {
                                              final updatedHistory = List.from(
                                                searchHistory,
                                              )..remove(query);
                                              searchHistoryNotifier.value =
                                                  updatedHistory;
                                              unawaited(
                                                addOrUpdateData<List>(
                                                  'user',
                                                  'searchHistory',
                                                  updatedHistory,
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  if (_suggestionsList.isEmpty) ...[
                                    if (items.isNotEmpty)
                                      const SizedBox(height: 18),
                                    _buildBrowseAll(context),
                                  ],
                                ],
                              );
                            },
                          )
                        : _buildSearchResults(context, primaryColor),
                  ),
                  const MiniPlayerBottomSpace(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Spotify-style browse grid shown while the search field is idle. Every
  /// tile opens a real Musify surface (library or downloads).
  Widget _buildBrowseAll(BuildContext context) {
    final tiles = <BrowseTileData>[];

    final shortcuts = <BrowseTileData>[
      BrowseTileData(
        title: context.l10n!.madeForYou,
        color: BrowseColors.cobalt,
        icon: FluentIcons.sparkle_24_filled,
        onTap: () => context.go('/home'),
      ),
      BrowseTileData(
        title: context.l10n!.likedSongs,
        color: BrowseColors.rose,
        icon: FluentIcons.heart_24_filled,
        onTap: () => context.push('/library/userSongs/liked'),
      ),
      BrowseTileData(
        title: context.l10n!.recentlyPlayed,
        color: BrowseColors.teal,
        icon: FluentIcons.history_24_regular,
        onTap: () => context.push('/library/userSongs/recents'),
      ),
      BrowseTileData(
        title: context.l10n!.downloads,
        color: BrowseColors.pine,
        icon: FluentIcons.arrow_download_24_regular,
        onTap: () => context.push('/library/downloads'),
      ),
    ];
    tiles.addAll(shortcuts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DaylightSectionHeader(title: context.l10n!.browseAll),
        const SizedBox(height: 4),
        BrowseTileGrid(tiles: tiles),
        const SizedBox(height: 18),
        GenreGrid(
          title: context.l10n!.genres,
          actionLabel: context.l10n!.seeAll,
          onAction: () => genreSearchRequest.value = 'pop songs',
        ),
      ],
    );
  }

  /// Spotify-style hero card for the best match in the result set.
  Widget _buildTopResultCard(
    BuildContext context, {
    Map<String, dynamic>? song,
    Map<String, dynamic>? artist,
    required Color primaryColor,
  }) {
    final isSong = song != null;
    final data = song ?? artist!;
    final title = data['title']?.toString() ?? '';
    final imageUrl = (data['highResImage'] ?? data['image'])?.toString();
    final subtitle = isSong
        ? (data['artist']?.toString() ?? '')
        : context.l10n!.artist;

    void onTap() {
      if (isSong) {
        audioHandler.playPlaylistSong(
          playlist: {'title': _searchBar.text, 'list': _songsSearchResult},
          songIndex: 0,
          shuffle: false,
        );
      } else {
        final artistId =
            data['ytid']?.toString() ?? data['title']?.toString() ?? '';
        if (artistId.isEmpty) return;
        context.push(
          '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(artistId)}',
          extra: data,
        );
      }
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Daylight.card,
          borderRadius: BorderRadius.circular(16),
          border: Daylight.hairline,
          boxShadow: Daylight.cardShadow,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 74,
                height: 74,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _topResultFallback(),
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Image(
                        image: ArtworkProvider.get(imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Daylight.display(
                      17,
                      color: Daylight.ink,
                      weight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSong
                        ? '${context.l10n!.song} · $subtitle'
                        : context.l10n!.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Daylight.ui(10.5, color: Daylight.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DaylightCircleButton(
              icon: isSong
                  ? FluentIcons.play_24_filled
                  : FluentIcons.arrow_right_24_regular,
              filled: isSong,
              tooltip: isSong ? context.l10n!.play : context.l10n!.artist,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _topResultFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: Daylight.softCobaltGradient),
      child: Center(
        child: Icon(
          FluentIcons.music_note_2_24_filled,
          size: 30,
          color: Daylight.cobalt,
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, Color primaryColor) {
    final widgets = <Widget>[];

    // Top result — the one thing Spotify always leads with.
    final topSong = _songsSearchResult.isNotEmpty
        ? _songsSearchResult.first
        : null;
    final topArtist = _artistsSearchResult.isNotEmpty
        ? _artistsSearchResult.first
        : null;
    if (topSong != null || topArtist != null) {
      widgets.add(DaylightSectionHeader(title: context.l10n!.topResult));
      widgets.add(const SizedBox(height: 4));
      widgets.add(
        _buildTopResultCard(
          context,
          song: topSong,
          artist: topArtist,
          primaryColor: primaryColor,
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    // Artists section
    if (_artistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.artists,
          primaryColor,
          icon: FluentIcons.person_24_filled,
        ),
      );

      final artists = _artistsSearchResult.take(3).toList();
      for (var index = 0; index < artists.length; index++) {
        final artist = Map<String, dynamic>.from(artists[index]);
        final artistId =
            artist['ytid']?.toString() ?? artist['title']?.toString() ?? '';
        if (artistId.isEmpty) continue;

        final borderRadius = getItemBorderRadius(index, artists.length);
        widgets.add(
          ArtistBar(
            key: listItemKey('search_artist', index, artist),
            artist: artist,
            borderRadius: borderRadius,
            onTap: () {
              context.push(
                '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(artistId)}',
                extra: artist,
              );
            },
          ),
        );
      }
    }

    // Songs section
    if (_songsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.songs,
          primaryColor,
          icon: FluentIcons.music_note_1_24_filled,
        ),
      );

      final songsCount = _songsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _songsSearchResult.length;

      for (var index = 0; index < songsCount; index++) {
        final song = _songsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, songsCount);
        widgets.add(
          SongBar(
            song,
            true,
            key: listItemKey('search_song', index, song),
            showMusicDuration: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Albums section
    if (_albumsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.albums,
          primaryColor,
          icon: FluentIcons.album_24_filled,
        ),
      );

      final albumsCount = _albumsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _albumsSearchResult.length;

      for (var index = 0; index < albumsCount; index++) {
        final playlist = _albumsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, albumsCount);

        widgets.add(
          PlaylistBar(
            key: listItemKey('search_album', index, playlist),
            playlist['title'],
            playlistId: playlist['ytid'],
            playlistArtwork: playlist['image'],
            cubeIcon: FluentIcons.cd_16_filled,
            isAlbum: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Playlists section
    if (_playlistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.playlists,
          primaryColor,
          icon: FluentIcons.text_bullet_list_24_filled,
        ),
      );

      final playlistsCount = _playlistsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _playlistsSearchResult.length;

      for (var index = 0; index < playlistsCount; index++) {
        final playlist = _playlistsSearchResult[index];
        final isLast = index == playlistsCount - 1;
        final borderRadius = getItemBorderRadius(index, playlistsCount);

        widgets.add(
          Padding(
            padding: isLast ? commonListViewBottomPadding : EdgeInsets.zero,
            child: PlaylistBar(
              key: listItemKey('search_playlist', index, playlist),
              playlist['title'],
              playlistId: playlist['ytid'],
              playlistArtwork: playlist['image'],
              cubeIcon: FluentIcons.apps_list_24_filled,
              borderRadius: borderRadius,
            ),
          ),
        );
      }
    }

    return Column(
      key: ValueKey(
        'results-${_songsSearchResult.length}-${_artistsSearchResult.length}-${_albumsSearchResult.length}-${_playlistsSearchResult.length}',
      ),
      children: widgets,
    );
  }

  Future<bool?> _showConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmationMessage: context.l10n!.removeSearchQueryQuestion,
          submitMessage: context.l10n!.confirm,
          onCancel: () {
            Navigator.of(context).pop(false);
          },
          onSubmit: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );
  }
}
