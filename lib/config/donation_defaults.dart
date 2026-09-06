import '../models/project_model.dart';

final List<Project> donationFallbackProjects = [
  Project(
    id: 'impact_hub_center',
    title: 'Impact Hub Center',
    description:
        'A central hub for training, discipleship, and community engagement.',
    targetAmount: 35000000.0,
    raisedAmount: 8000000.0,
    currency: 'NGN',
    status: 'active',
    priority: 1,
    imageUrl:
        'https://images.unsplash.com/photo-1593914370442-49d414beca24?q=80&w=1031&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
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
