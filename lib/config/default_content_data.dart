/// Default seed data and fallback content for ALIVE Nigeria content pages and mission projects.
class DefaultContentData {
  DefaultContentData._();

  static List<Map<String, dynamic>> get defaultContentPages => [
        {
          'id': 'page_about_alive',
          'title': 'About ALIVE Nigeria',
          'slug': 'about-alive',
          'language': 'en',
          'is_published': true,
          'publish_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'content':
              'A.L.I.V.E is an acronym for Africans Living In View of Eternity. ALIVE-Nigeria is the Nigerian chapter of this movement, committed to a Bible-based, youth-led revival across Africa.\n\nWe are men, women, graduates, working professionals, and student volunteers whose hearts are burdened for spreading God\'s Word and works. ALIVE Nigeria exists to challenge and equip believers with tools for individual missionary work, spiritual growth, mentorship, and service.\n\n"The Lord has appointed the youth to be His helping hand." — {ChS 30.1}\n\n"With such an army of workers as our youth, rightly trained, how soon the message of a crucified, risen, and soon-coming Saviour might be carried to the whole world." — Education, p. 271. {ChS 30.2}\n\nJoin us today and let us take the good news of the Gospel to places where no one wants to go.',
        },
        {
          'id': 'page_mission_vision',
          'title': 'Mission & Vision Statement',
          'slug': 'mission-vision',
          'language': 'en',
          'is_published': true,
          'publish_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'content':
              'MISSION STATEMENT:\nOur mission is to prepare Africa for the imminent return of Jesus Christ. Through biblical spiritual training and evangelistic efforts, we challenge African Seventh-day Adventist young adults to live with authentic biblical excellence, develop a missionary volunteer spirit, support missionary movements across Africa, and make meaningful impact in neglected areas.\n\nVISION STATEMENT:\nAt ALIVE, our vision is to ignite and sustain a Bible-based, youth-led revival movement across the continent of Africa, empowering every Seventh-day Adventist young professional to become a dedicated missionary with a deep personal relationship with Jesus Christ and commitment to His Great Commission.',
        },
        {
          'id': 'page_what_alive_emphasizes',
          'title': 'What ALIVE Emphasizes',
          'slug': 'what-alive-emphasizes',
          'language': 'en',
          'is_published': true,
          'publish_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'content':
              'ALIVE Nigeria emphasizes four core pillars of ministry:\n\n1. Evangelism: Taking the Gospel seriously and making outreach part of everyday ministry life.\n2. Discipleship: Helping people mature in Scripture, character, and practical obedience to Christ.\n3. Prayer and Care: Supporting members spiritually while building a culture of intercession and encouragement.\n4. Wholesome Living: Promoting healthy, balanced living that reflects stewardship of body, mind, and mission (health evangelism and plant-based nutrition).',
        },
        {
          'id': 'page_onboarding',
          'title': 'Welcome to ALIVE Nigeria',
          'slug': 'onboarding',
          'language': 'en',
          'is_published': true,
          'publish_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'content':
              'Welcome to ALIVE Nigeria — Africans Living In View of Eternity. Bible study, prayer, and service in one community.\n\nJoin our vibrant community united by Prayer, Study, Missions, and Health:\n\n• Evangelism & Gospel Tracts: In need of evangelism tracts? Access an uplifting library of gospel tracts ready for outreach. Easy to download and print for field evangelism, or share instantly in softcopy with friends and seekers.\n• Roles & Organization: We are organized to serve! From dedicated Members and Chapter Leaders to Coordinators, Directors, and Board of Trustees (BOD), every role is vital.\n• Tagging, Praying & Chatting: Stay deeply connected. Tag members, join chapter chats, pray together instantly, and share your powerful testimonies with the community.\n• Kids & Discipleship: Grow in Christ through interactive discipleship lessons, audio podcasts, and children’s mission adventures with illustrated Bible stories and memory verses.',
        },
        {
          'id': 'page_privacy_policy',
          'title': 'Community Guidelines & Privacy Policy',
          'slug': 'privacy-policy',
          'language': 'en',
          'is_published': true,
          'publish_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'content':
              'ALIVE Nigeria values user trust, spiritual confidentiality, and Christian brotherhood.\n\nPrivate prayer rooms, intercession requests, and personal reflections are protected with role-based and cryptographic boundaries. Chat communication across local chapters, committees, and leadership bodies must reflect Christ-like decorum, mutual respect, and spiritual upliftment.',
        },
        {
          'id': 'page_annual_retreat',
          'title': 'ALIVE Nigeria National Retreat 2026',
          'slug': 'annual-retreat',
          'language': 'en',
          'is_published': true,
          'publish_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'content':
              'Annual gathering of Adventist lay missionaries, working professionals, and students across Nigeria for spiritual revival, mission consecration, and evangelism training.',
        },
        {
          'id': 'page_mission_outreaches',
          'title': 'Campus & Rural Mission Outreaches (STMs & LTMs)',
          'slug': 'mission-outreaches',
          'language': 'en',
          'is_published': true,
          'publish_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'content':
              'Deploying Short-Term Missionaries (STMs) and Long-Term Missionaries (LTMs) to unreached campus territories and rural outposts across Nigeria.',
        },
        {
          'id': 'page_health_plus',
          'title': 'Health+ Plant-Based Living & Remedies',
          'slug': 'health-plus',
          'language': 'en',
          'is_published': true,
          'publish_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'content':
              'Authentic Nigerian plant-based recipes, natural therapeutic remedies, and wholesome living resources reflecting stewardship of body, mind, and mission.',
        },
        {
          'id': 'page_discipleship_daily',
          'title': 'Daily Word & Discipleship Growth',
          'slug': 'discipleship-growth',
          'language': 'en',
          'is_published': true,
          'publish_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'content':
              'Structured Bible study lessons, Daily Tasks, Instant Word memorization games, and spiritual progress tracking for personal and chapter development.',
        },
      ];

