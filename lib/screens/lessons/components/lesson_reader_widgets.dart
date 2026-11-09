import 'package:flutter/material.dart';
import '../../../services/pdf_extractor_service.dart';

/// A card framing an interactive lesson section with a numbered badge and color palette.
class LessonSectionCard extends StatelessWidget {
  final int number;
  final String title;
  final List<Widget> children;
  final bool isDark;
  final LessonColorPalette? palette;

  const LessonSectionCard({
    super.key,
    required this.number,
    required this.title,
    required this.children,
    required this.isDark,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePalette =
        palette ?? LessonColorPalette.byId(null, fallbackIndex: number - 1);
    final primaryColor = Color(effectivePalette.primaryHex);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: primaryColor,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

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
              accentColor: isDark ? Color(effectivePalette.accentHex) : primaryColor,
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

/// An interactive reflection input box for recording study notes and answers.
class LessonReflectionInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool isDark;
  final int maxLines;
  final int sectionNumber;
  final LessonColorPalette? palette;

  const LessonReflectionInput({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.isDark,
    this.maxLines = 2,
    this.sectionNumber = 1,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePalette =
        palette ?? LessonColorPalette.byId(null, fallbackIndex: sectionNumber - 1);
    final primaryColor = Color(effectivePalette.primaryHex);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF18181B)
            : Color(effectivePalette.lightTintHex).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 16, color: primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: isDark ? const Color(0xFF27272A) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: primaryColor.withValues(alpha: 0.25),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: primaryColor.withValues(alpha: 0.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dual Yes/No commitment button row for spiritual decisions.
class LessonYesNoDecision extends StatelessWidget {
  final String question;
  final bool? currentValue;
  final ValueChanged<bool> onSelect;
  final bool isDark;
  final LessonColorPalette? palette;

  const LessonYesNoDecision({
    super.key,
    required this.question,
    required this.currentValue,
    required this.onSelect,
    required this.isDark,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePalette = palette ?? LessonColorPalette.brandPalettes.first;
    final primaryColor = Color(effectivePalette.primaryHex);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onSelect(true),
                  icon: Icon(
                    currentValue == true
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 16,
                  ),
                  label: const Text('YES'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: currentValue == true
                        ? Colors.green.withValues(alpha: 0.15)
                        : null,
                    foregroundColor: currentValue == true ? Colors.green : null,
                    side: BorderSide(
                      color: currentValue == true ? Colors.green : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onSelect(false),
                  icon: Icon(
                    currentValue == false
                        ? Icons.cancel_rounded
                        : Icons.radio_button_unchecked,
                    size: 16,
                  ),
                  label: const Text('NO'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: currentValue == false
                        ? Colors.orange.withValues(alpha: 0.15)
                        : null,
                    foregroundColor: currentValue == false ? Colors.orange : null,
                    side: BorderSide(
                      color: currentValue == false ? Colors.orange : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

