import 'package:flutter/material.dart';
import '../../../services/pdf_extractor_service.dart';

export 'verse_quote_card.dart';
export 'reflection_input.dart';

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
                  style: TextStyle(
                    color: primaryColor.computeLuminance() > 0.5
                        ? const Color(0xFF0D1520)
                        : Colors.white,
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
                      color: currentValue == true
                          ? Colors.green
                          : Colors.grey.shade400,
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
                    foregroundColor:
                        currentValue == false ? Colors.orange : null,
                    side: BorderSide(
                      color: currentValue == false
                          ? Colors.orange
                          : Colors.grey.shade400,
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
