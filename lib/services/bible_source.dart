import '../constants/bible_verses.dart' show BibleVerse;
import '../constants/daily_verses.dart' as daily_data;
import '../utils/search_utils.dart';

/// BibleSource provides a unified interface for accessing Bible verses
/// from the bundled corpus, expanded topical references, and remote sources.
class BibleSource {
  BibleSource._();
  static final BibleSource instance = BibleSource._();

  /// Bundled daily verses corpus (Single Source of Truth)
  List<BibleVerse> get dailyCorpus => _allVerses;

  /// Expanded topical and thematic Bible verse corpus with authentic
  /// multilingual translations across English, Yoruba, Hausa, and Igbo.
  static final List<BibleVerse> _expandedCorpus = [
    const BibleVerse(
      reference: "Genesis 1:1",
      text: {
        "KJV": "In the beginning God created the heaven and the earth.",
        "NKJV": "In the beginning God created the heavens and the earth.",
        "NIV": "In the beginning God created the heavens and the earth.",
        "BM": "Ní ìbẹ̀rẹ̀ ohun gbogbo, Ọlọ́run dá ọ̀run àti ayé.",
        "yo": "Ní ìbẹ̀rẹ̀ ohun gbogbo, Ọlọ́run dá ọ̀run àti ayé.",
        "HAU": "A farko Allah ya halicci sammai da ƙasa.",
        "ha": "A farko Allah ya halicci sammai da ƙasa.",
        "IGBOB": "Na mmalite Chineke kere eluigwe na ụwa.",
        "ig": "Na mmalite Chineke kere eluigwe na ụwa.",
      },
    ),
    const BibleVerse(
      reference: "Genesis 1:3",
      text: {
        "KJV": "And God said, Let there be light: and there was light.",
        "NKJV": "Then God said, \"Let there be light\"; and there was light.",
        "NIV": "And God said, \"Let there be light,\" and there was light.",
        "BM": "Ọlọ́run sì wí pé, 'Jẹ́ kí ìmọ́lẹ̀ kí ó wà:' ìmọ́lẹ̀ sì wà.",
        "yo": "Ọlọ́run sì wí pé, 'Jẹ́ kí ìmọ́lẹ̀ kí ó wà:' ìmọ́lẹ̀ sì wà.",
        "HAU": "Allah kuwa ya ce, 'Bari haske ya kasance;' haske kuwa ya kasance.",
        "ha": "Allah kuwa ya ce, 'Bari haske ya kasance;' haske kuwa ya kasance.",
        "IGBOB": "Chineke wee sị, 'Ka ìhè dị;' ìhè wee dị.",
        "ig": "Chineke wee sị, 'Ka ìhè dị;' ìhè wee dị.",
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
    const BibleVerse(
      reference: "Psalm 23:4",
      text: {
        "KJV": "Yea, though I walk through the valley of the shadow of death, I will fear no evil: for thou art with me; thy rod and thy staff they comfort me.",
        "NKJV": "Yea, though I walk through the valley of the shadow of death, I will fear no evil; for You are with me; Your rod and Your staff, they comfort me.",
        "NIV": "Even though I walk through the darkest valley, I will fear no evil, for you are with me; your rod and your staff, they comfort me.",
        "BM": "Bí mo tilẹ̀ ń rìn la àfonífojì òjìji ikú já, èmi kì yóò bẹ̀rù ibi kan: nítorí tí ìwọ wà pẹ̀lú mi; ọ̀pá rẹ àti ọ̀pá-ìtìlẹ́yìn rẹ, wọ́n ń tù mí nínú.",
        "yo": "Bí mo tilẹ̀ ń rìn la àfonífojì òjìji ikú já, èmi kì yóò bẹ̀rù ibi kan: nítorí tí ìwọ wà pẹ̀lú mi; ọ̀pá rẹ àti ọ̀pá-ìtìlẹ́yìn rẹ, wọ́n ń tù mí nínú.",
        "HAU": "Ko da kuwa ina tafiya a cikin kwarin inuwar mutuwa, ba zan ji tsoron wani mugun abu ba, gama kana tare da ni, sandarka da ma'aikatanka suna ƙarfafa ni.",
        "ha": "Ko da kuwa ina tafiya a cikin kwarin inuwar mutuwa, ba zan ji tsoron wani mugun abu ba, gama kana tare da ni, sandarka da ma'aikatanka suna ƙarfafa ni.",
        "IGBOB": "Ee, ọ bụ ezie na m na-agafe na ndagwurugwu nke onyinyo ọnwụ, agaghị m atụ egwu ihe ọjọọ ọ bụla, n'ihi na gị onwe gị nọnyeere m; mkpanaka gị na mkpara gị na-akasi m obi.",
        "ig": "Ee, ọ bụ ezie na m na-agafe na ndagwurugwu nke onyinyo ọnwụ, agaghị m atụ egwu ihe ọjọọ ọ bụla, n'ihi na gị onwe gị nọnyeere m; mkpanaka gị na mkpara gị na-akasi m obi.",
      },
    ),
    const BibleVerse(
      reference: "Psalm 27:1",
      text: {
        "KJV": "The Lord is my light and my salvation; whom shall I fear? the Lord is the strength of my life; of whom shall I be afraid?",
        "NKJV": "The Lord is my light and my salvation; Whom shall I fear? The Lord is the strength of my life; Of whom shall I be afraid?",
        "NIV": "The Lord is my light and my salvation—whom shall I fear? The Lord is the stronghold of my life—of whom shall I be afraid?",
        "BM": "Olúwa ni ìmọ́lẹ̀ mi àti ìgbàlà mi; ta ni èmi yóò bẹ̀rù? Olúwa ni odi agbára ẹ̀mí mi; láti ọ̀dọ̀ ta ni èmi yóò fòyà?",
        "yo": "Olúwa ni ìmọ́lẹ̀ mi àti ìgbàlà mi; ta ni èmi yóò bẹ̀rù? Olúwa ni odi agbára ẹ̀mí mi; láti ọ̀dọ̀ ta ni èmi yóò fòyà?",
        "HAU": "Ubangiji shi ne haskena da cetona, wa zan ji tsoronsa? Ubangiji shi ne mafakar raina, wa zan firgita da shi?",
        "ha": "Ubangiji shi ne haskena da cetona, wa zan ji tsoronsa? Ubangiji shi ne mafakar raina, wa zan firgita da shi?",
        "IGBOB": "Onye-nwe bụ ìhè m na nzọpụta m; ònye ka m ga-atụ egwu? Onye-nwe bụ ebe ewusiri ike nke ndụ m; ònye ka m ga-atụ ụjọ ya?",
        "ig": "Onye-nwe bụ ìhè m na nzọpụta m; ònye ka m ga-atụ egwu? Onye-nwe bụ ebe ewusiri ike nke ndụ m; ònye ka m ga-atụ ụjọ ya?",
      },
    ),
    const BibleVerse(
      reference: "Psalm 46:1",
      text: {
        "KJV": "God is our refuge and strength, a very present help in trouble.",
        "NKJV": "God is our refuge and strength, A very present help in trouble.",
        "NIV": "God is our refuge and strength, an ever-present help in trouble.",
        "BM": "Ọlọ́run ni ààbò àti agbára wa, ìrànwọ́ tí ó wà ní àrọ́wọ́tó nígbà ìpọ́njú.",
        "yo": "Ọlọ́run ni ààbò àti agbára wa, ìrànwọ́ tí ó wà ní àrọ́wọ́tó nígbà ìpọ́njú.",
        "HAU": "Allah ne mafakarmu da ƙarfinmu, mai taimako a lokacin wahala.",
        "ha": "Allah ne mafakarmu da ƙarfinmu, mai taimako a lokacin wahala.",
        "IGBOB": "Chineke bụ ebe mgbaba anyị na ike anyị, enyemaka dị njikere mgbe niile na nsogbu.",
        "ig": "Chineke bụ ebe mgbaba anyị na ike anyị, enyemaka dị njikere mgbe niile na nsogbu.",
      },
    ),
    const BibleVerse(
      reference: "Psalm 46:10",
      text: {
        "KJV": "Be still, and know that I am God: I will be exalted among the heathen, I will be exalted in the earth.",
        "NKJV": "Be still, and know that I am God; I will be exalted among the nations, I will be exalted in the earth!",
        "NIV": "He says, \"Be still, and know that I am God; I will be exalted among the nations, I will be exalted in the earth.\"",
        "BM": "Ẹ dákẹ́ jẹ́ẹ́, kí ẹ sì mọ̀ pé èmi ni Ọlọ́run: a ó gbé mi ga láàárín àwọn orílẹ̀-èdè, a ó gbé mi ga ní ayé.",
        "yo": "Ẹ dákẹ́ jẹ́ẹ́, kí ẹ sì mọ̀ pé èmi ni Ọlọ́run: a ó gbé mi ga láàárín àwọn orílẹ̀-èdè, a ó gbé mi ga ní ayé.",
        "HAU": "Ku natsu, ku sani ni ne Allah. Za a ɗaukaka ni a cikin al'ummai, za a ɗaukaka ni a duniya.",
        "ha": "Ku natsu, ku sani ni ne Allah. Za a ɗaukaka ni a cikin al'ummai, za a ɗaukaka ni a duniya.",
        "IGBOB": "Dajụọ nwayọọ, mara na Mụ onwe m bụ Chineke; a ga-ebuli M elu n'etiti mba niile, a ga-ebuli M elu n'ụwa.",
        "ig": "Dajụọ nwayọọ, mara na Mụ onwe m bụ Chineke; a ga-ebuli M elu n'etiti mba niile, a ga-ebuli M elu n'ụwa.",
      },
    ),
    const BibleVerse(
      reference: "Psalm 91:1-2",
      text: {
        "KJV": "He that dwelleth in the secret place of the most High shall abide under the shadow of the Almighty. I will say of the Lord, He is my refuge and my fortress: my God; in him will I trust.",
        "NKJV": "He who dwells in the secret place of the Most High Shall abide under the shadow of the Almighty. I will say of the Lord, \"He is my refuge and my fortress; My God, in Him I will trust.\"",
        "NIV": "Whoever dwells in the shelter of the Most High will rest in the shadow of the Almighty. I will say of the Lord, \"He is my refuge and my fortress, my God, in whom I trust.\"",
        "BM": "Ẹni tí ó ń gbé ní ibi ìkọ̀kọ̀ Ọ̀gá-ògo yóò máa gbé ní abẹ́ òjìji Olódùmarè. Èmi ó sọ nípa Olúwa pé, 'Òun ni ààbò mi àti odi agbára mi: Ọlọ́run mi; nínú rẹ̀ ni èmi yóò gbẹ́kẹ̀lé.'",
        "yo": "Ẹni tí ó ń gbé ní ibi ìkọ̀kọ̀ Ọ̀gá-ògo yóò máa gbé ní abẹ́ òjìji Olódùmarè. Èmi ó sọ nípa Olúwa pé, 'Òun ni ààbò mi àti odi agbára mi: Ọlọ́run mi; nínú rẹ̀ ni èmi yóò gbẹ́kẹ̀lé.'",
        "HAU": "Wanda yake zama a mafakar Maɗaukaki zai zauna a ƙarƙashin inuwar Mai Iko Duka. Zan ce game da Ubangiji, 'Shi ne mafakata da kagarata, Allahna wanda nake dogara da shi.'",
        "ha": "Wanda yake zama a mafakar Maɗaukaki zai zauna a ƙarƙashin inuwar Mai Iko Duka. Zan ce game da Ubangiji, 'Shi ne mafakata da kagarata, Allahna wanda nake dogara da shi.'",
        "IGBOB": "Onye bi n'ebe zoro ezo nke Onye Kachasị Elu ga-anọgide n'okpuru ndo nke Onye Pụrụ Ime Ihe Niile. Aga m asị banyere Onye-nwe, 'Ọ bụ ebe mgbaba m na ebe ewusiri ike m: Chineke m; n'ime Ya ka m ga-atụkwasị obi.'",
        "ig": "Onye bi n'ebe zoro ezo nke Onye Kachasị Elu ga-anọgide n'okpuru ndo nke Onye Pụrụ Ime Ihe Niile. Aga m asị banyere Onye-nwe, 'Ọ bụ ebe mgbaba m na ebe ewusiri ike m: Chineke m; n'ime Ya ka m ga-atụkwasị obi.'",
      },
    ),
    const BibleVerse(
      reference: "Psalm 119:105",
      text: {
        "KJV": "Thy word is a lamp unto my feet, and a light unto my path.",
        "NKJV": "Your word is a lamp to my feet And a light to my path.",
        "NIV": "Your word is a lamp for my feet, a light on my path.",
        "BM": "Ọ̀rọ̀ rẹ ni fìtílà fún ẹsẹ̀ mi, àti ìmọ́lẹ̀ sí ipa-ọ̀nà mi.",
        "yo": "Ọ̀rọ̀ rẹ ni fìtílà fún ẹsẹ̀ mi, àti ìmọ́lẹ̀ sí ipa-ọ̀nà mi.",
        "HAU": "Maganarka fitila ce ga sawayena, da haske ga tafarkina.",
        "ha": "Maganarka fitila ce ga sawayena, da haske ga tafarkina.",
        "IGBOB": "Okwu gị bụ oriọna nye ụkwụ m, na ìhè n'ụzọ m.",
        "ig": "Okwu gị bụ oriọna nye ụkwụ m, na ìhè n'ụzọ m.",
      },
    ),
    const BibleVerse(
      reference: "Psalm 121:1-2",
      text: {
        "KJV": "I will lift up mine eyes unto the hills, from whence cometh my help. My help cometh from the Lord, which made heaven and earth.",
        "NKJV": "I will lift up my eyes to the hills— From whence comes my help? My help comes from the Lord, Who made heaven and earth.",
        "NIV": "I lift up my eyes to the mountains—where does my help come from? My help comes from the Lord, the Maker of heaven and earth.",
        "BM": "Èmi ó gbé ojú mi sókè sí àwọn òkè: níbo ni ìrànwọ́ mi yóò ti wá? Ìrànwọ́ mi ti ọ̀dọ̀ Olúwa wá, ẹni tí ó dá ọ̀run àti ayé.",
        "yo": "Èmi ó gbé ojú mi sókè sí àwọn òkè: níbo ni ìrànwọ́ mi yóò ti wá? Ìrànwọ́ mi ti ọ̀dọ̀ Olúwa wá, ẹni tí ó dá ọ̀run àti ayé.",
        "HAU": "Zan ɗaga idanuna zuwa duwatsu, daga ina taimakona zai fito? Taimakona yana fitowa daga wurin Ubangiji, Mahaliccin sama da ƙasa.",
        "ha": "Zan ɗaga idanuna zuwa duwatsu, daga ina taimakona zai fito? Taimakona yana fitowa daga wurin Ubangiji, Mahaliccin sama da ƙasa.",
        "IGBOB": "Aga m eweliri anya m lee ugwu niile, olee ebe enyemaka m si abịa? Enyemaka m si n'aka Onye-nwe bịa, Onye kere eluigwe na ụwa.",
        "ig": "Aga m eweliri anya m lee ugwu niile, olee ebe enyemaka m si abịa? Enyemaka m si n'aka Onye-nwe bịa, Onye kere eluigwe na ụwa.",
      },
    ),
    const BibleVerse(
      reference: "Proverbs 3:5-6",
      text: {
        "KJV": "Trust in the Lord with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths.",
        "NKJV": "Trust in the Lord with all your heart, And lean not on your own understanding; In all your ways acknowledge Him, And He shall direct your paths.",
        "NIV": "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.",
        "BM": "Fi gbogbo àyà rẹ gbẹ́kẹ̀lé Olúwa; má sì ṣe tẹríba sí òye ti ara rẹ. Ní gbogbo ọ̀nà rẹ mọ̀ Ọ́n, Òun yóò sì tọ́ ipa-ọ̀nà rẹ.",
        "yo": "Fi gbogbo àyà rẹ gbẹ́kẹ̀lé Olúwa; má sì ṣe tẹríba sí òye ti ara rẹ. Ní gbogbo ọ̀nà rẹ mọ̀ Ọ́n, Òun yóò sì tọ́ ipa-ọ̀nà rẹ.",
        "HAU": "Ka dogara ga Ubangiji da dukan zuciyarka, kada ka jingina ga basirarka. Ka shaida shi a dukan al'amuranka, shi kuma zai daidaita tafarkinka.",
        "ha": "Ka dogara ga Ubangiji da dukan zuciyarka, kada ka jingina ga basirarka. Ka shaida shi a dukan al'amuranka, shi kuma zai daidaita tafarkinka.",
        "IGBOB": "Tụkwasị Onye-nwe obi gị niile; adaberekwala na nghọta nke onwe gị. N'ụzọ gị niile mara Ya, Ọ ga-eduzi ụzọ gị niile.",
        "ig": "Tụkwasị Onye-nwe obi gị niile; adaberekwala na nghọta nke onwe gị. N'ụzọ gị niile mara Ya, Ọ ga-eduzi ụzọ gị niile.",
      },
    ),
    const BibleVerse(
      reference: "Proverbs 16:3",
      text: {
        "KJV": "Commit thy works unto the Lord, and thy thoughts shall be established.",
        "NKJV": "Commit your works to the Lord, And your thoughts will be established.",
        "NIV": "Commit to the Lord whatever you do, and he will establish your plans.",
        "BM": "Fi iṣẹ́ rẹ lé Olúwa lọ́wọ́, èrò inú rẹ yóò sì fi ìdí múlẹ̀.",
        "yo": "Fi iṣẹ́ rẹ lé Olúwa lọ́wọ́, èrò inú rẹ yóò sì fi ìdí múlẹ̀.",
        "HAU": "Ka danƙa ayyukanka ga Ubangiji, shawarwarinka kuwa za su tabbata.",
        "ha": "Ka danƙa ayyukanka ga Ubangiji, shawarwarinka kuwa za su tabbata.",
        "IGBOB": "Nyefee ọrụ gị n'aka Onye-nwe, atụmatụ gị niile ga-eguzosikwa ike.",
        "ig": "Nyefee ọrụ gị n'aka Onye-nwe, atụmatụ gị niile ga-eguzosikwa ike.",
      },
    ),
    const BibleVerse(
      reference: "Proverbs 18:10",
      text: {
        "KJV": "The name of the Lord is a strong tower: the righteous runneth into it, and is safe.",
        "NKJV": "The name of the Lord is a strong tower; The righteous run to it and are safe.",
        "NIV": "The name of the Lord is a fortified tower; the righteous run to it and are safe.",
        "BM": "Orúkọ Olúwa jẹ́ ilé-ìṣọ́ tí ó lágbára; olódodo sáré wọ inú rẹ̀, ó sì wà láìléwu.",
        "yo": "Orúkọ Olúwa jẹ́ ilé-ìṣọ́ tí ó lágbára; olódodo sáré wọ inú rẹ̀, ó sì wà láìléwu.",
        "HAU": "Sunan Ubangiji hasumiya ce mai ƙarfi, mai adalci yakan gudu ciki ya tsira.",
        "ha": "Sunan Ubangiji hasumiya ce mai ƙarfi, mai adalci yakan gudu ciki ya tsira.",
        "IGBOB": "Aha Onye-nwe bụ ụlọ elu siri ike; onye ezi omume na-agbaga n'ime ya wee nwee nchebe.",
        "ig": "Aha Onye-nwe bụ ụlọ elu siri ike; onye ezi omume na-agbaga n'ime ya wee nwee nchebe.",
      },
    ),
    const BibleVerse(
      reference: "Isaiah 40:29",
      text: {
        "KJV": "He giveth power to the faint; and to them that have no might he increaseth strength.",
        "NKJV": "He gives power to the weak, And to those who have no might He increases strength.",
        "NIV": "He gives strength to the weary and increases the power of the weak.",
        "BM": "Ó ń fún àwọn tí ó rẹ̀ ní agbára, ó sì ń mú ipá àwọn tí kò ní agbára pọ̀ sí i.",
        "yo": "Ó ń fún àwọn tí ó rẹ̀ ní agbára, ó sì ń mú ipá àwọn tí kò ní agbára pọ̀ sí i.",
        "HAU": "Yakan ba marar ƙarfi iko, yakan kuma ƙara wa mai rauni ƙarfi.",
        "ha": "Yakan ba marar ƙarfi iko, yakan kuma ƙara wa mai rauni ƙarfi.",
        "IGBOB": "Ọ na-enye ndị ike gwụrụ ume, Ọ na-emekwa ka ndị na-adịghị ike nwekwuo ume.",
        "ig": "Ọ na-enye ndị ike gwụrụ ume, Ọ na-emekwa ka ndị na-adịghị ike nwekwuo ume.",
      },
    ),
    const BibleVerse(
      reference: "Isaiah 40:31",
      text: {
        "KJV": "But they that wait upon the Lord shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.",
        "NKJV": "But those who wait on the Lord Shall renew their strength; They shall mount up with wings like eagles, They shall run and not be weary, They shall walk and not faint.",
        "NIV": "But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.",
        "BM": "Ṣùgbọ́n àwọn tí ó dúró de Olúwa yóò sọ agbára wọn di ọ̀tun; wọn yóò fi ìyẹ́ fò bí idì; wọn yóò sáré, kì yóò sì rẹ̀ wọ́n; wọn yóò rìn, agara kì yóò sì dá wọn.",
        "yo": "Ṣùgbọ́n àwọn tí ó dúró de Olúwa yóò sọ agbára wọn di ọ̀tun; wọn yóò fi ìyẹ́ fò bí idì; wọn yóò sáré, kì yóò sì rẹ̀ wọ́n; wọn yóò rìn, agara kì yóò sì dá wọn.",
        "HAU": "Amma masu jiran Ubangiji za su sabunta ƙarfinsu; za su tashi da fuka-fuki kamar gaggafa; za su yi gudu, ba za su gaji ba; za su yi tafiya, ba za su suma ba.",
        "ha": "Amma masu jiran Ubangiji za su sabunta ƙarfinsu; za su tashi da fuka-fuki kamar gaggafa; za su yi gudu, ba za su gaji ba; za su yi tafiya, ba za su suma ba.",
        "IGBOB": "Ma ndị na-echere Onye-nwe ga-enwe ume ọhụrụ; ha ga-eji nku feba elu dị ka ugo; ha ga-agba ọsọ, ma ike agaghị agwụ ha; ha ga-eje ije, ma ha agaghị ada mba.",
        "ig": "Ma ndị na-echere Onye-nwe ga-enwe ume ọhụrụ; ha ga-eji nku feba elu dị ka ugo; ha ga-agba ọsọ, ma ike agaghị agwụ ha; ha ga-eje ije, ma ha agaghị ada mba.",
      },
    ),
    const BibleVerse(
      reference: "Isaiah 41:10",
      text: {
        "KJV": "Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee; yea, I will uphold thee with the right hand of my righteousness.",
        "NKJV": "Fear not, for I am with you; Be not dismayed, for I am your God. I will strengthen you, Yes, I will help you, I will uphold you with My righteous right hand.",
        "NIV": "So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand.",
        "BM": "Má bẹ̀rù, nítorí tí mo wà pẹ̀lú rẹ; má fòyà, nítorí èmi ni Ọlọ́run rẹ: èmi yóò fún ọ ní agbára; bẹ́ẹ̀ ni, èmi yóò ràn ọ́ lọ́wọ́; bẹ́ẹ̀ ni, èmi yóò fi ọwọ́ ọ̀tún òdodo mi gbé ọ ró.",
        "yo": "Má bẹ̀rù, nítorí tí mo wà pẹ̀lú rẹ; má fòyà, nítorí èmi ni Ọlọ́run rẹ: èmi yóò fún ọ ní agbára; bẹ́ẹ̀ ni, èmi yóò ràn ọ́ lọ́wọ́; bẹ́ẹ̀ ni, èmi yóò fi ọwọ́ ọ̀tún òdodo mi gbé ọ ró.",
        "HAU": "Kada ka ji tsoro, gama ina tare da kai, kada ka firgita, gama ni ne Allahka. Zan ƙarfafa ka, i, zan taimake ka, i, zan riƙe ka da hannun damana na adalci.",
        "ha": "Kada ka ji tsoro, gama ina tare da kai, kada ka firgita, gama ni ne Allahka. Zan ƙarfafa ka, i, zan taimake ka, i, zan riƙe ka da hannun damana na adalci.",
        "IGBOB": "Atụla egwu, n'ihi na M nọnyeere gị; atụla ụjọ, n'ihi na M bụ Chineke gị. M ga-eme ka ị sie ike, ee, M ga-enyere gị aka, ee, M ga-eji aka nri nke ezi omume M kwado gị.",
        "ig": "Atụla egwu, n'ihi na M nọnyeere gị; atụla ụjọ, n'ihi na M bụ Chineke gị. M ga-eme ka ị sie ike, ee, M ga-enyere gị aka, ee, M ga-eji aka nri nke ezi omume M kwado gị.",
      },
    ),
    const BibleVerse(
      reference: "Isaiah 53:5",
      text: {
        "KJV": "But he was wounded for our transgressions, he was bruised for our iniquities: the chastisement of our peace was upon him; and with his stripes we are healed.",
        "NKJV": "But He was wounded for our transgressions, He was bruised for our iniquities; The chastisement for our peace was upon Him, And by His stripes we are healed.",
        "NIV": "But he was pierced for our transgressions, he was crushed for our iniquities; the punishment that brought us peace was on him, and by his wounds we are healed.",
        "BM": "Ṣùgbọ́n a gbọgbẹ́ fún ìrékọjá wa, a pa á lára fún ẹ̀ṣẹ̀ wa; ìbáwí àlàáfíà wa wà lórí rẹ̀, àti nípasẹ̀ àpá rẹ̀ ni a fi mú wa láradá.",
        "yo": "Ṣùgbọ́n a gbọgbẹ́ fún ìrékọjá wa, a pa á lára fún ẹ̀ṣẹ̀ wa; ìbáwí àlàáfíà wa wà lórí rẹ̀, àti nípasẹ̀ àpá rẹ̀ ni a fi mú wa láradá.",
        "HAU": "Amma an soke shi saboda laifofinmu, an ji masa rauni saboda muguntarmu; horon da ya kawo mana salama ya hau kansa, ta wurin raunukansa kuma aka warkar da mu.",
        "ha": "Amma an soke shi saboda laifofinmu, an ji masa rauni saboda muguntarmu; horon da ya kawo mana salama ya hau kansa, ta wurin raunukansa kuma aka warkar da mu.",
        "IGBOB": "Ma a mara Ya mma n'ihi njehie anyị, a zọpịara Ya n'ihi ajọ omume anyị; ntiwapụ nke udo anyị dịkwasịrị Ya, ọ bụkwa site n'ọnyá Ya ka e ji gwọọ anyị.",
        "ig": "Ma a mara Ya mma n'ihi njehie anyị, a zọpịara Ya n'ihi ajọ omume anyị; ntiwapụ nke udo anyị dịkwasịrị Ya, ọ bụkwa site n'ọnyá Ya ka e ji gwọọ anyị.",
      },
    ),
    const BibleVerse(
      reference: "Jeremiah 29:11",
      text: {
        "KJV": "For I know the thoughts that I think toward you, saith the Lord, thoughts of peace, and not of evil, to give you an expected end.",
        "NKJV": "For I know the thoughts that I think toward you, says the Lord, thoughts of peace and not of evil, to give you a future and a hope.",
        "NIV": "\"For I know the plans I have for you,\" declares the Lord, \"plans to prosper you and not to harm you, plans to give you hope and a future.\"",
        "BM": "Nítorí èmi mọ èrò tí mo rò sí yín, ni Olúwa wí, èrò àlàáfíà, kì í ṣe ti ibi, láti fún yín ní ìrètí ní ìkẹyìn.",
        "yo": "Nítorí èmi mọ èrò tí mo rò sí yín, ni Olúwa wí, èrò àlàáfíà, kì í ṣe ti ibi, láti fún yín ní ìrètí ní ìkẹyìn.",
        "HAU": "Gama na san dukan shirin da na yi dominku, in ji Ubangiji, shirin alheri ne, ba na cuta ba, domin in ba ku bege a nan gaba.",
        "ha": "Gama na san dukan shirin da na yi dominku, in ji Ubangiji, shirin alheri ne, ba na cuta ba, domin in ba ku bege a nan gaba.",
        "IGBOB": "N'ihi na amaara m atụmatụ ndị M na-atụrụ unu, ka Onye-nwe na-ekwupụta, atụmatụ nke udo ọ bụghị nke ihe ọjọọ, inye unu ọdịnihu na olileanya.",
        "ig": "N'ihi na amaara m atụmatụ ndị M na-atụrụ unu, ka Onye-nwe na-ekwupụta, atụmatụ nke udo ọ bụghị nke ihe ọjọọ, inye unu ọdịnihu na olileanya.",
      },
    ),
    const BibleVerse(
      reference: "Matthew 6:33",
      text: {
        "KJV": "But seek ye first the kingdom of God, and his righteousness; and all these things shall be added unto you.",
        "NKJV": "But seek first the kingdom of God and His righteousness, and all these things shall be added to you.",
        "NIV": "But seek first his kingdom and his righteousness, and all these things will be given to you as well.",
        "BM": "Ṣùgbọ́n ẹ kọ́kọ́ wá ìjọba Ọlọ́run àti òdodo rẹ̀, gbogbo àwọn nǹkan wọ̀nyí ni a ó sì fi kún un fún yín.",
        "yo": "Ṣùgbọ́n ẹ kọ́kọ́ wá ìjọba Ọlọ́run àti òdodo rẹ̀, gbogbo àwọn nǹkan wọ̀nyí ni a ó sì fi kún un fún yín.",
        "HAU": "Amma ku fara biɗar mulkinsa da adalcinsa, za a kuwa ba ku dukan waɗannan abubuwa ƙari.",
        "ha": "Amma ku fara biɗar mulkinsa da adalcinsa, za a kuwa ba ku dukan waɗannan abubuwa ƙari.",
        "IGBOB": "Kama buronụ ụzọ chọọ alaeze Ya na ezi omume Ya; a ga-atụkwasịkwara unu ihe ndị a niile.",
        "ig": "Kama buronụ ụzọ chọọ alaeze Ya na ezi omume Ya; a ga-atụkwasịkwara unu ihe ndị a niile.",
      },
    ),
    const BibleVerse(
      reference: "Matthew 11:28",
      text: {
        "KJV": "Come unto me, all ye that labour and are heavy laden, and I will give you rest.",
        "NKJV": "Come to Me, all you who labor and are heavy laden, and I will give you rest.",
        "NIV": "Come to me, all you who are weary and burdened, and I will give you rest.",
        "BM": "Ẹ wá sọ́dọ̀ mi, gbogbo ẹ̀yin tí ń ṣe làálàá, tí a sì di ẹrù wọ̀rọ̀kọ̀ le lórí, èmi yóò sì fún yín ní ìsinmi.",
        "yo": "Ẹ wá sọ́dọ̀ mi, gbogbo ẹ̀yin tí ń ṣe làálàá, tí a sì di ẹrù wọ̀rọ̀kọ̀ le lórí, èmi yóò sì fún yín ní ìsinmi.",
        "HAU": "Ku zo wurina, dukanku masu wahala da masu fama da kaya masu nauyi, ni kuwa zan ba ku hutawa.",
        "ha": "Ku zo wurina, dukanku masu wahala da masu fama da kaya masu nauyi, ni kuwa zan ba ku hutawa.",
        "IGBOB": "Bịakwutenụ M, unu niile ndị na-adọgbu onwe ha n'ọrụ na ndị e boworo ibu dị arọ, M ga-emekwa ka unu zuru ike.",
        "ig": "Bịakwutenụ M, unu niile ndị na-adọgbu onwe ha n'ọrụ na ndị e boworo ibu dị arọ, M ga-emekwa ka unu zuru ike.",
      },
    ),
    const BibleVerse(
      reference: "Matthew 28:19-20",
      text: {
        "KJV": "Go ye therefore, and teach all nations, baptizing them in the name of the Father, and of the Son, and of the Holy Ghost: Teaching them to observe all things whatsoever I have commanded you: and, lo, I am with you alway, even unto the end of the world.",
        "NKJV": "Go therefore and make disciples of all the nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit, teaching them to observe all things that I have commanded you; and lo, I am with you always, even to the end of the age.",
        "NIV": "Therefore go and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit, and teaching them to obey everything I have commanded you. And surely I am with you always, to the very end of the age.",
        "BM": "Nítorí náà, ẹ lọ, kí ẹ sì máa kọ́ gbogbo orílẹ̀-èdè, kí ẹ máa bamiptisi wọn ní orúkọ Baba, àti ti Ọmọ, àti ti Ẹ̀mí Mímọ́: Ẹ máa kọ́ wọn láti máa pa gbogbo ohun tí mo ti pa láṣẹ fún yín mọ́: sì kíyèsí i, èmi wà pẹ̀lú yín nígbà gbogbo, títí dé òpin ayé.",
        "yo": "Nítorí náà, ẹ lọ, kí ẹ sì máa kọ́ gbogbo orílẹ̀-èdè, kí ẹ máa bamiptisi wọn ní orúkọ Baba, àti ti Ọmọ, àti ti Ẹ̀mí Mímọ́: Ẹ máa kọ́ wọn láti máa pa gbogbo ohun tí mo ti pa láṣẹ fún yín mọ́: sì kíyèsí i, èmi wà pẹ̀lú yín nígbà gbogbo, títí dé òpin ayé.",
        "HAU": "Saboda haka ku tafi, ku almajirtar da dukan al'ummai, kuna yi musu baftisma da sunan Uba, da na Ɗa, da na Ruhu Mai Tsarki, kuna koya musu su kiyaye dukan abin da na umurce ku da shi. Ga shi kuwa, ina tare da ku kullum, har zuwa matuƙar zamani.",
        "ha": "Saboda haka ku tafi, ku almajirtar da dukan al'ummai, kuna yi musu baftisma da sunan Uba, da na Ɗa, da na Ruhu Mai Tsarki, kuna koya musu su kiyaye dukan abin da na umurce ku da shi. Ga shi kuwa, ina tare da ku kullum, har zuwa matuƙar zamani.",
        "IGBOB": "Ya mere gaanụ mee ka mba niile bụrụ ndị na-eso ụzọ, na-eme ha baptizim n'aha Nna, na nke Ọkpara, na nke Mmụọ Nsọ, na-akụziri ha idebe ihe niile M nyere unu n'iwu. Ma lee, M nọnyeere unu mgbe niile, ruo ọgwụgwụ nke oge a.",
        "ig": "Ya mere gaanụ mee ka mba niile bụrụ ndị na-eso ụzọ, na-eme ha baptizim n'aha Nna, na nke Ọkpara, na nke Mmụọ Nsọ, na-akụziri ha idebe ihe niile M nyere unu n'iwu. Ma lee, M nọnyeere unu mgbe niile, ruo ọgwụgwụ nke oge a.",
      },
    ),
    const BibleVerse(
      reference: "John 1:1",
      text: {
        "KJV": "In the beginning was the Word, and the Word was with God, and the Word was God.",
        "NKJV": "In the beginning was the Word, and the Word was with God, and the Word was God.",
        "NIV": "In the beginning was the Word, and the Word was with God, and the Word was God.",
        "BM": "Ní ìbẹ̀rẹ̀ ni Ọ̀rọ̀ wà, Ọ̀rọ̀ sì wà pẹ̀lú Ọlọ́run, Ọ̀rọ̀ náà sì jẹ́ Ọlọ́run.",
        "yo": "Ní ìbẹ̀rẹ̀ ni Ọ̀rọ̀ wà, Ọ̀rọ̀ sì wà pẹ̀lú Ọlọ́run, Ọ̀rọ̀ náà sì jẹ́ Ọlọ́run.",
        "HAU": "A farko Kalmar nan tana nan, Kalmar kuwa tana tare da Allah, Kalmar kuwa ita ce Allah.",
        "ha": "A farko Kalmar nan tana nan, Kalmar kuwa tana tare da Allah, Kalmar kuwa ita ce Allah.",
        "IGBOB": "Na mmalite Okwu ahụ dị, Okwu ahụ na Chineke nọkwa, Okwu ahụ bụkwa Chineke.",
        "ig": "Na mmalite Okwu ahụ dị, Okwu ahụ na Chineke nọkwa, Okwu ahụ bụkwa Chineke.",
      },
    ),
    const BibleVerse(
      reference: "John 3:16",
      text: {
        "KJV": "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
        "NKJV": "For God so loved the world that He gave His only begotten Son, that whoever believes in Him should not perish but have everlasting life.",
        "NIV": "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.",
        "BM": "Nítorí Ọlọ́run fẹ́ aráyé tó bẹ́ẹ̀ gẹ́gẹ́, tí ó fi Ọmọ bíbí rẹ̀ kanṣoṣo fúnni, kí ẹnikẹ́ni tí ó bá gbà á gbọ́ má bàa ṣègbé, ṣùgbọ́n kí ó lè ní ìyè àìnípẹ̀kun.",
        "yo": "Nítorí Ọlọ́run fẹ́ aráyé tó bẹ́ẹ̀ gẹ́gẹ́, tí ó fi Ọmọ bíbí rẹ̀ kanṣoṣo fúnni, kí ẹnikẹ́ni tí ó bá gbà á gbọ́ má bàa ṣègbé, ṣùgbọ́n kí ó lè ní ìyè àìnípẹ̀kun.",
        "HAU": "Gama Allah ya yi ƙaunar duniya har ya ba da makaɗaicin Ɗansa, domin duk wanda ya gaskata da shi kada ya halaka, sai dai ya sami rai na har abada.",
        "ha": "Gama Allah ya yi ƙaunar duniya har ya ba da makaɗaicin Ɗansa, domin duk wanda ya gaskata da shi kada ya halaka, sai dai ya sami rai na har abada.",
        "IGBOB": "N'ihi na Chineke hụrụ ụwa n'anya nke ukwuu nke na Ọ nyere Ọkpara Ọ mụrụ naanị ya, ka onye ọ bụla nke kwere na Ya wee ghara ila n'iyi, kama nwee ndụ ebighị ebi.",
        "ig": "N'ihi na Chineke hụrụ ụwa n'anya nke ukwuu nke na Ọ nyere Ọkpara Ọ mụrụ naanị ya, ka onye ọ bụla nke kwere na Ya wee ghara ila n'iyi, kama nwee ndụ ebighị ebi.",
      },
    ),
    const BibleVerse(
      reference: "John 14:1-3",
      text: {
        "KJV": "Let not your heart be troubled: ye believe in God, believe also in me. In my Father's house are many mansions: if it were not so, I would have told you. I go to prepare a place for you. And if I go and prepare a place for you, I will come again, and receive you unto myself; that where I am, there ye may be also.",
        "NKJV": "Let not your heart be troubled; you believe in God, believe also in Me. In My Father's house are many mansions; if it were not so, I would have told you. I go to prepare a place for you. And if I go and prepare a place for you, I will come again and receive you to Myself; that where I am, there you may be also.",
        "NIV": "\"Do not let your hearts be troubled. You believe in God; believe also in me. My Father's house has many rooms; if that were not so, would I have told you that I am going there to prepare a place for you? And if I go and prepare a place for you, I will come back and take you to be with me that you also may be where I am.\"",
        "BM": "Ẹ má ṣe jẹ́ kí ọkàn yín dàrú: ẹ gbà gbọ́ nínú Ọlọ́run, ẹ gbà mí gbọ́ pẹ̀lú. Ní ilé Baba mi ọ̀pọ̀ ibùgbé ló wà; èmi ń lọ láti pèsè àyè sílẹ̀ fún yín.",
        "yo": "Ẹ má ṣe jẹ́ kí ọkàn yín dàrú: ẹ gbà gbọ́ nínú Ọlọ́run, ẹ gbà mí gbọ́ pẹ̀lú. Ní ilé Baba mi ọ̀pọ̀ ibùgbé ló wà; èmi ń lọ láti pèsè àyè sílẹ̀ fún yín.",
        "HAU": "Kada zuciyarku ta firgita, ku gaskata da Allah, ku kuma gaskata da ni. A gidan Ubana akwai wuraren zama masu yawa; ina tafiya in shirya muku wuri.",
        "ha": "Kada zuciyarku ta firgita, ku gaskata da Allah, ku kuma gaskata da ni. A gidan Ubana akwai wuraren zama masu yawa; ina tafiya in shirya muku wuri.",
        "IGBOB": "Ka obi unu ghara ịnọ na nsogbu: kwere na Chineke, kwerekwa na Mụ onwe m. N'ụlọ Nna m, ọtụtụ ebe obibi dị; Ana m aga ịkwadebeere unu ebe.",
        "ig": "Ka obi unu ghara ịnọ na nsogbu: kwere na Chineke, kwerekwa na Mụ onwe m. N'ụlọ Nna m, ọtụtụ ebe obibi dị; Ana m aga ịkwadebeere unu ebe.",
      },
    ),
    const BibleVerse(
      reference: "John 14:6",
      text: {
        "KJV": "Jesus saith unto him, I am the way, the truth, and the life: no man cometh unto the Father, but by me.",
        "NKJV": "Jesus said to him, \"I am the way, the truth, and the life. No one comes to the Father except through Me.\"",
        "NIV": "Jesus answered, \"I am the way and the truth and the life. No one comes to the Father except through me.\"",
        "BM": "Jesu wí fún un pé, 'Èmi ni ọ̀nà, òtítọ́, àti ìyè: kò sí ẹnikẹ́ni tí ń wá sọ́dọ̀ Baba, bí kò ṣe nípasẹ̀ mi.'",
        "yo": "Jesu wí fún un pé, 'Èmi ni ọ̀nà, òtítọ́, àti ìyè: kò sí ẹnikẹ́ni tí ń wá sọ́dọ̀ Baba, bí kò ṣe nípasẹ̀ mi.'",
        "HAU": "Yesu ya ce masa, 'Ni ne hanya, da gaskiya, da rai. Ba mai zuwa wurin Uban sai ta wurina.'",
        "ha": "Yesu ya ce masa, 'Ni ne hanya, da gaskiya, da rai. Ba mai zuwa wurin Uban sai ta wurina.'",
        "IGBOB": "Jizọs sịrị ya, 'Mụ onwe m bụ ụzọ, na eziokwu, na ndụ. Ọ dịghị onye na-abịakwute Nna m ma ọ bụghị site na M.'",
        "ig": "Jizọs sịrị ya, 'Mụ onwe m bụ ụzọ, na eziokwu, na ndụ. Ọ dịghị onye na-abịakwute Nna m ma ọ bụghị site na M.'",
      },
    ),
    const BibleVerse(
      reference: "John 14:27",
      text: {
        "KJV": "Peace I leave with you, my peace I give unto you: not as the world giveth, give I unto you. Let not your heart be troubled, neither let it be afraid.",
        "NKJV": "Peace I leave with you, My peace I give to you; not as the world gives do I give to you. Let not your heart be troubled, neither let it be afraid.",
        "NIV": "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.",
        "BM": "Àlàáfíà ni mo fi sílẹ̀ fún yín, àlàáfíà mi ni mo fún yín; kì í ṣe bí ayé ti ń fi fúnni ni mo fún yín. Ẹ má ṣe jẹ́ kí ọkàn yín dàrú, bẹ́ẹ̀ ni kí ẹ má ṣe jẹ́ kí ó fò.",
        "yo": "Àlàáfíà ni mo fi sílẹ̀ fún yín, àlàáfíà mi ni mo fún yín; kì í ṣe bí ayé ti ń fi fúnni ni mo fún yín. Ẹ má ṣe jẹ́ kí ọkàn yín dàrú, bẹ́ẹ̀ ni kí ẹ má ṣe jẹ́ kí ó fò.",
        "HAU": "Salama nake bar muku, salamata nake ba ku; ba kamar yadda duniya take bayarwa nake ba ku ba. Kada zuciyarku ta firgita, kada kuma ta karai.",
        "ha": "Salama nake bar muku, salamata nake ba ku; ba kamar yadda duniya take bayarwa nake ba ku ba. Kada zuciyarku ta firgita, kada kuma ta karai.",
        "IGBOB": "Udo ka M na-ahapụrụ unu, udo nke M ka M na-enye unu; ọ bụghị dị ka ụwa si enye ka M na-enye unu. Ka obi unu ghara ịnọ na nsogbu, ka ọ ghara ịtụkwa egwu.",
        "ig": "Udo ka M na-ahapụrụ unu, udo nke M ka M na-enye unu; ọ bụghị dị ka ụwa si enye ka M na-enye unu. Ka obi unu ghara ịnọ na nsogbu, ka ọ ghara ịtụkwa egwu.",
      },
    ),
    const BibleVerse(
      reference: "Romans 8:28",
      text: {
        "KJV": "And we know that all things work together for good to them that love God, to them who are the called according to his purpose.",
        "NKJV": "And we know that all things work together for good to those who love God, to those who are the called according to His purpose.",
        "NIV": "And we know that in all things God works for the good of those who love him, who have been called according to his purpose.",
        "BM": "Àwa sì mọ̀ pé gbogbo nǹkan ló ń ṣiṣẹ́ pọ̀ fún rere àwọn tí ó fẹ́ràn Ọlọ́run, àwọn tí a pè gẹ́gẹ́ bí ète Rẹ̀.",
        "yo": "Àwa sì mọ̀ pé gbogbo nǹkan ló ń ṣiṣẹ́ pọ̀ fún rere àwọn tí ó fẹ́ràn Ọlọ́run, àwọn tí a pè gẹ́gẹ́ bí ète Rẹ̀.",
        "HAU": "Mun sani kuma cewa cikin dukan abu Allah yana aiki domin amfanin waɗanda suke ƙaunarsa, waɗanda aka kira bisa ga nufinsa.",
        "ha": "Mun sani kuma cewa cikin dukan abu Allah yana aiki domin amfanin waɗanda suke ƙaunarsa, waɗanda aka kira bisa ga nufinsa.",
        "IGBOB": "Anyị makwaara na n'ihe niile, Chineke na-arụkọ ọrụ maka ọdịmma nke ndị hụrụ Ya n'anya, bụ ndị a kpọrọ dịka nzube Ya si dị.",
        "ig": "Anyị makwaara na n'ihe niile, Chineke na-arụkọ ọrụ maka ọdịmma nke ndị hụrụ Ya n'anya, bụ ndị a kpọrọ dịka nzube Ya si dị.",
      },
    ),
    const BibleVerse(
      reference: "Romans 8:38-39",
      text: {
        "KJV": "For I am persuaded, that neither death, nor life, nor angels, nor principalities, nor powers, nor things present, nor things to come, Nor height, nor depth, nor any other creature, shall be able to separate us from the love of God, which is in Christ Jesus our Lord.",
        "NKJV": "For I am persuaded that neither death nor life, nor angels nor principalities nor powers, nor things present nor things to come, nor height nor depth, nor any other created thing, shall be able to separate us from the love of God which is in Christ Jesus our Lord.",
        "NIV": "For I am convinced that neither death nor life, neither angels nor demons, neither the present nor the future, nor any powers, neither height nor depth, nor anything else in all creation, will be able to separate us from the love of God that is in Christ Jesus our Lord.",
        "BM": "Nítorí ó dá mi lójú pé, kì í ṣe ikú, tàbí ìyè, tàbí àwọn áńgẹ́lì, tàbí àwọn ìjòyè, yóò lè yà wá kúrò nínú ìfẹ́ Ọlọ́run tí ó wà nínú Kristi Jesu Olúwa wa.",
        "yo": "Nítorí ó dá mi lójú pé, kì í ṣe ikú, tàbí ìyè, tàbí àwọn áńgẹ́lì, tàbí àwọn ìjòyè, yóò lè yà wá kúrò nínú ìfẹ́ Ọlọ́run tí ó wà nínú Kristi Jesu Olúwa wa.",
        "HAU": "Gama na tabbata cewa mutuwa ko rai, mala'iku ko masu mulki, ba wani abu da zai iya raba mu da ƙaunar Allah wadda take cikin Almasihu Yesu Ubangijinmu.",
        "ha": "Gama na tabbata cewa mutuwa ko rai, mala'iku ko masu mulki, ba wani abu da zai iya raba mu da ƙaunar Allah wadda take cikin Almasihu Yesu Ubangijinmu.",
        "IGBOB": "N'ihi na o doro m anya na ọnwụ ma ọ bụ ndụ, ndị mmụọ ozi ma ọ bụ ndị ọchịchị, agaghị enwe ike ikewapụ anyị n'ịhụnanya Chineke nke dị n'ime Kraịst Jizọs Onye-nwe anyị.",
        "ig": "N'ihi na o doro m anya na ọnwụ ma ọ bụ ndụ, ndị mmụọ ozi ma ọ bụ ndị ọchịchị, agaghị enwe ike ikewapụ anyị n'ịhụnanya Chineke nke dị n'ime Kraịst Jizọs Onye-nwe anyị.",
      },
    ),
    const BibleVerse(
      reference: "Romans 12:1-2",
      text: {
        "KJV": "I beseech you therefore, brethren, by the mercies of God, that ye present your bodies a living sacrifice, holy, acceptable unto God, which is your reasonable service. And be not conformed to this world: but be ye transformed by the renewing of your mind.",
        "NKJV": "I beseech you therefore, brethren, by the mercies of God, that you present your bodies a living sacrifice, holy, acceptable to God, which is your reasonable service. And do not be conformed to this world, but be transformed by the renewing of your mind.",
        "NIV": "Therefore, I urge you, brothers and sisters, in view of God's mercy, to offer your bodies as a living sacrifice, holy and pleasing to God—this is your true and proper worship. Do not conform to the pattern of this world, but be transformed by the renewing of your mind.",
        "BM": "Nítorí náà, mo bẹ̀ yín, ará, nípa àánú Ọlọ́run, kí ẹ gbé ara yín kalẹ̀ gẹ́gẹ́ bí ẹbọ ààyè, mímọ́, tí ó ṣe ìtẹ́wọ́gbà fún Ọlọ́run. Ẹ má sì ṣe bá ayé yìí dọ́gba: ṣùgbọ́n kí ẹ yípadà nípa títún èrò inú yín ṣe.",
        "yo": "Nítorí náà, mo bẹ̀ yín, ará, nípa àánú Ọlọ́run, kí ẹ gbé ara yín kalẹ̀ gẹ́gẹ́ bí ẹbọ ààyè, mímọ́, tí ó ṣe ìtẹ́wọ́gbà fún Ọlọ́run. Ẹ má sì ṣe bá ayé yìí dọ́gba: ṣùgbọ́n kí ẹ yípadà nípa títún èrò inú yín ṣe.",
        "HAU": "Saboda haka, 'yan'uwa, ina roƙonku saboda jinƙan Allah, ku miƙa jikunanku hadaya rayayya, mai tsarki, abin karɓa ga Allah. Kada kuma ku biye wa zamanin nan, sai dai ku canza ta wurin sabunta hankalinku.",
        "ha": "Saboda haka, 'yan'uwa, ina roƙonku saboda jinƙan Allah, ku miƙa jikunanku hadaya rayayya, mai tsarki, abin karɓa ga Allah. Kada kuma ku biye wa zamanin nan, sai dai ku canza ta wurin sabunta hankalinku.",
        "IGBOB": "Ya mere, ụmụnna m, ana m arịọ unu site n'ebere nke Chineke, ka unu wepụta ahụ unu dị ka àjà dị ndụ, dị nsọ, nke na-amasị Chineke. Unu emekwala ka ụwa a kwekọọ na ya, kama ka a gbanwee unu site n'ime ka uche unu dị ọhụrụ.",
        "ig": "Ya mere, ụmụnna m, ana m arịọ unu site n'ebere nke Chineke, ka unu wepụta ahụ unu dị ka àjà dị ndụ, dị nsọ, nke na-amasị Chineke. Unu emekwala ka ụwa a kwekọọ na ya, kama ka a gbanwee unu site n'ime ka uche unu dị ọhụrụ.",
      },
    ),
    const BibleVerse(
      reference: "Galatians 5:22-23",
      text: {
        "KJV": "But the fruit of the Spirit is love, joy, peace, longsuffering, gentleness, goodness, faith, Meekness, temperance: against such there is no law.",
        "NKJV": "But the fruit of the Spirit is love, joy, peace, longsuffering, kindness, goodness, faithfulness, gentleness, self-control. Against such there is no law.",
        "NIV": "But the fruit of the Spirit is love, joy, peace, forbearance, kindness, goodness, faithfulness, gentleness and self-control. Against such things there is no law.",
        "BM": "Ṣùgbọ́n èso ti Ẹ̀mí ni: ìfẹ́, ayọ̀, àlàáfíà, sùúrù, ìwà pẹ̀lẹ́, oore, ìgbàgbọ́, ìwà tútù, ìkóra-ẹni-níjàánu. Kò sí òfin tí ó lòdì sí irú àwọn nǹkan wọ̀nyí.",
        "yo": "Ṣùgbọ́n èso ti Ẹ̀mí ni: ìfẹ́, ayọ̀, àlàáfíà, sùúrù, ìwà pẹ̀lẹ́, oore, ìgbàgbọ́, ìwà tútù, ìkóra-ẹni-níjàánu. Kò sí òfin tí ó lòdì sí irú àwọn nǹkan wọ̀nyí.",
        "HAU": "Amma amfanin Ruhu shi ne: ƙauna, farin ciki, salama, haƙuri, kirki, nagarta, aminci, tawali'u, kamun kai. Babu shari'a a kan irin waɗannan.",
        "ha": "Amma amfanin Ruhu shi ne: ƙauna, farin ciki, salama, haƙuri, kirki, nagarta, aminci, tawali'u, kamun kai. Babu shari'a a kan irin waɗannan.",
        "IGBOB": "Ma mkpụrụ nke Mmụọ Nsọ bụ: ịhụnanya, ọṅụ, udo, ogologo ntachi obi, obiọma, ịdị mma, ikwesị ntụkwasị obi, ịdị nwayọọ, njide onwe onye. Ọ dịghị iwu megidere ihe ndị a.",
        "ig": "Ma mkpụrụ nke Mmụọ Nsọ bụ: ịhụnanya, ọṅụ, udo, ogologo ntachi obi, obiọma, ịdị mma, ikwesị ntụkwasị obi, ịdị nwayọọ, njide onwe onye. Ọ dịghị iwu megidere ihe ndị a.",
      },
    ),
    const BibleVerse(
      reference: "Ephesians 2:8-9",
      text: {
        "KJV": "For by grace are ye saved through faith; and that not of yourselves: it is the gift of God: Not of works, lest any man should boast.",
        "NKJV": "For by grace you have been saved through faith, and that not of yourselves; it is the gift of God, not of works, lest anyone should boast.",
        "NIV": "For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—not by works, so that no one can boast.",
        "BM": "Nítorí nípa oore-ọ̀fẹ́ ni a fi gbà yín là nípasẹ̀ ìgbàgbọ́; èyí kì í sì í ṣe láti ọwọ́ ara yín wá: ẹ̀bùn Ọlọ́run ni; kì í ṣe nípa iṣẹ́, kí ẹnikẹ́ni má bàa ṣògo.",
        "yo": "Nítorí nípa oore-ọ̀fẹ́ ni a fi gbà yín là nípasẹ̀ ìgbàgbọ́; èyí kì í sì í ṣe láti ọwọ́ ara yín wá: ẹ̀bùn Ọlọ́run ni; kì í ṣe nípa iṣẹ́, kí ẹnikẹ́ni má bàa ṣògo.",
        "HAU": "Gama ta wurin alheri aka cece ku ta wurin bangaskiya, wannan kuwa ba daga gare ku ba ne, kyauta ce ta Allah, ba ta wurin ayyuka ba ne, domin kada wani ya yi fahariya.",
        "ha": "Gama ta wurin alheri aka cece ku ta wurin bangaskiya, wannan kuwa ba daga gare ku ba ne, kyauta ce ta Allah, ba ta wurin ayyuka ba ne, domin kada wani ya yi fahariya.",
        "IGBOB": "N'ihi na site n'amara ka e ji zọpụta unu site na okwukwe; nke a abụghịkwa nke si n'onwe unu pụta, ọ bụ onyinye Chineke; ọ bụghị site n'ọrụ, ka onye ọ bụla ghara ịnya isi.",
        "ig": "N'ihi na site n'amara ka e ji zọpụta unu site na okwukwe; nke a abụghịkwa nke si n'onwe unu pụta, ọ bụ onyinye Chineke; ọ bụghị site n'ọrụ, ka onye ọ bụla ghara ịnya isi.",
      },
    ),
    const BibleVerse(
      reference: "Philippians 4:6-7",
      text: {
        "KJV": "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God. And the peace of God, which passeth all understanding, shall keep your hearts and minds through Christ Jesus.",
        "NKJV": "Be anxious for nothing, but in everything by prayer and supplication, with thanksgiving, let your requests be made known to God; and the peace of God, which surpasses all understanding, will guard your hearts and minds through Christ Jesus.",
        "NIV": "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.",
        "BM": "Ẹ má ṣe ṣàníyàn nípa ohunkóhun; ṣùgbọ́n nínú ohun gbogbo, nípa àdúrà àti ẹ̀bẹ̀ pẹ̀lú ọpẹ́, ẹ máa fi ìbéèrè yín hàn fún Ọlọ́run. Àlàáfíà Ọlọ́run, tí ó ju gbogbo òye lọ, yóò máa pa ọkàn àti èrò yín mọ́ nínú Kristi Jesu.",
        "yo": "Ẹ má ṣe ṣàníyàn nípa ohunkóhun; ṣùgbọ́n nínú ohun gbogbo, nípa àdúrà àti ẹ̀bẹ̀ pẹ̀lú ọpẹ́, ẹ máa fi ìbéèrè yín hàn fún Ọlọ́run. Àlàáfíà Ọlọ́run, tí ó ju gbogbo òye lọ, yóò máa pa ọkàn àti èrò yín mọ́ nínú Kristi Jesu.",
        "HAU": "Kada ku damu da kome, amma a cikin kowane abu ta wurin addu'a da roƙo tare da godiya, ku sanar da buƙatunku ga Allah. Salamar Allah kuwa wadda ta fi gaban dukan fahamta, za ta tsare zukatanku da tunaninku a cikin Almasihu Yesu.",
        "ha": "Kada ku damu da kome, amma a cikin kowane abu ta wurin addu'a da roƙo tare da godiya, ku sanar da buƙatunku ga Allah. Salamar Allah kuwa wadda ta fi gaban dukan fahamta, za ta tsare zukatanku da tunaninku a cikin Almasihu Yesu.",
        "IGBOB": "Unu echegbula onwe unu maka ihe ọ bụla, kama n'ihe niile, site n'ekpere na arịrịọ tinyere ekele, mee ka a mara arịrịọ unu nye Chineke. Udo nke Chineke, nke karịrị nghọta niile, ga-echebe obi unu na uche unu n'ime Kraịst Jizọs.",
        "ig": "Unu echegbula onwe unu maka ihe ọ bụla, kama n'ihe niile, site n'ekpere na arịrịọ tinyere ekele, mee ka a mara arịrịọ unu nye Chineke. Udo nke Chineke, nke karịrị nghọta niile, ga-echebe obi unu na uche unu n'ime Kraịst Jizọs.",
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
      reference: "2 Timothy 1:7",
      text: {
        "KJV": "For God hath not given us the spirit of fear; but of power, and of love, and of a sound mind.",
        "NKJV": "For God has not given us a spirit of fear, but of power and of love and of a sound mind.",
        "NIV": "For the Spirit God gave us does not make us timid, but gives us power, love and self-discipline.",
        "BM": "Nítorí Ọlọ́run kò fún wa ní ẹ̀mí ìbẹ̀rù, ṣùgbọ́n ní ti agbára, àti ti ìfẹ́, àti ti ìkóra-ẹni-níjàánu.",
        "yo": "Nítorí Ọlọ́run kò fún wa ní ẹ̀mí ìbẹ̀rù, ṣùgbọ́n ní ti agbára, àti ti ìfẹ́, àti ti ìkóra-ẹni-níjàánu.",
        "HAU": "Gama Allah bai ba mu ruhun tsoro ba, amma na iko, da na ƙauna, da na kame kai.",
        "ha": "Gama Allah bai ba mu ruhun tsoro ba, amma na iko, da na ƙauna, da na kame kai.",
        "IGBOB": "N'ihi na Chineke enyeghị anyị mmụọ nke egwu, kama nke ike, na nke ịhụnanya, na nke ezi uche.",
        "ig": "N'ihi na Chineke enyeghị anyị mmụọ nke egwu, kama nke ike, na nke ịhụnanya, na nke ezi uche.",
      },
    ),
    const BibleVerse(
      reference: "Hebrews 11:1",
      text: {
        "KJV": "Now faith is the substance of things hoped for, the evidence of things not seen.",
        "NKJV": "Now faith is the substance of things hoped for, the evidence of things not seen.",
        "NIV": "Now faith is confidence in what we hope for and assurance about what we do not see.",
        "BM": "Ǹjẹ́ ìgbàgbọ́ ni ìdánilójú ohun tí a ń retí, ẹ̀rí ohun tí a kò rí.",
        "yo": "Ǹjẹ́ ìgbàgbọ́ ni ìdánilójú ohun tí a ń retí, ẹ̀rí ohun tí a kò rí.",
        "HAU": "Bangaskiya kuwa ita ce tabbatar da abubuwan da ake bege, shaida ce kuma ta abubuwan da ba a gani ba.",
        "ha": "Bangaskiya kuwa ita ce tabbatar da abubuwan da ake bege, shaida ce kuma ta abubuwan da ba a gani ba.",
        "IGBOB": "Ugbu a okwukwe bụ ntụkwasị obi na ihe ndị a na-atụ anya ya, bụrụkwa ihe àmà na-egosi na ihe ndị a na-adịghị ahụ anya dị n'ezie.",
        "ig": "Ugbu a okwukwe bụ ntụkwasị obi na ihe ndị a na-atụ anya ya, bụrụkwa ihe àmà na-egosi na ihe ndị a na-adịghị ahụ anya dị n'ezie.",
      },
    ),
    const BibleVerse(
      reference: "Hebrews 12:1-2",
      text: {
        "KJV": "Wherefore seeing we also are compassed about with so great a cloud of witnesses, let us lay aside every weight, and the sin which doth so easily beset us, and let us run with patience the race that is set before us, Looking unto Jesus the author and finisher of our faith.",
        "NKJV": "Therefore we also, since we are surrounded by so great a cloud of witnesses, let us lay aside every weight, and the sin which so easily ensnares us, and let us run with endurance the race that is set before us, looking unto Jesus, the author and finisher of our faith.",
        "NIV": "Therefore, since we are surrounded by such a great cloud of witnesses, let us throw off everything that hinders and the sin that so easily entangles. And let us run with perseverance the race marked out for us, fixing our eyes on Jesus, the pioneer and perfecter of faith.",
        "BM": "Nítorí náà, bí ó ti ṣe pé a yí wa ká pẹ̀lú àwọsánmọ̀ àwọn ẹlẹ́rìí tí ó tó báyìí, ẹ jẹ́ kí a gbé gbogbo ìwọ̀n wọ̀nyí kúrò, àti ẹ̀ṣẹ̀ tí ó tètè ń dẹ́kùn mú wa, kí a sì fi sùúrù sá eré tí a gbé ka iwájú wa, kí a máa wo Jesu aṣáájú àti aláṣepé ìgbàgbọ́ wa.",
        "yo": "Nítorí náà, bí ó ti ṣe pé a yí wa ká pẹ̀lú àwọsánmọ̀ àwọn ẹlẹ́rìí tí ó tó báyìí, ẹ jẹ́ kí a gbé gbogbo ìwọ̀n wọ̀nyí kúrò, àti ẹ̀ṣẹ̀ tí ó tètè ń dẹ́kùn mú wa, kí a sì fi sùúrù sá eré tí a gbé ka iwájú wa, kí a máa wo Jesu aṣáájú àti aláṣepé ìgbàgbọ́ wa.",
        "HAU": "Saboda haka, da yake muna kewaye da gajimaren shaidu mai girma haka, bari mu yar da kowane nauyi da zunubin da yake sauƙin sarƙe mu, mu kuma yi tseren da aka sa a gabanmu da juriya, muna zuba wa Yesu ido, jagoran bangaskiyarmu kuma mai cika ta.",
        "ha": "Saboda haka, da yake muna kewaye da gajimaren shaidu mai girma haka, bari mu yar da kowane nauyi da zunubin da yake sauƙin sarƙe mu, mu kuma yi tseren da aka sa a gabanmu da juriya, muna zuba wa Yesu ido, jagoran bangaskiyarmu kuma mai cika ta.",
        "IGBOB": "Ya mere, ebe ọ bụ na igwe ojii dị ukwuu nke ndị akaebe gbara anyị gburugburu, ka anyị wezụga ibu niile na mmehie nke na-adabere anyị ngwa ngwa, ka anyị jiri ntachi obi gbaa ọsọ ahụ e debere n'ihu anyị, na-elegide anya na Jizọs, Onye na-ebute ma na-eme ka okwukwe anyị zuo oke.",
        "ig": "Ya mere, ebe ọ bụ na igwe ojii dị ukwuu nke ndị akaebe gbara anyị gburugburu, ka anyị wezụga ibu niile na mmehie nke na-adabere anyị ngwa ngwa, ka anyị jiri ntachi obi gbaa ọsọ ahụ e debere n'ihu anyị, na-elegide anya na Jizọs, Onye na-ebute ma na-eme ka okwukwe anyị zuo oke.",
      },
    ),
    const BibleVerse(
      reference: "Revelation 21:4",
      text: {
        "KJV": "And God shall wipe away all tears from their eyes; and there shall be no more death, neither sorrow, nor crying, neither shall there be any more pain: for the former things are passed away.",
        "NKJV": "And God will wipe away every tear from their eyes; there shall be no more death, nor sorrow, nor crying. There shall be no more pain, for the former things have passed away.",
        "NIV": "\"He will wipe every tear from their eyes. There will be no more death or mourning or crying or pain, for the old order of things has passed away.\"",
        "BM": "Ọlọ́run yóò sì nu gbogbo omijé kúrò ní ojú wọn; kì yóò sì sí ikú mọ́, bẹ́ẹ̀ ni kì yóò sí ọ̀fọ̀, tàbí ẹkún, tàbí ìrora mọ́: nítorí tí àwọn ohun àtijọ́ ti kọjá lọ.",
        "yo": "Ọlọ́run yóò sì nu gbogbo omijé kúrò ní ojú wọn; kì yóò sì sí ikú mọ́, bẹ́ẹ̀ ni kì yóò sì sí ọ̀fọ̀, tàbí ẹkún, tàbí ìrora mọ́: nítorí tí àwọn ohun àtijọ́ ti kọjá lọ.",
        "HAU": "Zai share dukan hawaye daga idanunsu, babu sauran mutuwa, ko baƙin ciki, ko kuka, ko azaba, gama abubuwan dā sun shuɗe.",
        "ha": "Zai share dukan hawaye daga idanunsu, babu sauran mutuwa, ko baƙin ciki, ko kuka, ko azaba, gama abubuwan dā sun shuɗe.",
        "IGBOB": "Chineke ga-ehichapụkwa anya mmiri niile n'anya ha; ọnwụ agaghị adịkwa ọzọ, iru uju ma ọ bụ ákwá ma ọ bụ ihe mgbu agaghị adịkwa ọzọ: n'ihi na ihe mbụ niile agafeela.",
        "ig": "Chineke ga-ehichapụkwa anya mmiri niile n'anya ha; ọnwụ agaghị adịkwa ọzọ, iru uju ma ọ bụ ákwá ma ọ bụ ihe mgbu agaghị adịkwa ọzọ: n'ihi na ihe mbụ niile agafeela.",
      },
    ),
    const BibleVerse(
      reference: "Revelation 22:20",
      text: {
        "KJV": "He which testifieth these things saith, Surely I come quickly. Amen. Even so, come, Lord Jesus.",
        "NKJV": "He who testifies to these things says, \"Surely I am coming quickly.\" Amen. Even so, come, Lord Jesus!",
        "NIV": "He who testifies to these things says, \"Yes, I am coming soon.\" Amen. Come, Lord Jesus.",
        "BM": "Ẹni tí ó jẹ́rìí sí nǹkan wọ̀nyí wí pé, 'Nítòótọ́, èmi ń bọ̀ ní kánkán.' Àmín. Bẹ́ẹ̀ ni, wá, Jesu Olúwa.",
        "yo": "Ẹni tí ó jẹ́rìí sí nǹkan wọ̀nyí wí pé, 'Nítòótọ́, èmi ń bọ̀ ní kánkán.' Àmín. Bẹ́ẹ̀ ni, wá, Jesu Olúwa.",
        "HAU": "Wanda yake shaidar waɗannan abubuwa ya ce, 'I, ina zuwa da sauri.' Amin. Haka ne, zo, Ubangiji Yesu.",
        "ha": "Wanda yake shaidar waɗannan abubuwa ya ce, 'I, ina zuwa da sauri.' Amin. Haka ne, zo, Ubangiji Yesu.",
        "IGBOB": "Onye na-agba akaebe maka ihe ndị a na-asị, 'N'ezie Ana m abịa ngwa ngwa.' Amen. Bịa, Onye-nwe Jizọs.",
        "ig": "Onye na-agba akaebe maka ihe ndị a na-asị, 'N'ezie Ana m abịa ngwa ngwa.' Amen. Bịa, Onye-nwe Jizọs.",
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

  /// Single Source of Truth helper: Look up translated text for any reference and language.
  String? getTranslatedText(String reference, String langCode) {
    if (langCode == 'en') return null;
    final cleanRef = reference.trim().toLowerCase();
    final localVersion = {'yo': 'BM', 'ha': 'HAU', 'ig': 'IGBOB'}[langCode] ?? 'KJV';
    
    for (final v in dailyCorpus) {
      if (v.reference.trim().toLowerCase() == cleanRef) {
        return v.text[langCode] ?? v.text[localVersion];
      }
    }
    return null;
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
      'psalm 46:1',
      'romans 8:28',
    ],
    'peace': [
      'john 14:27',
      'philippians 4:6-7',
      'psalm 23:1',
      'psalm 23:4',
      'isaiah 41:10',
      'matthew 11:28',
    ],
    'strength': [
      'philippians 4:13',
      'isaiah 40:29',
      'isaiah 40:31',
      'psalm 27:1',
      'psalm 46:1',
      'proverbs 18:10',
    ],
    'guidance': [
      'proverbs 3:5-6',
      'psalm 119:105',
      'proverbs 16:3',
      'psalm 121:1-2',
      'matthew 6:33',
    ],
    'comfort': [
      'psalm 23:4',
      'matthew 11:28',
      'john 14:1-3',
      'revelation 21:4',
      'romans 8:38-39',
    ],
    'salvation': [
      'john 3:16',
      'ephesians 2:8-9',
      'john 14:6',
      'romans 8:28',
      'matthew 28:19-20',
    ],
  };

  /// Non-genealogy verses pool for random selection
  List<BibleVerse> get nonGenealogyCorpus {
    return dailyCorpus.where((v) => !_isGenealogy(v.reference)).toList();
  }

  bool _isGenealogy(String reference) {
    final lower = reference.toLowerCase();
    if (lower.startsWith('genesis 5') ||
        lower.startsWith('genesis 10') ||
        lower.startsWith('genesis 11') ||
        lower.startsWith('genesis 36') ||
        lower.startsWith('1 chronicles 1') ||
        lower.startsWith('1 chronicles 2') ||
        lower.startsWith('1 chronicles 3') ||
        lower.startsWith('1 chronicles 4') ||
        lower.startsWith('1 chronicles 5') ||
        lower.startsWith('1 chronicles 6') ||
        lower.startsWith('1 chronicles 7') ||
        lower.startsWith('1 chronicles 8') ||
        lower.startsWith('1 chronicles 9') ||
        lower.startsWith('matthew 1:') ||
        lower.startsWith('luke 3:23')) {
      return true;
    }
    return false;
  }

  /// Find verse by reference
  BibleVerse? findByReference(String reference) {
    final cleanRef = reference.trim().toLowerCase();
    return dailyCorpus.where((v) => v.reference.trim().toLowerCase() == cleanRef).firstOrNull;
  }

  /// Search verses by query
  List<BibleVerse> search(String query) {
    if (query.trim().isEmpty) return const [];
    final phrase = query.trim().toLowerCase();
    final words = phrase.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    final results = <BibleVerse>[];
    final seenRefs = <String>{};

    void addVerse(BibleVerse v) {
      if (seenRefs.add(v.reference.toLowerCase())) {
        results.add(v);
      }
    }

    // 1. Exact Reference Match
    final exactRef = findByReference(phrase);
    if (exactRef != null) {
      addVerse(exactRef);
    }

    // 2. Exact Phrase Match
    for (final verse in dailyCorpus) {
      for (final text in verse.text.values) {
        if (text.toLowerCase().contains(phrase)) {
          addVerse(verse);
          break;
        }
      }
    }

    // 3. Thematic / Topical Matches
    for (final entry in _topicalThemes.entries) {
      final topic = entry.key;
      if (phrase.contains(topic) || topic.contains(phrase) || words.contains(topic)) {
        for (final ref in entry.value) {
          final matchedVerse = findByReference(ref);
          if (matchedVerse != null) {
            addVerse(matchedVerse);
          }
        }
      }
    }

    // 4. Keyword Matches
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

  /// Get a random verse from the corpus
  BibleVerse? randomVerse({bool excludeGenealogy = true}) {
    final pool = excludeGenealogy ? nonGenealogyCorpus : dailyCorpus;
    if (pool.isEmpty) return null;
    final verses = List<BibleVerse>.of(pool)..shuffle();
    return verses.first;
  }
}