  static List<Map<String, dynamic>> get defaultProjects => [
        {
          'id': 'impact_hub_center',
          'title': 'Impact Hub Center',
          'summary': 'Community discipleship and outreach facility',
          'description':
              'A central hub for training, discipleship, and community engagement. Seed funding has helped prepare the project scope, early planning, and ministry coordination for the hub.',
          'goal': 35000000.0,
          'raised': 8384400.0,
          'currency': 'NGN',
          'status': 'active',
          'priority': 1,
          'cta_label': 'Donate for this item',
          'image_url': 'assets/images/impact_hub_3d_view.png',
          'viewer_url': 'alive_ng_3d_viewer.html',
          'fund_update_title': 'Progress so far',
          'fund_update_text':
              'Seed funding has helped prepare the project scope, early planning, and ministry coordination for the hub.',
          'fund_update_images': <String>[],
        },
        {
          'id': 'vehicle_purchase',
          'title': 'Vehicle Purchase',
          'summary': 'Mission vehicle for outreach logistics',
          'description':
              'Reliable transportation for mission trips and logistics across Nigeria.',
          'goal': 18000000.0,
          'raised': 0.0,
          'currency': 'NGN',
          'status': 'active',
          'priority': 2,
          'cta_label': 'Donate for this item',
          'image_url':
              'https://images.unsplash.com/photo-1597685204565-110abf469a1e?q=80&w=870&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
          'fund_update_title': '',
          'fund_update_text': '',
          'fund_update_images': <String>[],
        },
        {
          'id': 'media_studio_setup',
          'title': 'Media Studio Setup',
          'summary': 'Podcast and content production equipment',
          'description':
              'Equipping the ministry with high-quality media production capabilities for tracts, audio podcasts, video meetings, and digital evangelism.',
          'goal': 9000000.0,
          'raised': 0.0,
          'currency': 'NGN',
          'status': 'planning',
          'priority': 3,
          'cta_label': 'Donate for this item',
          'image_url':
              'https://images.unsplash.com/photo-1769699167906-a44d5ae50abb?q=80&w=387&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
          'fund_update_title': '',
          'fund_update_text': '',
          'fund_update_images': <String>[],
        },
      ];
}
