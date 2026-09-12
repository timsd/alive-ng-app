import '../constants/bible_verses.dart' show BibleVerse;
import '../constants/daily_verses.dart' as daily_data;
import '../utils/search_utils.dart';

/// BibleSource provides a unified interface for accessing Bible verses
/// from the bundled corpus, expanded topical references, and remote sources.
class BibleSource {
  BibleSource._();
  static final BibleSource instance = BibleSource._();

  /// Bundled daily verses corpus
  List<BibleVerse> get dailyCorpus => _allVerses;

  /// Expanded topical and thematic Bible verse corpus
  static final List<BibleVerse> _expandedCorpus = [
    const BibleVerse(
      reference: "Genesis 1:1",
      text: {
        "KJV": "In the beginning God created the heaven and the earth.",
        "NKJV": "In the beginning God created the heavens and the earth.",
        "NIV": "In the beginning God created the heavens and the earth.",
      },
    ),
    const BibleVerse(
      reference: "Genesis 1:3",
      text: {
        "KJV": "And God said, Let there be light: and there was light.",
        "NKJV": "Then God said, \"Let there be light\"; and there was light.",
        "NIV": "And God said, \"Let there be light,\" and there was light.",
      },
    ),
    const BibleVerse(
      reference: "Psalm 23:1",
      text: {
        "KJV": "The Lord is my shepherd; I shall not want.",
        "NKJV": "The Lord is my shepherd; I shall not want.",
        "NIV": "The Lord is my shepherd, I lack nothing.",
      },
    ),
    const BibleVerse(
      reference: "Psalm 23:4",
      text: {
        "KJV": "Yea, though I walk through the valley of the shadow of death, I will fear no evil: for thou art with me; thy rod and thy staff they comfort me.",
        "NKJV": "Yea, though I walk through the valley of the shadow of death, I will fear no evil; for You are with me; Your rod and Your staff, they comfort me.",
        "NIV": "Even though I walk through the darkest valley, I will fear no evil, for you are with me; your rod and your staff, they comfort me.",
      },
    ),
    const BibleVerse(
      reference: "Psalm 27:1",
      text: {
        "KJV": "The Lord is my light and my salvation; whom shall I fear? the Lord is the strength of my life; of whom shall I be afraid?",
        "NKJV": "The Lord is my light and my salvation; Whom shall I fear? The Lord is the strength of my life; Of whom shall I be afraid?",
        "NIV": "The Lord is my light and my salvation—whom shall I fear? The Lord is the stronghold of my life—of whom shall I be afraid?",
      },
    ),
    const BibleVerse(
      reference: "Psalm 46:1",
      text: {
        "KJV": "God is our refuge and strength, a very present help in trouble.",
        "NKJV": "God is our refuge and strength, A very present help in trouble.",
        "NIV": "God is our refuge and strength, an ever-present help in trouble.",
      },
    ),
    const BibleVerse(
      reference: "Psalm 46:10",
      text: {
        "KJV": "Be still, and know that I am God: I will be exalted among the heathen, I will be exalted in the earth.",
        "NKJV": "Be still, and know that I am God; I will be exalted among the nations, I will be exalted in the earth!",
        "NIV": "He says, \"Be still, and know that I am God; I will be exalted among the nations, I will be exalted in the earth.\"",
      },
    ),
    const BibleVerse(
      reference: "Psalm 91:1-2",
      text: {
        "KJV": "He that dwelleth in the secret place of the most High shall abide under the shadow of the Almighty. I will say of the Lord, He is my refuge and my fortress: my God; in him will I trust.",
        "NKJV": "He who dwells in the secret place of the Most High Shall abide under the shadow of the Almighty. I will say of the Lord, \"He is my refuge and my fortress; My God, in Him I will trust.\"",
        "NIV": "Whoever dwells in the shelter of the Most High will rest in the shadow of the Almighty. I will say of the Lord, \"He is my refuge and my fortress, my God, in whom I trust.\"",
      },
    ),
    const BibleVerse(
      reference: "Psalm 119:105",
      text: {
        "KJV": "Thy word is a lamp unto my feet, and a light unto my path.",
        "NKJV": "Your word is a lamp to my feet And a light to my path.",
        "NIV": "Your word is a lamp for my feet, a light on my path.",
      },
    ),
    const BibleVerse(
      reference: "Psalm 121:1-2",
      text: {
        "KJV": "I will lift up mine eyes unto the hills, from whence cometh my help. My help cometh from the Lord, which made heaven and earth.",
        "NKJV": "I will lift up my eyes to the hills— From whence comes my help? My help comes from the Lord, Who made heaven and earth.",
        "NIV": "I lift up my eyes to the mountains—where does my help come from? My help comes from the Lord, the Maker of heaven and earth.",
      },
    ),
    const BibleVerse(
      reference: "Proverbs 3:5-6",
      text: {
        "KJV": "Trust in the Lord with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths.",
        "NKJV": "Trust in the Lord with all your heart, And lean not on your own understanding; In all your ways acknowledge Him, And He shall direct your paths.",
        "NIV": "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.",
      },
    ),
    const BibleVerse(
      reference: "Proverbs 18:10",
      text: {
        "KJV": "The name of the Lord is a strong tower: the righteous runneth into it, and is safe.",
        "NKJV": "The name of the Lord is a strong tower; The righteous run to it and are safe.",
        "NIV": "The name of the Lord is a fortified tower; the righteous run to it and are safe.",
      },
    ),
    const BibleVerse(
      reference: "Isaiah 40:29",
      text: {
        "KJV": "He giveth power to the faint; and to them that have no might he increaseth strength.",
        "NKJV": "He gives power to the weak, And to those who have no might He increases strength.",
        "NIV": "He gives strength to the weary and increases the power of the weak.",
      },
    ),
    const BibleVerse(
      reference: "Isaiah 40:31",
      text: {
        "KJV": "But they that wait upon the Lord shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.",
        "NKJV": "But those who wait on the Lord Shall renew their strength; They shall mount up with wings like eagles, They shall run and not be weary, They shall walk and not faint.",
        "NIV": "But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.",
      },
    ),
    const BibleVerse(
      reference: "Isaiah 41:10",
      text: {
        "KJV": "Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee; yea, I will uphold thee with the right hand of my righteousness.",
        "NKJV": "Fear not, for I am with you; Be not dismayed, for I am your God. I will strengthen you, Yes, I will help you, I will uphold you with My righteous right hand.",
        "NIV": "So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand.",
      },
    ),
    const BibleVerse(
      reference: "Isaiah 53:5",
      text: {
        "KJV": "But he was wounded for our transgressions, he was bruised for our iniquities: the chastisement of our peace was upon him; and with his stripes we are healed.",
        "NKJV": "But He was wounded for our transgressions, He was bruised for our iniquities; The chastisement for our peace was upon Him, And by His stripes we are healed.",
        "NIV": "But he was pierced for our transgressions, he was crushed for our iniquities; the punishment that brought us peace was on him, and by his wounds we are healed.",
      },
    ),
    const BibleVerse(
      reference: "Jeremiah 29:11",
      text: {
        "KJV": "For I know the thoughts that I think toward you, saith the Lord, thoughts of peace, and not of evil, to give you an expected end.",
        "NKJV": "For I know the thoughts that I think toward you, says the Lord, thoughts of peace and not of evil, to give you a future and a hope.",
        "NIV": "\"For I know the plans I have for you,\" declares the Lord, \"plans to prosper you and not to harm you, plans to give you hope and a future.\"",
      },
    ),
    const BibleVerse(
      reference: "Matthew 6:33",
      text: {
        "KJV": "But seek ye first the kingdom of God, and his righteousness; and all these things shall be added unto you.",
        "NKJV": "But seek first the kingdom of God and His righteousness, and all these things shall be added to you.",
        "NIV": "But seek first his kingdom and his righteousness, and all these things will be given to you as well.",
      },
    ),
    const BibleVerse(
      reference: "Matthew 11:28",
      text: {
        "KJV": "Come unto me, all ye that labour and are heavy laden, and I will give you rest.",
        "NKJV": "Come to Me, all you who labor and are heavy laden, and I will give you rest.",
        "NIV": "Come to me, all you who are weary and burdened, and I will give you rest.",
      },
    ),
    const BibleVerse(
      reference: "Matthew 28:19-20",
      text: {
        "KJV": "Go ye therefore, and teach all nations, baptizing them in the name of the Father, and of the Son, and of the Holy Ghost: Teaching them to observe all things whatsoever I have commanded you: and, lo, I am with you alway, even unto the end of the world.",
        "NKJV": "Go therefore and make disciples of all the nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit, teaching them to observe all things that I have commanded you; and lo, I am with you always, even to the end of the age.",
        "NIV": "Therefore go and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit, and teaching them to obey everything I have commanded you. And surely I am with you always, to the very end of the age.",
      },
    ),
    const BibleVerse(
      reference: "John 1:1",
      text: {
        "KJV": "In the beginning was the Word, and the Word was with God, and the Word was God.",
        "NKJV": "In the beginning was the Word, and the Word was with God, and the Word was God.",
        "NIV": "In the beginning was the Word, and the Word was with God, and the Word was God.",
      },
    ),
    const BibleVerse(
      reference: "John 3:16",
      text: {
        "KJV": "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
        "NKJV": "For God so loved the world that He gave His only begotten Son, that whoever believes in Him should not perish but have everlasting life.",
        "NIV": "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.",
      },
    ),
    const BibleVerse(
      reference: "John 14:1-3",
      text: {
        "KJV": "Let not your heart be troubled: ye believe in God, believe also in me. In my Father's house are many mansions: if it were not so, I would have told you. I go to prepare a place for you. And if I go and prepare a place for you, I will come again, and receive you unto myself; that where I am, there ye may be also.",
        "NKJV": "Let not your heart be troubled; you believe in God, believe also in Me. In My Father's house are many mansions; if it were not so, I would have told you. I go to prepare a place for you. And if I go and prepare a place for you, I will come again and receive you to Myself; that where I am, there you may be also.",
        "NIV": "\"Do not let your hearts be troubled. You believe in God; believe also in me. My Father's house has many rooms; if that were not so, would I have told you that I am going there to prepare a place for you? And if I go and prepare a place for you, I will come back and take you to be with me that you also may be where I am.\"",
      },
    ),
    const BibleVerse(
      reference: "John 14:6",
      text: {
        "KJV": "Jesus saith unto him, I am the way, the truth, and the life: no man cometh unto the Father, but by me.",
        "NKJV": "Jesus said to him, \"I am the way, the truth, and the life. No one comes to the Father except through Me.\"",
        "NIV": "Jesus answered, \"I am the way and the truth and the life. No one comes to the Father except through me.\"",
      },
    ),
    const BibleVerse(
      reference: "John 14:27",
      text: {
        "KJV": "Peace I leave with you, my peace I give unto you: not as the world giveth, give I unto you. Let not your heart be troubled, neither let it be afraid.",
        "NKJV": "Peace I leave with you, My peace I give to you; not as the world gives do I give to you. Let not your heart be troubled, neither let it be afraid.",
        "NIV": "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.",
      },
    ),
    const BibleVerse(
      reference: "Romans 8:28",
      text: {
        "KJV": "And we know that all things work together for good to them that love God, to them who are the called according to his purpose.",
        "NKJV": "And we know that all things work together for good to those who love God, to those who are the called according to His purpose.",
        "NIV": "And we know that in all things God works for the good of those who love him, who have been called according to his purpose.",
      },
    ),
    const BibleVerse(
      reference: "Romans 8:38-39",
      text: {
        "KJV": "For I am persuaded, that neither death, nor life, nor angels, nor principalities, nor powers, nor things present, nor things to come, Nor height, nor depth, nor any other creature, shall be able to separate us from the love of God, which is in Christ Jesus our Lord.",
        "NKJV": "For I am persuaded that neither death nor life, nor angels nor principalities nor powers, nor things present nor things to come, nor height nor depth, nor any other created thing, shall be able to separate us from the love of God which is in Christ Jesus our Lord.",
        "NIV": "For I am convinced that neither death nor life, neither angels nor demons, neither the present nor the future, nor any powers, neither height nor depth, nor anything else in all creation, will be able to separate us from the love of God that is in Christ Jesus our Lord.",
      },
    ),
    const BibleVerse(
      reference: "Romans 12:1-2",
      text: {
        "KJV": "I beseech you therefore, brethren, by the mercies of God, that ye present your bodies a living sacrifice, holy, acceptable unto God, which is your reasonable service. And be not conformed to this world: but be ye transformed by the renewing of your mind.",
        "NKJV": "I beseech you therefore, brethren, by the mercies of God, that you present your bodies a living sacrifice, holy, acceptable to God, which is your reasonable service. And do not be conformed to this world, but be transformed by the renewing of your mind.",
        "NIV": "Therefore, I urge you, brothers and sisters, in view of God's mercy, to offer your bodies as a living sacrifice, holy and pleasing to God—this is your true and proper worship. Do not conform to the pattern of this world, but be transformed by the renewing of your mind.",
      },
    ),
    const BibleVerse(
      reference: "Galatians 5:22-23",
      text: {
        "KJV": "But the fruit of the Spirit is love, joy, peace, longsuffering, gentleness, goodness, faith, Meekness, temperance: against such there is no law.",
        "NKJV": "But the fruit of the Spirit is love, joy, peace, longsuffering, kindness, goodness, faithfulness, gentleness, self-control. Against such there is no law.",
        "NIV": "But the fruit of the Spirit is love, joy, peace, forbearance, kindness, goodness, faithfulness, gentleness and self-control. Against such things there is no law.",
      },
    ),
    const BibleVerse(
      reference: "Ephesians 2:8-9",
      text: {
        "KJV": "For by grace are ye saved through faith; and that not of yourselves: it is the gift of God: Not of works, lest any man should boast.",
        "NKJV": "For by grace you have been saved through faith, and that not of yourselves; it is the gift of God, not of works, lest anyone should boast.",
        "NIV": "For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—not by works, so that no one can boast.",
      },
    ),
    const BibleVerse(
      reference: "Philippians 4:6-7",
      text: {
        "KJV": "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God. And the peace of God, which passeth all understanding, shall keep your hearts and minds through Christ Jesus.",
        "NKJV": "Be anxious for nothing, but in everything by prayer and supplication, with thanksgiving, let your requests be made known to God; and the peace of God, which surpasses all understanding, will guard your hearts and minds through Christ Jesus.",
        "NIV": "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.",
      },
    ),
    const BibleVerse(
      reference: "Philippians 4:13",
      text: {
        "KJV": "I can do all things through Christ which strengtheneth me.",
        "NKJV": "I can do all things through Christ who strengthens me.",
        "NIV": "I can do all this through him who gives me strength.",
      },
    ),
    const BibleVerse(
      reference: "Hebrews 11:1",
      text: {
        "KJV": "Now faith is the substance of things hoped for, the evidence of things not seen.",
        "NKJV": "Now faith is the substance of things hoped for, the evidence of things not seen.",
        "NIV": "Now faith is confidence in what we hope for and assurance about what we do not see.",
      },
    ),
    const BibleVerse(
      reference: "Hebrews 12:1-2",
      text: {
        "KJV": "Wherefore seeing we also are compassed about with so great a cloud of witnesses, let us lay aside every weight, and the sin which doth so easily beset us, and let us run with patience the race that is set before us, Looking unto Jesus the author and finisher of our faith.",
        "NKJV": "Therefore we also, since we are surrounded by so great a cloud of witnesses, let us lay aside every weight, and the sin which so easily ensnares us, and let us run with endurance the race that is set before us, looking unto Jesus, the author and finisher of our faith.",
        "NIV": "Therefore, since we are surrounded by such a great cloud of witnesses, let us throw off everything that hinders and the sin that so easily entangles. And let us run with perseverance the race marked out for us, fixing our eyes on Jesus, the pioneer and perfecter of faith.",
      },
    ),
    const BibleVerse(
      reference: "Revelation 21:4",
      text: {
        "KJV": "And God shall wipe away all tears from their eyes; and there shall be no more death, neither sorrow, nor crying, neither shall there be any more pain: for the former things are passed away.",
        "NKJV": "And God will wipe away every tear from their eyes; there shall be no more death, nor sorrow, nor crying. There shall be no more pain, for the former things have passed away.",
        "NIV": "\"He will wipe every tear from their eyes. There will be no more death or mourning or crying or pain, for the old order of things has passed away.\"",
      },
    ),
    const BibleVerse(
      reference: "Revelation 22:20",
      text: {
        "KJV": "He which testifieth these things saith, Surely I come quickly. Amen. Even so, come, Lord Jesus.",
        "NKJV": "He who testifies to these things says, \"Surely I am coming quickly.\" Amen. Even so, come, Lord Jesus!",
        "NIV": "He who testifies to these things says, \"Yes, I am coming soon.\" Amen. Come, Lord Jesus.",
      },
    ),
  ];

