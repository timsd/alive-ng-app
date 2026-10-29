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
  const BibleVerse(
    reference: "John 3:16",
    text: {
      "KJV":
          "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
      "NKJV":
          "For God so loved the world that He gave His only begotten Son, that whoever believes in Him should not perish but have everlasting life.",
      "NIV":
          "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.",
      "BM":
          "Nítorí Ọlọ́run fẹ́ aráyé tó bẹ́ẹ̀ gẹ́gẹ́, tí ó fi Ọmọ bíbí rẹ̀ kanṣoṣo fúnni, kí ẹnikẹ́ni tí ó bá gbà á gbọ́ má bàa ṣègbé, ṣùgbọ́n kí ó lè ní ìyè àìnípẹ̀kun.",
      "yo":
          "Nítorí Ọlọ́run fẹ́ aráyé tó bẹ́ẹ̀ gẹ́gẹ́, tí ó fi Ọmọ bíbí rẹ̀ kanṣoṣo fúnni, kí ẹnikẹ́ni tí ó bá gbà á gbọ́ má bàa ṣègbé, ṣùgbọ́n kí ó lè ní ìyè àìnípẹ̀kun.",
      "HAU":
          "Gama Allah ya yi ƙaunar duniya har ya ba da makaɗaicin Ɗansa, domin duk wanda ya gaskata da shi kada ya halaka, sai dai ya sami rai na har abada.",
      "ha":
          "Gama Allah ya yi ƙaunar duniya har ya ba da makaɗaicin Ɗansa, domin duk wanda ya gaskata da shi kada ya halaka, sai dai ya sami rai na har abada.",
      "IGBOB":
          "N'ihi na Chineke hụrụ ụwa n'anya nke ukwuu nke na Ọ nyere Ọkpara Ọ mụrụ naanị ya, ka onye ọ bụla nke kwere na Ya wee ghara ila n'iyi, kama nwee ndụ ebighị ebi.",
      "ig":
          "N'ihi na Chineke hụrụ ụwa n'anya nke ukwuu nke na Ọ nyere Ọkpara Ọ mụrụ naanị ya, ka onye ọ bụla nke kwere na Ya wee ghara ila n'iyi, kama nwee ndụ ebighị ebi.",
    },
  ),
  const BibleVerse(
    reference: "Philippians 4:13",
    text: {
      "KJV": "I can do all things through Christ which strengtheneth me.",
      "NKJV": "I can do all things through Christ who strengthens me.",
      "NIV": "I can do all this through him who gives me strength.",
      "BM": "Mo lè ṣe ohun gbogbo nínú Kristi ẹni tí ń fún mi ní agbára.",
      "yo": "Mo lè ṣe ohun gbogbo nínú Kristi ẹni tí ń fún mi ní agbára.",
      "HAU": "Ina da ikon yin abu duka ta wurin Almasihu mai ƙarfafa ni.",
      "ha": "Ina da ikon yin abu duka ta wurin Almasihu mai ƙarfafa ni.",
      "IGBOB": "Enwere m ike ime ihe niile site na Kraịst Onye na-eme ka m sie ike.",
      "ig": "Enwere m ike ime ihe niile site na Kraịst Onye na-eme ka m sie ike.",
    },
  ),
  const BibleVerse(
    reference: "Jeremiah 29:11",
    text: {
      "KJV":
          "For I know the thoughts that I think toward you, saith the Lord, thoughts of peace, and not of evil, to give you an expected end.",
      "NKJV":
          "For I know the thoughts that I think toward you, says the Lord, thoughts of peace and not of evil, to give you a future and a hope.",
      "NIV":
          "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, to give you hope and a future.",
      "BM":
          "Nítorí èmi mọ èrò tí mo rò sí yín, ni Olúwa wí, èrò àlàáfíà, kì í ṣe ti ibi, láti fún yín ní ìrètí ní ìkẹyìn.",
      "yo":
          "Nítorí èmi mọ èrò tí mo rò sí yín, ni Olúwa wí, èrò àlàáfíà, kì í ṣe ti ibi, láti fún yín ní ìrètí ní ìkẹyìn.",
      "HAU":
          "Gama na san dukan shirin da na yi dominku, in ji Ubangiji, shirin alheri ne, ba na cuta ba, domin in ba ku bege a nan gaba.",
      "ha":
          "Gama na san dukan shirin da na yi dominku, in ji Ubangiji, shirin alheri ne, ba na cuta ba, domin in ba ku bege a nan gaba.",
      "IGBOB":
          "N'ihi na amaara m atụmatụ ndị M na-atụrụ unu, ka Onye-nwe na-ekwupụta, atụmatụ nke udo ọ bụghị nke ihe ọjọọ, inye unu ọdịnihu na olileanya.",
      "ig":
          "N'ihi na amaara m atụmatụ ndị M na-atụrụ unu, ka Onye-nwe na-ekwupụta, atụmatụ nke udo ọ bụghị nke ihe ọjọọ, inye unu ọdịnihu na olileanya.",
    },
  ),
  const BibleVerse(
    reference: "Romans 8:28",
    text: {
      "KJV":
          "And we know that all things work together for good to them that love God, to them who are the called according to his purpose.",
      "NKJV":
          "And we know that all things work together for good to those who love God, to those who are the called according to His purpose.",
      "NIV":
          "And we know that in all things God works for the good of those who love him, who have been called according to his purpose.",
      "BM":
          "Àwa sì mọ̀ pé gbogbo nǹkan ló ń ṣiṣẹ́ pọ̀ fún rere àwọn tí ó fẹ́ràn Ọlọ́run, àwọn tí a pè gẹ́gẹ́ bí ète Rẹ̀.",
      "yo":
          "Àwa sì mọ̀ pé gbogbo nǹkan ló ń ṣiṣẹ́ pọ̀ fún rere àwọn tí ó fẹ́ràn Ọlọ́run, àwọn tí a pè gẹ́gẹ́ bí ète Rẹ̀.",
      "HAU":
          "Mun sani kuma cewa cikin dukan abu Allah yana aiki domin amfanin waɗanda suke ƙaunarsa, waɗanda aka kira bisa ga nufinsa.",
      "ha":
          "Mun sani kuma cewa cikin dukan abu Allah yana aiki domin amfanin waɗanda suke ƙaunarsa, waɗanda aka kira bisa ga nufinsa.",
      "IGBOB":
          "Anyị makwaara na n'ihe niile, Chineke na-arụkọ ọrụ maka ọdịmma nke ndị hụrụ Ya n'anya, bụ ndị a kpọrọ dịka nzube Ya si dị.",
      "ig":
          "Anyị makwaara na n'ihe niile, Chineke na-arụkọ ọrụ maka ọdịmma nke ndị hụrụ Ya n'anya, bụ ndị a kpọrọ dịka nzube Ya si dị.",
    },
  ),
  const BibleVerse(
    reference: "Proverbs 3:5-6",
    text: {
      "KJV":
          "Trust in the Lord with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths.",
      "NKJV":
          "Trust in the Lord with all your heart, And lean not on your own understanding; In all your ways acknowledge Him, And He shall direct your paths.",
      "NIV":
          "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.",
      "BM":
          "Fi gbogbo àyà rẹ gbẹ́kẹ̀lé Olúwa; má sì ṣe tẹríba sí òye ti ara rẹ. Ní gbogbo ọ̀nà rẹ mọ̀ Ọ́n, Òun yóò sì tọ́ ipa-ọ̀nà rẹ.",
      "yo":
          "Fi gbogbo àyà rẹ gbẹ́kẹ̀lé Olúwa; má sì ṣe tẹríba sí òye ti ara rẹ. Ní gbogbo ọ̀nà rẹ mọ̀ Ọ́n, Òun yóò sì tọ́ ipa-ọ̀nà rẹ.",
      "HAU":
          "Ka dogara ga Ubangiji da dukan zuciyarka, kada ka jingina ga basirarka. Ka shaida shi a dukan al'amuranka, shi kuma zai daidaita tafarkinka.",
      "ha":
          "Ka dogara ga Ubangiji da dukan zuciyarka, kada ka jingina ga basirarka. Ka shaida shi a dukan al'amuranka, shi kuma zai daidaita tafarkinka.",
      "IGBOB":
          "Tụkwasị Onye-nwe obi gị niile; adaberekwala na nghọta nke onwe gị. N'ụzọ gị niile mara Ya, Ọ ga-eduzi ụzọ gị niile.",
      "ig":
          "Tụkwasị Onye-nwe obi gị niile; adaberekwala na nghọta nke onwe gị. N'ụzọ gị niile mara Ya, Ọ ga-eduzi ụzọ gị niile.",
    },
  ),
  const BibleVerse(
    reference: "Isaiah 40:31",
    text: {
      "KJV":
          "But they that wait upon the Lord shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.",
      "NKJV":
          "But those who wait on the Lord Shall renew their strength; They shall mount up with wings like eagles, They shall run and not be weary, They shall walk and not faint.",
      "NIV":
          "But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.",
      "BM":
          "Ṣùgbọ́n àwọn tí ó dúró de Olúwa yóò sọ agbára wọn di ọ̀tun; wọn yóò fi ìyẹ́ fò bí idì; wọn yóò sáré, kì yóò sì rẹ̀ wọ́n; wọn yóò rìn, agara kì yóò sì dá wọn.",
      "yo":
          "Ṣùgbọ́n àwọn tí ó dúró de Olúwa yóò sọ agbára wọn di ọ̀tun; wọn yóò fi ìyẹ́ fò bí idì; wọn yóò sáré, kì yóò sì rẹ̀ wọ́n; wọn yóò rìn, agara kì yóò sì dá wọn.",
      "HAU":
          "Amma masu jiran Ubangiji za su sabunta ƙarfinsu; za su tashi da fuka-fuki kamar gaggafa; za su yi gudu, ba za su gaji ba; za su yi tafiya, ba za su suma ba.",
      "ha":
          "Amma masu jiran Ubangiji za su sabunta ƙarfinsu; za su tashi da fuka-fuki kamar gaggafa; za su yi gudu, ba za su gaji ba; za su yi tafiya, ba za su suma ba.",
      "IGBOB":
          "Ma ndị na-echere Onye-nwe ga-enwe ume ọhụrụ; ha ga-eji nku feba elu dị ka ugo; ha ga-agba ọsọ, ma ike agaghị agwụ ha; ha ga-eje ije, ma ha agaghị ada mba.",
      "ig":
          "Ma ndị na-echere Onye-nwe ga-enwe ume ọhụrụ; ha ga-eji nku feba elu dị ka ugo; ha ga-agba ọsọ, ma ike agaghị agwụ ha; ha ga-eje ije, ma ha agaghị ada mba.",
    },
  ),
  const BibleVerse(
    reference: "Psalm 23:1",
    text: {
      "KJV": "The Lord is my shepherd; I shall not want.",
      "NKJV": "The Lord is my shepherd; I shall not want.",
      "NIV": "The Lord is my shepherd, I lack nothing.",
      "BM": "Olúwa ni olùṣọ́-àgùntàn mi; èmi kì yóò ṣe aláìní.",
      "yo": "Olúwa ni olùṣọ́-àgùntàn mi; èmi kì yóò ṣe aláìní.",
      "HAU": "Ubangiji shi ne makiyayina, ba zan rasa kome ba.",
      "ha": "Ubangiji shi ne makiyayina, ba zan rasa kome ba.",
      "IGBOB": "Onye-nwe bụ onye ọzụzụ atụrụ m; ihe agaghị akọ m.",
      "ig": "Onye-nwe bụ onye ọzụzụ atụrụ m; ihe agaghị akọ m.",
    },
  ),
];
