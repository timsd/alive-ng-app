import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prayer_request.dart';
import '../utils/toast_utils.dart';
import '../utils/logger.dart';

class PrayerRequestsService {
  static final _supabase = Supabase.instance.client;
  static final _logger = Logger('PrayerRequestsService');

  static Future<List<PrayerRequest>> fetchPrayerRequests() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('prayer_requests')
          .select('*')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PrayerRequest.fromJson(json))
          .toList();
    } catch (error) {
      _logger.error('Error fetching prayer requests', error);
      ToastUtils.showError('Failed to load prayer requests');
      return [];
    }
  }

  static Future<bool> createPrayerRequest({
    required String title,
    required String description,
    bool isAnonymous = false,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to create a prayer request');
        return false;
      }

      await _supabase.from('prayer_requests').insert({
        'user_id': user.id,
        'title': title,
        'description': description,
        'is_anonymous': isAnonymous,
        'prayer_count': 0,
      });

      ToastUtils.showSuccess('Prayer request created successfully');
      return true;
    } catch (error) {
      _logger.error('Error creating prayer request', error);
      ToastUtils.showError('Failed to create prayer request');
      return false;
    }
  }

  static Future<bool> prayForRequest(String requestId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to pray for requests');
        return false;
      }

      // Increment prayer count
      await _supabase.rpc('increment_prayer_count', params: {
        'request_id': requestId,
      });

      ToastUtils.showSuccess('Thank you for praying!');
      return true;
    } catch (error) {
      _logger.error('Error praying for request', error);
      ToastUtils.showError('Failed to record prayer');
      return false;
    }
  }

  static Future<bool> updatePrayerRequest({
    required String id,
    String? title,
    String? description,
    bool? isAnonymous,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to update prayer requests');
        return false;
      }

      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (isAnonymous != null) updates['is_anonymous'] = isAnonymous;

      await _supabase
          .from('prayer_requests')
          .update(updates)
          .eq('id', id)
          .eq('user_id', user.id);

      ToastUtils.showSuccess('Prayer request updated successfully');
      return true;
    } catch (error) {
      _logger.error('Error updating prayer request', error);
      ToastUtils.showError('Failed to update prayer request');
      return false;
    }
  }

  static Future<bool> deletePrayerRequest(String id) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to delete prayer requests');
        return false;
      }

      await _supabase
          .from('prayer_requests')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      ToastUtils.showSuccess('Prayer request deleted successfully');
      return true;
    } catch (error) {
      _logger.error('Error deleting prayer request', error);
      ToastUtils.showError('Failed to delete prayer request');
      return false;
    }
  }
}