  static List<BibleVerse> get _allVerses {
    final list = <BibleVerse>[];
    final seen = <String>{};
    for (final v in daily_data.dailyVerses) {
      final key = v.reference.toLowerCase();
      if (seen.add(key)) list.add(v);
    }
    for (final v in _expandedCorpus) {
      final key = v.reference.toLowerCase();
      if (seen.add(key)) list.add(v);
    }
    return list;
  }

  static final Map<String, List<String>> _topicalThemes = {
    'love': [
      'john 3:16',
      '1 corinthians 13:4-8',
      '1 corinthians 13:13',
      '1 john 4:7-8',
      'romans 5:8',
      '1 john 4:19',
    ],
    'faith': [
      'hebrews 11:1',
      'hebrews 11:6',
      'romans 10:17',
      '2 corinthians 5:7',
      'ephesians 2:8-9',
      'proverbs 3:5-6',
    ],
    'hope': [
      'jeremiah 29:11',
      'romans 15:13',
      'isaiah 40:31',
      'psalm 42:11',
      '1 peter 1:3',
    ],
    'peace': [
      'john 14:27',
      'philippians 4:6-7',
      'isaiah 26:3',
      'psalm 29:11',
      'matthew 11:28-30',
    ],
    'prayer': [
      'philippians 4:6',
      '1 thessalonians 5:17',
      'matthew 6:9-13',
      'james 5:16',
      'mark 11:24',
    ],
    'strength': [
      'philippians 4:13',
      'isaiah 40:29',
      'psalm 46:1',
      'psalm 28:7',
      'ephesians 6:10',
    ],
    'comfort': [
      'psalm 23:4',
      '2 corinthians 1:3-4',
      'matthew 5:4',
      'psalm 34:18',
      'revelation 21:4',
    ],
    'forgiveness': [
      '1 john 1:9',
      'ephesians 4:32',
      'colossians 3:13',
      'psalm 103:12',
      'matthew 6:14-15',
    ],
    'salvation': [
      'john 3:16',
      'romans 10:9',
      'acts 4:12',
      'ephesians 2:8-9',
      'titus 3:5',
    ],
    'grace': [
      'ephesians 2:8-9',
      '2 corinthians 12:9',
      'hebrews 4:16',
      'romans 6:14',
      'john 1:16',
    ],
    'wisdom': [
      'james 1:5',
      'proverbs 9:10',
      'proverbs 3:13',
      'colossians 3:16',
      'ecclesiastes 7:12',
    ],
    'healing': [
      'jeremiah 17:14',
      'james 5:14-15',
      'isaiah 53:5',
      'psalm 103:2-3',
      '1 peter 2:24',
    ],
    'trust': [
      'proverbs 3:5-6',
      'psalm 56:3',
      'psalm 37:5',
      'psalm 62:8',
      'nahum 1:7',
    ],
    'light': [
      'psalm 119:105',
      'john 8:12',
      'matthew 5:14-16',
      'genesis 1:3',
      '1 john 1:5',
    ],
    'courage': [
      'joshua 1:9',
      'psalm 27:1',
      'deuteronomy 31:6',
      '1 corinthians 16:13',
      'isaiah 41:10',
    ],
    'fear': [
      'psalm 23:4',
      'psalm 27:1',
      'isaiah 41:10',
      '2 timothy 1:7',
      'psalm 56:3',
    ],
    'joy': [
      'psalm 16:11',
      'nehemiah 8:10',
      'romans 15:13',
      'galatians 5:22-23',
      'james 1:2-3',
    ],
  };

