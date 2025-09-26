class BibleVerse {
  final String reference;
  final Map<String, String> text;

  const BibleVerse({
    required this.reference,
    required this.text,
  });

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      reference: json['reference'] as String,
      text: Map<String, String>.from(json['text'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reference': reference,
      'text': text,
    };
  }
}

final List<BibleVerse> dailyVerses = [
  BibleVerse(
    reference: "John 3:16",
    text: {
      "KJV":
          "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
      "NKJV":
          "For God so loved the world that He gave His only begotten Son, that whoever believes in Him should not perish but have everlasting life.",
      "NIV":
          "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life."
    },
  ),
  BibleVerse(
    reference: "Philippians 4:13",
    text: {
      "KJV": "I can do all things through Christ which strengtheneth me.",
      "NKJV": "I can do all things through Christ who strengthens me.",
      "NIV": "I can do all this through him who gives me strength."
    },
  ),
  BibleVerse(
    reference: "Jeremiah 29:11",
    text: {
      "KJV":
          "For I know the thoughts that I think toward you, saith the Lord, thoughts of peace, and not of evil, to give you an expected end.",
      "NKJV":
          "For I know the thoughts that I think toward you, says the Lord, thoughts of peace and not of evil, to give you a future and a hope.",
      "NIV":
          "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, to give you hope and a future."
    },
  ),
  BibleVerse(
    reference: "Romans 8:28",
    text: {
      "KJV":
          "And we know that all things work together for good to them that love God, to them who are the called according to his purpose.",
      "NKJV":
          "And we know that all things work together for good to those who love God, to those who are the called according to His purpose.",
      "NIV":
          "And we know that in all things God works for the good of those who love him, who have been called according to his purpose."
    },
  ),
  BibleVerse(
    reference: "Proverbs 3:5-6",
    text: {
      "KJV":
          "Trust in the Lord with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths.",
      "NKJV":
          "Trust in the Lord with all your heart, And lean not on your own understanding; In all your ways acknowledge Him, And He shall direct your paths.",
      "NIV":
          "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight."
    },
  ),
  BibleVerse(
    reference: "Isaiah 40:31",
    text: {
      "KJV":
          "But they that wait upon the Lord shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.",
      "NKJV":
          "But those who wait on the Lord Shall renew their strength; They shall mount up with wings like eagles, They shall run and not be weary, They shall walk and not faint.",
      "NIV":
          "But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint."
    },
  ),
  BibleVerse(
    reference: "Psalm 23:1",
    text: {
      "KJV": "The Lord is my shepherd; I shall not want.",
      "NKJV": "The Lord is my shepherd; I shall not want.",
      "NIV": "The Lord is my shepherd, I lack nothing."
    },
  ),
];




