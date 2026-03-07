import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class PodcastSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hintText;

  const PodcastSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText = 'Search podcasts...'
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveSpacing(context, 12),
            ),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}