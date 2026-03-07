class ValidationUtils {
  static bool isValidEmail(String input) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(input);
  }

  static bool isValidPhone(String input) {
    final phone = input.replaceAll(RegExp(r'[^0-9+]'), '');
    // Accept E.164-like or local numbers with length 7-15
    final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
    return phoneRegex.hasMatch(phone);
  }

  static bool isPositiveInteger(String input) {
    final val = int.tryParse(input);
    return val != null && val > 0;
  }
}