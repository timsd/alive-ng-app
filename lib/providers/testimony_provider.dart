import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/testimony_service.dart';

final testimonyServiceProvider = Provider<TestimonyService>((ref) {
  return TestimonyService.instance;
});
