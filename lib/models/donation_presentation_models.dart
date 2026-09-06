import 'package:flutter/material.dart';

@immutable
class DonationImpact {
  const DonationImpact(
      {required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;
}

@immutable
class DonationAmountOption {
  const DonationAmountOption({required this.amount, required this.label});
  final double amount;
  final String label;
}
