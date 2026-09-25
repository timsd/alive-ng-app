import '../models/project_model.dart';

/// A destination a donor can direct their gift toward.
///
/// These are the non-project purposes: things the organisation runs on that are
/// not capital projects. A gift picking one of these is recorded against the
/// matching [DonationType] where one exists (so `appMaintenance` finally has a
/// real entry point) and always carries `fund_designation` so the receipt and
/// the finance report can trace it.
class DonationPurposeOption {
  /// Stable id stored in the donation metadata.
  final String id;

  /// Human label shown to the donor and printed on the receipt.
  final String label;

  final String? description;

  const DonationPurposeOption({
    required this.id,
    required this.label,
    this.description,
  });
}

/// Administrative / operational purposes a donor can choose when the gift is
/// not tied to one of the capital projects.
const List<DonationPurposeOption> kAdministrativePurposes = [
  DonationPurposeOption(
    id: 'app_maintenance',
    label: 'App Maintenance',
    description: 'Hosting, push notifications and running costs of the app.',
  ),
  DonationPurposeOption(
    id: 'campus_workers',
    label: 'Campus Workers',
    description: 'Supporting full-time workers serving on campuses.',
  ),
  DonationPurposeOption(
    id: 'volunteers',
    label: 'Volunteers',
    description: 'Equipping and funding those serving as volunteers.',
  ),
  DonationPurposeOption(
    id: 'media_and_equipment',
    label: 'Media & Equipment',
    description: 'Cameras, audio, production and ministry equipment.',
  ),
];

/// The single option that means "no specific destination".
const DonationPurposeOption kGeneralSupportPurpose = DonationPurposeOption(
  id: 'general_support',
  label: 'General Support',
  description: 'Wherever the need is greatest.',
);

/// Look up an administrative purpose by its id, or null when it is unknown.
DonationPurposeOption? donationPurposeById(String id) {
  for (final option in kAdministrativePurposes) {
    if (option.id == id) return option;
  }
  return null;
}

final List<Project> donationFallbackProjects = [
  Project(
    id: 'impact_hub_center',
    title: 'Impact Hub Center',
    description:
        'A central hub for training, discipleship, and community engagement.',
    targetAmount: 35000000.0,
    raisedAmount: 8384400.0,
    currency: 'NGN',
    status: 'active',
    priority: 1,
    imageUrl: 'assets/images/impact_hub_3d_view.png',
    viewerUrl: 'alive_ng_3d_viewer.html',
    fundUpdateTitle: 'Progress so far',
    fundUpdateText:
        'Seed funding has helped prepare the project scope, early planning, and ministry coordination for the hub.',
    fundUpdateImages: <String>[],
    category: '',
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Project(
    id: 'vehicle_purchase',
    title: 'Vehicle Purchase',
    description:
        'Reliable transportation for mission trips and logistics across Nigeria.',
    targetAmount: 18000000.0,
    raisedAmount: 0.0,
    currency: 'NGN',
    status: 'active',
    priority: 2,
    imageUrl:
        'https://images.unsplash.com/photo-1597685204565-110abf469a1e?q=80&w=870&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    fundUpdateTitle: '',
    fundUpdateText: '',
    fundUpdateImages: <String>[],
    category: '',
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Project(
    id: 'media_studio_setup',
    title: 'Media Studio Setup',
    description:
        'Equipping the ministry with high-quality media production capabilities.',
    targetAmount: 9000000.0,
    raisedAmount: 0.0,
    currency: 'NGN',
    status: 'planning',
    priority: 3,
    imageUrl:
        'https://images.unsplash.com/photo-1769699167906-a44d5ae50abb?q=80&w=387&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    fundUpdateTitle: '',
    fundUpdateText: '',
    fundUpdateImages: <String>[],
    category: '',
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];
