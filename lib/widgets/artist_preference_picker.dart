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
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/artist_preference_service.dart';
import 'package:musify/services/playlists_manager.dart' show searchArtists;
import 'package:musify/theme/daylight.dart';
import 'package:musify/utilities/artwork_provider.dart';

/// Spotify-style taste picker: the user picks artists they like and Musify
/// builds the home feed from those seeds. Mirrors REA findings from Spotify's
/// onboarding quiz (pick artists → submit → curated recommendations).
class ArtistPreferencePicker extends StatefulWidget {
  const ArtistPreferencePicker({
    super.key,
    this.onDone,
    this.initialSelection = const [],
  });

  final VoidCallback? onDone;
  final List<PreferredArtist> initialSelection;

  @override
  State<ArtistPreferencePicker> createState() =>
      _ArtistPreferencePickerState();
}

class _ArtistPreferencePickerState extends State<ArtistPreferencePicker> {
  // Real artist names load reliably as verified artists; generic genre words
  // mostly resolve to "topic" channels that the official-artist filter drops.
  static const _seedArtists = [
    'Zild', 'Taylor Swift', 'The Weeknd', 'Radiohead',
    'Arctic Monkeys', 'Billie Eilish', 'BINI', 'Coldplay',
  ];

  final _selected = <PreferredArtist>{};
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _artists = [];
  List<Map<String, dynamic>> _genresResults = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Standalone routes pass no initial selection; read what the user saved
    // earlier so the picker reflects their real taste on re-open.
    _selected.addAll(
      widget.initialSelection.isNotEmpty
          ? widget.initialSelection
          : preferredArtists.value,
    );
    _loadSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loading = true);
    final results = await Future.wait(
      _seedArtists.take(6).map((g) => searchArtists(g, limit: 2)),
    );
    final combined = <String, Map<String, dynamic>>{};
    for (final group in results) {
      for (final artist in group) {
        final id = (artist['ytid'] ?? artist['id'])?.toString() ?? '';
        if (id.isNotEmpty) combined.putIfAbsent(id, () => artist);
      }
    }
    // Keep already-selected artists visible even if the seeded search changes.
    for (final saved in _selected) {
      if (saved.id.isNotEmpty) {
        combined.putIfAbsent(saved.id, () => {
          'ytid': saved.id,
          'title': saved.name,
          'image': saved.image,
        });
      }
    }
    if (!mounted) return;
    setState(() {
      _artists = combined.values.toList();
      _loading = false;
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _genresResults = const []);
      return;
    }
    final results = await searchArtists(query.trim(), limit: 8);
    if (!mounted) return;
    setState(() => _genresResults = results);
  }

  void _toggle(Map<String, dynamic> artist) {
    final preferred = PreferredArtist(
      id: (artist['ytid'] ?? artist['id'])?.toString() ?? '',
      name: (artist['title'] ?? artist['name'])?.toString() ?? '',
      image: artist['image']?.toString(),
    );
    if (preferred.id.isEmpty && preferred.name.isEmpty) return;
    setState(() {
      if (_selected.any((a) => a.id == preferred.id)) {
        _selected.removeWhere((a) => a.id == preferred.id);
      } else {
        _selected.add(preferred);
      }
    });
  }

  Future<void> _finish() async {
    await setPreferredArtists(_selected.toList());
    if (widget.onDone != null) {
      widget.onDone!.call();
    } else if (mounted && Navigator.of(context).canPop()) {
      // Opened as a standalone route (e.g. from Settings): save then go back.
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.chooseFavoriteArtists),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              l10n.chooseFavoriteArtistsNote,
              style: Daylight.ui(12.5, color: Daylight.muted, height: 1.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: SearchBar(
              controller: _controller,
              hintText: l10n.searchArtist,
              leading: const Icon(
                FluentIcons.search_24_regular,
                size: 18,
              ),
              onChanged: _search,
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(Daylight.card),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildGrid(context),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final query = _controller.text.trim();
    final list = query.isEmpty ? _artists : _genresResults;
    if (list.isEmpty) {
      return Center(
        child: Text(
          context.l10n!.noResults,
          style: Daylight.ui(13, color: Daylight.muted),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) => _ArtistCard(
        artist: list[index],
        selected: _selected.any(
          (a) => a.id == (list[index]['ytid'] ?? list[index]['id'])?.toString(),
        ),
        onTap: () => _toggle(list[index]),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n!.artistsSelected(_selected.length),
              style: Daylight.ui(12, color: Daylight.muted),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _selected.isEmpty ? null : _finish,
              style: FilledButton.styleFrom(
                backgroundColor: Daylight.cobalt,
                foregroundColor: Daylight.onAccent,
                disabledBackgroundColor: Daylight.cobalt.withValues(alpha: 0.4),
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: Text(context.l10n!.continueLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  const _ArtistCard({
    required this.artist,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> artist;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (artist['title'] ?? artist['name'])?.toString() ?? '';
    final image = artist['image']?.toString();
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: name,
        child: Container(
          decoration: BoxDecoration(
            color: Daylight.card,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? Border.all(color: Daylight.cobalt, width: 2)
                : Border.all(color: Daylight.line),
            boxShadow: Daylight.cardShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: image == null || image.isEmpty
                      ? ColoredBox(
                          color: Daylight.cardTintStrong,
                          child: Icon(
                            FluentIcons.person_24_regular,
                            size: 30,
                            color: Daylight.muted,
                          ),
                        )
                      : Image(
                          image: ArtworkProvider.get(image),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: Daylight.cardTintStrong,
                            child: Icon(
                              FluentIcons.person_24_regular,
                              size: 30,
                              color: Daylight.muted,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Daylight.ui(
                    12,
                    weight: FontWeight.w600,
                    color: selected ? Daylight.cobalt : Daylight.ink,
                  ),
                ),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(
                    FluentIcons.checkmark_circle_24_filled,
                    size: 18,
                    color: Daylight.cobalt,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
