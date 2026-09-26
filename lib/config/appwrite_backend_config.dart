class AppwriteBackendConfig {
  static const String endpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://api.alivenigeria.org/v1',
  );
  static const String projectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: '6a3bef53002f5090dedf',
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
  /// One row per person per office. The server-side source of truth for
  /// office-based access control (see OfficeAccessService).
  static const String orgOfficeHoldersCollectionId = 'org_office_holders';
  static const String orgOfficesCollectionId = 'org_offices';
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
  static const String deleteAccountFunctionId = 'delete_account';
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
  static const String boardReportsCollectionId = 'board_reports';
  static const String boardDocumentsCollectionId = 'board_documents';
  static const String boardDecisionsCollectionId = 'board_decisions';
  static const String prayerRequestsCollectionId = 'prayer_requests';
  static const String prayerInteractionsCollectionId = 'prayer_interactions';
  static const String prayerStrengtheningFeedCollectionId =
      'prayer_strengthening_feed';
  static const String testimoniesCollectionId = 'testimonies';
  static const String privatePrayerRoomsCollectionId = 'private_prayer_rooms';
  static const String prayerTestimoniesCollectionId = 'prayer_testimonies';
  static const String pushTokensCollectionId = 'push_tokens';
  static const String notificationSettingsCollectionId =
      'notification_settings';
  static const String adminNotificationsCollectionId = 'admin_notifications';
  static const String analyticsEventsCollectionId = 'analytics_events';
  static const String userActivitiesCollectionId = 'user_activities';
  static const String readingSessionsCollectionId = 'reading_sessions';
  static const String chapterReadingsCollectionId = 'chapter_readings';
  static const String chaptersCollectionId = 'chapters';
  static const String chapterMembersCollectionId = 'chapter_members';
  static const String chapterActivitiesCollectionId = 'chapter_activities';
  static const String chapterTasksCollectionId = 'chapter_tasks';
  static const String chapterReportsCollectionId = 'chapter_reports';
  static const String eventsCollectionId = 'events';
  static const String userEventsCollectionId = 'user_events';
  static const String announcementsCollectionId = 'announcements';
  static const String contentPagesCollectionId = 'content_pages';
  static const String dynamicContentCollectionId = 'dynamic_content';
  static const String featuredContentCollectionId = 'featured_content';
  static const String booksCollectionId = 'books';
  static const String articlesCollectionId = 'articles';
  static const String videosCollectionId = 'videos';
  static const String studyGuidesCollectionId = 'study_guides';
  static const String studyLessonsCollectionId = 'study_lessons';
  static const String studyQuestionsCollectionId = 'study_questions';
  static const String studyProgressCollectionId = 'study_progress';
  static const String studySessionsCollectionId = 'study_sessions';
  static const String taskAssignmentsCollectionId = 'task_assignments';
  static const String dailyVersesCollectionId = 'daily_verses';
  static const String memoryVersesCollectionId = 'memory_verses';
  static const String prayerActivitiesCollectionId = 'prayer_activities';
  static const String serviceProjectsCollectionId = 'service_projects';
  static const String kidsStoriesCollectionId = 'kids_stories';
  static const String kidsMissionsCollectionId = 'kids_missions';
  static const String learningResourcesCollectionId = 'learning_resources';
  static const String discipleshipContactsCollectionId =
      'discipleship_contacts';
  static const String contactInteractionsCollectionId = 'contact_interactions';
  static const String discipleshipStudySessionsCollectionId =
      'discipleship_study_sessions';
  static const String discipleshipPrayerRequestsCollectionId =
      'discipleship_prayer_requests';
  static const String progressMilestonesCollectionId = 'progress_milestones';
  static const String discipleshipReportsCollectionId = 'discipleship_reports';
  static const String leadershipRecordsCollectionId = 'leadership_records';
  static const String leadershipTransitionsCollectionId =
      'leadership_transitions';
  static const String leadershipHistoryCollectionId = 'leadership_history';
  static const String meetingFilesCollectionId = 'meeting_files';
  static const String missionsCollectionId = 'missions';
  static const String userMissionsCollectionId = 'user_missions';
  static const String tractsCollectionId = 'tracts';
  static const String tractContentsCollectionId = 'tract_contents';
  static const String tractCategoriesCollectionId = 'tract_categories';
  static const String podcastsCollectionId = 'podcasts';
  static const String podcastEpisodesCollectionId = 'podcast_episodes';
  static const String podcastCategoriesCollectionId = 'podcast_categories';
  static const String healthTrackingCollectionId = 'health_tracking';
  static const String userSubmittedRecipesCollectionId =
      'user_submitted_recipes';
  static const String userSubmittedHealthTipsCollectionId =
      'user_submitted_health_tips';
  /// The link the branded reset email points at.
  ///
  /// The app routes with a URL fragment (`/#/reset-password`), so anything
  /// appended after `#` becomes part of the FRAGMENT, not the query string.
  /// `?userId=..&secret=..` placed there was invisible to
  /// `GoRouterState.uri.queryParameters`, and the reset screen rendered
  /// without a token -- which is why the link appeared to have no secret
  /// attached. The parameters therefore go BEFORE the fragment, where
  /// `Uri` exposes them as real query parameters.
  static const String passwordRecoveryUrl =
      'https://app.alivenigeria.org/reset-password';
  static const String oauthSuccessUrl = 'https://app.alivenigeria.org/#/home';
  static const String oauthFailureUrl = 'https://app.alivenigeria.org/#/auth';

  /// Monitored support mailbox. Every transactional email sent through the
  /// `send_email` Appwrite Function is configured with this address as its
  /// Reply-To so donor/member replies reach a human inbox.
  ///
  /// NOTE: only `app.alivenigeria.org` is verified for *sending* in Resend, so
  /// this address must never be used as a `From` value.
  static const String supportEmail = 'app@alivenigeria.org';

  static const String _superAdminEmailsRaw = String.fromEnvironment(
    'APPWRITE_SUPER_ADMIN_EMAILS',
    defaultValue:
        'alivenigeria2011@gmail.com,dammyolodude@gmail.com,app@alivenigeria.org',
  );

  static List<String> get superAdminEmails => _superAdminEmailsRaw
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList();

  static bool isSuperAdminEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    final normalized = email.trim().toLowerCase();
    return superAdminEmails.contains(normalized);
  }
}
