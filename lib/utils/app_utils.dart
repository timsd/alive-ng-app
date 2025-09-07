import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Utility class for common app functions
class AppUtils {
  /// Combines multiple CSS class names (similar to clsx/twMerge in React)
  /// This is mainly for consistency with React patterns, though Flutter uses different styling
  static String combineClasses(List<String?> classes) {
    return classes
        .where((className) => className != null && className.isNotEmpty)
        .join(' ');
  }

  /// Format date to readable string
  static String formatDate(DateTime date, {String? locale}) {
    return DateFormat.yMMMd(locale).format(date);
  }

  /// Format time to readable string
  static String formatTime(DateTime time, {String? locale}) {
    return DateFormat.jm(locale).format(time);
  }

  /// Format date and time to readable string
  static String formatDateTime(DateTime dateTime, {String? locale}) {
    return DateFormat.yMMMd(locale).add_jm().format(dateTime);
  }

  /// Get relative time string (e.g., "2 hours ago")
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phone) {
    return RegExp(r'^[\+]?[1-9]?[0-9]{7,15}$').hasMatch(phone);
  }

  /// Generate initials from name
  static String getInitials(String name) {
    final names = name.trim().split(' ');
    if (names.isEmpty) return '';

    if (names.length == 1) {
      return names[0].substring(0, 1).toUpperCase();
    }

    return '${names[0].substring(0, 1)}${names[names.length - 1].substring(0, 1)}'
        .toUpperCase();
  }

  /// Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Convert string to title case
  static String toTitleCase(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Generate random color
  static Color getRandomColor() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[(DateTime.now().millisecondsSinceEpoch % colors.length)];
  }

  /// Get color from string (consistent color for same string)
  static Color getColorFromString(String text) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    final hash = text.hashCode;
    return colors[hash.abs() % colors.length];
  }

  /// Show snackbar with message
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
      ),
    );
  }

  /// Show error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: Colors.red,
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: Colors.green,
    );
  }

  /// Format currency
  static String formatCurrency(double amount, {String symbol = '₦'}) {
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  /// Format number with commas
  static String formatNumber(num number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }

  /// Debounce function calls
  static Timer? _debounceTimer;
  static void debounce(VoidCallback callback,
      {Duration delay = const Duration(milliseconds: 500)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.shortestSide >= 600;
  }

  /// Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Hide keyboard
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Launch URL
  static Future<void> launchURL(String url) async {
    // This would typically use url_launcher package
    // await launchUrl(Uri.parse(url));
    debugPrint('Launch URL: $url');
  }

  /// Share text
  static Future<void> shareText(String text) async {
    // This would typically use share_plus package
    // await Share.share(text);
    debugPrint('Share text: $text');
  }

  /// Copy to clipboard
  static Future<void> copyToClipboard(String text) async {
    // This would typically use flutter/services
    // await Clipboard.setData(ClipboardData(text: text));
    debugPrint('Copy to clipboard: $text');
  }
}

/// Extension methods for common operations
extension StringExtensions on String {
  /// Check if string is empty or null
  bool get isNullOrEmpty => isEmpty;

  /// Capitalize first letter
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Remove all whitespace
  String get removeWhitespace => replaceAll(RegExp(r'\s+'), '');

  /// Check if string is numeric
  bool get isNumeric => double.tryParse(this) != null;
}

extension DateTimeExtensions on DateTime {
  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Get start of day
  DateTime get startOfDay => DateTime(year, month, day);

  /// Get end of day
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);
}

extension ListExtensions<T> on List<T> {
  /// Get random element from list
  T? get randomElement {
    if (isEmpty) return null;
    return this[(DateTime.now().millisecondsSinceEpoch % length)];
  }

  /// Remove duplicates from list
  List<T> get unique => toSet().toList();
}
