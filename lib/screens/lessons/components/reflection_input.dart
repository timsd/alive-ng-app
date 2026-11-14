import 'package:flutter/material.dart';
import '../../../services/pdf_extractor_service.dart';

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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
