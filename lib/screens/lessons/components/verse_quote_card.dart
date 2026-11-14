import 'package:flutter/material.dart';
import '../../../services/pdf_extractor_service.dart';

/// A quote card presenting an impactful scripture verse with a reference button.
class LessonVerseQuoteCard extends StatelessWidget {
  final String quote;
  final String reference;
  final bool isDark;
  final LessonColorPalette? palette;
  final void Function(String ref) onOpenScripture;

  const LessonVerseQuoteCard({
    super.key,
    required this.quote,
    required this.reference,
    required this.isDark,
    this.palette,
    required this.onOpenScripture,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePalette =
        palette ?? LessonColorPalette.byId(null, fallbackIndex: reference.hashCode);
    final primaryColor = Color(effectivePalette.primaryHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Color(effectivePalette.darkTintHex)
            : Color(effectivePalette.lightTintHex),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: primaryColor, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$quote"',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.4,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: LessonScriptureChip(
              reference: reference,
              accentColor:
                  isDark ? Color(effectivePalette.accentHex) : primaryColor,
              onTap: () => onOpenScripture(reference),
            ),
          ),
        ],
      ),
    );
  }
}

/// A chip button for tapping into a scripture reference directly.
class LessonScriptureChip extends StatelessWidget {
  final String reference;
  final Color? accentColor;
  final VoidCallback onTap;

  const LessonScriptureChip({
    super.key,
    required this.reference,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = accentColor ?? Colors.green;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: chipColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new, color: chipColor, size: 12),
            const SizedBox(width: 4),
            Text(
              reference,
              style: TextStyle(
                color: chipColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
