import 'package:appwrite/appwrite.dart' as aw;
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

/// Service for managing kids' content including memory verses, prayers, and activities
class KidsContentService {
  static final aw.TablesDB _tables = aw.TablesDB(appwriteClient);
  static final Logger _logger = Logger('KidsContentService');

  // Collections
  static const String _memoryVersesCollection = 'memory_verses';
  static const String _prayerActivitiesCollection = 'prayer_activities';
  static const String _serviceProjectsCollection = 'service_projects';
  static const String _kidsStoriesCollection = 'kids_stories';
  static const String _kidsMissionsCollection = 'kids_missions';
  static const String _learningResourcesCollection = 'learning_resources';

  static String _collectionId(String collection) {
    return switch (collection) {
      _memoryVersesCollection => AppwriteBackendConfig.memoryVersesCollectionId,
      _prayerActivitiesCollection =>
        AppwriteBackendConfig.prayerActivitiesCollectionId,
      _serviceProjectsCollection =>
        AppwriteBackendConfig.serviceProjectsCollectionId,
      _kidsStoriesCollection => AppwriteBackendConfig.kidsStoriesCollectionId,
      _kidsMissionsCollection => AppwriteBackendConfig.kidsMissionsCollectionId,
      _learningResourcesCollection =>
        AppwriteBackendConfig.learningResourcesCollectionId,
      _ => collection,
    };
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static Map<String, dynamic> _documentData(dynamic document) {
    return _normalizeReadData({
      ...Map<String, dynamic>.from(document.data as Map),
      'id': document.$id,
    });
  }

  static Map<String, dynamic> _normalizeReadData(Map<String, dynamic> data) {
    return {
      ...data,
      if (data['age_group'] != null) 'ageGroup': data['age_group'],
      if (data['resource_type'] != null) 'resourceType': data['resource_type'],
      if (data['moral_lesson'] != null) 'moralLesson': data['moral_lesson'],
      if (data['bible_reference'] != null)
        'bibleReference': data['bible_reference'],
      if (data['sda_doctrine'] != null) 'sdaDoctrine': data['sda_doctrine'],
      if (data['sda_values'] != null) 'sdaValues': data['sda_values'],
      if (data['image_url'] != null) 'imageUrl': data['image_url'],
      if (data['audio_url'] != null) 'audioUrl': data['audio_url'],
      if (data['created_at'] != null) 'createdAt': data['created_at'],
      if (data['updated_at'] != null) 'updatedAt': data['updated_at'],
    };
  }

  static Map<String, dynamic> _writeData(Map<String, dynamic> data) {
    final mapped = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.key == 'id' || entry.key.startsWith(r'$')) continue;
      final key = switch (entry.key) {
        'ageGroup' => 'age_group',
        'resourceType' => 'resource_type',
        'moralLesson' => 'moral_lesson',
        'bibleReference' => 'bible_reference',
        'sdaDoctrine' => 'sda_doctrine',
        'sdaValues' => 'sda_values',
        'imageUrl' => 'image_url',
        'audioUrl' => 'audio_url',
        'illustrationUrl' => 'illustration_url',
        'mediaUrl' => 'media_url',
        'isActive' => 'is_active',
        'createdAt' => 'created_at',
        'updatedAt' => 'updated_at',
        _ => entry.key,
      };
      mapped[key] = entry.value;
    }
    return mapped;
  }

  static List<Map<String, dynamic>> _offlineItemsFor(String collection) {
    return switch (collection) {
      _memoryVersesCollection => _offlineMemoryVerses,
      _prayerActivitiesCollection => _offlinePrayerActivities,
      _serviceProjectsCollection => _offlineServiceProjects,
      _kidsStoriesCollection => _offlineKidsStories,
      _learningResourcesCollection => _offlineLearningResources,
      _ => const <Map<String, dynamic>>[],
    };
  }

  static Future<List<Map<String, dynamic>>> _listAppwrite(
    String collection, {
    String? category,
    String? ageGroup,
    String? qualifierKey,
    String? qualifierValue,
  }) async {
    final snapshot = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: _collectionId(collection),
      queries: [aw.Query.limit(200)],
    );
    final remoteItems = snapshot.rows.map(_documentData).toList();
    final items =
        remoteItems.isEmpty ? _offlineItemsFor(collection) : remoteItems;
    return items
        .where((item) => _matchesFilters(
              item,
              category: category,
              ageGroup: ageGroup,
              qualifierKey: qualifierKey,
              qualifierValue: qualifierValue,
            ))
        .toList();
  }

  static bool _matchesFilters(
    Map<String, dynamic> item, {
    String? category,
    String? ageGroup,
    String? qualifierKey,
    String? qualifierValue,
  }) {
    final categoryMatch =
        category == null || item['category']?.toString() == category;
    final ageGroupValue = item['ageGroup']?.toString();
    final ageGroupMatch = ageGroup == null ||
        ageGroupValue == null ||
        ageGroupValue == ageGroup ||
        ageGroupValue == 'all';
    final qualifierMatch = qualifierKey == null ||
        qualifierValue == null ||
        item[qualifierKey]?.toString() == qualifierValue;
    return categoryMatch && ageGroupMatch && qualifierMatch;
  }

  static Future<String> _createAppwriteDocument(
      String collection, Map<String, dynamic> data) async {
    final id = data['id'] as String? ?? aw.ID.unique();
    final payload = _writeData({
      ..._coerceWriteData(collection, data),
      'created_at': data['created_at'] ?? data['createdAt'] ?? _now(),
      'updated_at': _now(),
      'is_active': data['is_active'] ?? data['isActive'] ?? true,
    });
    await _tables.createRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: _collectionId(collection),
      rowId: id,
      data: payload,
    );
    return id;
  }

  static Future<void> _updateAppwriteDocument(
      String collection, String id, Map<String, dynamic> updates) async {
    await _tables.updateRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: _collectionId(collection),
      rowId: id,
      data: _writeData({...updates, 'updated_at': _now()}),
    );
  }

  static Future<void> _deleteAppwriteDocument(
      String collection, String id) async {
    await _tables.deleteRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: _collectionId(collection),
      rowId: id,
    );
  }

  static Future<void> _upsertAppwriteDocument(
      String collection, Map<String, dynamic> data) async {
    final id = data['id'] as String? ?? aw.ID.unique();
    final payload = _writeData({
      ..._coerceWriteData(collection, data),
      'created_at': data['created_at'] ?? data['createdAt'] ?? _now(),
      'updated_at': _now(),
      'is_active': data['is_active'] ?? data['isActive'] ?? true,
    });

    try {
      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _collectionId(collection),
        rowId: id,
        data: payload,
      );
    } on aw.AppwriteException catch (e) {
      if (e.code != 409) rethrow;
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: _collectionId(collection),
        rowId: id,
        data: payload,
      );
    }
  }

  static Map<String, dynamic> _coerceWriteData(
    String collection,
    Map<String, dynamic> data,
  ) {
    final mapped = Map<String, dynamic>.from(data);
    if (collection == _kidsStoriesCollection && mapped['duration'] is String) {
      mapped['duration'] =
          int.tryParse(mapped['duration'].toString().split(' ').first) ?? 0;
    }
    return mapped;
  }

  static Future<void> _seedAppwriteDefaults(
    String collection,
    List<Map<String, dynamic>> items,
  ) async {
    for (final item in items) {
      await _upsertAppwriteDocument(collection, item);
    }
  }

  static final List<Map<String, dynamic>> _offlineMemoryVerses = [
    {
      'id': 'mv_001',
      'category': 'Love',
      'verse':
          'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.',
      'reference': 'John 3:16',
      'ageGroup': 'all',
      'difficulty': 'easy',
      'theme': 'Gods Love',
    },
    {
      'id': 'mv_002',
      'category': 'Obedience',
      'verse': 'Children, obey your parents in the Lord, for this is right.',
      'reference': 'Ephesians 6:1',
      'ageGroup': 'young',
      'difficulty': 'easy',
      'theme': 'Family',
    },
    {
      'id': 'mv_003',
      'category': 'Sabbath',
      'verse': 'Remember the Sabbath day by keeping it holy.',
      'reference': 'Exodus 20:8',
      'ageGroup': 'all',
      'difficulty': 'easy',
      'theme': 'Sabbath',
    },
    {
      'id': 'mv_004',
      'category': 'Prayer',
      'verse':
          'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.',
      'reference': 'Philippians 4:6',
      'ageGroup': 'older',
      'difficulty': 'medium',
      'theme': 'Prayer',
    },
  ];

  static final List<Map<String, dynamic>> _offlinePrayerActivities = [
    {
      'id': 'pa_001',
      'type': 'morning',
      'title': 'Good Morning Prayer',
      'content':
          'Dear Jesus, thank You for this new day. Please help me to be kind, obedient, and loving today. Guide my steps and keep me safe. Amen.',
      'ageGroup': 'young',
      'duration': '1 minute',
      'category': 'Daily Prayers',
    },
    {
      'id': 'pa_002',
      'type': 'meal',
      'title': 'Mealtime Blessing',
      'content':
          'Dear God, thank You for this food. Bless it to nourish our bodies. Help us remember those who are hungry and teach us to share. Amen.',
      'ageGroup': 'all',
      'duration': '30 seconds',
      'category': 'Meal Prayers',
    },
    {
      'id': 'pa_003',
      'type': 'bedtime',
      'title': 'Bedtime Prayer',
      'content':
          'Dear Jesus, thank You for watching over me today. Forgive me for any wrong I have done. Please give me peaceful sleep and sweet dreams. Amen.',
      'ageGroup': 'young',
      'duration': '1 minute',
      'category': 'Daily Prayers',
    },
  ];

  static final List<Map<String, dynamic>> _offlineServiceProjects = [
    {
      'id': 'sp_001',
      'title': 'Helping Elderly Neighbors',
      'description':
          'Visit elderly neighbors to help with simple tasks like carrying groceries, reading to them, or just spending time together.',
      'ageGroup': 'all',
      'duration': '1-2 hours',
      'category': 'Community Service',
      'difficulty': 'easy',
      'impact': 'Brings joy and assistance to elderly community members',
    },
    {
      'id': 'sp_002',
      'title': 'Food Bank Collection',
      'description':
          'Organize a food drive at church or school to collect non-perishable items for local food banks.',
      'ageGroup': 'older',
      'duration': '2-4 weeks',
      'category': 'Hunger Relief',
      'difficulty': 'medium',
      'impact': 'Provides meals for families in need',
    },
    {
      'id': 'sp_003',
      'title': 'Environmental Cleanup',
      'description':
          'Organize a neighborhood or park cleanup to care for Gods creation by picking up litter and planting flowers.',
      'ageGroup': 'all',
      'duration': '2-3 hours',
      'category': 'Environmental',
      'difficulty': 'easy',
      'impact': 'Beautifies community and protects environment',
    },
  ];

  static final List<Map<String, dynamic>> _offlineKidsStories = [
    {
      'id': 'ks_001',
      'title': 'The Special Day - Sabbath',
      'content':
          'Long ago, God created the world in six days. On the seventh day, He rested and made it holy. This special day is called the Sabbath.',
      'category': 'Sabbath',
      'ageGroup': 'young',
      'moralLesson':
          'The Sabbath is Gods special gift to us for rest and worship.',
      'bibleReference': 'Genesis 2:2-3',
      'sdaDoctrine': 'Sabbath Observance',
      'duration': '3 minutes',
    },
    {
      'id': 'ks_002',
      'title': 'Jesus is Coming Back',
      'content':
          'Jesus promised His disciples that He would come back to take them to heaven.',
      'category': 'Second Coming',
      'ageGroup': 'all',
      'moralLesson':
          'Jesus loves us and is preparing a wonderful home for us in heaven.',
      'bibleReference': 'John 14:1-3',
      'sdaDoctrine': 'Second Coming of Christ',
      'duration': '4 minutes',
    },
    {
      'id': 'ks_003',
      'title': 'The Power of Prayer',
      'content':
          'Daniel prayed to God three times every day, even when it was dangerous.',
      'category': 'Prayer',
      'ageGroup': 'all',
      'moralLesson':
          'God always hears our prayers and will protect those who trust in Him.',
      'bibleReference': 'Daniel 6:10-23',
      'sdaDoctrine': 'Prayer and Faith',
      'duration': '5 minutes',
    },
  ];

  static final List<Map<String, dynamic>> _offlineLearningResources = [
    {
      'id': 'lr_001',
      'title': 'Bible Heroes Activity Sheet',
      'subject': 'Bible',
      'category': 'Activity',
      'ageGroup': 'young',
      'resourceType': 'worksheet',
    },
    {
      'id': 'lr_002',
      'title': 'Sabbath Coloring Guide',
      'subject': 'Sabbath',
      'category': 'Art',
      'ageGroup': 'young',
      'resourceType': 'printable',
    },
    {
      'id': 'lr_003',
      'title': 'Junior Bible Study Notes',
      'subject': 'Bible',
      'category': 'Study',
      'ageGroup': 'older',
      'resourceType': 'study_guide',
    },
  ];

  /// Initialize kids content with default data
  static Future<void> initializeKidsContent() async {
    try {
      await Future.wait([
        _initializeMemoryVerses(),
        _initializePrayerActivities(),
        _initializeServiceProjects(),
        _initializeKidsStories(),
        _initializeLearningResources(),
      ]);
    } catch (e) {
      _logger.error('Error initializing kids content', e);
      throw DatabaseException('Error initializing kids content',
          originalError: e);
    }
  }

  /// Initialize memory verses with SDA-appropriate content
  static Future<void> _initializeMemoryVerses() async {
    final memoryVerses = [
      {
        'id': 'mv_001',
        'category': 'Love',
        'verse':
            'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.',
        'reference': 'John 3:16',
        'ageGroup': 'all',
        'difficulty': 'easy',
        'theme': 'Gods Love',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'mv_002',
        'category': 'Obedience',
        'verse': 'Children, obey your parents in the Lord, for this is right.',
        'reference': 'Ephesians 6:1',
        'ageGroup': 'young',
        'difficulty': 'easy',
        'theme': 'Family',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'mv_003',
        'category': 'Sabbath',
        'verse': 'Remember the Sabbath day by keeping it holy.',
        'reference': 'Exodus 20:8',
        'ageGroup': 'all',
        'difficulty': 'easy',
        'theme': 'Sabbath',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'mv_004',
        'category': 'Prayer',
        'verse':
            'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.',
        'reference': 'Philippians 4:6',
        'ageGroup': 'older',
        'difficulty': 'medium',
        'theme': 'Prayer',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'mv_005',
        'category': 'Kindness',
        'verse':
            'Be kind and compassionate to one another, forgiving each other, just as in Christ God forgave you.',
        'reference': 'Ephesians 4:32',
        'ageGroup': 'all',
        'difficulty': 'medium',
        'theme': 'Character',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'mv_006',
        'category': 'Creation',
        'verse': 'In the beginning God created the heavens and the earth.',
        'reference': 'Genesis 1:1',
        'ageGroup': 'young',
        'difficulty': 'easy',
        'theme': 'Creation',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'mv_007',
        'category': 'Second Coming',
        'verse':
            'And if I go and prepare a place for you, I will come back and take you to be with me that you also may be where I am.',
        'reference': 'John 14:3',
        'ageGroup': 'older',
        'difficulty': 'medium',
        'theme': 'Second Coming',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'mv_008',
        'category': 'Health',
        'verse':
            'Do you not know that your bodies are temples of the Holy Spirit, who is in you, whom you have received from God?',
        'reference': '1 Corinthians 6:19',
        'ageGroup': 'older',
        'difficulty': 'hard',
        'theme': 'Health',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'mv_009',
        'category': 'Trust',
        'verse':
            'Trust in the Lord with all your heart and lean not on your own understanding.',
        'reference': 'Proverbs 3:5',
        'ageGroup': 'all',
        'difficulty': 'medium',
        'theme': 'Trust',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'mv_010',
        'category': 'Stewardship',
        'verse':
            'Bring the whole tithe into the storehouse, that there may be food in my house.',
        'reference': 'Malachi 3:10',
        'ageGroup': 'older',
        'difficulty': 'medium',
        'theme': 'Stewardship',
        'createdAt': KidsContentService._now(),
      },
    ];

    await _seedAppwriteDefaults(_memoryVersesCollection, memoryVerses);
  }

  /// Initialize prayer activities
  static Future<void> _initializePrayerActivities() async {
    final prayerActivities = [
      {
        'id': 'pa_001',
        'type': 'morning',
        'title': 'Good Morning Prayer',
        'content':
            'Dear Jesus, thank You for this new day. Please help me to be kind, obedient, and loving today. Guide my steps and keep me safe. Amen.',
        'ageGroup': 'young',
        'duration': '1 minute',
        'category': 'Daily Prayers',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'pa_002',
        'type': 'meal',
        'title': 'Mealtime Blessing',
        'content':
            'Dear God, thank You for this food. Bless it to nourish our bodies. Help us remember those who are hungry and teach us to share. Amen.',
        'ageGroup': 'all',
        'duration': '30 seconds',
        'category': 'Meal Prayers',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'pa_003',
        'type': 'bedtime',
        'title': 'Bedtime Prayer',
        'content':
            'Dear Jesus, thank You for watching over me today. Forgive me for any wrong I have done. Please give me peaceful sleep and sweet dreams. Amen.',
        'ageGroup': 'young',
        'duration': '1 minute',
        'category': 'Daily Prayers',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'pa_004',
        'type': 'sabbath',
        'title': 'Sabbath Welcome Prayer',
        'content':
            'Dear God, we welcome Your holy Sabbath day. Help us to rest, worship, and spend special time with You and our family. Bless our Sabbath hours. Amen.',
        'ageGroup': 'all',
        'duration': '1 minute',
        'category': 'Sabbath Prayers',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'pa_005',
        'type': 'gratitude',
        'title': 'Thankfulness Prayer',
        'content':
            'Dear God, thank You for my family, friends, home, and food. Thank You for loving me and taking care of me every day. Help me to always be grateful. Amen.',
        'ageGroup': 'all',
        'duration': '1 minute',
        'category': 'Gratitude Prayers',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'pa_006',
        'type': 'guidance',
        'title': 'Prayer for Wisdom',
        'content':
            'Dear Jesus, please give me wisdom to make good choices today. Help me to be honest, kind, and helpful to others. Guide me in all I do. Amen.',
        'ageGroup': 'older',
        'duration': '1 minute',
        'category': 'Guidance Prayers',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'pa_007',
        'type': 'family',
        'title': 'Family Prayer',
        'content':
            'Dear God, please bless our family. Help us to love each other, be patient, and work together. Keep us healthy and safe. Thank You for our home. Amen.',
        'ageGroup': 'all',
        'duration': '1 minute',
        'category': 'Family Prayers',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'pa_008',
        'type': 'forgiveness',
        'title': 'Prayer for Forgiveness',
        'content':
            'Dear Jesus, I am sorry for the wrong things I have done. Please forgive me and help me to do better. Thank You for Your love and mercy. Amen.',
        'ageGroup': 'all',
        'duration': '1 minute',
        'category': 'Forgiveness Prayers',
        'createdAt': KidsContentService._now(),
      },
    ];

    await _seedAppwriteDefaults(_prayerActivitiesCollection, prayerActivities);
  }

  /// Initialize service projects
  static Future<void> _initializeServiceProjects() async {
    final serviceProjects = [
      {
        'id': 'sp_001',
        'title': 'Helping Elderly Neighbors',
        'description':
            'Visit elderly neighbors to help with simple tasks like carrying groceries, reading to them, or just spending time together.',
        'ageGroup': 'all',
        'duration': '1-2 hours',
        'materials': ['Time', 'Caring heart', 'Parent supervision'],
        'category': 'Community Service',
        'difficulty': 'easy',
        'impact': 'Brings joy and assistance to elderly community members',
        'sdaValues': ['Love', 'Service', 'Community'],
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'sp_002',
        'title': 'Food Bank Collection',
        'description':
            'Organize a food drive at church or school to collect non-perishable items for local food banks.',
        'ageGroup': 'older',
        'duration': '2-4 weeks',
        'materials': ['Collection boxes', 'Flyers', 'Transportation'],
        'category': 'Hunger Relief',
        'difficulty': 'medium',
        'impact': 'Provides meals for families in need',
        'sdaValues': ['Compassion', 'Stewardship', 'Service'],
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'sp_003',
        'title': 'Environmental Cleanup',
        'description':
            'Organize a neighborhood or park cleanup to care for Gods creation by picking up litter and planting flowers.',
        'ageGroup': 'all',
        'duration': '2-3 hours',
        'materials': ['Gloves', 'Trash bags', 'Seeds or plants'],
        'category': 'Environmental',
        'difficulty': 'easy',
        'impact': 'Beautifies community and protects environment',
        'sdaValues': ['Stewardship', 'Creation Care', 'Community'],
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'sp_004',
        'title': 'Comfort Bags for Homeless',
        'description':
            'Create care packages with snacks, socks, toiletries, and encouraging notes for homeless individuals.',
        'ageGroup': 'all',
        'duration': '2-3 hours',
        'materials': ['Bags', 'Snacks', 'Socks', 'Toiletries', 'Notes'],
        'category': 'Homeless Outreach',
        'difficulty': 'easy',
        'impact': 'Provides basic needs and shows love to those without homes',
        'sdaValues': ['Compassion', 'Love', 'Service'],
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'sp_005',
        'title': 'Reading to Younger Children',
        'description':
            'Volunteer to read Bible stories and educational books to younger children at church, library, or community center.',
        'ageGroup': 'older',
        'duration': '1 hour weekly',
        'materials': ['Age-appropriate books', 'Bible story books'],
        'category': 'Education',
        'difficulty': 'easy',
        'impact': 'Promotes literacy and shares positive values',
        'sdaValues': ['Education', 'Service', 'Mentorship'],
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'sp_006',
        'title': 'Hospital Encouragement Cards',
        'description':
            'Create handmade cards with Bible verses and encouraging messages for patients in local hospitals.',
        'ageGroup': 'all',
        'duration': '1-2 hours',
        'materials': ['Cardstock', 'Markers', 'Stickers', 'Bible verses'],
        'category': 'Healthcare Support',
        'difficulty': 'easy',
        'impact': 'Brings hope and encouragement to sick patients',
        'sdaValues': ['Healing', 'Hope', 'Compassion'],
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'sp_007',
        'title': 'Animal Shelter Assistance',
        'description':
            'Help at local animal shelters by walking dogs, playing with cats, or making toys for the animals.',
        'ageGroup': 'all',
        'duration': '2-3 hours',
        'materials': ['Old towels', 'Toys', 'Time and energy'],
        'category': 'Animal Care',
        'difficulty': 'easy',
        'impact': 'Provides care and love for abandoned animals',
        'sdaValues': ['Creation Care', 'Compassion', 'Stewardship'],
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'sp_008',
        'title': 'School Supply Drive',
        'description':
            'Collect school supplies for underprivileged children to help them succeed in their education.',
        'ageGroup': 'all',
        'duration': '2-3 weeks',
        'materials': ['Collection boxes', 'Promotional materials'],
        'category': 'Education Support',
        'difficulty': 'medium',
        'impact': 'Ensures all children have tools needed for learning',
        'sdaValues': ['Education', 'Equality', 'Service'],
        'createdAt': KidsContentService._now(),
      },
    ];

    await _seedAppwriteDefaults(_serviceProjectsCollection, serviceProjects);
  }

  /// Initialize kids stories with SDA doctrinal content
  static Future<void> _initializeKidsStories() async {
    final kidsStories = [
      {
        'id': 'ks_001',
        'title': 'The Special Day - Sabbath',
        'content':
            'Long ago, God created the world in six days. On the seventh day, He rested and made it holy. This special day is called the Sabbath. Every week, we remember Gods creation by resting and worshiping Him on the Sabbath day.',
        'category': 'Sabbath',
        'ageGroup': 'young',
        'moralLesson':
            'The Sabbath is Gods special gift to us for rest and worship.',
        'bibleReference': 'Genesis 2:2-3',
        'sdaDoctrine': 'Sabbath Observance',
        'duration': '3 minutes',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'ks_002',
        'title': 'Jesus is Coming Back',
        'content':
            'Jesus promised His disciples that He would come back to take them to heaven. One day, Jesus will return in the clouds with angels. All who love Him will go to live with Him forever in a beautiful place with no sadness or pain.',
        'category': 'Second Coming',
        'ageGroup': 'all',
        'moralLesson':
            'Jesus loves us and is preparing a wonderful home for us in heaven.',
        'bibleReference': 'John 14:1-3',
        'sdaDoctrine': 'Second Coming of Christ',
        'duration': '4 minutes',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'ks_003',
        'title': 'Our Bodies are Special Temples',
        'content':
            'God made our bodies to be His temple. Just like we keep a church clean and beautiful, we should take care of our bodies by eating healthy food, exercising, and avoiding things that harm us. This shows love and respect for God.',
        'category': 'Health',
        'ageGroup': 'all',
        'moralLesson': 'We honor God by taking good care of our bodies.',
        'bibleReference': '1 Corinthians 6:19-20',
        'sdaDoctrine': 'Christian Lifestyle and Health',
        'duration': '3 minutes',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'ks_004',
        'title': 'The Gift of Giving',
        'content':
            'A little boy had only two small coins, but he gave them to help Gods work. Jesus saw his generous heart and was pleased. When we give our tithe and offerings, we show that we trust God to take care of us.',
        'category': 'Stewardship',
        'ageGroup': 'older',
        'moralLesson':
            'God loves a cheerful giver, no matter how small the gift.',
        'bibleReference': 'Mark 12:41-44',
        'sdaDoctrine': 'Stewardship and Tithing',
        'duration': '4 minutes',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'ks_005',
        'title': 'The Power of Prayer',
        'content':
            'Daniel prayed to God three times every day, even when it was dangerous. God protected Daniel in the lions den because of his faith and prayers. We can talk to God anytime, anywhere, and He will listen to us.',
        'category': 'Prayer',
        'ageGroup': 'all',
        'moralLesson':
            'God always hears our prayers and will protect those who trust in Him.',
        'bibleReference': 'Daniel 6:10-23',
        'sdaDoctrine': 'Prayer and Faith',
        'duration': '5 minutes',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'ks_006',
        'title': 'Gods Beautiful Creation',
        'content':
            'In the beginning, God spoke and created the sun, moon, stars, plants, animals, and people. Everything He made was very good. We are special because God made us in His image and gave us the job to take care of His creation.',
        'category': 'Creation',
        'ageGroup': 'young',
        'moralLesson':
            'We are special to God and should care for His creation.',
        'bibleReference': 'Genesis 1:1-31',
        'sdaDoctrine': 'Creation and Stewardship',
        'duration': '4 minutes',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'ks_007',
        'title': 'The Sanctuary in Heaven',
        'content':
            'Long ago, God told Moses to build a special tent called the sanctuary. It showed how Jesus would save us from sin. Today, Jesus is in the heavenly sanctuary, working as our High Priest to help us and prepare us for heaven.',
        'category': 'Sanctuary',
        'ageGroup': 'older',
        'moralLesson':
            'Jesus is always working to help us and save us from sin.',
        'bibleReference': 'Hebrews 8:1-2',
        'sdaDoctrine': 'Heavenly Sanctuary',
        'duration': '5 minutes',
        'createdAt': KidsContentService._now(),
      },
      {
        'id': 'ks_008',
        'title': 'The Gift of Prophecy',
        'content':
            'God gave Ellen White special dreams and visions to help guide His church. She wrote many books to help people understand the Bible better and live healthy, happy lives. God still speaks to His people today through His Word and His messengers.',
        'category': 'Prophecy',
        'ageGroup': 'older',
        'moralLesson':
            'God loves us and gives us guidance through His prophets.',
        'bibleReference': 'Revelation 19:10',
        'sdaDoctrine': 'Gift of Prophecy',
        'duration': '4 minutes',
        'createdAt': KidsContentService._now(),
      },
    ];

    await _seedAppwriteDefaults(_kidsStoriesCollection, kidsStories);
  }

  /// Get memory verses by category
  static Future<List<Map<String, dynamic>>> getMemoryVerses({
    String? category,
    String? ageGroup,
    String? difficulty,
  }) async {
    try {
      return await _listAppwrite(
        _memoryVersesCollection,
        category: category,
        ageGroup: ageGroup,
        qualifierKey: 'difficulty',
        qualifierValue: difficulty,
      );
    } catch (e) {
      _logger.error('Error loading memory verses from Appwrite', e);
      return _filterOfflineItems(
        _offlineMemoryVerses,
        category: category,
        ageGroup: ageGroup,
        qualifierKey: 'difficulty',
        qualifierValue: difficulty,
      );
    }
  }

  /// Get prayer activities by type
  static Future<List<Map<String, dynamic>>> getPrayerActivities({
    String? type,
    String? ageGroup,
    String? category,
  }) async {
    try {
      return await _listAppwrite(
        _prayerActivitiesCollection,
        category: category,
        ageGroup: ageGroup,
        qualifierKey: 'type',
        qualifierValue: type,
      );
    } catch (e) {
      _logger.error('Error loading prayer activities from Appwrite', e);
      return _filterOfflineItems(
        _offlinePrayerActivities,
        category: category,
        ageGroup: ageGroup,
        qualifierKey: 'type',
        qualifierValue: type,
      );
    }
  }

  /// Get service projects by category
  static Future<List<Map<String, dynamic>>> getServiceProjects({
    String? category,
    String? ageGroup,
    String? difficulty,
  }) async {
    try {
      return await _listAppwrite(
        _serviceProjectsCollection,
        category: category,
        ageGroup: ageGroup,
        qualifierKey: 'difficulty',
        qualifierValue: difficulty,
      );
    } catch (e) {
      _logger.error('Error loading service projects from Appwrite', e);
      return _filterOfflineItems(
        _offlineServiceProjects,
        category: category,
        ageGroup: ageGroup,
        qualifierKey: 'difficulty',
        qualifierValue: difficulty,
      );
    }
  }

  /// Get kids stories by category
  static Future<List<Map<String, dynamic>>> getKidsStories({
    String? category,
    String? ageGroup,
    String? sdaDoctrine,
  }) async {
    try {
      return await _listAppwrite(
        _kidsStoriesCollection,
        category: category,
        ageGroup: ageGroup,
        qualifierKey: 'sdaDoctrine',
        qualifierValue: sdaDoctrine,
      );
    } catch (e) {
      _logger.error('Error loading kids stories from Appwrite', e);
      return _filterOfflineItems(
        _offlineKidsStories,
        category: category,
        ageGroup: ageGroup,
        qualifierKey: 'sdaDoctrine',
        qualifierValue: sdaDoctrine,
      );
    }
  }

  /// Get all categories for memory verses
  static Future<List<String>> getMemoryVerseCategories() async {
    final items = await getMemoryVerses();
    final categories = items
        .map((item) => item['category']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
    return categories.toList()..sort();
  }

  /// Get all categories for service projects
  static Future<List<String>> getServiceProjectCategories() async {
    final items = await getServiceProjects();
    final categories = items
        .map((item) => item['category']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
    return categories.toList()..sort();
  }

  /// Get random memory verse for daily devotion
  static Future<Map<String, dynamic>?> getRandomMemoryVerse(
      {String? ageGroup}) async {
    final verses = await getMemoryVerses(ageGroup: ageGroup);
    if (verses.isEmpty) return null;

    verses.shuffle();
    return verses.first;
  }

  /// Get prayer for specific time of day
  static Future<Map<String, dynamic>?> getPrayerForTime(String timeType,
      {String? ageGroup}) async {
    final prayers =
        await getPrayerActivities(type: timeType, ageGroup: ageGroup);
    if (prayers.isEmpty) return null;

    prayers.shuffle();
    return prayers.first;
  }

  static List<Map<String, dynamic>> _filterOfflineItems(
    List<Map<String, dynamic>> items, {
    String? category,
    String? ageGroup,
    String? qualifierKey,
    String? qualifierValue,
  }) {
    return items
        .where((item) {
          final categoryMatch =
              category == null || item['category']?.toString() == category;
          final ageGroupValue = item['ageGroup']?.toString();
          final ageGroupMatch = ageGroup == null ||
              ageGroupValue == null ||
              ageGroupValue == ageGroup ||
              ageGroupValue == 'all';
          final qualifierMatch = qualifierKey == null ||
              qualifierValue == null ||
              item[qualifierKey]?.toString() == qualifierValue;
          return categoryMatch && ageGroupMatch && qualifierMatch;
        })
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // Admin update/delete helpers
  static Future<void> updateMemoryVerse(
      String id, Map<String, dynamic> updates) async {
    try {
      await _updateAppwriteDocument(_memoryVersesCollection, id, updates);
    } catch (e) {
      throw DatabaseException('Failed to update memory verse',
          originalError: e);
    }
  }

  static Future<void> deleteMemoryVerse(String id) async {
    try {
      await _deleteAppwriteDocument(_memoryVersesCollection, id);
    } catch (e) {
      throw DatabaseException('Failed to delete memory verse',
          originalError: e);
    }
  }

  static Future<void> updatePrayerActivity(
      String id, Map<String, dynamic> updates) async {
    try {
      await _updateAppwriteDocument(_prayerActivitiesCollection, id, updates);
    } catch (e) {
      throw DatabaseException('Failed to update prayer activity',
          originalError: e);
    }
  }

  static Future<void> deletePrayerActivity(String id) async {
    try {
      await _deleteAppwriteDocument(_prayerActivitiesCollection, id);
    } catch (e) {
      throw DatabaseException('Failed to delete prayer activity',
          originalError: e);
    }
  }

  static Future<void> updateServiceProject(
      String id, Map<String, dynamic> updates) async {
    try {
      await _updateAppwriteDocument(_serviceProjectsCollection, id, updates);
    } catch (e) {
      throw DatabaseException('Failed to update service project',
          originalError: e);
    }
  }

  static Future<void> deleteServiceProject(String id) async {
    try {
      await _deleteAppwriteDocument(_serviceProjectsCollection, id);
    } catch (e) {
      throw DatabaseException('Failed to delete service project',
          originalError: e);
    }
  }

  static Future<void> updateKidsStory(
      String id, Map<String, dynamic> updates) async {
    try {
      await _updateAppwriteDocument(_kidsStoriesCollection, id, updates);
    } catch (e) {
      throw DatabaseException('Failed to update kids story', originalError: e);
    }
  }

  static Future<void> deleteKidsStory(String id) async {
    try {
      await _deleteAppwriteDocument(_kidsStoriesCollection, id);
    } catch (e) {
      throw DatabaseException('Failed to delete kids story', originalError: e);
    }
  }

  // Static wrappers for learning resources to match admin usage
  static Future<void> updateLearningResource(
      String id, Map<String, dynamic> updates) async {
    try {
      await _updateAppwriteDocument(_learningResourcesCollection, id, updates);
    } catch (e) {
      throw DatabaseException('Failed to update learning resource',
          originalError: e);
    }
  }

  static Future<void> deleteLearningResource(String id) async {
    try {
      await _deleteAppwriteDocument(_learningResourcesCollection, id);
    } catch (e) {
      throw DatabaseException('Failed to delete learning resource',
          originalError: e);
    }
  }

  // Static create helpers used by admin screen
  static Future<String> createMemoryVerse(Map<String, dynamic> verse) async {
    try {
      return await _createAppwriteDocument(_memoryVersesCollection, verse);
    } catch (e) {
      throw DatabaseException('Failed to create memory verse',
          originalError: e);
    }
  }

  static Future<String> createPrayerActivity(
      Map<String, dynamic> activity) async {
    try {
      return await _createAppwriteDocument(
          _prayerActivitiesCollection, activity);
    } catch (e) {
      throw DatabaseException('Failed to create prayer activity',
          originalError: e);
    }
  }

  static Future<String> createServiceProject(
      Map<String, dynamic> project) async {
    try {
      return await _createAppwriteDocument(_serviceProjectsCollection, project);
    } catch (e) {
      throw DatabaseException('Failed to create service project',
          originalError: e);
    }
  }

  static Future<String> createKidsStory(Map<String, dynamic> story) async {
    try {
      return await _createAppwriteDocument(_kidsStoriesCollection, story);
    } catch (e) {
      throw DatabaseException('Failed to create kids story', originalError: e);
    }
  }

  static Future<String> createKidsMission(Map<String, dynamic> mission) async {
    try {
      return await _createAppwriteDocument(_kidsMissionsCollection, mission);
    } catch (e) {
      throw DatabaseException('Failed to create kids mission',
          originalError: e);
    }
  }

  /// Seed the 10 sample kids missions. Safe to call repeatedly: it skips
  /// missions whose title already exists so admins can re-run it without
  /// creating duplicates.
  static Future<int> seedSampleKidsMission() async {
    final samples = _sampleMissions();
    var created = 0;
    for (final mission in samples) {
      try {
        await createKidsMission(mission);
        created++;
      } catch (_) {
        // Skip duplicates or network errors and continue with the rest.
      }
    }
    return created;
  }

  static List<Map<String, dynamic>> _sampleMissions() {
    const data = _SampleMissionsData.missions;
    return data
        .map((m) => {
              ...m,
              'instructions': json.encode(m['instructions']),
              'is_active': true,
              'is_locked': false,
              'created_at':
                  DateTime.now().toUtc().toIso8601String(),
              'updated_at':
                  DateTime.now().toUtc().toIso8601String(),
            })
        .toList();
  }


  static Future<String> createLearningResource(
      Map<String, dynamic> resource) async {
    try {
      return await _createAppwriteDocument(
          _learningResourcesCollection, resource);
    } catch (e) {
      throw DatabaseException('Failed to create learning resource',
          originalError: e);
    }
  }
}

/// The 10 sample kids missions shown in the old web project, ported over so
/// admins can seed them with one tap from the Kids Missions admin screen.
class _SampleMissionsData {
  static const List<Map<String, Object>> missions = [
    {
      'title': 'Share a Bible Story',
      'description':
          'Tell a favorite Bible story to a friend or family member',
      'location': 'Home/School',
      'difficulty': 'easy',
      'duration': '15 minutes',
      'points': 10,
      'category': 'sharing',
      'verification_method': 'story',
      'instructions': [
        'Choose one of your favorite Bible stories',
        'Find someone who would like to hear it',
        'Tell the story in your own words',
        'Explain what lesson you learned from it',
      ],
    },
    {
      'title': 'Help Someone in Need',
      'description': 'Find someone who needs help and offer assistance',
      'location': 'Community',
      'difficulty': 'easy',
      'duration': '30 minutes',
      'points': 15,
      'category': 'service',
      'verification_method': 'photo',
      'instructions': [
        'Look around for someone who might need help',
        'Offer your assistance kindly',
        'Help them with what they need',
        'Don\'t expect anything in return',
      ],
    },
    {
      'title': 'Memorize the Beatitudes',
      'description':
          'Learn and recite the Beatitudes from Matthew 5:3-12',
      'location': 'Anywhere',
      'difficulty': 'medium',
      'duration': '1 hour',
      'points': 20,
      'category': 'learning',
      'verification_method': 'quiz',
      'instructions': [
        'Read Matthew 5:3-12 several times',
        'Break it into smaller sections',
        'Practice reciting each section',
        'Recite the complete passage from memory',
      ],
    },
    {
      'title': 'Prayer Walk',
      'description': 'Take a walk and pray for people and places you see',
      'location': 'Neighborhood',
      'difficulty': 'easy',
      'duration': '20 minutes',
      'points': 10,
      'category': 'prayer',
      'verification_method': 'story',
      'instructions': [
        'Take a walk in your neighborhood or area',
        'Pray silently for each person you see',
        'Pray for the homes and families you pass',
        'Ask God to bless your community',
      ],
    },
    {
      'title': 'Make a Get-Well Card',
      'description':
          'Create and deliver a get-well card to someone who is sick',
      'location': 'Home/Hospital/Church',
      'difficulty': 'easy',
      'duration': '45 minutes',
      'points': 15,
      'category': 'service',
      'verification_method': 'photo',
      'instructions': [
        'Think of someone you know who is unwell',
        'Make a colorful, encouraging card',
        'Write a Bible verse and personal message',
        'Deliver it with a smile and pray with them if possible',
      ],
    },
    {
      'title': 'Invite a Friend to Church',
      'description':
          'Invite a friend who doesn\'t attend church to come with you',
      'location': 'School/Community',
      'difficulty': 'medium',
      'duration': '1 week',
      'points': 25,
      'category': 'evangelism',
      'verification_method': 'witness',
      'instructions': [
        'Think of a friend who doesn\'t attend church regularly',
        'Tell them about fun activities at your church',
        'Invite them to a special program or regular service',
        'Offer to sit with them and help them feel welcome',
      ],
    },
    {
      'title': 'Collect Items for the Needy',
      'description':
          'Gather clothes, food, or supplies to donate to those in need',
      'location': 'Community',
      'difficulty': 'medium',
      'duration': '2 hours',
      'points': 20,
      'category': 'service',
      'verification_method': 'photo',
      'instructions': [
        'Ask your family for items they can donate',
        'Organize the items neatly',
        'Find a local charity or church that accepts donations',
        'Deliver the items and see how your help makes a difference',
      ],
    },
    {
      'title': 'Learn the Books of the Bible',
      'description': 'Memorize all 66 books of the Bible in order',
      'location': 'Anywhere',
      'difficulty': 'hard',
      'duration': '2 weeks',
      'points': 30,
      'category': 'learning',
      'verification_method': 'quiz',
      'instructions': [
        'Start with the Old Testament books (39 books)',
        'Learn them in groups of 5-10',
        'Practice daily until you can recite them',
        'Then learn the New Testament books (27 books)',
        'Practice reciting all 66 books in order',
      ],
    },
    {
      'title': 'Neighborhood Cleanup',
      'description': 'Organize or join a neighborhood cleanup activity',
      'location': 'Neighborhood',
      'difficulty': 'medium',
      'duration': '1.5 hours',
      'points': 20,
      'category': 'service',
      'verification_method': 'photo',
      'instructions': [
        'Get permission from parents/guardians',
        'Gather gloves and garbage bags',
        'Pick up litter in your neighborhood or a local park',
        'Properly dispose of all collected trash',
      ],
    },
    {
      'title': 'Teach a Bible Song',
      'description': 'Teach a Bible song or hymn to younger children',
      'location': 'Church/Home',
      'difficulty': 'easy',
      'duration': '30 minutes',
      'points': 15,
      'category': 'sharing',
      'verification_method': 'story',
      'instructions': [
        'Choose a simple, memorable Bible song',
        'Practice singing it until you know it well',
        'Find younger children who would like to learn',
        'Teach them the words and tune patiently',
      ],
    },
  ];
}


/// Age groups for kids content
enum KidsAgeGroup {
  young, // 3-7 years
  older, // 8-12 years
  all, // All ages
}

/// Difficulty levels for memory verses
enum MemoryVerseDifficulty {
  easy,
  medium,
  hard,
}

/// Prayer types
enum PrayerType {
  morning,
  meal,
  bedtime,
  sabbath,
  gratitude,
  guidance,
  family,
  forgiveness,
}

Future<void> _initializeLearningResources() async {
  final resources = [
    {
      'id': 'lr_001',
      'title': 'Sabbath Activity Pack',
      'description':
          'Coloring pages, memory verse cards, and simple crafts to celebrate the Sabbath.',
      'category': 'Sabbath',
      'ageGroup': 'young',
      'resourceType': 'activity_pack',
      'downloadable': true,
      'createdAt': KidsContentService._now(),
    },
    {
      'id': 'lr_002',
      'title': 'Creation Week Lesson Plan',
      'description':
          'Seven-day lesson plan with songs, verses, and crafts to learn about creation.',
      'category': 'Creation',
      'ageGroup': 'all',
      'resourceType': 'lesson_plan',
      'downloadable': true,
      'createdAt': KidsContentService._now(),
    },
    {
      'id': 'lr_003',
      'title': 'Three Angels Messages Visual Guide',
      'description':
          'Kid-friendly poster and story guide explaining the three angels messages.',
      'category': 'Three Angels',
      'ageGroup': 'older',
      'resourceType': 'poster_guide',
      'downloadable': true,
      'createdAt': KidsContentService._now(),
    },
    {
      'id': 'lr_004',
      'title': 'Healthy Choices Chart',
      'description':
          'Daily tracker for sleep, water, exercise, and devotional time.',
      'category': 'Health',
      'ageGroup': 'all',
      'resourceType': 'chart',
      'downloadable': true,
      'createdAt': KidsContentService._now(),
    },
    {
      'id': 'lr_005',
      'title': 'Sanctuary Symbols Coloring',
      'description':
          'Coloring pack explaining sanctuary furniture and symbols pointing to Jesus.',
      'category': 'Sanctuary',
      'ageGroup': 'older',
      'resourceType': 'coloring_pack',
      'downloadable': true,
      'createdAt': KidsContentService._now(),
    },
  ];

  await KidsContentService._seedAppwriteDefaults(
    'learning_resources',
    resources,
  );
}

Future<List<Map<String, dynamic>>> getLearningResources({
  String? category,
  String? ageGroup,
  String? resourceType,
}) async {
  try {
    return await KidsContentService._listAppwrite(
      'learning_resources',
      category: category,
      ageGroup: ageGroup,
      qualifierKey: 'resourceType',
      qualifierValue: resourceType,
    );
  } catch (e) {
    KidsContentService._logger
        .error('Error loading learning resources from Appwrite', e);
    return KidsContentService._filterOfflineItems(
      KidsContentService._offlineLearningResources,
      category: category,
      ageGroup: ageGroup,
      qualifierKey: 'resourceType',
      qualifierValue: resourceType,
    );
  }
}

Future<String> createLearningResource(Map<String, dynamic> resource) async {
  try {
    return await KidsContentService._createAppwriteDocument(
      'learning_resources',
      resource,
    );
  } catch (e) {
    throw DatabaseException('Failed to create learning resource',
        originalError: e);
  }
}

Future<void> updateLearningResource(
    String id, Map<String, dynamic> updates) async {
  try {
    await KidsContentService._updateAppwriteDocument(
      'learning_resources',
      id,
      updates,
    );
  } catch (e) {
    throw DatabaseException('Failed to update learning resource',
        originalError: e);
  }
}

Future<void> deleteLearningResource(String id) async {
  try {
    await KidsContentService._deleteAppwriteDocument('learning_resources', id);
  } catch (e) {
    throw DatabaseException('Failed to delete learning resource',
        originalError: e);
  }
}