  /// Returns true if the verse or reference belongs to a genealogical passage.
  static bool isGenealogy({
    String? reference,
    String? text,
  }) {
    final ref = (reference ?? '').toLowerCase();

    // Prominent biblical genealogy chapters & passages across the 66 books:
    if (ref.startsWith('genesis 5')) return true;
    if (ref.startsWith('genesis 10')) return true;
    if (ref.startsWith('genesis 11') && !ref.startsWith('genesis 11:1-9')) {
      return true;
    }
    if (ref.startsWith('genesis 36')) return true;
    if (ref.startsWith('numbers 1:') || ref == 'numbers 1') return true;
    if (ref.startsWith('numbers 26')) return true;
    for (var i = 1; i <= 9; i++) {
      if (ref.startsWith('1 chronicles $i:') ||
          ref == '1 chronicles $i' ||
          ref.startsWith('1 chron $i')) {
        return true;
      }
    }
    if (ref.startsWith('ezra 2') || ref.startsWith('nehemiah 7')) return true;
    if (ref.startsWith('matthew 1') &&
        (ref.contains(':1') ||
            ref.contains(':2') ||
            ref.contains(':3') ||
            ref.contains(':4') ||
            ref.contains(':5') ||
            ref.contains(':6') ||
            ref.contains(':7') ||
            ref.contains(':8') ||
            ref.contains(':9') ||
            ref.contains(':10') ||
            ref.contains(':11') ||
            ref.contains(':12') ||
            ref.contains(':13') ||
            ref.contains(':14') ||
            ref.contains(':15') ||
            ref.contains(':16') ||
            ref.contains(':17'))) {
      return true;
    }
    if (ref.startsWith('luke 3') &&
        (ref.contains(':23') ||
            ref.contains(':24') ||
            ref.contains(':25') ||
            ref.contains(':26') ||
            ref.contains(':27') ||
            ref.contains(':28') ||
            ref.contains(':29') ||
            ref.contains(':30') ||
            ref.contains(':31') ||
            ref.contains(':32') ||
            ref.contains(':33') ||
            ref.contains(':34') ||
            ref.contains(':35') ||
            ref.contains(':36') ||
            ref.contains(':37') ||
            ref.contains(':38'))) {
      return true;
    }

    // Textual genealogy patterns:
    if (text != null && text.isNotEmpty) {
      final t = text.toLowerCase();
      if (t.contains('begat') ||
          t.contains('which was the son of') ||
          t.contains('these are the generations of')) {
        return true;
      }
      final sonOfCount = t.split('the son of').length - 1;
      if (sonOfCount >= 2) return true;
    }

    return false;
  }

