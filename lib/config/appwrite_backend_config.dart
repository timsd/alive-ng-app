class AppwriteBackendConfig {
  static const String endpoint =
      String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue:
        'http://appwrite-he4p5j9b9dj42v5nzeklu2u3.84.8.219.248.sslip.io/v1',
  );
  static const String projectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: '6a088e5f0003764bde50',
  );
  static const String databaseId = String.fromEnvironment(
    'APPWRITE_DATABASE_ID',
    defaultValue: '6a089307002e54291a32',
  );
  static const String fcmProviderId = String.fromEnvironment(
    'APPWRITE_FCM_PROVIDER_ID',
    defaultValue: '',
  );
  static const String usersCollectionId = '6a08943100226f5b4963';
  static const String chatChannelsCollectionId = '6a08f1c70032affbc00d';
  static const String chatMessagesCollectionId = '6a08e25e0034f79fcd2f';
  static const String messageTagsCollectionId = '6a08f391001a5c02aaa9';
  static const String generalChatRoomId = '6a08e02b000b15bb588b';
  static const String chatFilesBucketId = '6a08f51f002d2baf5e78';
  static const String profileFilesBucketId = 'profile_files';
  static const String boardDocumentsBucketId = 'board_documents';
  static const String tractFilesBucketId = 'tract_files';
  static const String podcastMediaBucketId = 'podcast_media';
  static const String contentMediaBucketId = 'content_media';
  static const String meetingFilesBucketId = 'meeting_files';
  static const String systemExportsBucketId = 'system_exports';
  static const String createLiveKitTokenFunctionId = '6a08e9010035dc8c1e51';
  static const String paystackPaymentsFunctionId = 'paystack_payments';
  static const String paystackWebhookFunctionId = 'paystack_webhook';
  static const String sendEmailFunctionId = 'send_email';
  static const String adminTeamId = '6a098ba2001455c27fdb';
  static const String approvalTokensCollectionId = 'approval_tokens';
  static const String donationRecordsCollectionId = 'donation_records';
  static const String projectsCollectionId = 'projects';
  static const String downloadableMaterialsCollectionId =
      'downloadable_materials';
  static const String materialDownloadsCollectionId = 'material_downloads';
  static const String paymentLogsCollectionId = 'payment_logs';
  static const String giftSubmissionsCollectionId = 'gift_submissions';
  static const String appSettingsCollectionId = 'app_settings';
  static const String prayerRequestsCollectionId = 'prayer_requests';
  static const String prayerInteractionsCollectionId = 'prayer_interactions';
  static const String prayerStrengtheningFeedCollectionId =
      'prayer_strengthening_feed';
  static const String testimoniesCollectionId = 'testimonies';
  static const String pushTokensCollectionId = 'push_tokens';
  static const String notificationSettingsCollectionId =
      'notification_settings';
  static const String adminNotificationsCollectionId = 'admin_notifications';
  static const String eventsCollectionId = 'events';
  static const String userEventsCollectionId = 'user_events';
  static const String announcementsCollectionId = 'announcements';
  static const String contentPagesCollectionId = 'content_pages';
  static const String dynamicContentCollectionId = 'dynamic_content';
  static const String featuredContentCollectionId = 'featured_content';
  static const String studyGuidesCollectionId = 'study_guides';
  static const String studyProgressCollectionId = 'study_progress';
  static const String dailyVersesCollectionId = 'daily_verses';
  static const String kidsStoriesCollectionId = 'kids_stories';
  static const String kidsMissionsCollectionId = 'kids_missions';
  static const String healthTrackingCollectionId = 'health_tracking';
  static const String passwordRecoveryUrl =
      'https://app.alivenigeria.org/#/reset-password';
  static const String oauthSuccessUrl = 'https://app.alivenigeria.org/#/home';
  static const String oauthFailureUrl = 'https://app.alivenigeria.org/#/auth';
}
