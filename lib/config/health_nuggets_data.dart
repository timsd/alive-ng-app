/// Model representing a single daily Seventh-day Adventist health nugget.
class HealthNugget {
  final int day;
  final String category; // NEWSTART pillar
  final String title;
  final String nugget;
  final String speaker;
  final String scripture;

  const HealthNugget({
    required this.day,
    required this.category,
    required this.title,
    required this.nugget,
    required this.speaker,
    required this.scripture,
  });
}

/// 365-day rotating library of Seventh-day Adventist health nuggets
/// grounded in NEWSTART principles and teachings from global Adventist
/// preachers, physicians, and health pioneers.
class HealthNuggetsData {
  HealthNuggetsData._();

  static const List<String> categories = [
    'All',
    'Nutrition',
    'Exercise',
    'Water',
    'Sunlight',
    'Temperance',
    'Air',
    'Rest',
    'Trust in God',
  ];

  /// Returns the 1-based day of the year (1..366) for [date].
  static int dayOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1;
  }

  /// Returns the nugget scheduled for [date], cycling cleanly through all 365 days.
  static HealthNugget nuggetForDate(DateTime date) {
    final index = (dayOfYear(date) - 1) % allNuggets.length;
    return allNuggets[index];
  }

  /// Returns the nugget for a 1-based [day] (1..365).
  static HealthNugget nuggetForDay(int day) {
    final index = ((day - 1) % allNuggets.length + allNuggets.length) %
        allNuggets.length;
    return allNuggets[index];
  }

  static const List<HealthNugget> allNuggets = [
    HealthNugget(
      day: 1,
      category: 'Trust in God',
      title: 'The Temple of the Living God',
      nugget:
          'Your body is not your own—it is the dwelling place of the Holy Spirit. Every daily habit of eating, resting, and moving is an act of worship.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '1 Corinthians 6:19-20',
    ),
    HealthNugget(
      day: 2,
      category: 'Nutrition',
      title: 'Eat as Close to Nature as Possible',
      nugget:
          'Grains, fruits, nuts, and vegetables, prepared in a simple and natural way, are the most healthful and nourishing diet chosen for us by the Creator.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 3,
      category: 'Water',
      title: 'Pure Water Inside and Out',
      nugget:
          'In health and in sickness, pure water is one of heaven\'s choicest blessings. Drink two glasses upon waking to flush overnight metabolic waste.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'Isaiah 44:3',
    ),
    HealthNugget(
      day: 4,
      category: 'Exercise',
      title: 'The Power of a Brisk Daily Walk',
      nugget:
          'Walking outdoors in fresh air is one of the finest medicines known to humanity. Thirty minutes of brisk walking daily lowers blood pressure and clears the mind.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: '3 John 1:2',
    ),
    HealthNugget(
      day: 5,
      category: 'Sunlight',
      title: 'Sunlight Builds Immunity and Joy',
      nugget:
          'Fifteen to twenty minutes of morning sunlight activates vitamin D synthesis, strengthens bones, and naturally elevates brain serotonin.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Malachi 4:2',
    ),
    HealthNugget(
      day: 6,
      category: 'Temperance',
      title: 'True Temperance Defined',
      nugget:
          'True temperance teaches us to dispense entirely with everything hurtful and to use judiciously that which is healthful.',
      speaker: 'Inspired by Ellen G. White — Patriarchs and Prophets',
      scripture: '1 Corinthians 9:25',
    ),
    HealthNugget(
      day: 7,
      category: 'Rest',
      title: 'Sabbath: God\'s Weekly Sanctuary in Time',
      nugget:
          'God built a weekly rhythm of restoration into creation. Stepping away from secular labor on the Sabbath lowers stress hormones and renews the soul.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Exodus 20:8-11',
    ),
    HealthNugget(
      day: 8,
      category: 'Air',
      title: 'Deep Diaphragmatic Breathing',
      nugget:
          'Most people use only the top third of their lungs. Slow, deep abdominal breathing in clean outdoor air oxygenates the blood and calms the nervous system.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Genesis 2:7',
    ),
    HealthNugget(
      day: 9,
      category: 'Nutrition',
      title: 'Daniel\'s Ten-Day Proof',
      nugget:
          'Daniel purposed in his heart not to defile himself. A simple, unrefined plant-based diet produced clearer minds and stronger bodies in just ten days.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Daniel 1:12-15',
    ),
    HealthNugget(
      day: 10,
      category: 'Water',
      title: 'Never Drink Water With Meals',
      nugget:
          'Drinking large amounts of liquid during meals dilutes digestive enzymes and slows gastric emptying. Hydrate well between meals instead.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Proverbs 25:25',
    ),
    HealthNugget(
      day: 11,
      category: 'Trust in God',
      title: 'A Merry Heart Does Good Like a Medicine',
      nugget:
          'Gratitude and joy are not mere emotions—they measurably strengthen immune cells and lower inflammatory markers in the bloodstream.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Proverbs 17:22',
    ),
    HealthNugget(
      day: 12,
      category: 'Nutrition',
      title: 'Eat Breakfast Like a King',
      nugget:
          'A hearty, fiber-rich breakfast stabilizes blood glucose for hours, sharpens mental focus, and prevents late-night overeating.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Ecclesiastes 10:17',
    ),
    HealthNugget(
      day: 13,
      category: 'Rest',
      title: 'The Healing Power of Early Sleep',
      nugget:
          'Two hours of sleep before midnight are worth more to cellular repair and melatonin production than four hours after midnight.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Psalm 127:2',
    ),
    HealthNugget(
      day: 14,
      category: 'Exercise',
      title: 'Motion Is Lotion for the Joints',
      nugget:
          'Joint cartilage has no direct blood supply; it receives nutrients through the compression and release of regular movement.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Isaiah 40:31',
    ),
    HealthNugget(
      day: 15,
      category: 'Temperance',
      title: 'Guard the Mind Against Digital Overload',
      nugget:
          'Temperance applies to our eyes and ears as much as our stomach. Constant screen stimulation fatigues the frontal lobe where moral decisions are made.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Philippians 4:8',
    ),
    HealthNugget(
      day: 16,
      category: 'Nutrition',
      title: 'Chew Your Food Thoroughly',
      nugget:
          'Digestion begins in the mouth. Thorough chewing mixes food with salivary amylase, eases stomach workload, and signals fullness naturally.',
      speaker: 'Hydrotherapy & Sanitarium Principles',
      scripture: '1 Corinthians 10:31',
    ),
    HealthNugget(
      day: 17,
      category: 'Sunlight',
      title: 'Open the Curtains to Sunlight',
      nugget:
          'Sunlight is nature\'s disinfectant. Let direct sunshine into your bedrooms and living spaces daily to destroy mold spores and bacteria.',
      speaker: 'Inspired by Ellen G. White — Counsels on Health',
      scripture: 'Psalm 84:11',
    ),
    HealthNugget(
      day: 18,
      category: 'Air',
      title: 'Sleep With Fresh Ventilation',
      nugget:
          'Stagnant bedroom air deprives the brain of oxygen overnight. Keep a window slightly cracked for gentle cross-ventilation while sleeping.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Job 33:4',
    ),
    HealthNugget(
      day: 19,
      category: 'Trust in God',
      title: 'Forgiveness Frees the Body',
      nugget:
          'Harboring bitterness keeps the sympathetic nervous system locked in fight-or-flight. Forgiveness releases both the soul and the cardiovascular system.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Ephesians 4:32',
    ),
    HealthNugget(
      day: 20,
      category: 'Nutrition',
      title: 'The Longevity Secret of Legumes',
      nugget:
          'Adventist Health Studies show that people who eat beans, lentils, and peas regularly enjoy significantly longer, healthier lives.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Daniel 1:16',
    ),
    HealthNugget(
      day: 21,
      category: 'Water',
      title: 'Contrast Hydrotherapy for Circulation',
      nugget:
          'Alternating warm and cool water in the shower stimulates white blood cell activity, relieves muscle soreness, and invigorates sluggish circulation.',
      speaker: 'Hydrotherapy & Sanitarium Principles',
      scripture: 'John 7:38',
    ),
    HealthNugget(
      day: 22,
      category: 'Nutrition',
      title: 'Five Hours Between Meals',
      nugget:
          'Allow at least five hours between meals with nothing but water in between. The stomach needs rest to complete digestion before receiving new food.',
      speaker: 'Inspired by Ellen G. White — Counsels on Diet and Foods',
      scripture: 'Ecclesiastes 3:1',
    ),
    HealthNugget(
      day: 23,
      category: 'Exercise',
      title: 'Exercise Reverses Insulin Resistance',
      nugget:
          'A 15-minute walk immediately after a meal helps muscles absorb glucose without needing extra insulin, protecting against type 2 diabetes.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Proverbs 31:17',
    ),
    HealthNugget(
      day: 24,
      category: 'Temperance',
      title: 'Avoid Stimulants That Borrow Tomorrow\'s Energy',
      nugget:
          'Caffeine and energy drinks do not create energy—they whip tired nerves into spending reserves. True vitality comes from rest and nourishment.',
      speaker: 'Creation & Health Principles',
      scripture: 'Proverbs 20:1',
    ),
    HealthNugget(
      day: 25,
      category: 'Trust in God',
      title: 'Faith Over Fear in Health Crises',
      nugget:
          'When anxiety rises, prayer shifts the brain from panic to peace. Cast every care upon the Great Physician who knows every cell of your frame.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '1 Peter 5:7',
    ),
    HealthNugget(
      day: 26,
      category: 'Nutrition',
      title: 'A Handful of Nuts Daily',
      nugget:
          'Loma Linda researchers found that eating a small handful of raw nuts five times a week cuts heart disease risk nearly in half.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Genesis 43:11',
    ),
    HealthNugget(
      day: 27,
      category: 'Rest',
      title: 'Light Evening Meals for Deep Sleep',
      nugget:
          'Eating a heavy meal right before bed forces the stomach to work while the brain tries to rest. Finish supper at least three hours before sleep.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 4:8',
    ),
    HealthNugget(
      day: 28,
      category: 'Sunlight',
      title: 'Morning Light Resets Your Biological Clock',
      nugget:
          'Stepping outside into natural daylight within 30 minutes of waking anchors your circadian rhythm and improves nighttime sleep quality.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Psalm 113:3',
    ),
    HealthNugget(
      day: 29,
      category: 'Water',
      title: 'Dehydration Mimics Fatigue and Hunger',
      nugget:
          'Even mild dehydration reduces concentration and triggers false hunger signals. Before reaching for a snack, drink a full glass of clean water.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'John 4:14',
    ),
    HealthNugget(
      day: 30,
      category: 'Air',
      title: 'Nature Walks Clear Brain Fog',
      nugget:
          'Trees release phytoncides and negative ions that refresh the lungs, lower cortisol, and restore mental clarity after hours indoors.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 104:10-14',
    ),
    HealthNugget(
      day: 31,
      category: 'Temperance',
      title: 'Simplicity Over Excess',
      nugget:
          'Too many varieties at a single meal confuse digestion. Two or three simple, wholesome dishes are kinder to the stomach than a banquet.',
      speaker: 'Inspired by Ellen G. White — Counsels on Diet and Foods',
      scripture: 'Proverbs 23:2',
    ),
    HealthNugget(
      day: 32,
      category: 'Nutrition',
      title: 'Whole Grains Over Refined Flour',
      nugget:
          'Refining strips away fiber, B-vitamins, and minerals. Choose whole oats, brown rice, millet, sorghum, and whole-wheat bread for steady energy.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Psalm 81:16',
    ),
    HealthNugget(
      day: 33,
      category: 'Exercise',
      title: 'Strength Training Preserves Independence',
      nugget:
          'Simple resistance exercises—like bodyweight squats, push-ups, or gardening—preserve muscle mass and bone density at every age.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Deuteronomy 33:25',
    ),
    HealthNugget(
      day: 34,
      category: 'Trust in God',
      title: 'Health Message as the Right Arm of the Gospel',
      nugget:
          'Caring for people\'s physical needs opens hearts to spiritual truth. Jesus healed bodies before preaching sermons—medical ministry is His method.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Matthew 9:35',
    ),
    HealthNugget(
      day: 35,
      category: 'Nutrition',
      title: 'Eat the Rainbow Every Day',
      nugget:
          'Deep greens, bright reds, oranges, and purples contain distinct phytochemicals that protect your DNA and fight cellular inflammation.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 104:14',
    ),
    HealthNugget(
      day: 36,
      category: 'Water',
      title: 'Warm Foot Baths for Congestion',
      nugget:
          'A hot foot bath draws excess blood away from a congested head or chest, easing colds, headaches, and sleeplessness naturally.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Psalm 23:2',
    ),
    HealthNugget(
      day: 37,
      category: 'Rest',
      title: 'Micro-Breaks Restore Productivity',
      nugget:
          'Standing up to stretch and rest your eyes for two minutes every hour prevents vascular stiffness and sustains mental sharpness.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Mark 6:31',
    ),
    HealthNugget(
      day: 38,
      category: 'Temperance',
      title: 'Sugar Suppresses Immune Defenses',
      nugget:
          'Refined sugar temporarily impairs white blood cells\' ability to engulf bacteria. Satisfy your sweet tooth with whole, ripe fruits instead.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Proverbs 25:27',
    ),
    HealthNugget(
      day: 39,
      category: 'Sunlight',
      title: 'Sunlight Lowers Blood Pressure',
      nugget:
          'Moderate sun exposure releases nitric oxide from the skin into the bloodstream, gently relaxing blood vessels and lowering blood pressure.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Ecclesiastes 11:7',
    ),
    HealthNugget(
      day: 40,
      category: 'Air',
      title: 'Posture Shapes Lung Capacity',
      nugget:
          'Slouching compresses the diaphragm and shrinks lung volume. Sit and stand tall with shoulders relaxed back to breathe freely.',
      speaker: 'Inspired by Ellen G. White — Education',
      scripture: 'Psalm 139:14',
    ),
    HealthNugget(
      day: 41,
      category: 'Nutrition',
      title: 'Fiber Is the Broom of the Digestive Tract',
      nugget:
          'Dietary fiber—found exclusively in plant foods—feeds beneficial gut bacteria, lowers cholesterol, and prevents colon disease.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 42,
      category: 'Trust in God',
      title: 'Morning Devotion Anchors Emotional Health',
      nugget:
          'Beginning the day with Scripture and prayer before checking notifications calms the amygdala and strengthens resilience against stress.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 5:3',
    ),
    HealthNugget(
      day: 43,
      category: 'Exercise',
      title: 'Gardening: Exercise With Purpose',
      nugget:
          'God placed our first parents in a garden to tend it. Digging, planting, and weeding combine strength, flexibility, sunshine, and fresh air.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'Genesis 2:15',
    ),
    HealthNugget(
      day: 44,
      category: 'Water',
      title: 'Keep Your Urine Pale Straw-Colored',
      nugget:
          'A simple daily check for proper hydration is urine color: pale straw means well-hydrated; dark yellow means drink more water now.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Isaiah 58:11',
    ),
    HealthNugget(
      day: 45,
      category: 'Rest',
      title: 'Darkness Triggers Healing Melatonin',
      nugget:
          'Keep your bedroom dark and free of glowing screens at night. Even dim blue light suppresses melatonin and fragments deep sleep.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 139:12',
    ),
    HealthNugget(
      day: 46,
      category: 'Nutrition',
      title: 'Healthy Fats From Whole Plants',
      nugget:
          'Replace refined oils and animal fats with whole avocados, walnuts, flaxseeds, chia seeds, and olives for heart and brain protection.',
      speaker: 'Creation & Health Principles',
      scripture: 'Deuteronomy 8:8',
    ),
    HealthNugget(
      day: 47,
      category: 'Temperance',
      title: 'Say No to Tobacco and Vaping',
      nugget:
          'Every breath is a gift from God. Avoiding all tobacco, nicotine, and recreational drugs protects the lungs, arteries, and brain.',
      speaker: 'GC Health Ministries Principles',
      scripture: '1 Corinthians 3:16-17',
    ),
    HealthNugget(
      day: 48,
      category: 'Air',
      title: 'Houseplants and Fresh Air Flow',
      nugget:
          'Clean indoor air reduces headaches and fatigue. Open windows daily for 15 minutes to replace stale indoor air with crisp outdoor oxygen.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Psalm 150:6',
    ),
    HealthNugget(
      day: 49,
      category: 'Trust in God',
      title: 'God\'s Laws of Health Are Laws of Love',
      nugget:
          'Every health principle in Scripture and nature is designed by a loving Father to spare us unnecessary suffering and maximize our joy.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Exodus 15:26',
    ),
    HealthNugget(
      day: 50,
      category: 'Nutrition',
      title: 'Cut Back on Excess Salt',
      nugget:
          'High sodium stiffens blood vessels and strains the kidneys. Season meals generously with garlic, ginger, turmeric, basil, and lemon instead.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Colossians 4:6',
    ),
    HealthNugget(
      day: 51,
      category: 'Exercise',
      title: 'Exercise Grows New Brain Cells',
      nugget:
          'Aerobic exercise increases BDNF—a natural growth factor that builds new neurons in the hippocampus and sharpens memory.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Romans 12:1-2',
    ),
    HealthNugget(
      day: 52,
      category: 'Water',
      title: 'Fever Baths and Cool Compresses',
      nugget:
          'Water is nature\'s gentlest temperature regulator. A cool cloth on the forehead and plenty of fluids support the body during fever.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Proverbs 17:22',
    ),
    HealthNugget(
      day: 53,
      category: 'Sunlight',
      title: 'Respect the Midday Sun',
      nugget:
          'Gentle morning or late-afternoon sun nourishes without burning. Avoid harsh midday sunburn while still enjoying daily outdoor light.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 121:6',
    ),
    HealthNugget(
      day: 54,
      category: 'Rest',
      title: 'Consistent Wake Times Heal Insomnia',
      nugget:
          'Waking up at the same hour every morning—even on weekends—trains your brain to fall asleep effortlessly at night.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Psalm 92:1-2',
    ),
    HealthNugget(
      day: 55,
      category: 'Temperance',
      title: 'Alcohol Offers No Safe Dose for the Brain',
      nugget:
          'Modern medical studies confirm what Scripture warned long ago: alcohol damages brain gray matter and raises cancer risk even in small amounts.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Proverbs 23:29-32',
    ),
    HealthNugget(
      day: 56,
      category: 'Nutrition',
      title: 'Local Nigerian Superfoods: Beans & Leafy Greens',
      nugget:
          'Oloyin beans, ugwu, efo, and okra packed with plant protein and iron are affordable, God-given powerhouses for daily vitality.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Psalm 104:14',
    ),
    HealthNugget(
      day: 57,
      category: 'Trust in God',
      title: 'Peace That Guards Heart and Mind',
      nugget:
          'Chronic worry wears out the immune system. Prayerful thanksgiving acts as a garrison guarding both your emotional peace and physical health.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Philippians 4:6-7',
    ),
    HealthNugget(
      day: 58,
      category: 'Exercise',
      title: 'Take the Stairs Today',
      nugget:
          'Small bursts of movement add up. Choosing stairs over elevators and parking farther away strengthens the heart without needing a gym.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: '2 Samuel 22:33',
    ),
    HealthNugget(
      day: 59,
      category: 'Air',
      title: 'Nasal Breathing Filters and Warms Air',
      nugget:
          'Breathe through your nose rather than your mouth. The nasal passages filter dust, humidify air, and produce nitric oxide for lung health.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Genesis 2:7',
    ),
    HealthNugget(
      day: 60,
      category: 'Water',
      title: 'Wash Hands Often With Clean Water',
      nugget:
          'Biblical sanitation laws were centuries ahead of modern medicine. Simple handwashing with soap and clean running water prevents most infections.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Leviticus 15:13',
    ),
    HealthNugget(
      day: 61,
      category: 'Nutrition',
      title: 'Garlic and Ginger: Natural Kitchen Allies',
      nugget:
          'Fresh garlic and ginger support healthy circulation, calm digestive inflammation, and bolster natural immune defenses.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Ezekiel 47:12',
    ),
    HealthNugget(
      day: 62,
      category: 'Rest',
      title: 'Worry-Free Bedtime Routine',
      nugget:
          'Write down tomorrow\'s tasks and pray over them an hour before bed so your mind can enter sleep unburdened.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 3:5',
    ),
    HealthNugget(
      day: 63,
      category: 'Temperance',
      title: 'Stop Eating at 80% Full',
      nugget:
          'Leaving the table slightly light—rather than stuffed—prevents sluggishness, acid reflux, and metabolic strain.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Proverbs 25:16',
    ),
    HealthNugget(
      day: 64,
      category: 'Sunlight',
      title: 'Outdoor Light Combats Seasonal Blues',
      nugget:
          'Bright natural light entering the eyes signals the brain to curb daytime drowsiness and lift depressive moods.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Psalm 27:1',
    ),
    HealthNugget(
      day: 65,
      category: 'Trust in God',
      title: 'Cooperate With the Great Physician',
      nugget:
          'Prayer is not a substitute for obedience to health laws, nor are remedies a substitute for prayer. Faith and lifestyle work hand in hand.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'James 2:17',
    ),
    HealthNugget(
      day: 66,
      category: 'Nutrition',
      title: 'Ground Flaxseed for Heart and Brain',
      nugget:
          'One to two tablespoons of freshly ground flaxseed or chia seed daily supplies plant-based omega-3 fats without mercury or cholesterol.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Genesis 1:11',
    ),
    HealthNugget(
      day: 67,
      category: 'Exercise',
      title: 'Stretch Tight Muscles Daily',
      nugget:
          'Gentle stretching after a warm walk relieves lower-back tension, improves balance, and keeps the body supple.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Hebrews 12:12',
    ),
    HealthNugget(
      day: 68,
      category: 'Water',
      title: 'Warm Lemon Water in the Morning',
      nugget:
          'A glass of warm water with a squeeze of fresh lemon gently stimulates bowel motility and refreshes the palate.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Psalm 107:35',
    ),
    HealthNugget(
      day: 69,
      category: 'Air',
      title: 'Avoid Secondhand Smoke and Fumes',
      nugget:
          'Protect your lungs from indoor cooking smoke, exhaust fumes, and tobacco smoke—clean air is essential for clear blood and bright minds.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Job 33:4',
    ),
    HealthNugget(
      day: 70,
      category: 'Rest',
      title: 'Sabbath Fellowship Heals Loneliness',
      nugget:
          'Loneliness harms health as much as smoking. Gathering with your church family on Sabbath provides belonging, encouragement, and joy.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Hebrews 10:25',
    ),
    HealthNugget(
      day: 71,
      category: 'Nutrition',
      title: 'Cruciferous Vegetables Protect Cells',
      nugget:
          'Cabbage, broccoli, kale, and cauliflower contain sulforaphane, a potent compound that activates the liver\'s natural detox enzymes.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Daniel 1:12',
    ),
    HealthNugget(
      day: 72,
      category: 'Temperance',
      title: 'Fast Occasionally for Digestive Renewal',
      nugget:
          'Skipping an evening meal when feeling sluggish or mildly unwell gives the digestive organs a restorative break.',
      speaker: 'Inspired by Ellen G. White — Counsels on Diet and Foods',
      scripture: 'Matthew 6:17-18',
    ),
    HealthNugget(
      day: 73,
      category: 'Trust in God',
      title: 'Serve Someone Today for Better Health',
      nugget:
          'Doing good to others is the best remedy for self-absorption and gloom. Generous service releases oxytocin and lowers stress.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Acts 20:35',
    ),
    HealthNugget(
      day: 74,
      category: 'Water',
      title: 'Charcoal Poultices for Bites and Swelling',
      nugget:
          'Activated charcoal mixed with flaxseed or water makes a time-tested Adventist natural poultice to draw out toxins from insect bites.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: '2 Kings 20:7',
    ),
    HealthNugget(
      day: 75,
      category: 'Exercise',
      title: 'Walk With a Friend for Accountability',
      nugget:
          'Walking with a spouse, friend, or church member turns exercise into joyful fellowship and doubles your consistency.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Ecclesiastes 4:9',
    ),
    HealthNugget(
      day: 76,
      category: 'Sunlight',
      title: 'Sun-Ripened Foods Carry Nature\'s Energy',
      nugget:
          'Freshly harvested fruits and vegetables absorb solar energy directly. Prioritize fresh, local, in-season produce whenever available.',
      speaker: 'Creation & Health Principles',
      scripture: 'Deuteronomy 33:14',
    ),
    HealthNugget(
      day: 77,
      category: 'Nutrition',
      title: 'Beware of Liquid Calories',
      nugget:
          'Sodas and sweetened juices spike blood sugar rapidly without satisfying hunger. Eat whole fruit so the fiber slows sugar absorption.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Isaiah 55:2',
    ),
    HealthNugget(
      day: 78,
      category: 'Rest',
      title: 'Unplug One Hour Before Sleep',
      nugget:
          'Trade late-night scrolling for calm reading, journaling, or prayer an hour before bed so your nervous system can unwind.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Psalm 46:10',
    ),
    HealthNugget(
      day: 79,
      category: 'Air',
      title: 'Sing Hymns to Strengthen Your Lungs',
      nugget:
          'Heartfelt singing expands lung capacity, regulates breathing rhythm, lowers cortisol, and lifts the spirit in praise.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 95:1',
    ),
    HealthNugget(
      day: 80,
      category: 'Temperance',
      title: 'Dress Comfortably and Healthfully',
      nugget:
          'Restrictive clothing and tight waistbands impede circulation and shallow out breathing. Dress for warmth, modesty, and free movement.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: '1 Timothy 2:9',
    ),
    HealthNugget(
      day: 81,
      category: 'Nutrition',
      title: 'Plant-Based Calcium Sources',
      nugget:
          'Strong bones do not require cow\'s milk. Dark leafy greens, sesame seeds, almonds, okra, and fortified plant milks offer absorbable calcium.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Proverbs 3:8',
    ),
    HealthNugget(
      day: 82,
      category: 'Water',
      title: 'Steam Inhalation for Sinus Relief',
      nugget:
          'Inhaling warm steam with a drop of eucalyptus oil loosens sinus congestion naturally without rebound side effects.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Psalm 147:18',
    ),
    HealthNugget(
      day: 83,
      category: 'Trust in God',
      title: 'Confidence in the Creator\'s Design',
      nugget:
          'Your body is fearfully and wonderfully made with built-in self-healing systems. Remove the hindrances and trust God\'s design.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 139:14',
    ),
    HealthNugget(
      day: 84,
      category: 'Exercise',
      title: 'Balance Exercises Prevent Falls',
      nugget:
          'Practicing standing on one foot safely near a counter for 30 seconds a day sharpens proprioception and protects longevity.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Psalm 18:33',
    ),
    HealthNugget(
      day: 85,
      category: 'Nutrition',
      title: 'Fermented Foods Support Gut Immunity',
      nugget:
          'Nearly 70% of the immune system resides in the gut. Naturally fermented foods like ogi, sauerkraut, and plant yogurt nourish good flora.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: '1 Corinthians 6:19',
    ),
    HealthNugget(
      day: 86,
      category: 'Temperance',
      title: 'Avoid Heavy Spices That Irritate the Stomach',
      nugget:
          'Excessive hot pepper, vinegar, and harsh condiments inflame the gastric lining and numb natural taste buds to simple foods.',
      speaker: 'Inspired by Ellen G. White — Counsels on Diet and Foods',
      scripture: 'Job 6:6',
    ),
    HealthNugget(
      day: 87,
      category: 'Sunlight',
      title: 'Vitamin D Protects Against Respiratory Illness',
      nugget:
          'Optimal vitamin D levels from safe sun exposure dramatically strengthen frontline defenses against seasonal respiratory infections.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 19:4-6',
    ),
    HealthNugget(
      day: 88,
      category: 'Rest',
      title: 'Short Power Naps Refresh Without Grogginess',
      nugget:
          'A 15-to-20-minute afternoon rest restores alertness without disrupting nighttime sleep.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 23:2-3',
    ),
    HealthNugget(
      day: 89,
      category: 'Air',
      title: 'Deep Breaths Before Stressful Conversations',
      nugget:
          'Taking three slow, deep breaths before responding activates the vagus nerve and replaces reactive anger with calm wisdom.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'James 1:19',
    ),
    HealthNugget(
      day: 90,
      category: 'Nutrition',
      title: 'Zero Dietary Cholesterol in Plant Foods',
      nugget:
          'Plants contain zero cholesterol. Shifting toward whole plant foods naturally lowers LDL cholesterol and keeps arteries clear.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 91,
      category: 'Water',
      title: 'Hydrate Before Exercise and After',
      nugget:
          'Drink water 30 minutes before physical activity and replenish steadily afterward so your heart does not have to pump thickened blood.',
      speaker: 'Hydrotherapy & Sanitarium Principles',
      scripture: 'Proverbs 11:25',
    ),
    HealthNugget(
      day: 92,
      category: 'Trust in God',
      title: 'Sabbath Rest Reminds Us Who Sustains Us',
      nugget:
          'Resting on the seventh day declares that our survival depends on God\'s grace, not our frantic overwork.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Genesis 2:2-3',
    ),
    HealthNugget(
      day: 93,
      category: 'Exercise',
      title: 'Consistency Beats Intensity',
      nugget:
          'Moderate daily movement is far safer and more effective than exhausting yourself once a week on Saturday night or Sunday.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Galatians 6:9',
    ),
    HealthNugget(
      day: 94,
      category: 'Nutrition',
      title: 'B12 Awareness on a Plant-Based Diet',
      nugget:
          'On a predominantly or fully plant-based diet, ensure reliable vitamin B12 intake through fortified foods or a simple supplement.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Proverbs 27:23',
    ),
    HealthNugget(
      day: 95,
      category: 'Temperance',
      title: 'Calm Speech Lowers Blood Pressure',
      nugget:
          'A gentle answer turns away wrath—and also prevents adrenaline spikes that strain the heart.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Proverbs 15:1',
    ),
    HealthNugget(
      day: 96,
      category: 'Sunlight',
      title: 'Sunlight Synchronizes Hormone Balance',
      nugget:
          'Daily outdoor light helps regulate cortisol in the morning and melatonin at night, supporting thyroid and metabolic health.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Genesis 1:16',
    ),
    HealthNugget(
      day: 97,
      category: 'Rest',
      title: 'A Cool, Quiet Bedroom Aids Deep Sleep',
      nugget:
          'Your core body temperature drops to initiate sleep. Keep your sleeping space cool, tidy, and ventilated.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Proverbs 3:24',
    ),
    HealthNugget(
      day: 98,
      category: 'Air',
      title: 'Aerobic Movement Trains Oxygen Delivery',
      nugget:
          'Brisk walking or cycling strengthens the heart and diaphragm so every cell receives abundant oxygen with less effort.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: '1 Timothy 4:8',
    ),
    HealthNugget(
      day: 99,
      category: 'Nutrition',
      title: 'Sweet Potatoes: Nature\'s Beta-Carotene Gift',
      nugget:
          'Roasted or boiled sweet potatoes deliver slow-release carbohydrates, potassium, and vitamin A for sharp vision and skin health.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Psalm 145:15-16',
    ),
    HealthNugget(
      day: 100,
      category: 'Trust in God',
      title: 'Celebrate 100 Days of Faithful Stewardship',
      nugget:
          'Small, faithful daily choices compound into lifelong transformation. Keep honoring God in body, mind, and spirit.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Luke 16:10',
    ),
    HealthNugget(
      day: 101,
      category: 'Water',
      title: 'Ice-Cold Drinks Slow Digestion',
      nugget:
          'Room-temperature or warm water is absorbed smoothly, whereas ice-cold drinks chill stomach enzymes and delay digestion.',
      speaker: 'Inspired by Ellen G. White — Counsels on Diet and Foods',
      scripture: 'Proverbs 25:25',
    ),
    HealthNugget(
      day: 102,
      category: 'Exercise',
      title: 'Break Up Sitting Time Every 45 Minutes',
      nugget:
          'Prolonged sitting slows blood flow in the legs. Stand, walk to get water, or stretch for two minutes every 45 minutes of desk work.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Ecclesiastes 11:6',
    ),
    HealthNugget(
      day: 103,
      category: 'Nutrition',
      title: 'Garlic Allicin Needs 10 Minutes to Activate',
      nugget:
          'Crush or chop fresh garlic and let it rest for 10 minutes before cooking so its beneficial allicin compound forms fully.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Numbers 11:5',
    ),
    HealthNugget(
      day: 104,
      category: 'Temperance',
      title: 'Contentment Curbs Stress Eating',
      nugget:
          'Often we eat not from physical hunger, but from boredom or stress. Pause to pray and ask what your soul truly needs.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '1 Timothy 6:6',
    ),
    HealthNugget(
      day: 105,
      category: 'Rest',
      title: 'Mental Rest Requires Unfinished-Task Boundaries',
      nugget:
          'Set a clear evening stop time for work emails and chores so your brain knows when the workday has ended.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 127:2',
    ),
    HealthNugget(
      day: 106,
      category: 'Sunlight',
      title: 'Expose Arms and Face Without Sunscreen Briefly',
      nugget:
          'Ten to fifteen minutes of gentle morning sun on arms and face lets your skin synthesize vitamin D naturally before seeking shade.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Malachi 4:2',
    ),
    HealthNugget(
      day: 107,
      category: 'Air',
      title: 'Clean Bedding Improves Night Breathing',
      nugget:
          'Sun-dry pillows and wash sheets regularly in hot water to reduce dust mites and keep nighttime airways clear.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'Psalm 51:7',
    ),
    HealthNugget(
      day: 108,
      category: 'Nutrition',
      title: 'Oats Lower LDL Cholesterol Naturally',
      nugget:
          'The soluble beta-glucan fiber in whole rolled oats binds excess cholesterol in the digestive tract and sweeps it out.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 109,
      category: 'Trust in God',
      title: 'Hope Is an Anchor for Physical Recovery',
      nugget:
          'Patients anchored in hopeful faith recover faster and maintain healthier habits because they believe their life has eternal purpose.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Hebrews 6:19',
    ),
    HealthNugget(
      day: 110,
      category: 'Water',
      title: 'Fomentations Ease Muscle Spasms',
      nugget:
          'Moist heat (hot fomentation) followed by a brief cool wipe relaxes deep muscle spasms and boosts local healing blood flow.',
      speaker: 'Hydrotherapy & Sanitarium Principles',
      scripture: 'Isaiah 1:6',
    ),
    HealthNugget(
      day: 111,
      category: 'Exercise',
      title: 'Swimming: Gentle Full-Body Conditioning',
      nugget:
          'Water supports body weight while providing resistance in every direction, making swimming ideal for joint-friendly fitness.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Psalm 93:4',
    ),
    HealthNugget(
      day: 112,
      category: 'Nutrition',
      title: 'Turmeric + Black Pepper Boosts Absorption',
      nugget:
          'Pairing turmeric with a pinch of black pepper increases curcumin absorption dramatically, offering natural anti-inflammatory support.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Ezekiel 47:12',
    ),
    HealthNugget(
      day: 113,
      category: 'Temperance',
      title: 'Avoid Snacking Between Meals',
      nugget:
          'Constant grazing keeps insulin elevated all day and prevents the migrating motor complex from sweeping the small intestine clean.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Ecclesiastes 3:1',
    ),
    HealthNugget(
      day: 114,
      category: 'Rest',
      title: 'Brain Cleaning Happens During Deep Sleep',
      nugget:
          'During deep sleep, the brain\'s glymphatic system flushes out toxic proteins accumulated during waking hours.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Jeremiah 31:25-26',
    ),
    HealthNugget(
      day: 115,
      category: 'Air',
      title: 'Outdoor Exercise Doubles Mood Benefits',
      nugget:
          'Exercising in green outdoor spaces reduces tension and boosts energy more effectively than identical workouts indoors.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 23:2',
    ),
    HealthNugget(
      day: 116,
      category: 'Nutrition',
      title: 'Avoid Ultra-Processed Meats and Additives',
      nugget:
          'Processed meats and chemical preservatives carry the highest cardiovascular and cancer risks. Choose fresh, whole plant proteins.',
      speaker: 'Creation & Health Principles',
      scripture: 'Leviticus 11:44',
    ),
    HealthNugget(
      day: 117,
      category: 'Trust in God',
      title: 'Gratitude Journal Before Bed',
      nugget:
          'Writing down three blessings each evening trains the brain to scan for God\'s goodness instead of rehearsing tomorrow\'s fears.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '1 Thessalonians 5:18',
    ),
    HealthNugget(
      day: 118,
      category: 'Water',
      title: 'Drink Water Before Feeling Thirsty',
      nugget:
          'Thirst is a late signal—by the time your mouth feels dry, cellular hydration has already dropped. Sip steadily throughout the day.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Revelation 22:17',
    ),
    HealthNugget(
      day: 119,
      category: 'Sunlight',
      title: 'Eye Health Needs Natural Distance Viewing',
      nugget:
          'Looking out at distant trees or horizons in natural daylight relaxes eye focusing muscles strained by close-up phone screens.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Ecclesiastes 11:7',
    ),
    HealthNugget(
      day: 120,
      category: 'Exercise',
      title: 'Core Strength Protects Your Spine',
      nugget:
          'Simple daily planks and back extensions stabilize the spine, prevent back pain, and support upright posture.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 18:32',
    ),
    HealthNugget(
      day: 121,
      category: 'Nutrition',
      title: 'Eat Fruits Separately or First',
      nugget:
          'Fresh fruits digest quickly in the stomach; eating them at the start of a meal or as a simple meal prevents fermentation.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Song of Solomon 2:3',
    ),
    HealthNugget(
      day: 122,
      category: 'Temperance',
      title: 'Keep Your Temper by Guarding Your Sleep',
      nugget:
          'Sleep deprivation lowers self-control and magnifies irritability. Getting full rest is a spiritual safeguard for kindness.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'Ephesians 4:26',
    ),
    HealthNugget(
      day: 123,
      category: 'Rest',
      title: 'Take a Weekly Break From News Cycles',
      nugget:
          'Constant alarming headlines keep stress hormones elevated. Let Sabbath be a sanctuary from worldly anxiety and bad news.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Isaiah 26:3',
    ),
    HealthNugget(
      day: 124,
      category: 'Air',
      title: 'Laugh Often to Ventilate the Lungs',
      nugget:
          'Hearty laughter expels stale residual air from the lungs, boosts oxygen intake, and releases natural pain-relieving endorphins.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 126:2',
    ),
    HealthNugget(
      day: 125,
      category: 'Nutrition',
      title: 'Seeds: Tiny Packages of Minerals',
      nugget:
          'Pumpkin, sunflower, and sesame seeds are rich in zinc, magnesium, and iron—essential for immune resilience and energy.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 126,
      category: 'Trust in God',
      title: 'Trust God With What You Cannot Control',
      nugget:
          'Do your faithful part with NEWSTART habits, then surrender outcomes to God. Peace of conscience is stronger than any tonic.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Proverbs 3:5-6',
    ),
    HealthNugget(
      day: 127,
      category: 'Water',
      title: 'Saltwater Gargle for Sore Throats',
      nugget:
          'Gargling warm salted water draws fluid out of swollen throat tissues and washes away irritants safely.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Job 6:6',
    ),
    HealthNugget(
      day: 128,
      category: 'Exercise',
      title: 'Post-Meal Strolls Aid Digestion',
      nugget:
          'Instead of lying down right after eating, take a calm 10-minute stroll to assist gastric motility and prevent acid reflux.',
      speaker: 'Inspired by Ellen G. White — Counsels on Health',
      scripture: 'Psalm 128:1',
    ),
    HealthNugget(
      day: 129,
      category: 'Nutrition',
      title: 'Berries Protect Memory and Blood Vessels',
      nugget:
          'Blueberries, blackberries, and hibiscus (zobo without excess sugar) pack anthocyanins that protect brain neurons from oxidative stress.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Psalm 104:15',
    ),
    HealthNugget(
      day: 130,
      category: 'Temperance',
      title: 'Moderation Even in Good Work',
      nugget:
          'Even ministry and noble labor require boundaries. Overwork without rest is intemperance that shortens your years of service.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Mark 6:31',
    ),
    HealthNugget(
      day: 131,
      category: 'Sunlight',
      title: 'Sunlight Destroys Household Pathogens',
      nugget:
          'Air out blankets, mats, and shoes in direct sunshine weekly—ultraviolet light naturally sanitizes fabrics.',
      speaker: 'Hydrotherapy & Sanitarium Principles',
      scripture: 'Psalm 19:6',
    ),
    HealthNugget(
      day: 132,
      category: 'Rest',
      title: 'Aim for Seven to Eight Hours Nightly',
      nugget:
          'Adults consistently sleeping 7 to 8 hours show lower rates of hypertension, obesity, and cognitive decline.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Psalm 4:8',
    ),
    HealthNugget(
      day: 133,
      category: 'Air',
      title: 'Avoid Synthetic Air Fresheners',
      nugget:
          'Chemical sprays mask odors while adding volatile compounds to indoor air. Choose open windows and clean surfaces instead.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Psalm 150:6',
    ),
    HealthNugget(
      day: 134,
      category: 'Nutrition',
      title: 'Plantain & Beans: Balanced Local Nutrition',
      nugget:
          'Boiled or baked ripe plantain paired with seasoned beans and leafy greens gives slow energy, potassium, and complete amino acids.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Psalm 145:16',
    ),
    HealthNugget(
      day: 135,
      category: 'Trust in God',
      title: 'Pray Before Every Meal With Gratitude',
      nugget:
          'Pausing to thank God before eating shifts the nervous system into "rest and digest" mode, improving enzyme secretion.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '1 Timothy 4:4-5',
    ),
    HealthNugget(
      day: 136,
      category: 'Water',
      title: 'Warm Herbal Teas Without Caffeine',
      nugget:
          'Chamomile, peppermint, ginger, and hibiscus teas hydrate and soothe digestion without the adrenal jolt of coffee or black tea.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Psalm 104:14',
    ),
    HealthNugget(
      day: 137,
      category: 'Exercise',
      title: 'Exercise Is Nature\'s Antidepressant',
      nugget:
          'Regular brisk aerobic exercise rivals medication for mild-to-moderate depression while strengthening the heart and sleep.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Nehemiah 8:10',
    ),
    HealthNugget(
      day: 138,
      category: 'Nutrition',
      title: 'Read Ingredient Labels Carefully',
      nugget:
          'If a packaged food has a long list of chemical names and added sugars, leave it on the shelf and choose whole ingredients.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Isaiah 55:2',
    ),
    HealthNugget(
      day: 139,
      category: 'Temperance',
      title: 'Avoid Eating Between Anxiety Triggers',
      nugget:
          'When stressed, take a brisk 5-minute walk or drink water instead of reaching for comfort sweets.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Philippians 4:13',
    ),
    HealthNugget(
      day: 140,
      category: 'Sunlight',
      title: 'Morning Walk Beats Sunglasses Early',
      nugget:
          'In gentle early-morning light, letting natural daylight reach your eyes (without staring at the sun) cues healthy circadian hormones.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Psalm 113:3',
    ),
    HealthNugget(
      day: 141,
      category: 'Rest',
      title: 'Protect the Sabbath Hours From Friday Dusk',
      nugget:
          'Preparing meals and tidying the home before Friday sunset lets you enter Sabbath rest peacefully without last-minute rush.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Luke 23:54',
    ),
    HealthNugget(
      day: 142,
      category: 'Air',
      title: 'Box Breathing Calms Acute Anxiety',
      nugget:
          'Inhale for 4 seconds, hold 4, exhale 4, pause 4. Two minutes of calm breathing steadies heart rate and clears panic.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'John 14:27',
    ),
    HealthNugget(
      day: 143,
      category: 'Nutrition',
      title: 'Don\'t Fry What You Can Steam or Bake',
      nugget:
          'Deep frying creates oxidized fats and inflammatory compounds. Steaming, boiling, roasting, and baking preserve nutrients cleanly.',
      speaker: 'Creation & Health Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 144,
      category: 'Trust in God',
      title: 'Community Prayer Multiplies Resilience',
      nugget:
          'Sharing burdens with trusted believers lowers feelings of isolation and strengthens emotional endurance.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Galatians 6:2',
    ),
    HealthNugget(
      day: 145,
      category: 'Water',
      title: 'Cold Compress for Acute Sprains',
      nugget:
          'In the first 24 hours after a minor sprain, resting, elevating, and applying a cool damp compress limits swelling.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Psalm 147:3',
    ),
    HealthNugget(
      day: 146,
      category: 'Exercise',
      title: 'Build Endurance Gradually',
      nugget:
          'Start with 10 minutes a day if you are new to exercise, adding 5 minutes each week until 30–45 minutes feels natural.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Zechariah 4:10',
    ),
    HealthNugget(
      day: 147,
      category: 'Nutrition',
      title: 'Mushrooms Support Immune Surveillance',
      nugget:
          'Cooked mushrooms supply beta-glucans and ergothioneine, natural compounds that help white blood cells stay vigilant.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 104:24',
    ),
    HealthNugget(
      day: 148,
      category: 'Temperance',
      title: 'Keep Caffeine Out of Children\'s Drinks',
      nugget:
          'Developing brains need steady sleep and calm focus—avoid sodas, energy drinks, and caffeinated beverages for children and teens.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Proverbs 22:6',
    ),
    HealthNugget(
      day: 149,
      category: 'Sunlight',
      title: 'Sunlight Strengthens Muscle Function',
      nugget:
          'Adequate vitamin D from regular sunlight improves muscle strength, balance, and recovery after physical work.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Ecclesiastes 11:7',
    ),
    HealthNugget(
      day: 150,
      category: 'Rest',
      title: 'Avoid Heavy Debates Before Bedtime',
      nugget:
          'Resolve conflicts kindly before nightfall so anger does not keep adrenaline pumping into your sleep hours.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Ephesians 4:26',
    ),
    HealthNugget(
      day: 151,
      category: 'Air',
      title: 'Stand and Stretch Your Ribcage',
      nugget:
          'Reaching both arms overhead while taking a deep breath opens the intercostal muscles and refreshes sluggish afternoon energy.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Job 33:4',
    ),
    HealthNugget(
      day: 152,
      category: 'Nutrition',
      title: 'Dates and Raisins: Whole Natural Sweetness',
      nugget:
          'Use blended dates or ripe bananas in porridge and baking instead of white refined sugar to retain fiber and potassium.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Psalm 92:12',
    ),
    HealthNugget(
      day: 153,
      category: 'Trust in God',
      title: 'God\'s Promise of Renewed Strength',
      nugget:
          'Those who wait upon the Lord renew their strength—spiritual trust sustains physical perseverance when life feels heavy.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Isaiah 40:31',
    ),
    HealthNugget(
      day: 154,
      category: 'Water',
      title: 'Hydration Lubricates Joints and Discs',
      nugget:
          'Spinal discs are largely water. Consistent daily hydration keeps cushions resilient and reduces stiffness.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Isaiah 58:11',
    ),
    HealthNugget(
      day: 155,
      category: 'Exercise',
      title: 'Active Chores Count as Real Movement',
      nugget:
          'Sweeping, mopping, carrying groceries, and walking to the market all burn calories and keep metabolism responsive.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Colossians 3:23',
    ),
    HealthNugget(
      day: 156,
      category: 'Nutrition',
      title: 'Avoid Reheated Burnt Cooking Oils',
      nugget:
          'Reusing cooking oil repeatedly creates free radicals that damage blood vessel linings. Cook fresh with minimal water or steam.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: '1 Corinthians 6:19',
    ),
    HealthNugget(
      day: 157,
      category: 'Temperance',
      title: 'Regular Meal Times Train Digestion',
      nugget:
          'Eating at predictable hours each day prepares stomach acid and digestive enzymes right on schedule, preventing indigestion.',
      speaker: 'Inspired by Ellen G. White — Counsels on Diet and Foods',
      scripture: 'Ecclesiastes 3:1',
    ),
    HealthNugget(
      day: 158,
      category: 'Rest',
      title: 'Silence Is Medicine for an Overstimulated Brain',
      nugget:
          'Spend 15 quiet minutes daily without podcasts, music, or screens so your brain can consolidate memory and hear God\'s still small voice.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '1 Kings 19:12',
    ),
    HealthNugget(
      day: 159,
      category: 'Sunlight',
      title: 'Afternoon Sun After Work Refreshes',
      nugget:
          'Stepping outside for 15 minutes in late afternoon light eases transition from work stress to peaceful evening family time.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 104:19',
    ),
    HealthNugget(
      day: 160,
      category: 'Air',
      title: 'Clean Kitchen Ventilation Matters',
      nugget:
          'Always vent steam and cooking smoke outdoors so fine particles do not irritate sensitive bronchial passages.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Genesis 2:7',
    ),
    HealthNugget(
      day: 161,
      category: 'Nutrition',
      title: 'Potassium-Rich Foods Balance Blood Pressure',
      nugget:
          'Bananas, avocados, spinach, sweet potatoes, and beans supply potassium that naturally counterbalances sodium and relaxes arteries.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 162,
      category: 'Trust in God',
      title: 'Stewardship Includes Preventive Care',
      nugget:
          'Routine blood pressure and blood sugar checks are wise stewardship—catch imbalances early and address them with lifestyle reform.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Proverbs 22:3',
    ),
    HealthNugget(
      day: 163,
      category: 'Water',
      title: 'Warm Bath Before Bed Aids Sleep',
      nugget:
          'A warm bath an hour before bedtime relaxes tight muscles; as your body cools afterward, sleepiness follows naturally.',
      speaker: 'Hydrotherapy & Sanitarium Principles',
      scripture: 'Psalm 4:8',
    ),
    HealthNugget(
      day: 164,
      category: 'Exercise',
      title: 'Involve the Whole Family in Weekend Hikes',
      nugget:
          'Nature walks on Sabbath afternoon build family bonds, spark wonder at God\'s creation, and keep everyone active.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 19:1',
    ),
    HealthNugget(
      day: 165,
      category: 'Nutrition',
      title: 'Soak Beans Well Before Cooking',
      nugget:
          'Soaking dried beans overnight and discarding the soaking water reduces gas-forming oligosaccharides and improves mineral absorption.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Daniel 1:12',
    ),
    HealthNugget(
      day: 166,
      category: 'Temperance',
      title: 'Eat Slowly and Without Distraction',
      nugget:
          'Put down your phone during meals. Mindful eating lets you enjoy flavor, chew well, and notice natural fullness cues.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Ecclesiastes 2:24',
    ),
    HealthNugget(
      day: 167,
      category: 'Rest',
      title: 'Don\'t Overcommit Your Calendar',
      nugget:
          'Saying a gracious "no" to non-essential demands protects margin for sleep, family worship, and genuine service.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Matthew 11:28-30',
    ),
    HealthNugget(
      day: 168,
      category: 'Air',
      title: 'Walk Away From Traffic Exhaust When Exercising',
      nugget:
          'Choose quiet side streets, parks, or school tracks for your morning walk so you breathe cleaner air into deep lungs.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 23:2',
    ),
    HealthNugget(
      day: 169,
      category: 'Nutrition',
      title: 'Tomatoes and Lycopene Benefit Heart & Prostate',
      nugget:
          'Cooked tomatoes concentrate lycopene, a powerful antioxidant linked to healthier blood vessels and cellular protection.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 170,
      category: 'Trust in God',
      title: 'Kindness Is Contagious Wellness',
      nugget:
          'Offering a sincere word of encouragement lowers both the giver\'s and receiver\'s stress levels.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Proverbs 16:24',
    ),
    HealthNugget(
      day: 171,
      category: 'Water',
      title: 'Keep a Reusable Water Bottle Visible',
      nugget:
          'Keeping clean water right on your desk or in your bag makes reaching 8 glasses a day effortless.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'John 7:37',
    ),
    HealthNugget(
      day: 172,
      category: 'Sunlight',
      title: 'Natural Light Boosts Classroom and Work Focus',
      nugget:
          'Position desks near windows when possible; natural daylight reduces eye strain and increases daytime alertness.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 36:9',
    ),
    HealthNugget(
      day: 173,
      category: 'Exercise',
      title: 'Calf Raises Improve Leg Circulation',
      nugget:
          'Your calf muscles act as a "second heart" pumping blood back upward. Do 20 slow calf raises while brushing your teeth.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Isaiah 35:3',
    ),
    HealthNugget(
      day: 174,
      category: 'Nutrition',
      title: 'Make Half Your Plate Vegetables',
      nugget:
          'Filling half your plate with steamed or fresh vegetables automatically crowds out excess calories while flooding cells with micronutrients.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Daniel 1:15',
    ),
    HealthNugget(
      day: 175,
      category: 'Temperance',
      title: 'Choose Water Over Energy Drinks During Study',
      nugget:
          'Students who hydrate with water and sleep well retain far more information than those cramming on energy drinks.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Proverbs 2:6',
    ),
    HealthNugget(
      day: 176,
      category: 'Rest',
      title: 'Forgive Yourself and Rest in Grace',
      nugget:
          'Guilt over past mistakes steals sleep and peace. Bring every failure to Jesus, receive full pardon, and rest peacefully.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '1 John 1:9',
    ),
    HealthNugget(
      day: 177,
      category: 'Air',
      title: 'Exhale Completely to Refresh Oxygen',
      nugget:
          'A full, slow exhale empties stale carbon dioxide from the lower lungs, allowing the next inhale to draw fresh air deeply.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Job 33:4',
    ),
    HealthNugget(
      day: 178,
      category: 'Nutrition',
      title: 'Millet and Sorghum: Resilient Whole Grains',
      nugget:
          'Traditional African grains like millet and guinea corn are naturally gluten-free, mineral-rich, and gentle on blood sugar.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Ezekiel 4:9',
    ),
    HealthNugget(
      day: 179,
      category: 'Trust in God',
      title: 'Worship Resets Perspective',
      nugget:
          'Singing praises and reading the Psalms lifts our eyes above temporary worries to the faithfulness of an unchanging God.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 103:1-5',
    ),
    HealthNugget(
      day: 180,
      category: 'Water',
      title: 'Drink Water After Waking Before Coffee or Tea',
      nugget:
          'Rehydrating with plain water first thing restores overnight fluid loss and wakes up the brain naturally without stimulants.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 63:1',
    ),
    HealthNugget(
      day: 181,
      category: 'Exercise',
      title: 'Midyear Check: How Active Is Your Week?',
      nugget:
          'Aim for at least 150 minutes of moderate movement per week—just 25 minutes a day six days a week transforms heart health.',
      speaker: 'GC Health Ministries Principles',
      scripture: '1 Corinthians 9:24',
    ),
    HealthNugget(
      day: 182,
      category: 'Nutrition',
      title: 'Avoid Heavy Cheese and Greasy Pastries',
      nugget:
          'Saturated fat and refined flour clog arteries and promote insulin resistance. Choose nut-based spreads and whole-grain breads.',
      speaker: 'Creation & Health Principles',
      scripture: 'Isaiah 55:2',
    ),
    HealthNugget(
      day: 183,
      category: 'Temperance',
      title: 'Guard Against Overeating on Festive Days',
      nugget:
          'Fellowship meals are for joy, not stomach overload. Sample thoughtfully and savor conversation more than second helpings.',
      speaker: 'Inspired by Ellen G. White — Counsels on Diet and Foods',
      scripture: 'Proverbs 23:1-3',
    ),
    HealthNugget(
      day: 184,
      category: 'Sunlight',
      title: 'Sunlight Helps Regulate Healthy Mood',
      nugget:
          'Even on cloudy days, outdoor light is far brighter than indoor bulbs—step outside for 15 minutes to brighten your outlook.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Psalm 97:11',
    ),
    HealthNugget(
      day: 185,
      category: 'Rest',
      title: 'Avoid Caffeine Altogether for Deeper Sleep',
      nugget:
          'Even morning caffeine lingers in the bloodstream for hours and reduces deep restorative sleep architecture.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Psalm 127:2',
    ),
    HealthNugget(
      day: 186,
      category: 'Air',
      title: 'Keep Dust Down With Damp Cloths',
      nugget:
          'Wiping surfaces with a damp cloth traps dust instead of tossing allergens into the air you breathe.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Psalm 150:6',
    ),
    HealthNugget(
      day: 187,
      category: 'Nutrition',
      title: 'Lentils Cook Fast Without Overnight Soaking',
      nugget:
          'Red and brown lentils cook in 20 minutes, pack folate and iron, and make hearty stews that stabilize energy all afternoon.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Genesis 25:34',
    ),
    HealthNugget(
      day: 188,
      category: 'Trust in God',
      title: 'Sabbath Peace Is a Foretaste of Heaven',
      nugget:
          'Every seventh day, lay down earthly anxieties and remember the Creator who restores all things.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Isaiah 58:13-14',
    ),
    HealthNugget(
      day: 189,
      category: 'Water',
      title: 'Warm Wet Socks Remedy for Head Colds',
      nugget:
          'Wearing damp cool cotton socks covered by dry wool socks overnight gently boosts foot circulation and relieves nasal congestion.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'John 7:38',
    ),
    HealthNugget(
      day: 190,
      category: 'Exercise',
      title: 'Protect Your Knees With Strong Quads',
      nugget:
          'Wall sits and gentle step-ups strengthen thigh muscles that absorb shock and protect knee cartilage.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Hebrews 12:12-13',
    ),
    HealthNugget(
      day: 191,
      category: 'Nutrition',
      title: 'Eat Raw Vegetables Daily for Enzymes',
      nugget:
          'Crisp salads of cucumber, carrot, cabbage, and tomatoes add natural crunch, hydration, and heat-sensitive vitamins like vitamin C.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 192,
      category: 'Temperance',
      title: 'Practice Digital Sabbath Hours',
      nugget:
          'Turning off social media notifications for a full day each week restores attention span and deepens real-life relationships.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 46:10',
    ),
    HealthNugget(
      day: 193,
      category: 'Rest',
      title: 'Listen to Your Body\'s Fatigue Signals',
      nugget:
          'Pushing past exhaustion with stimulants leads to burnout. Respect tiredness as God\'s built-in dashboard warning light.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Exodus 33:14',
    ),
    HealthNugget(
      day: 194,
      category: 'Sunlight',
      title: 'Morning Sun Aids Calcium Absorption',
      nugget:
          'Vitamin D activated by sunlight is the key that unlocks calcium absorption in the gut—both sun and greens work together.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Malachi 4:2',
    ),
    HealthNugget(
      day: 195,
      category: 'Air',
      title: 'Avoid Mould in Damp Corners',
      nugget:
          'Fix leaks promptly and let sunlight and airflow dry damp bathrooms so airborne mold spores never trigger asthma or fatigue.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Leviticus 14:40',
    ),
    HealthNugget(
      day: 196,
      category: 'Nutrition',
      title: 'Almonds and Groundnuts in Moderation',
      nugget:
          'Roast nuts lightly without excess salt or oil. A small palmful satisfies hunger with healthy fats, vitamin E, and protein.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Genesis 43:11',
    ),
    HealthNugget(
      day: 197,
      category: 'Trust in God',
      title: 'Contentment Guards the Cardiovascular System',
      nugget:
          'Envy and comparison breed chronic stress; contentment in Christ brings restful sleep and steady peace.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Proverbs 14:30',
    ),
    HealthNugget(
      day: 198,
      category: 'Water',
      title: 'Filter or Boil Questionable Water',
      nugget:
          'Clean water is foundational to health. Always ensure drinking water is properly filtered or boiled when away from trusted sources.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: '2 Kings 2:21',
    ),
    HealthNugget(
      day: 199,
      category: 'Exercise',
      title: 'Walk Faster for Extra Heart Protection',
      nugget:
          'Adding short 1-minute brisk intervals into your regular walk boosts cardiovascular fitness without straining joints.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Isaiah 40:31',
    ),
    HealthNugget(
      day: 200,
      category: 'Nutrition',
      title: '200 Days of Living Whole!',
      nugget:
          'Health is not perfection in one meal—it is the faithful direction of your daily table toward simple, nourishing plant foods.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: '3 John 1:2',
    ),
    HealthNugget(
      day: 201,
      category: 'Temperance',
      title: 'Avoid Very Hot or Very Cold Foods',
      nugget:
          'Eating piping-hot foods or ice-cold desserts shocks delicate oral and gastric tissues. Enjoy foods comfortably warm or cool.',
      speaker: 'Inspired by Ellen G. White — Counsels on Diet and Foods',
      scripture: '1 Corinthians 9:25',
    ),
    HealthNugget(
      day: 202,
      category: 'Rest',
      title: 'Keep Work Devices Out of the Bedroom',
      nugget:
          'Associate your bed exclusively with rest and peace—not spreadsheets, alerts, or late-night debates.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 4:8',
    ),
    HealthNugget(
      day: 203,
      category: 'Sunlight',
      title: 'Protect Eyes With Wide-Brimmed Hats Outdoors',
      nugget:
          'Under intense tropical midday sun, a simple brimmed hat shades eyes and face while keeping you cool outdoors.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 121:5-6',
    ),
    HealthNugget(
      day: 204,
      category: 'Air',
      title: 'Breathe Calmly Through Traffic Delays',
      nugget:
          'You cannot speed up traffic, but deep rhythmic breathing keeps your blood pressure steady and your spirit patient.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'James 1:4',
    ),
    HealthNugget(
      day: 205,
      category: 'Nutrition',
      title: 'Avocado: Heart-Healthy Butter Alternative',
      nugget:
          'Mashed ripe avocado with a pinch of lemon and garlic replaces dairy butter on bread with zero cholesterol and rich potassium.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Deuteronomy 8:8',
    ),
    HealthNugget(
      day: 206,
      category: 'Trust in God',
      title: 'God Values Your Body and Soul Together',
      nugget:
          'In Scripture, humans are a unified whole—caring for physical health honors the Creator who formed us from the dust and breathed life.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '1 Thessalonians 5:23',
    ),
    HealthNugget(
      day: 207,
      category: 'Water',
      title: 'Rinse Fresh Produce Under Running Water',
      nugget:
          'Washing fruits and leafy greens thoroughly in clean water removes soil bacteria and surface residues safely.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Psalm 24:3-4',
    ),
    HealthNugget(
      day: 208,
      category: 'Exercise',
      title: 'Shoulder Rolls Relieve Desk Tension',
      nugget:
          'Roll your shoulders slowly backward ten times every hour to release neck stiffness and invite deeper breathing.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Matthew 11:29',
    ),
    HealthNugget(
      day: 209,
      category: 'Nutrition',
      title: 'Avoid Hydrogenated Trans Fats Completely',
      nugget:
          'Partially hydrogenated oils in cheap margarines and commercial snacks stiffen cell membranes. Read labels and skip them.',
      speaker: 'Creation & Health Principles',
      scripture: '1 Corinthians 6:19',
    ),
    HealthNugget(
      day: 210,
      category: 'Temperance',
      title: 'Self-Control Begins With Small Choices',
      nugget:
          'Saying no to an unnecessary second dessert strengthens the brain\'s prefrontal cortex for every moral choice.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Galatians 5:22-23',
    ),
    HealthNugget(
      day: 211,
      category: 'Rest',
      title: 'Stretch Gently Before Climbing Into Bed',
      nugget:
          'Three minutes of gentle calf and back stretches signals muscles to release the day\'s physical tension.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Psalm 3:5',
    ),
    HealthNugget(
      day: 212,
      category: 'Sunlight',
      title: 'Eat Lunch Outdoors When Weather Permits',
      nugget:
          'Stepping outside during your lunch break gives fresh air, sunlight, and a real mental reset for the afternoon.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Ecclesiastes 11:7',
    ),
    HealthNugget(
      day: 213,
      category: 'Air',
      title: 'Deep Breathing Eases Mild Tension Headaches',
      nugget:
          'Many afternoon headaches stem from shallow breathing and dehydration. Drink a glass of water and breathe deeply outdoors.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Genesis 2:7',
    ),
    HealthNugget(
      day: 214,
      category: 'Nutrition',
      title: 'Watermelon Hydrates and Refreshes',
      nugget:
          'Watermelon is over 90% water and rich in citrulline and lycopene—an ideal tropical refresher between meals.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Numbers 11:5',
    ),
    HealthNugget(
      day: 215,
      category: 'Trust in God',
      title: 'Peaceful Homes Nurture Healthy Hearts',
      nugget:
          'Speaking tenderly and praying together as a family lowers household stress more than any supplement.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Joshua 24:15',
    ),
    HealthNugget(
      day: 216,
      category: 'Water',
      title: 'Evening Bath Washes Away Day\'s Fatigue',
      nugget:
          'Clean skin breathes better and regulates temperature more efficiently during sleep.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'Hebrews 10:22',
    ),
    HealthNugget(
      day: 217,
      category: 'Exercise',
      title: 'Skip the Car for Short Errands',
      nugget:
          'Walking to nearby shops builds daily step counts naturally while saving fuel and clearing your head.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Micah 6:8',
    ),
    HealthNugget(
      day: 218,
      category: 'Nutrition',
      title: 'Pumpkin Leaves (Ugwu) Pack Iron & Folate',
      nugget:
          'Lightly steamed dark green leaves paired with vitamin C-rich tomatoes or lemon boost non-heme iron absorption naturally.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 219,
      category: 'Temperance',
      title: 'Avoid Late-Night Heavy Suppers',
      nugget:
          'Let the digestive tract clock out with the sun. A light piece of fruit or warm herbal tea is plenty if hungry late.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Ecclesiastes 10:17',
    ),
    HealthNugget(
      day: 220,
      category: 'Rest',
      title: 'Music With Calm Tempo Lowers Heart Rate',
      nugget:
          'Soft acoustic hymns in the evening slow breathing and prepare the mind for peaceful rest.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '1 Samuel 16:23',
    ),
    HealthNugget(
      day: 221,
      category: 'Sunlight',
      title: 'Plants Need Sun—And So Do You',
      nugget:
          'Just as leaves wilt in dark basements, human immunity and mood fade without daily natural light.',
      speaker: 'Inspired by Ellen G. White — Counsels on Health',
      scripture: 'Psalm 84:11',
    ),
    HealthNugget(
      day: 222,
      category: 'Air',
      title: 'Walk Briskly to Expand Lung Alveoli',
      nugget:
          'During rest, many tiny air sacs in the lungs stay partially collapsed; brisk walking opens them fully for better oxygen exchange.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Job 33:4',
    ),
    HealthNugget(
      day: 223,
      category: 'Nutrition',
      title: 'Cinnamon Helps Steady Blood Sugar',
      nugget:
          'A sprinkle of Ceylon cinnamon on morning oats adds natural sweetness and supports healthy insulin sensitivity.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Exodus 30:23',
    ),
    HealthNugget(
      day: 224,
      category: 'Trust in God',
      title: 'Memorize Healing Promises of Scripture',
      nugget:
          'Storing verses like Psalm 103 and Isaiah 41:10 in your heart gives instant strength during sleepless nights or illness.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 119:11',
    ),
    HealthNugget(
      day: 225,
      category: 'Water',
      title: 'Cold Water Splash Refreshes Drowsy Eyes',
      nugget:
          'Instead of reaching for an afternoon soda, splash cool water on your face and drink a glass of pure water.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Proverbs 25:25',
    ),
    HealthNugget(
      day: 226,
      category: 'Exercise',
      title: 'Push-Ups Build Upper-Body Resilience',
      nugget:
          'Whether against a wall, on knees, or full floor push-ups, strengthening chest and arm muscles supports daily lifting safely.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 144:1',
    ),
    HealthNugget(
      day: 227,
      category: 'Nutrition',
      title: 'Avoid Excess White Sugar in Tea and Pap',
      nugget:
          'Gradually reduce added sugar by half each week—within 21 days your taste buds reset to enjoy natural sweetness.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Proverbs 25:27',
    ),
    HealthNugget(
      day: 228,
      category: 'Temperance',
      title: 'Balance Screen Time With Face-to-Face Care',
      nugget:
          'Visit an elderly neighbor or call a friend instead of scrolling—real human warmth heals loneliness.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: '3 John 1:14',
    ),
    HealthNugget(
      day: 229,
      category: 'Rest',
      title: 'Keep a Consistent Bedtime Anchor',
      nugget:
          'Going to bed within the same 30-minute window each night deepens REM and slow-wave restorative sleep.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Psalm 127:2',
    ),
    HealthNugget(
      day: 230,
      category: 'Sunlight',
      title: 'Morning Sunlight Helps Prevent Myopia in Youth',
      nugget:
          'Research shows children who spend 1–2 hours playing outdoors in natural daylight have far lower rates of nearsightedness.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Zechariah 8:5',
    ),
    HealthNugget(
      day: 231,
      category: 'Air',
      title: 'Keep Bedroom Clutter-Free for Cleaner Air',
      nugget:
          'Fewer piles of clothes and papers mean less trapped dust and calmer visual rest.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: '1 Corinthians 14:40',
    ),
    HealthNugget(
      day: 232,
      category: 'Nutrition',
      title: 'Soybeans and Tofu: Versatile Plant Protein',
      nugget:
          'Minimally processed soy foods like tofu, tempeh, and soy milk provide complete protein and isoflavones linked to heart protection.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Daniel 1:12',
    ),
    HealthNugget(
      day: 233,
      category: 'Trust in God',
      title: 'Wait Patiently on God\'s Timing',
      nugget:
          'Healing—whether emotional or physical—often unfolds step by step. Stay faithful in daily habits and trust God\'s clock.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 27:14',
    ),
    HealthNugget(
      day: 234,
      category: 'Water',
      title: 'Drink More Water in Hot or Humid Weather',
      nugget:
          'Perspiration rapidly depletes fluids and electrolytes. Pair extra water with mineral-rich fruits like oranges and bananas.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Isaiah 49:10',
    ),
    HealthNugget(
      day: 235,
      category: 'Exercise',
      title: 'Cycling Protects Joints While Building Stamina',
      nugget:
          'Stationary or outdoor cycling delivers strong aerobic conditioning with minimal impact on ankles and knees.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: '1 Timothy 4:8',
    ),
    HealthNugget(
      day: 236,
      category: 'Nutrition',
      title: 'Onion Flavonoids Support Blood Vessels',
      nugget:
          'Red and yellow onions are rich in quercetin, an antioxidant that helps calm vascular inflammation.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Numbers 11:5',
    ),
    HealthNugget(
      day: 237,
      category: 'Temperance',
      title: 'Do Not Eat When Deeply Upset',
      nugget:
          'Stress and anger halt digestive juices. Calm down with prayer and deep breaths before sitting down to eat.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'Proverbs 15:17',
    ),
    HealthNugget(
      day: 238,
      category: 'Rest',
      title: 'Protect Youth Sleep From Late Homework',
      nugget:
          'Teenagers need 8–10 hours of sleep for brain development. Help young people finish studying earlier for sharper focus.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Proverbs 3:24',
    ),
    HealthNugget(
      day: 239,
      category: 'Sunlight',
      title: 'Open Curtains First Thing in the Morning',
      nugget:
          'Flooding your home with morning light lifts energy, discourages oversleeping, and sets a cheerful tone for worship.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 118:24',
    ),
    HealthNugget(
      day: 240,
      category: 'Air',
      title: 'Take Slow Outdoor Walks After Rain',
      nugget:
          'Rain washes dust and pollen from the atmosphere, leaving crisp, refreshing air ideal for deep breathing.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 72:6',
    ),
    HealthNugget(
      day: 241,
      category: 'Nutrition',
      title: 'Carrots and Squash Nourish Eyes and Skin',
      nugget:
          'Vibrant orange vegetables deliver carotenoids that protect the retina and keep mucous membranes resilient.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 242,
      category: 'Trust in God',
      title: 'Cast Burdens Through Intercessory Prayer',
      nugget:
          'Praying for others shifts focus outward and reminds us that God is actively at work across His church.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'James 5:16',
    ),
    HealthNugget(
      day: 243,
      category: 'Water',
      title: 'Avoid Sweetened Sports Drinks for Light Activity',
      nugget:
          'For workouts under an hour, plain water is all your body needs—save yourself the unnecessary sugar and dyes.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Isaiah 55:2',
    ),
    HealthNugget(
      day: 244,
      category: 'Exercise',
      title: 'Good Posture Starts With Strong Back Muscles',
      nugget:
          'Gentle row exercises or squeezing shoulder blades together for 5 seconds counters hours of leaning over phones.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 145:14',
    ),
    HealthNugget(
      day: 245,
      category: 'Nutrition',
      title: 'Homemade Dressings Beat Bottled Sauces',
      nugget:
          'Blend lemon juice, garlic, herbs, and blended cashews or tahini for creamy salads without chemical thickeners.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 246,
      category: 'Temperance',
      title: 'Keep Speech Pure and Uplifting',
      nugget:
          'Gossip poisons the mind just as spoiled food poisons the stomach. Speak what builds faith and courage.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Ephesians 4:29',
    ),
    HealthNugget(
      day: 247,
      category: 'Rest',
      title: 'Sabbath Afternoons Are Made for Restoration',
      nugget:
          'Combine unhurried family time, nature walks, and quiet rest on Sabbath afternoon to enter the new week refreshed.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Mark 2:27',
    ),
    HealthNugget(
      day: 248,
      category: 'Sunlight',
      title: 'Gentle Sun Helps Calm Skin Flare-Ups',
      nugget:
          'Brief, non-burning morning sunlight often soothes eczema and psoriasis while boosting local skin immunity.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Malachi 4:2',
    ),
    HealthNugget(
      day: 249,
      category: 'Air',
      title: 'Check Your Breathing Right Now',
      nugget:
          'Drop your shoulders, unclench your jaw, and take one slow, deep belly breath. Stress leaves on the exhale.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 46:10',
    ),
    HealthNugget(
      day: 250,
      category: 'Nutrition',
      title: 'Whole Corn, Yam, and Cocoyam in Balance',
      nugget:
          'Pair traditional whole starches with generous vegetable soups and beans rather than heavy palm-oil sauces for lasting energy.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Psalm 104:14',
    ),
    HealthNugget(
      day: 251,
      category: 'Trust in God',
      title: 'God\'s Mercies Are New Every Morning',
      nugget:
          'Yesterday\'s slip in diet or exercise does not define today. Begin fresh this morning with gratitude and resolve.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Lamentations 3:22-23',
    ),
    HealthNugget(
      day: 252,
      category: 'Water',
      title: 'Warm Water Soothes Morning Coughs',
      nugget:
          'Sipping warm water with a touch of honey (for adults and children over age 1) calms throat irritation naturally.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Proverbs 16:24',
    ),
    HealthNugget(
      day: 253,
      category: 'Exercise',
      title: 'Climb Hills or Inclines Gradually',
      nugget:
          'Walking up gentle slopes builds leg power and heart capacity quickly—pace yourself so you can still speak comfortably.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Habakkuk 3:19',
    ),
    HealthNugget(
      day: 254,
      category: 'Nutrition',
      title: 'Beets Support Natural Blood Flow',
      nugget:
          'Dietary nitrates in beets convert to nitric oxide in the body, helping blood vessels dilate and supporting stamina.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 255,
      category: 'Temperance',
      title: 'Guard Against Late-Night Entertainment',
      nugget:
          'Exciting movies or heated social feeds right before bed flood the brain with cortisol when you need peace.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Psalm 101:3',
    ),
    HealthNugget(
      day: 256,
      category: 'Rest',
      title: 'Change Your Work Posture Often',
      nugget:
          'Alternating between sitting and standing while working reduces lower-back fatigue and keeps legs energized.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Ecclesiastes 3:1',
    ),
    HealthNugget(
      day: 257,
      category: 'Sunlight',
      title: 'Natural Sunlight Lifts Hospital Recovery',
      nugget:
          'Studies show patients in sunlit rooms heal faster and need less pain medication than those in dim rooms.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Malachi 4:2',
    ),
    HealthNugget(
      day: 258,
      category: 'Air',
      title: 'Avoid Sleeping Under Heavy Blankets Over Face',
      nugget:
          'Covering your head while sleeping traps exhaled carbon dioxide. Keep your face uncovered to breathe fresh room air.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'Genesis 2:7',
    ),
    HealthNugget(
      day: 259,
      category: 'Nutrition',
      title: 'Replace Mayonnaise With Avocado or Hummus',
      nugget:
          'Chickpea hummus and mashed avocado add creaminess and fiber to sandwiches without refined oils or eggs.',
      speaker: 'Creation & Health Principles',
      scripture: 'Daniel 1:12',
    ),
    HealthNugget(
      day: 260,
      category: 'Trust in God',
      title: 'Heals All Our Diseases',
      nugget:
          'Whether through natural laws, skilled physicians, or direct miracle, all true healing comes from the Lord.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 103:3',
    ),
    HealthNugget(
      day: 261,
      category: 'Water',
      title: 'Stay Hydrated During Long Travel',
      nugget:
          'Bus, car, and air travel dehydrate the body quickly. Carry clean water and stretch your legs at every stop.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 121:8',
    ),
    HealthNugget(
      day: 262,
      category: 'Exercise',
      title: 'Grip Strength Predicts Healthy Aging',
      nugget:
          'Carrying groceries, squeezing a stress ball, or hanging gently from a bar maintains hand and forearm strength for life.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Ecclesiastes 9:10',
    ),
    HealthNugget(
      day: 263,
      category: 'Nutrition',
      title: 'Eat Breakfast Within Two Hours of Waking',
      nugget:
          'Fueling your brain early prevents mid-morning cortisol spikes and reduces cravings for sugary pastries.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'John 21:12',
    ),
    HealthNugget(
      day: 264,
      category: 'Temperance',
      title: 'Keep Household Portions Moderate',
      nugget:
          'Serving food onto smaller plates naturally prevents overeating without leaving anyone feeling deprived.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Proverbs 23:2',
    ),
    HealthNugget(
      day: 265,
      category: 'Rest',
      title: 'Make Sabbath Eve Peaceful',
      nugget:
          'A calm family worship at sundown Friday signals body and soul that six days of toil are complete.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Genesis 2:2',
    ),
    HealthNugget(
      day: 266,
      category: 'Sunlight',
      title: 'Sunlight Encourages Healthy Serotonin',
      nugget:
          'Higher brain serotonin from daily sunlight brings calm focus during the day and converts to melatonin at night.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Psalm 19:4-5',
    ),
    HealthNugget(
      day: 267,
      category: 'Air',
      title: 'Sing Together in Worship',
      nugget:
          'Congregational singing synchronizes breathing, deepens community bonds, and uplifts weary hearts.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Colossians 3:16',
    ),
    HealthNugget(
      day: 268,
      category: 'Nutrition',
      title: 'Papaya (Pawpaw) Aids Gentle Digestion',
      nugget:
          'Ripe pawpaw contains natural papain enzymes and soothing fiber that calm sluggish digestion.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Ezekiel 47:12',
    ),
    HealthNugget(
      day: 269,
      category: 'Trust in God',
      title: 'Do Not Borrow Tomorrow\'s Trouble',
      nugget:
          'Jesus reminds us that each day has enough of its own care. Live faithfully today and leave tomorrow in His hands.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Matthew 6:34',
    ),
    HealthNugget(
      day: 270,
      category: 'Water',
      title: 'Clean Water Prevents Kidney Stones',
      nugget:
          'Drinking 8–10 glasses of water daily dilutes urine minerals and protects kidneys from painful crystal buildup.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Isaiah 58:11',
    ),
    HealthNugget(
      day: 271,
      category: 'Exercise',
      title: 'Warm Up Before Vigorous Work',
      nugget:
          'Spend 5 minutes walking slowly or swinging arms gently before lifting or sprinting to protect tendons and joints.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Proverbs 24:27',
    ),
    HealthNugget(
      day: 272,
      category: 'Nutrition',
      title: 'Whole Apples Over Apple Juice',
      nugget:
          'Pectin fiber in whole apples feeds healthy gut bacteria and slows sugar absorption—skip stripped juices.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Proverbs 25:11',
    ),
    HealthNugget(
      day: 273,
      category: 'Temperance',
      title: 'Avoid Energy-Draining Comparisons',
      nugget:
          'Focus on progressing from where you were last month rather than comparing your body or pace to others.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Galatians 6:4',
    ),
    HealthNugget(
      day: 274,
      category: 'Rest',
      title: 'Dim House Lights After Sunset',
      nugget:
          'Lowering bright overhead lights in the evening tells your pineal gland that night has arrived.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Psalm 104:20',
    ),
    HealthNugget(
      day: 275,
      category: 'Sunlight',
      title: 'Vitamin D Supports Mood During Stressful Seasons',
      nugget:
          'Keeping vitamin D healthy through safe sun exposure protects emotional resilience when life gets demanding.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 27:1',
    ),
    HealthNugget(
      day: 276,
      category: 'Air',
      title: 'Practice Belly Breathing Lying Down',
      nugget:
          'Place one hand on your chest and one on your belly; let only the belly hand rise as you inhale slowly.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Genesis 2:7',
    ),
    HealthNugget(
      day: 277,
      category: 'Nutrition',
      title: 'Sesame Seeds & Tahini Build Strong Bones',
      nugget:
          'Just two tablespoons of ground sesame or tahini deliver substantial calcium, copper, and healthy fats.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 278,
      category: 'Trust in God',
      title: 'Love Casts Out Fear',
      nugget:
          'Chronic fear weakens immunity; resting in God\'s unconditional love quiets the nervous system.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '1 John 4:18',
    ),
    HealthNugget(
      day: 279,
      category: 'Water',
      title: 'Wash Fruits Before Peeling',
      nugget:
          'Even oranges, mangoes, and melons should be rinsed first so your knife does not drag surface bacteria inside.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 51:2',
    ),
    HealthNugget(
      day: 280,
      category: 'Exercise',
      title: 'Dance or March Indoors on Rainy Days',
      nugget:
          'Heavy rain is no excuse to stay sedentary—put on uplifting gospel music and march briskly indoors for 20 minutes.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Psalm 149:3',
    ),
    HealthNugget(
      day: 281,
      category: 'Nutrition',
      title: 'Avoid Artificial Sweeteners',
      nugget:
          'Zero-calorie chemical sweeteners can disrupt gut microbiota and confuse appetite regulation. Choose whole fruit instead.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Isaiah 55:2',
    ),
    HealthNugget(
      day: 282,
      category: 'Temperance',
      title: 'Don\'t Eat Standing Up in a Rush',
      nugget:
          'Sitting calmly at a table helps you digest food properly and prevents mindless overconsumption.',
      speaker: 'Inspired by Ellen G. White — Counsels on Diet and Foods',
      scripture: '1 Corinthians 14:40',
    ),
    HealthNugget(
      day: 283,
      category: 'Rest',
      title: 'Take Annual Vacation Time Seriously',
      nugget:
          'Stepping away from routine duties for a few days each year restores creativity, marriage joy, and heart health.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Mark 6:31',
    ),
    HealthNugget(
      day: 284,
      category: 'Sunlight',
      title: 'Sun-Warmed Walkways Invite Outdoor Habits',
      nugget:
          'Keep walking shoes right by the door so stepping out into morning sun becomes automatic.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Psalm 119:105',
    ),
    HealthNugget(
      day: 285,
      category: 'Air',
      title: 'Fresh Air Prevents Afternoon Slump',
      nugget:
          'Stuffy offices build up carbon dioxide, causing drowsiness. Step outside for three minutes of fresh air at 3 PM.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Job 33:4',
    ),
    HealthNugget(
      day: 286,
      category: 'Nutrition',
      title: 'Cook Vegetables Lightly to Keep Crunch',
      nugget:
          'Overboiling greens until mushy destroys vitamin C and folate. Steam briefly until vibrant green and tender-crisp.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 287,
      category: 'Trust in God',
      title: 'Serve in Health Evangelism',
      nugget:
          'Sharing a simple healthy recipe or praying with a sick neighbor turns your wellness habits into loving witness.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Matthew 10:8',
    ),
    HealthNugget(
      day: 288,
      category: 'Water',
      title: 'Warm Compress Relieves Tension Neck Pain',
      nugget:
          'A warm damp towel wrapped around stiff neck muscles for 10 minutes melts tightness safely.',
      speaker: 'Hydrotherapy & Sanitarium Principles',
      scripture: 'Isaiah 1:6',
    ),
    HealthNugget(
      day: 289,
      category: 'Exercise',
      title: 'Stretch Hamstrings to Ease Low Back',
      nugget:
          'Tight back-of-thigh muscles pull on the pelvis. Gentle daily hamstring stretches keep your lower back comfortable.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Psalm 18:32',
    ),
    HealthNugget(
      day: 290,
      category: 'Nutrition',
      title: 'Walnuts Nourish Brain Membranes',
      nugget:
          'Shaped remarkably like the human brain, walnuts are rich in plant omega-3 ALA and polyphenols for cognitive longevity.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Song of Solomon 6:11',
    ),
    HealthNugget(
      day: 291,
      category: 'Temperance',
      title: 'Practice Fasting From Complaining',
      nugget:
          'Grumbling elevates cortisol and discourages everyone nearby. Replace complaints with one concrete thing you appreciate.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Philippians 2:14',
    ),
    HealthNugget(
      day: 292,
      category: 'Rest',
      title: 'Avoid Heavy Exercise Right Before Sleep',
      nugget:
          'Vigorous workouts raise core body temperature and adrenaline; finish intense exercise at least 3 hours before bedtime.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 4:8',
    ),
    HealthNugget(
      day: 293,
      category: 'Sunlight',
      title: 'Let Children Play Outdoors Daily',
      nugget:
          'Active outdoor play builds strong bones, sharper eyesight, better sleep, and cheerful social skills.',
      speaker: 'Inspired by Ellen G. White — Education',
      scripture: 'Zechariah 8:5',
    ),
    HealthNugget(
      day: 294,
      category: 'Air',
      title: 'Avoid Burning Plastics or Trash Near Homes',
      nugget:
          'Protect your neighborhood\'s air—toxic smoke from burning waste lingers in lungs and harms children.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Matthew 22:39',
    ),
    HealthNugget(
      day: 295,
      category: 'Nutrition',
      title: 'Black-Eyed Peas & Corn: Classic Protein Pair',
      nugget:
          'Combining legumes and whole grains provides all essential amino acids effortlessly without saturated animal fat.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Daniel 1:12',
    ),
    HealthNugget(
      day: 296,
      category: 'Trust in God',
      title: 'Trust God\'s Healing When Diagnosis Scares You',
      nugget:
          'Seek wise medical counsel, adopt every NEWSTART habit, and anchor your heart in the Great Physician\'s presence.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Isaiah 41:10',
    ),
    HealthNugget(
      day: 297,
      category: 'Water',
      title: 'Drink Water After Every Restroom Break',
      nugget:
          'Linking a half-glass of water to every restroom break keeps hydration steady without needing to count.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'John 4:14',
    ),
    HealthNugget(
      day: 298,
      category: 'Exercise',
      title: 'Jump Rope or Step-Ups Boost Bone Density',
      nugget:
          'Gentle weight-bearing impacts signal bone cells to lay down stronger mineral matrix, preventing osteoporosis.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Proverbs 3:8',
    ),
    HealthNugget(
      day: 299,
      category: 'Nutrition',
      title: 'Avoid Skipping Meals Then Binging',
      nugget:
          'Starving all day triggers extreme evening hunger and poor food choices. Eat a nourishing breakfast and balanced lunch.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Ecclesiastes 10:17',
    ),
    HealthNugget(
      day: 300,
      category: 'Trust in God',
      title: '300 Days of Walking With the Creator',
      nugget:
          'Every healthy meal, deep breath, and Sabbath rest is a testimony that God cares about your whole life today.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '3 John 1:2',
    ),
    HealthNugget(
      day: 301,
      category: 'Temperance',
      title: 'Guard Against Workaholism',
      nugget:
          'Your worth is rooted in Christ, not endless busyness. Work diligently, then rest without guilt.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 127:2',
    ),
    HealthNugget(
      day: 302,
      category: 'Rest',
      title: 'Read Something Uplifting Before Sleep',
      nugget:
          'A chapter of Psalms or inspiring devotional reading leaves peaceful thoughts in your subconscious overnight.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'Psalm 63:6',
    ),
    HealthNugget(
      day: 303,
      category: 'Sunlight',
      title: 'Sunlight Helps Clear Mild Winter/Rainy Blues',
      nugget:
          'Whenever the clouds break, take 15 minutes outside—bright sky light boosts mood even through light haze.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Ecclesiastes 11:7',
    ),
    HealthNugget(
      day: 304,
      category: 'Air',
      title: 'Keep Nasal Passages Clear With Saline',
      nugget:
          'A gentle warm saline rinse clears dust and pollen naturally without medicated spray dependency.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Genesis 2:7',
    ),
    HealthNugget(
      day: 305,
      category: 'Nutrition',
      title: 'Chickpeas (Garbanzo) Keep You Full Longer',
      nugget:
          'High fiber and slow-digesting protein in chickpeas prevent mid-afternoon energy crashes.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Daniel 1:15',
    ),
    HealthNugget(
      day: 306,
      category: 'Water',
      title: 'Hydrate Well When Nursing a Cold',
      nugget:
          'Extra water and warm vegetable broths thin mucus secretions and help the body clear viral invaders faster.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Proverbs 17:22',
    ),
    HealthNugget(
      day: 307,
      category: 'Exercise',
      title: 'Evening Family Walks Build Connection',
      nugget:
          'A 15-minute stroll after supper lets parents and children talk openly while aiding digestion.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Deuteronomy 6:7',
    ),
    HealthNugget(
      day: 308,
      category: 'Nutrition',
      title: 'Limit Refined White Rice and White Bread',
      nugget:
          'Swap white rice occasionally for brown rice, ofada rice, quinoa, or bulgur to triple fiber and B-vitamin intake.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Psalm 81:16',
    ),
    HealthNugget(
      day: 309,
      category: 'Temperance',
      title: 'Practice Patience While Waiting',
      nugget:
          'Impatience spikes blood pressure unnecessarily. Use waiting lines as moments to pray silently for people around you.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Galatians 5:22',
    ),
    HealthNugget(
      day: 310,
      category: 'Rest',
      title: 'Check Your Mattress and Pillow Support',
      nugget:
          'A supportive pillow keeping your neck aligned with your spine prevents morning headaches and shoulder pain.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 4:8',
    ),
    HealthNugget(
      day: 311,
      category: 'Sunlight',
      title: 'Vitamin D Works Alongside Physical Activity',
      nugget:
          'Outdoor walking combines vitamin D production with weight-bearing bone stimulation in one simple habit.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Malachi 4:2',
    ),
    HealthNugget(
      day: 312,
      category: 'Air',
      title: 'Humming Gently Boosts Sinus Nitric Oxide',
      nugget:
          'Soft humming vibrates sinus passages and dramatically increases natural nitric oxide airflow, helping clear mild congestion.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 95:1',
    ),
    HealthNugget(
      day: 313,
      category: 'Nutrition',
      title: 'Herbs and Spices Pack Concentrated Antioxidants',
      nugget:
          'Oregano, thyme, rosemary, basil, and cloves contain far more antioxidants per gram than most fruits—season freely!',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Psalm 104:14',
    ),
    HealthNugget(
      day: 314,
      category: 'Trust in God',
      title: 'Forgive Quickly to Protect Your Peace',
      nugget:
          'Resentment is a heavy backpack your heart was never built to carry. Lay it at the cross today.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Colossians 3:13',
    ),
    HealthNugget(
      day: 315,
      category: 'Water',
      title: 'Cool Showers After Sweating Restore Tone',
      nugget:
          'Finishing a warm post-exercise shower with 30 seconds of cool water closes pores and leaves you invigorated.',
      speaker: 'Hydrotherapy & Sanitarium Principles',
      scripture: 'John 7:38',
    ),
    HealthNugget(
      day: 316,
      category: 'Exercise',
      title: 'Ankle Circles Prevent Stiffness on Flights',
      nugget:
          'Rotating ankles and flexing calves hourly during long journeys protects against sluggish leg circulation.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Isaiah 35:3',
    ),
    HealthNugget(
      day: 317,
      category: 'Nutrition',
      title: 'Garden Eggs (African Eggplant) Support Cholesterol',
      nugget:
          'Low in calories and rich in soluble fiber and polyphenols, garden eggs make a crisp, heart-friendly snack.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 318,
      category: 'Temperance',
      title: 'Keep Mealtime Conversation Cheerful',
      nugget:
          'Laughter and warm conversation at the table relax the nervous system and help every family member digest better.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: 'Proverbs 15:17',
    ),
    HealthNugget(
      day: 319,
      category: 'Rest',
      title: 'Avoid Heavy Problem-Solving After 9 PM',
      nugget:
          'Tackle complex budgets or tough decisions in the morning when your prefrontal cortex is fresh, not at midnight.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Psalm 127:2',
    ),
    HealthNugget(
      day: 320,
      category: 'Sunlight',
      title: 'Sunlight Regulates Healthy Immune Balance',
      nugget:
          'Balanced sun exposure calms overactive autoimmune responses while strengthening defenses against infection.',
      speaker: 'Creation & Health Principles',
      scripture: 'Psalm 84:11',
    ),
    HealthNugget(
      day: 321,
      category: 'Air',
      title: 'Spend Time Under Trees Weekly',
      nugget:
          'Forest bathing—simply sitting or walking quietly among trees—lowers blood pressure and boosts natural killer immune cells.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Psalm 96:12',
    ),
    HealthNugget(
      day: 322,
      category: 'Nutrition',
      title: 'Citrus Pith Holds Extra Bioflavonoids',
      nugget:
          'When eating oranges or tangerines, enjoy the soft white pith too—it contains rutin and hesperidin that strengthen capillaries.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 323,
      category: 'Trust in God',
      title: 'Your Life Is Hid With Christ in God',
      nugget:
          'Security in God\'s love frees you from frantic status-seeking, allowing genuine rest and joyful health.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Colossians 3:3',
    ),
    HealthNugget(
      day: 324,
      category: 'Water',
      title: 'Sip Water Slowly Rather Than Gulping',
      nugget:
          'Sipping water steadily throughout the day hydrates tissues better than chugging a liter all at once.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Isaiah 58:11',
    ),
    HealthNugget(
      day: 325,
      category: 'Exercise',
      title: 'Sit-to-Stand Practice Keeps Legs Strong',
      nugget:
          'Standing up from a chair 10 times without using your hands strengthens thighs and preserves lifelong mobility.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Deuteronomy 33:25',
    ),
    HealthNugget(
      day: 326,
      category: 'Nutrition',
      title: 'Whole Cornmeal Over Refined Starch',
      nugget:
          'Unrefined whole grains retain the germ and bran where vitamin E, magnesium, and protective antioxidants live.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Psalm 81:16',
    ),
    HealthNugget(
      day: 327,
      category: 'Temperance',
      title: 'Steer Clear of Gossip and Negativity',
      nugget:
          'Guard what enters your ears just as carefully as what enters your mouth—toxic media breeds anxious thoughts.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Philippians 4:8',
    ),
    HealthNugget(
      day: 328,
      category: 'Rest',
      title: 'Wake Gently Without Panic Alarms',
      nugget:
          'Waking to a calm chime at a consistent hour avoids morning adrenaline jolts and starts worship peacefully.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 5:3',
    ),
    HealthNugget(
      day: 329,
      category: 'Sunlight',
      title: 'Morning Sun Helps Reset Jet Lag and Shift Fatigue',
      nugget:
          'Early daylight exposure is the fastest natural signal to align your body\'s internal clock.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 113:3',
    ),
    HealthNugget(
      day: 330,
      category: 'Air',
      title: 'Keep Car Windows Cracked Briefly on Drives',
      nugget:
          'Recirculated cabin air builds up CO2 quickly; briefly refreshing cabin air keeps drivers alert and focused.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Job 33:4',
    ),
    HealthNugget(
      day: 331,
      category: 'Nutrition',
      title: 'Bananas: Quick Pre-Walk Potassium',
      nugget:
          'A ripe banana before a morning walk offers gentle energy, vitamin B6, and potassium for steady muscle contractions.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 332,
      category: 'Trust in God',
      title: 'Be Still and Know That He Is God',
      nugget:
          'Daily stillness in God\'s presence lowers blood pressure and reminds us who holds the universe together.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 46:10',
    ),
    HealthNugget(
      day: 333,
      category: 'Water',
      title: 'Check Elderly Loved Ones\' Hydration',
      nugget:
          'Thirst sensation fades with age. Gently remind parents and grandparents to drink clean water throughout the day.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: '1 Timothy 5:8',
    ),
    HealthNugget(
      day: 334,
      category: 'Exercise',
      title: 'Move Every Day—Even If Only 10 Minutes',
      nugget:
          'On packed days, a brisk 10-minute walk keeps the daily habit unbroken and boosts circulation.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Zechariah 4:10',
    ),
    HealthNugget(
      day: 335,
      category: 'Nutrition',
      title: 'Dates, Figs, and Plums Support Regularity',
      nugget:
          'Soluble and insoluble fibers in dried fruits gently support bowel regularity without harsh laxatives.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Deuteronomy 8:8',
    ),
    HealthNugget(
      day: 336,
      category: 'Temperance',
      title: 'Avoid Eating Out of Boredom',
      nugget:
          'Ask yourself before opening the fridge: "Am I truly hungry, or just tired or bored?"',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Proverbs 23:2',
    ),
    HealthNugget(
      day: 337,
      category: 'Rest',
      title: 'Honor the Rhythm of Work and Rest',
      nugget:
          'God designed six days for purposeful labor and the seventh for complete rest—both are sacred commands.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Exodus 20:9-10',
    ),
    HealthNugget(
      day: 338,
      category: 'Sunlight',
      title: 'Enjoy Sunset Walks for Evening Calm',
      nugget:
          'Watching the shifting evening light signals your brain to begin winding down toward restful sleep.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Genesis 24:63',
    ),
    HealthNugget(
      day: 339,
      category: 'Air',
      title: 'Clear Cluttered Airways With Hydration & Steam',
      nugget:
          'Moist air and good hydration keep nasal cilia sweeping away dust and microbes effortlessly.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Genesis 2:7',
    ),
    HealthNugget(
      day: 340,
      category: 'Nutrition',
      title: 'Roasted Pumpkin & Sunflower Seeds Snack',
      nugget:
          'Swap fried chips for lightly toasted pumpkin or sunflower seeds—crunchy, satisfying, and packed with magnesium.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 341,
      category: 'Trust in God',
      title: 'Pray Over Your Kitchen and Table',
      nugget:
          'Dedicate your home\'s meals to God\'s glory so preparing simple, wholesome food becomes joyful ministry.',
      speaker: 'Inspired by Ellen G. White — Ministry of Healing',
      scripture: '1 Corinthians 10:31',
    ),
    HealthNugget(
      day: 342,
      category: 'Water',
      title: 'Warm Foot Soak Eases Cold Feet Before Sleep',
      nugget:
          'Warming cold feet in a basin of warm water for 10 minutes helps blood vessels relax so you fall asleep faster.',
      speaker: 'Hydrotherapy & Sanitarium Principles',
      scripture: 'Psalm 4:8',
    ),
    HealthNugget(
      day: 343,
      category: 'Exercise',
      title: 'Take a Stretching Break Between Meetings',
      nugget:
          'Reach up, twist gently side to side, and walk across the room between calls to keep energy flowing.',
      speaker: 'Adventist Health Ministries Principles',
      scripture: 'Isaiah 40:31',
    ),
    HealthNugget(
      day: 344,
      category: 'Nutrition',
      title: 'Avoid Excess Fried Street Snacks',
      nugget:
          'Carry roasted groundnuts, bananas, or apples in your bag so hunger never forces you into greasy pastries.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Proverbs 27:12',
    ),
    HealthNugget(
      day: 345,
      category: 'Temperance',
      title: 'Simplicity Brings Peace to Hospitality',
      nugget:
          'Invite friends over for a simple pot of beans, salad, and warm fellowship—love matters far more than elaborate menus.',
      speaker: 'Inspired by Ellen G. White — Counsels on Diet and Foods',
      scripture: 'Romans 12:13',
    ),
    HealthNugget(
      day: 346,
      category: 'Rest',
      title: 'Turn Off Notification Sounds Overnight',
      nugget:
          'Even brief phone chimes fragment deep sleep cycles. Use Do Not Disturb so your brain rests uninterrupted.',
      speaker: 'Weimar NEWSTART Principles',
      scripture: 'Psalm 3:5',
    ),
    HealthNugget(
      day: 347,
      category: 'Sunlight',
      title: 'Sun-Dry Laundry When Possible',
      nugget:
          'Fresh air and sunlight naturally freshen clothes and linens without harsh chemical dryer sheets.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Psalm 19:6',
    ),
    HealthNugget(
      day: 348,
      category: 'Air',
      title: 'Deep Exhalation Releases Shoulder Tension',
      nugget:
          'Let your breath out with a quiet sigh as you drop your shoulders—instant relief for desk-bound muscles.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Matthew 11:28',
    ),
    HealthNugget(
      day: 349,
      category: 'Nutrition',
      title: 'Coconut Water: Natural Electrolyte Boost',
      nugget:
          'Fresh green coconut water replenishes potassium and fluids naturally after hot outdoor exertion.',
      speaker: 'ALIVE Nigeria Health Ministry',
      scripture: 'Psalm 104:14',
    ),
    HealthNugget(
      day: 350,
      category: 'Trust in God',
      title: 'Rejoice Always in the Lord',
      nugget:
          'Joy rooted in Christ\'s salvation is steady regardless of circumstances, uplifting both spirit and immune health.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Philippians 4:4',
    ),
    HealthNugget(
      day: 351,
      category: 'Water',
      title: 'Drink Water Before Heavy Mental Work',
      nugget:
          'Your brain is roughly 75% water; even 2% dehydration slows reaction time and memory recall.',
      speaker: 'Mental & Physical Health Principles',
      scripture: 'Proverbs 2:6',
    ),
    HealthNugget(
      day: 352,
      category: 'Exercise',
      title: 'Strengthen Your Ankles and Feet',
      nugget:
          'Walking barefoot safely indoors on clean floors or grass strengthens small stabilizing foot muscles.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Psalm 18:33',
    ),
    HealthNugget(
      day: 353,
      category: 'Nutrition',
      title: 'Garlic, Onion, and Lemon: Everyday Defenders',
      nugget:
          'Building everyday soups and stews on garlic, onions, tomatoes, and fresh herbs packs immune protection into every bite.',
      speaker: 'Uchee Pines Natural Health Principles',
      scripture: 'Ezekiel 47:12',
    ),
    HealthNugget(
      day: 354,
      category: 'Temperance',
      title: 'End-of-Year Balance Without Gluttony',
      nugget:
          'Celebrate holidays with gratitude, vibrant fruit salads, and brisk walks—don\'t sacrifice January health to December excess.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: '1 Corinthians 10:31',
    ),
    HealthNugget(
      day: 355,
      category: 'Rest',
      title: 'Reflect on God\'s Faithfulness This Year',
      nugget:
          'Looking back at answered prayers calms anxiety about the coming year and deepens restful trust.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 77:11-12',
    ),
    HealthNugget(
      day: 356,
      category: 'Sunlight',
      title: 'Step Outside Even on Busy Holiday Weeks',
      nugget:
          'Ten minutes in morning sunlight keeps mood bright and digestion smooth amid busy family schedules.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Malachi 4:2',
    ),
    HealthNugget(
      day: 357,
      category: 'Air',
      title: 'Crack a Window During Family Gatherings',
      nugget:
          'Crowded rooms deplete oxygen quickly. Fresh cross-ventilation keeps guests alert, comfortable, and healthier.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Genesis 2:7',
    ),
    HealthNugget(
      day: 358,
      category: 'Nutrition',
      title: 'Warm Oatmeal With Fruit and Walnuts',
      nugget:
          'Simple whole oats topped with banana, cinnamon, and walnuts fuel steady morning energy in minutes.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Genesis 1:29',
    ),
    HealthNugget(
      day: 359,
      category: 'Trust in God',
      title: 'Peace On Earth Begins in Surrendered Hearts',
      nugget:
          'Receiving Christ\'s peace transforms how we treat our bodies, our families, and our neighbors.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Luke 2:14',
    ),
    HealthNugget(
      day: 360,
      category: 'Water',
      title: 'Clean Water Is a Ministry Opportunity',
      nugget:
          'Whenever we share clean water or teach simple hygiene, we reflect the love of Jesus, the Living Water.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Matthew 10:42',
    ),
    HealthNugget(
      day: 361,
      category: 'Exercise',
      title: 'Finish the Year Moving Forward',
      nugget:
          'Invite a friend for a year-end walk and share one health goal you are praying about for the new year.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Philippians 3:13-14',
    ),
    HealthNugget(
      day: 362,
      category: 'Nutrition',
      title: 'Plan Simple Weekly Plant-Forward Menus',
      nugget:
          'Writing a simple 5-meal rotation of beans, greens, whole grains, and fresh fruit removes daily guesswork.',
      speaker: 'CHIP & Lifestyle Medicine Principles',
      scripture: 'Proverbs 21:5',
    ),
    HealthNugget(
      day: 363,
      category: 'Temperance',
      title: 'Choose Habits You Can Sustain All Year',
      nugget:
          'Skip extreme crash diets. Steady, joyful NEWSTART habits practiced 365 days a year create lasting vitality.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Galatians 6:9',
    ),
    HealthNugget(
      day: 364,
      category: 'Rest',
      title: 'Enter the New Year Rested in Body & Soul',
      nugget:
          'Give yourself permission to sleep well tonight—tomorrow\'s strength is forged in tonight\'s rest.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Psalm 4:8',
    ),
    HealthNugget(
      day: 365,
      category: 'Trust in God',
      title: 'Every Day Belongs to the Great Physician',
      nugget:
          'As 365 days complete and the cycle begins anew, may you prosper and be in health, even as your soul prospers.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '3 John 1:2',
    ),
    HealthNugget(
      day: 366,
      category: 'Water',
      title: 'Unrefined Mineral Salt & Cellular Hydration',
      nugget:
          'A tiny crystal of unrefined sea salt with a full glass of pure water supplies trace minerals that help water enter thirsty cells effectively.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Matthew 5:13',
    ),
    HealthNugget(
      day: 367,
      category: 'Nutrition',
      title: 'Cayenne & Ginger Support Healthy Circulation',
      nugget:
          'A tiny pinch of cayenne or fresh ginger in warm water gently dilates peripheral blood vessels and warms cold hands and feet.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Psalm 104:14',
    ),
    HealthNugget(
      day: 368,
      category: 'Water',
      title: 'Castor Oil Compresses for Gentle Relief',
      nugget:
          'A warm flannel cloth lightly soaked with cold-pressed castor oil placed over a sore joint or abdomen supports lymphatic flow and comfort.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Isaiah 1:6',
    ),
    HealthNugget(
      day: 369,
      category: 'Nutrition',
      title: 'Slippery Elm Soothes Irritated Digestion',
      nugget:
          'Stirring a teaspoon of slippery elm bark powder into warm water forms a gentle mucilage that coats and calms an upset stomach lining.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Ezekiel 47:12',
    ),
    HealthNugget(
      day: 370,
      category: 'Exercise',
      title: 'Gentle Rebounding Moves Lymphatic Fluid',
      nugget:
          'Unlike blood, the lymphatic system has no heart pump—gentle bouncing, brisk walking, and deep breathing keep lymph flowing cleanly.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Psalm 139:14',
    ),
    HealthNugget(
      day: 371,
      category: 'Rest',
      title: 'Magnesium-Rich Greens Calm Evening Nerves',
      nugget:
          'Dark leafy greens, pumpkin seeds, and almonds provide natural magnesium that relaxes tight muscles and prepares the brain for deep sleep.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Psalm 4:8',
    ),
    HealthNugget(
      day: 372,
      category: 'Temperance',
      title: 'Give the Liver an Overnight Rest',
      nugget:
          'Finishing a light supper early allows the liver to complete detoxification and cellular repair overnight instead of digesting heavy fats.',
      speaker: 'Natural Health & NEWSTART Principles',
      scripture: 'Ecclesiastes 10:17',
    ),
    HealthNugget(
      day: 373,
      category: 'Sunlight',
      title: 'Near-Infrared Sunlight Energizes Mitochondria',
      nugget:
          'Natural outdoor sunlight—even in shade near green trees—delivers near-infrared light that helps cell mitochondria produce melatonin and repair tissue.',
      speaker: 'Loma Linda & Adventist Health Study',
      scripture: 'Malachi 4:2',
    ),
    HealthNugget(
      day: 374,
      category: 'Trust in God',
      title: 'Whole-Person Health Anchored in Hope',
      nugget:
          'God\'s health message is never about legalism—it is an invitation to live with clear minds so we can hear His voice and serve joyfully.',
      speaker: 'Biblical Health & Stewardship',
      scripture: '3 John 1:2',
    ),
    HealthNugget(
      day: 375,
      category: 'Rest',
      title: 'Emotional Resilience Through Sabbath & Community',
      nugget:
          'Healing trauma and burnout requires safe spiritual community, unhurried Sabbath rest, and honest prayer before a compassionate Savior.',
      speaker: 'GC Health Ministries Principles',
      scripture: 'Psalm 34:18',
    ),
    HealthNugget(
      day: 376,
      category: 'Nutrition',
      title: 'Thirty Days to Lower Blood Pressure Naturally',
      nugget:
          'Combining potassium-rich whole plants, daily brisk walking, and stress reduction measurably lowers blood pressure in just weeks.',
      speaker: 'Adventist Lifestyle Medicine',
      scripture: 'Proverbs 17:22',
    ),
    HealthNugget(
      day: 377,
      category: 'Trust in God',
      title: 'Clear Minds Hear the Three Angels\' Messages',
      nugget:
          'Biblical health reform prepares God\'s people with discernment, temperance, and physical endurance for the final days of earth\'s history.',
      speaker: 'Biblical Health & Stewardship',
      scripture: 'Revelation 14:7',
    ),
  ];
}