  /// Corpus excluding genealogies for games and quizzes
  List<BibleVerse> get nonGenealogyCorpus => dailyCorpus
      .where((v) => !isGenealogy(
            reference: v.reference,
            text: v.text.values.first,
          ))
      .toList();

  /// Find a verse by reference in the bundled corpus
  BibleVerse? findByReference(String reference) {
    final clean = reference.trim().toLowerCase();
    for (final verse in dailyCorpus) {
      if (verse.reference.toLowerCase() == clean) {
        return verse;
      }
    }
    return null;
  }

  /// Search standard (shared with SearchUtils): exact reference first, then
  /// exact phrase ("jesus wept" -> John 11:35), then ALL-words, then ANY-word.
  List<BibleVerse> search(String query) {
    final phrase = SearchUtils.normalize(query);
    if (phrase.isEmpty) return [];

    final words = SearchUtils.tokensOf(query);

    final seenRefs = <String>{};
    final results = <BibleVerse>[];

    void addVerse(BibleVerse verse) {
      final key = verse.reference.toLowerCase();
      if (seenRefs.add(key)) {
        results.add(verse);
      }
    }

    // 1. Exact Reference Match
    for (final verse in dailyCorpus) {
      if (SearchUtils.normalize(verse.reference) == phrase) {
        addVerse(verse);
      }
    }

    // 2. Partial Reference Match (e.g. "John 3", "Psalm 23")
    for (final verse in dailyCorpus) {
      if (SearchUtils.normalize(verse.reference).contains(phrase)) {
        addVerse(verse);
      }
    }

    // 3. Full Phrase in Verse Text ("jesus wept" matches John 11:35)
    for (final verse in dailyCorpus) {
      final allTexts = verse.text.values.map(SearchUtils.normalize).toList();
      if (allTexts.any((t) => t.contains(phrase))) {
        addVerse(verse);
      }
    }

    // 4. Thematic / Topical Matches (e.g., search "faith", "love", "peace", "hope")
    for (final entry in _topicalThemes.entries) {
      final topic = entry.key;
      if (phrase.contains(topic) ||
          topic.contains(phrase) ||
          words.contains(topic)) {
        for (final ref in entry.value) {
          final matchedVerse = findByReference(ref);
          if (matchedVerse != null) {
            addVerse(matchedVerse);
          }
        }
      }
    }

    // 5. Multi-Word and Keyword Matches (ranked by shared scoring standard)
    if (words.isNotEmpty) {
      final scoredMatches = <MapEntry<BibleVerse, int>>[];

      for (final verse in dailyCorpus) {
        if (seenRefs.contains(verse.reference.toLowerCase())) continue;

        final score = SearchUtils.scoreVerse(
          reference: verse.reference,
          text: verse.text.values.join(' '),
          query: query,
        );

        if (score > 0) {
          scoredMatches.add(MapEntry(verse, score));
        }
      }

      scoredMatches.sort((a, b) => b.value.compareTo(a.value));
      for (final entry in scoredMatches) {
        addVerse(entry.key);
      }
    }

    return results;
  }

  /// Get a random verse from the corpus (excluding genealogies by default)
  BibleVerse? randomVerse({bool excludeGenealogy = true}) {
    final pool = excludeGenealogy ? nonGenealogyCorpus : dailyCorpus;
    if (pool.isEmpty) return null;
    final verses = List<BibleVerse>.of(pool)..shuffle();
    return verses.first;
  }
}
