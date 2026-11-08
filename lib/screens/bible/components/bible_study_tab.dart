import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// The My Study tab displaying user Notes, Highlights, and Bookmarks.
class BibleStudyTab extends StatefulWidget {
  final List<Map<String, dynamic>> notes;
  final List<Map<String, dynamic>> highlights;
  final List<Map<String, dynamic>> bookmarks;
  final bool isLoading;
  final void Function(String reference) onOpenReference;
  final void Function(String reference, String verseText) onEditNote;
  final void Function(String reference) onDeleteNote;
  final void Function(String reference) onDeleteHighlight;
  final void Function(String raw) onDeleteBookmark;
  final VoidCallback onOpenReader;

  const BibleStudyTab({
    super.key,
    required this.notes,
    required this.highlights,
    required this.bookmarks,
    required this.isLoading,
    required this.onOpenReference,
    required this.onEditNote,
    required this.onDeleteNote,
    required this.onDeleteHighlight,
    required this.onDeleteBookmark,
    required this.onOpenReader,
  });

  @override
  State<BibleStudyTab> createState() => _BibleStudyTabState();
}

class _BibleStudyTabState extends State<BibleStudyTab> {
  int _subTabIndex = 0; // 0 = Notes, 1 = Highlights, 2 = Bookmarks
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // 1. Sub-Tabs Segmented Bar: Notes, Highlights, Bookmarks
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStudyPill(
                    index: 0,
                    icon: Icons.note_alt_outlined,
                    label: 'Notes',
                    count: widget.notes.length,
                  ),
                  const SizedBox(width: 8),
                  _buildStudyPill(
                    index: 1,
                    icon: Icons.border_color_outlined,
                    label: 'Highlights',
                    count: widget.highlights.length,
                  ),
                  const SizedBox(width: 8),
                  _buildStudyPill(
                    index: 2,
                    icon: Icons.bookmark_border_rounded,
                    label: 'Bookmarks',
                    count: widget.bookmarks.length,
                  ),
                ],
              ),
            ),
          ),

          // 2. Search / Filter Field
          Padding(
            padding: EdgeInsets.fromLTRB(
              isSmallScreen ? 12 : 16,
              10,
              isSmallScreen ? 12 : 16,
              6,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: _subTabIndex == 0
                    ? 'Search notes & verses...'
                    : (_subTabIndex == 1
                        ? 'Search highlights...'
                        : 'Search bookmarks...'),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
            ),
          ),

          // 3. Main Content Area
          Expanded(
            child: _buildSubTabContent(isSmallScreen),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyPill({
    required int index,
    required IconData icon,
    required String label,
    required int count,
  }) {
    final isSelected = _subTabIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        setState(() {
          _subTabIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.onPrimary.withValues(alpha: 0.25)
                    : colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabContent(bool isSmallScreen) {
    switch (_subTabIndex) {
      case 0:
        return _buildNotesList(isSmallScreen);
      case 1:
        return _buildHighlightsList(isSmallScreen);
      case 2:
      default:
        return _buildBookmarksList(isSmallScreen);
    }
  }

  Widget _buildNotesList(bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _searchQuery.isEmpty
        ? widget.notes
        : widget.notes.where((item) {
            final ref = (item['reference'] ?? '').toString().toLowerCase();
            final note = (item['note'] ?? '').toString().toLowerCase();
            final verse = (item['verseText'] ?? '').toString().toLowerCase();
            return ref.contains(_searchQuery) ||
                note.contains(_searchQuery) ||
                verse.contains(_searchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyStudyState(
        icon: Icons.note_alt_outlined,
        title: _searchQuery.isEmpty ? 'No Notes Saved' : 'No matching notes found',
        description: _searchQuery.isEmpty
            ? 'Tap any verse while reading the Bible and select "Notes" to record personal revelations, insights, and study notes.'
            : 'Try a different search term or book reference.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final reference = item['reference'] as String;
        final note = item['note'] as String;
        final verseText = item['verseText'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => widget.onOpenReference(reference),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          reference,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit Note',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => widget.onEditNote(reference, verseText),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Delete Note',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => widget.onDeleteNote(reference),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(
                          color: colorScheme.primary,
                          width: 3.5,
                        ),
                      ),
                    ),
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13.5 : 14.5,
                        height: 1.4,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (verseText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '“$verseText”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12.5,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightsList(bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _searchQuery.isEmpty
        ? widget.highlights
        : widget.highlights.where((item) {
            final ref = (item['reference'] ?? '').toString().toLowerCase();
            final text = (item['text'] ?? '').toString().toLowerCase();
            return ref.contains(_searchQuery) || text.contains(_searchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyStudyState(
        icon: Icons.border_color_outlined,
        title: _searchQuery.isEmpty ? 'No Highlights Yet' : 'No matching highlights found',
        description: _searchQuery.isEmpty
            ? 'Highlight meaningful verses by tapping any verse in the reader and choosing a color.'
            : 'Try searching for another book or verse.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final reference = item['reference'] as String;
        final color = item['color'] as Color;
        final text = item['text'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => widget.onOpenReference(reference),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        reference,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: 'Share Highlight',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(text: '$reference\n$text'),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Clear Highlight',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => widget.onDeleteHighlight(reference),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13.5 : 14.5,
                        height: 1.4,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookmarksList(bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _searchQuery.isEmpty
        ? widget.bookmarks
        : widget.bookmarks.where((item) {
            final ref = (item['reference'] ?? '').toString().toLowerCase();
            final text = (item['text'] ?? '').toString().toLowerCase();
            return ref.contains(_searchQuery) || text.contains(_searchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyStudyState(
        icon: Icons.bookmark_border_rounded,
        title: _searchQuery.isEmpty ? 'No Bookmarks Saved' : 'No matching bookmarks found',
        description: _searchQuery.isEmpty
            ? 'Save verses for fast reference by tapping any verse in the reader and selecting "Bookmark".'
            : 'Try a different search term or book reference.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final reference = item['reference'] as String;
        final text = item['text'] as String;
        final date = item['date'] as DateTime;
        final raw = item['raw'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => widget.onOpenReference(reference),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bookmark_added, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        reference,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM d, y').format(date),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: 'Share',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(text: '$reference\n$text'),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Remove Bookmark',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => widget.onDeleteBookmark(raw),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13.5 : 14.5,
                      height: 1.4,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyStudyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: colorScheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_stories, size: 18),
              label: const Text('Open Bible Reader'),
              onPressed: widget.onOpenReader,
            ),
          ],
        ),
      ),
    );
  }
}
