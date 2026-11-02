import 'package:shared_preferences/shared_preferences.dart';
import '../models/podcast_models.dart';
import '../utils/logger.dart';

/// Central registry of the SAMPLE (seed) content that user-facing screens
/// show out of the box — sample podcasts, downloaded episodes, etc.
///
/// Admins can hide (delete) any sample from the Sample Content admin screen;
/// hidden ids are persisted locally so user-facing screens stop showing them.
class SampleContentService {
  static final SampleContentService _instance =
      SampleContentService._internal();
  factory SampleContentService() => _instance;
  SampleContentService._internal();

  static final Logger _logger = Logger('SampleContentService');
  static const String _hiddenKey = 'hidden_sample_content_ids';

  Set<String> _hiddenIds = {};
  bool _loaded = false;

  /// Production Podcast 1 shown out of the box and editable in Admin.
  static const List<Map<String, dynamic>> samplePodcasts = [
    {
      'id': 'podcast_mec_agana_01',
      'type': 'podcast',
      'title': "Reclaiming God's Pattern: The Biblical Strategy for Mission",
      'description':
          'In this presentation from the 2019 Alive Nigeria Mission Empowerment Conference, the speaker explores the biblical blueprint for mission and evangelism through centers of influence and the W3 class.',
      'host': 'Pastor Agana',
      'category': 'MEC',
      'episodes': 1,
      'rating': 5.0,
      'hasAudio': true,
      'audioUrl':
          'https://api.alivenigeria.org/v1/storage/buckets/podcast_media/files/test_podcast_agana_01/view?project=6a3bef53002f5090dedf',
      'tags': ['MEC', 'Mission', 'Evangelism', 'W3'],
      'notes': _productionNotes,
      'transcript': _productionTranscript,
    },
  ];

  /// Converted sample podcasts into real Podcast models for user screens.
  List<Podcast> get visibleSamplePodcasts =>
      samplePodcasts.where((s) => !_hiddenIds.contains(s['id'])).map((s) {
        final categoryName = (s['category'] ?? 'MEC').toString();
        final category = PodcastCategory.values.firstWhere(
          (e) =>
              e.name.toLowerCase() == categoryName.toLowerCase() ||
              e.displayName.toLowerCase() == categoryName.toLowerCase(),
          orElse: () => PodcastCategory.mec,
        );
        return Podcast(
          id: s['id'].toString(),
          title: (s['title'] ?? 'Podcast').toString(),
          description: (s['description'] ?? '').toString(),
          category: category,
          customCategory: categoryName,
          host: (s['host'] ?? '').toString(),
          episodes: (s['episodes'] as num?)?.toInt() ?? 1,
          rating: (s['rating'] as num?)?.toDouble() ?? 5.0,
          isSubscribed: false,
          tags: (s['tags'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const ['MEC', 'Mission'],
          audioUrl: (s['audioUrl'] ?? s['audio_url'])?.toString(),
        );
      }).toList();

  List<Map<String, dynamic>> get visibleEpisodes =>
      sampleEpisodes.where((s) => !_hiddenIds.contains(s['id'])).toList();

  /// Production Episode 1 shown on Downloaded / Episodes tab.
  static const List<Map<String, dynamic>> sampleEpisodes = [
    {
      'id': 'episode_mec_agana_01',
      'type': 'episode',
      'title': "Reclaiming God's Pattern: The Biblical Strategy for Mission",
      'podcastTitle':
          "Reclaiming God's Pattern: The Biblical Strategy for Mission",
      'host': 'Pastor Agana',
      'duration': '48 min',
      'downloadDate': '2019-11-01',
      'category': 'MEC',
      'hasAudio': true,
      'audioUrl':
          'https://api.alivenigeria.org/v1/storage/buckets/podcast_media/files/test_podcast_agana_01/view?project=6a3bef53002f5090dedf',
      'description':
          'In this presentation from the 2019 Alive Nigeria Mission Empowerment Conference, the speaker explores the biblical blueprint for mission and evangelism through centers of influence and the W3 class.',
      'notes': _productionNotes,
      'transcript': _productionTranscript,
    },
  ];

  /// Every sample item (podcasts + episodes) for the admin screen.
  List<Map<String, dynamic>> get allSamples => [
        ...samplePodcasts,
        ...sampleEpisodes,
      ];

  List<Map<String, dynamic>> get visibleSamples =>
      allSamples.where((s) => !isHidden(s['id'] as String)).toList();

  bool isHidden(String id) => _hiddenIds.contains(id);

  static const String _deletedKey = 'deleted_sample_content_ids';
  Set<String> _deletedIds = {};

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _hiddenIds = (prefs.getStringList(_hiddenKey) ?? []).toSet();
      _deletedIds = (prefs.getStringList(_deletedKey) ?? []).toSet();
      _loaded = true;
    } catch (e) {
      _logger.error('Failed to load hidden sample ids: $e');
      _loaded = true;
    }
  }

  /// Ensures hidden ids are loaded before the UI checks visibility.
  Future<void> ensureLoaded() => _ensureLoaded();

  /// Whether a sample has been permanently deleted on this device.
  bool isDeleted(String id) => _deletedIds.contains(id);

  /// Permanently delete a sample from this device's registry. The sample
  /// disappears from the admin list AND from every user-facing screen.
  Future<bool> deleteSample(String id) async {
    try {
      await _ensureLoaded();
      _hiddenIds.add(id);
      _deletedIds.add(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hiddenKey, _hiddenIds.toList());
      await prefs.setStringList(_deletedKey, _deletedIds.toList());
      return true;
    } catch (e) {
      _logger.error('Failed to delete sample $id: $e');
      return false;
    }
  }

  /// Hide (soft-delete) a sample so user-facing screens stop showing it.
  Future<bool> hideSample(String id) async {
    try {
      await _ensureLoaded();
      _hiddenIds.add(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hiddenKey, _hiddenIds.toList());
      return true;
    } catch (e) {
      _logger.error('Failed to hide sample $id: $e');
      return false;
    }
  }

  /// Restore a previously hidden or deleted sample.
  Future<bool> restoreSample(String id) async {
    try {
      await _ensureLoaded();
      _hiddenIds.remove(id);
      _deletedIds.remove(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hiddenKey, _hiddenIds.toList());
      await prefs.setStringList(_deletedKey, _deletedIds.toList());
      return true;
    } catch (e) {
      _logger.error('Failed to restore sample $id: $e');
      return false;
    }
  }
}

const String _productionNotes = '''
## Overview

In this presentation from the 2019 Alive Nigeria Mission Empowerment Conference, the speaker explores the biblical blueprint for mission and evangelism. Drawing from both the Old and New Testaments, the presentation establishes that God consistently engages **centers of influence**—influential, educated, and well-to-do individuals (referred to as the **W3 class**: Wealthy, Worldly, and Well-educated)—to advance His kingdom and ultimately reach all levels of society.

Key themes discussed in the presentation include:

* **The Edenic Ideal & Accountability:** Adam was established as the crowned king and steward of the earth, setting a precedent where leaders and monarchs hold a primary line of accountability before God.
* **Old Testament Precedents:** God systematically called influential figures out of their comfort zones—such as Abraham (a wealthy chieftain), Moses (an educated heir of Pharaoh), Joseph (exalted in Egypt), Daniel and his companions (nobles trained for the royal court), and kings like Nebuchadnezzar, Artaxerxes, and Cyrus—to influence entire nations.
* **New Testament Continuity:** Early Christian mission actively engaged key figures of influence and resources, including Lydia (a wealthy merchant), Zacchaeus, Joseph of Arimathea, Roman Centurions, and the Ethiopian treasurer.
* **Christ’s Example & Disciples' Education:** Jesus Himself set the ultimate example by stepping out of heavenly comfort into humble service. Furthermore, while His disciples began as humble, unlettered men, Christ educated and elevated their intellectual and spiritual capacity before sending them into mission.
* **Challenging Modern Paradigms:** The speaker urges the church to align its mission strategy with biblical patterns rather than financial budgets or conventional assumptions, ensuring that elite and influential groups are intentionally evangelized alongside the poor.

---

## Scripture Foundation

* **Genesis 3:15** – The *Protoevangelium* (first declaration of the gospel) proclaimed by God in Eden.
* **Genesis 13:2** – Abraham's standing as a man of significant wealth in silver, gold, and livestock.
* **Job 1:6** – Illustration of original dominion surrendered by humanity.
* **Daniel 1:1–4** – Selection of noble, educated, and capable youths to serve in the Babylonian court.
* **Daniel 4:1–3** – King Nebuchadnezzar’s public proclamation of God’s eternal kingdom.
* **Jonah 3:6–9** – The repentance of the King of Nineveh leading an entire empire to seek God.
* **Matthew 19:23–26** – Christ’s teaching on the difficulty of the rich entering the kingdom, emphasizing that *"with God all things are possible."*
* **Luke 2:52** – Jesus growing in wisdom, stature, and favor with God and man.
* **Acts 16:14–15** – The conversion of Lydia, a businesswoman and key financier of the early church in Europe.
* **Philippians 2:5–8** – Christ leaving His divine comfort zone to take the form of a servant.
* **Revelation 21:24** – The vision of the New Jerusalem where *"the kings of the earth do bring their glory and honor into it."*

---

## Call to Action

1. **Re-align Mission Strategy with Biblical Patterns:** Shift from passive or budget-restricted evangelism to an intentional, Spirit-led approach that targets leaders, professionals, and centers of influence.
2. **Invest in Personal & Intellectual Development:** Elevate personal standards of learning, communication, and spiritual understanding to engage effectively with analytical, educated, or skeptical minds.
3. **Step Out of Comfort Zones:** Emulate the example of Christ, patriarchs, and apostles by sacrificing personal comfort to carry the gospel to unreached sectors of society.
4. **Utilize Resources & Influence for the Gospel:** Encourage professionals and individuals of means to dedicate their talents, influence, and wealth directly to the advancement of God's work.
''';

const String _productionTranscript = r'''
[00:00] Intro Announcement: This message was presented at the Alive Nigeria Mission Empowerment Conference 2019, "All or Nothing," in Owerri, Nigeria. For all the resources like this, visit us online at www.alivenigeria.org.
[00:30] Speaker: Well, this afternoon we have two more presentations to cover. The first one will be a biblical tour of W3 evangelism. Okay?
[01:00] In the morning, we tried to establish that there is a paradigm in the Bible for how we ought to approach mission in general. We also established that the way the church is going about mission is not exactly in line with that paradigm.
[01:45] We saw the paradigm was that we need to focus on reaching the upper classes first, and once we have done that, they will help with their talents and their resources—the abilities that God has entrusted to them—to take the message across to the wider population and the lower classes as well.
[02:30] I have to stress that throughout, in the Spirit of Prophecy, when you see that term "higher classes," it's not derogatory, it's not trying to say that they are better people. And when you see "lower classes," it does not mean that those who are called lower classes are inferior people. I hope that's clear. These are just terms that are used to describe their relative difference in privilege—relative difference in privilege and resources that each class has.
[03:20] So that was "Sabotaging the Kingdom." We also tried to then establish in our second presentation the profile of the W3. Who are they, right? What are they like? How do they think? What are some of the ideas and philosophies and cultural movements that influence their lifestyle, the way they think, the way they approach issues of religion, issues of faith? Okay?
[04:10] So that was our second presentation, even though we were quite hard pressed for time and we could not finish it thoroughly. I will do my best to weave in some of those concepts which we could not touch into the subsequent presentations.
[04:50] This afternoon, we want to look at the Bible and see examples—what did God Himself do, right? So that we can follow. I think you will agree with me that it's best to follow the example that God has laid, right? Yes.
[05:30] So, if we can see a pattern, that's the thing we are looking for. That's all we are looking for. We are going to look through these examples in Scripture to try and find a pattern, and we'll see if we can replicate that pattern in our time or not. Okay? And I submit to you before we start that we exactly can, and we'll find success if we do.
[06:15] So please, bow your head with me as usual. Let's pray before we start.
[06:30] Prayer: Father in heaven, we are thankful for the lunch that we've enjoyed. We're thankful for the rest as well. We also want to thank You for the presentations that have gone before. We pray that You will help us to build upon it so that we will be fruitful instruments in Your hands in this great work. We also commit all the other seminars into Your hands, and we pray that all will go well unto Your glory. Let us give all or nothing; in fact, let us give all, not nothing, for Your work. In Jesus' name we pray, Amen.
[07:20] Speaker: Okay. So please move us forward. It's quite inconvenient that I always have to say "please move us forward," but I don't have a pointer, so please bear with me. Okay.
[07:50] We are going right back to Eden. It's always a good place to start because in Eden you have the ideal living situation for humanity, right?
[08:20] But also in Eden, it's a good place to start because this is the first place where mission became necessary. Okay? Sin came in, and very immediately mission became necessary. Okay?
[08:50] So right from Eden, we see—we have to ask ourselves what class of people were Adam and Eve, right? What class of people were they? Were they high-class people? To have high-class people, you need to have low-class people, right? So that you can make a difference, right?
[09:30] But you only had Adam and Eve at a point, okay? But for our purpose—for the purpose of this discussion—yes, we will say that they were high-class people, okay? Because they were given what? They were given dominion, right? And authority.
[10:10] So the way the Spirit of Prophecy describes that is in the form of a coronation. Adam was actually crowned a king. I don't know how many people are aware of that, right? But Adam was not just the first created man; he was not just the son of God; he was also the king of this earth, right?
[10:50] So he had the dominion, he had the power, he had the authority. Okay? In sin, he surrendered this authority and decided to make himself a servant of the devil, right? Of the enemy.
[11:30] This is why in Job 1:6 you read that Satan came with the rest of the sons of God into heaven, right? To represent the earth. So when God asked him, "What are you doing here?", he says what? "I have come from walking to and fro and up and down in the midst of the earth," okay?
[12:10] That expression in the Old Testament—you find that expression a few times, okay? Abraham also used that expression—to describe possession, okay? At some point God asked Abraham, "Get up and walk up and down in the land, right? I'm giving it all to you." That act of walking up and down the land signifies that "this is my territory," okay?
[12:50] So for him to say that "I have come from walking to and fro and up and down," he's saying, "I have free access; I can go anywhere I want, the whole place is mine," okay? That is the dominion that was surrendered to him, okay?
[13:30] So we have to start off by recognizing that in the very beginning, right in the very, very beginning, we have high-class people right in the garden of Eden. But it continues from there; let's go forward.
[14:10] What was God's plan? God's plan is to fill the earth with righteousness through the king. Because after all, if Adam was a king, God could have chosen to give up on him, right? Give up on him and start again, huh?
[14:50] But Adam, through his own repentance, right, helped to spur on the first inklings of the gospel work. Don't forget God Himself made a sacrifice and clothed them. So God is the first evangelist, isn't He? Right? God is the first evangelist.
[15:30] The very first statement of evangelism that we know of is Genesis 3:15. Right? What does it say? "I shall put enmity between your seed and the seed of the woman..." Right? Between the seed of the woman and the serpent, right? Okay. One will bruise the heel; the other will bruise the head, okay?
[16:15] So this is the statement about the coming of Jesus Christ. Okay, it's an evangelistic statement. So God is the first evangelist. Now, having passed on that message, Adam and his wife Eve were to pass on that message to their children, on and on and on. There was never a time in God's plan when there should be people in this world who had no idea about the coming of Jesus Christ. Are you with me? Okay.
[17:00] So the Godhead fulfilled this role in evangelizing the first couple as soon as they sinned, right? And all throughout history, you will find that God has always expected the monarch, the king, to represent His righteousness. And whenever they have failed, they have seen punishment, haven't they?
[17:40] Right? Okay. So there is a pattern. You rarely find God complaining to the population of Israel, right? "All of you, you've left your king, right? And he's sinning; why aren't you doing something about it?" Are you with me?
[18:20] No, but you see God talking to the king and saying that what? "You have allowed your people to build high places to the gods of Asherah and Baal, right? And you have not taken them down." That's the line of accountability. That's the line of accountability, okay? Jesus Himself fulfilled this role, and we'll touch more on Jesus Christ later, okay?
[19:00] So let's look in the Old Testament now. We'll look in the Old Testament, we'll look in the New Testament, okay? We'll tie it up. (You have a question? Please hold it for now, okay? Because of the way time has been treating us of late, we'll try and do the questions after. You're smiling! Okay.)
[19:40] So in the Old Testament, let's start with Abraham. Why are we starting with Abraham? Because the entire gospel is based on covenants, right?
[20:20] Covenant was broken in Eden, and for a while, the human family wandered about in sin. You had pockets of faithfulness here and there, okay? But in total, mankind was drifting away from God such that He had to actually destroy the earth in a flood. He started again with a family, and they were not perfect either, right?
[21:00] So at some point, God decides to consummate a covenant with human beings, and He starts through a man called Abraham. The thing is, Abraham was not a poor man. Right? He was not a poor man at all. Abraham was a chieftain; he was a commander of a troop; he was a leader of a household; he was wealthy.
[21:40] Don't forget that Abraham was able to go and conquer kings to release his nephew Lot, right? Abraham was respected by the kings in the Mesopotamian area—in the Ancient Near East where he lived, right?
[22:20] Abraham was not a small man at all. He was a merchant, he was a warrior, and he was a wealthy man. In Genesis chapter 13, verse 2, you read something interesting about the wealth of Abraham. Very often in the Old Testament, when wealth is reckoned, it's reckoned in terms of cattle, right, sheep, goats, herd.
[23:00] But when you read about Abraham as early as that, it tells us that Abraham was wealthy in silver and gold. Right? So yeah, he had cattle and sheep and all of that, but here is a man who was proper, proper wealthy. Right? Yeah, he was a super-billionaire of his day, you can probably put it that way, okay?
[23:45] And why would God choose a man like Abraham? Why would God choose a man like Abraham? Because there is a certain pattern which we have already seen, okay? It's easier for somebody with influence to affect his household, his community, his nation, right? It's easier.
[24:30] And so God promises Abraham that in him all the families of the earth will be what? Will be blessed. This is the establishment of covenant, and it has to be very significant for us that God began the whole thing, right, by appealing to the W3. Right?
[25:15] He was, by the standards of his day, he would have been an educated man, right, by the standards of his day. He was certainly wealthy, right? And he was a man who was at least, if for nothing at all, more preoccupied with the gods of his fathers than with the God of Yahweh, right?
[26:00] Okay, so let's move on. Another important figure in God's reaching out to the human family is Moses, isn't it? In Hebrews 11:24, we are told that Moses did not insist on keeping his reputation as the child of Pharaoh's daughter, right?
[26:45] Moses identified with his people, but he could have opted to live the life of an heir to the Egyptian throne. Moses was raised in the household of the Egyptian Pharaoh, right? Moses would have been taken to the best school available in that day. He lived in luxury and wealth for the better part of his early life, at least 40 years.
[27:30] (Audience member points out slide typo) You are correct, you are correct. Thank you very much, that's an oversight, so that should be Moses, right? That should be Moses.
[28:00] He was an Egyptian elite; he was highly educated, and he was a warrior. Moses, according to tradition, led Egyptian armies in battle, right? And he was raised an heir to the Pharaoh.
[28:45] So again, a member of the W3 class who was called by God out of his W3 situation into the wilderness for another what, 40 years, okay, and taught some lessons, and then sent to deliver God's people from Egypt, right? Raised an heir of Pharaoh, highly educated, lived in opulence and luxury—we've been through this slide, so let's move forward.
[29:30] And then we look at Joseph. Was Joseph poor in his very beginning? Who was his father? Okay, now Jacob was a wealthy man, blessed by God, right? By the time Jacob left his uncle's place, was he a poor man? No, wealthy man.
[30:15] He treated his son Joseph with quite a difference, didn't he? So much so that his brothers were envious, right? So you are a... in Ghana, we say we have a term, we say dadaba, right? Dadaba means... it's Twi, okay? It comes from dada ba, child of father, okay?
[31:00] So you have a house, there's a father and there's a mother, right? Their father's favorite child is the one they call the child of the father, even though all the children are children of the father. Are you with me? It's just a term that shows endearment, okay? So he was a dadaba of his family, okay?
[31:45] Son of a rich man, favored by his father. (Audience asks) Dadaba, yes, it's a Ghanaian term, yes, for a child that is most endeared to his father. Dadaba! Okay.
[32:20] All right, so here he was; he was raised in wealth, but he was sold into slavery, right? But even there, he was redeemed into nobility in Egypt, okay, and he was used by God to save many, okay?
[33:00] And then we look at Daniel. Because at a certain point, after the children of Israel had been redeemed out of Egypt, right, they went astray and they were taken into captivity in Babylon, okay?
[33:45] In Babylon, the necessity to continue teaching mankind about the love of God and about the plan of salvation did not stop, it did not cease. In fact, even there, the children of Israel were now given an opportunity to spread that message wider, okay?
[34:30] And where better than the very capital of the world, with the richest and most powerful king that the world had at the time, okay? And so you have Daniel and his brothers, his three Hebrew friends, right?
[35:10] There's something interesting to note about them. When you read Daniel chapter 1, verses 1 to 4, their beginning is told, okay? They were not common people, were they? No, because the king asked for the chief of his eunuchs to bring him certain kinds of people, okay?
[35:50] What kinds of people? Yes, right? Knowledgeable, scientific in their thinking, good-looking, able to stand in the presence of the king, right? People of nobility, right, from the royal families, right? Certain of the children of the princes, right, and of the king's seed, such as to stand in the presence of the king, okay?
[36:35] So these are the kinds of people that God selects to take His message into a palace of influence, of great influence. There were poor people in Israel at the time of the captivity, right? There were, but these are the ones that God saddled with the task. Okay, let's move on.
[37:15] So look at the results, okay? The greatest monarch in the world at the time, King Nebuchadnezzar—a wicked man by our standards. By 11 years old, this man was a general of the Babylonian army. Yes! How old are you, Daniel? 13. He was younger than you!
[38:00] Standing in front of an army, he had been trained to kill from a very early age, trained to lead from a very early age, okay? He practiced wickedness for many years in his life; by the time he was this old, you can understand why he tells the magicians, "If you don't tell me the interpretation of my dreams, what will happen to you? Cut off your head, your houses will be made a dunghill." He meant it, and he would have done it! And they knew that he would have done it; this was not a man to mince his words at all, right?
[38:50] Such a man is led by these brothers to say something like this, to write this to the nations and peoples of every language who live in all the earth: "May you prosper greatly. It is my pleasure to tell you about the miraculous signs and wonders that the Most High God has performed for me. How great are His signs, how mighty His wonders! His kingdom is an eternal kingdom; His dominion endures from generation to generation." Amen, right?
[39:40] Now, a message like this from a man like this has influence, right? It does, it does.
[40:15] Nehemiah, Ezra... During the end of the period of captivity, Nehemiah and Ezra are very influential in getting the Israelites back into Jerusalem, correct? So Ezra leads an initial return, but Nehemiah leads the major one, okay?
[41:00] And the king Artaxerxes, who is another very, very, very wicked man in history, is ministered to by Nehemiah such that he develops a soft spot for the children of Israel. He allows them to go back and rebuild their temple, even against opposition, okay?
[41:45] And you also have Cyrus, who in fact is mentioned in the book of Isaiah more than a hundred years before he was even born as ordained by God to work a deliverance for His people, right? So you can see—you can see that God has a pattern, right? A pattern for doing this work that we are calling what? Missions.
[42:30] Now, I'm pointing all these things out because usually when we think about missions, we always do think about reaching out to the poor, right? And sometimes you can't blame us, because we read that Jesus Christ came to save the what? Right? You read "Blessed are the poor in spirit," right?
[43:15] "Go and tell John what you have seen, the blind see, the lame walk, and the poor have the gospel preached unto them." Isn't that what Jesus Christ told the disciples of John to go and tell him when he was in prison and sent them to come and ask, "Are you the Messiah or not?" Right? "And the poor have the gospel preached unto them."
[44:00] So we read these phrases and we can easily misunderstand, right? It can easily look as if God is only interested in... right? Not so! He is interested in them, yes! Yes, but the paradigm is that He tends to reach them through centers of influence. Those centers of influence are usually highly influential people, trained by God, taken out of a certain circumstance, and we'll look at that in the end.
[44:45] So look at the King of Nineveh's words, okay? We mentioned Jonah this morning. (Question? Contribution?)
[45:15] Audience member: I like Jonah's story. If you keep looking at that term "poor" from one side, you realize that if you are wealthy, you can be poor in other areas. Of course! Then you will have a better mindset, because you will realize okay, the poor in wealth can be rich in other things...
[45:45] Speaker: Very true, thank you for that submission, very true indeed, right? So this is another letter from the King of Nineveh. Nineveh was the capital of Assyria, the Assyrian Empire. And Jonah had been told to go there and preach to them. He refused, but eventually he went, right?
[46:30] Another very wicked city. You know the reason why Jonah didn't want to go over there was the Assyrians had been very brutal to the Israelites, to his people. He did not see why God should pardon them. And mind you, the message that God had given him did not include pardon!
[47:15] When you read the text very well, God told him, "Go and warn the people of Assyria because what they are doing is not good." He didn't say, "I'm going to pardon them." But Jonah said, "I know You! Is that You, this God? I know You! You are not interested in destroying anybody! If I go there right now, they will repent and You will save them! I'm not going anywhere!"
[48:00] And when you check, when Jonah actually went, finally entered the city, what was he saying? He was walking along the streets and he was saying what? "Forty days yet, and Nineveh will be destroyed!" He didn't tell them that, "You people better repent, otherwise you'll be destroyed." He didn't say, "If you repent, you'll be saved; otherwise..." He didn't give them a chance! He said, "Forty days, Nineveh will be destroyed!" That was what he wanted, right?
[48:45] But that was not the kind of God who had sent him, okay? Very wicked people, but look at what their king says, okay? Let me go back and look at it.
[49:15] When the king heard the message, he rent his clothes, he called for a fast, he said, "Do not let people or animals, herds or flocks, taste anything." Can you imagine, even the animals are fasting in repentance! "Do not let them eat or drink, but let people and animals be covered with sackcloth." How do you cover animals with sackcloth? Lock them in!
[50:00] This is just the king's way of saying, "Look, nobody is exempt, right? Nobody is exempt, we are all going to pray. Let everyone call urgently on God!" Imagine a king saying that! "Let everyone call urgently on God. Let them give up their evil ways and their violence. Who knows? God may relent, and with compassion turn from His fierce anger so that we will not perish."
[50:45] You see, "Who knows?", because Jonah had not told them that they had a chance! Right? Jonah had not come and told them they had a chance. So, "Who knows?" But there was hope for them, and they were saved. Amen.
[51:30] That's the kind of influence that a powerful man can have over his people to save, right? To save.
[52:00] Then you look at the Hezekian Revival. You had a king called Hezekiah who was ministered to by Micah and Isaiah, right? Hezekiah led Israel into a great revival, okay? You can read about the details on your own, I'm sure you have before, to the extent that he had all the scriptures read to the people to remind them of what their duties were to the Lord at a time of great backsliding in Israel, right?
[52:45] Moving forward, there are so many more. We can't possibly exhaust the long list of W3 personalities in the Old Testament, right? But you can think about other people like David, Solomon, who played their role, right? Okay, so let's move forward.
[53:15] Audience member: You can add Samson.
[53:30] Speaker: You can definitely add Samson. In fact, you can add many of the judges of Israel before King Saul came into the picture, because they were leaders, they were military leaders of their people, right? In Deborah's case, for example, she was an actual judge; she sat under the palm tree judging the tribes of Israel, so they had influence, definitely. You can even talk about the people whom Jethro advised Moses to put over the people, right? To divide the labor so that he wouldn't tire out, and so on and on. Yes, definitely.
[54:15] And so we come into the New Testament, right? And we see people like Lydia. Who was Lydia? Lydia is the first documented convert to the Christian religion in Europe—first documented convert! The first person who we know on the European continent accepted the Christian message, right, and it's documented. That's Lydia, and she was not a small woman!
[55:00] According to the book of Acts, we are told that she was a trader in purple, right? Purple was a kind of—it was basically a form of linen, right, dyed, exactly, right? Often dyed purple. And people who traded in that were very, very wealthy indeed. She was a rich woman; she was a great financier of the church. Now think about it: on the continent of Europe, this is the first person on record to have accepted the message. Do you think that that was by accident on God's part?
[55:50] So if the Spirit of Prophecy tells us, "First reach the higher classes, and then the lower classes will follow," does it make sense or not? That's what God Himself did, right? We see that in the Old Testament; we see that in the New Testament, right?
[56:30] The rich young ruler is one of the people who did not successfully convert, at least per the documentation that we have in Scripture, right? But God would have very, very happily welcomed him. You have Zacchaeus, who was a wealthy man through ill gain, right? But the Lord still used Zacchaeus to proclaim goodness. He says, "Half of my property I give to the poor; everybody I've ever stolen from, I'm going to return fourfold." Total repentance! And he entertained the Son of God in his own house!
[57:20] Think about that. The temple that Solomon built did not have the foot of Christ step in it—that was a glorious building. But Zacchaeus's house, the foot of Christ stepped inside it, right? But Zacchaeus's house did! Right?
[58:00] So you have people like Joseph of Arimathea, who provided a burial ground for Christ. Without Joseph of Arimathea, many of the songs we think about—the resurrection of Christ coming out of the tomb, "He is risen, He is Lord"—we would not be singing them, right? Because probably different arrangements would have been made. He is forever a part of the evangelism story because of his money, take it or leave it, right? Money is not evil!
[58:50] Definitely, I'm just using the money as a metonymy, right? Because very often we look at money as a bad thing, so I intentionally use that, right? But yes, it's influence, definitely, okay? Because I'm sure at the time there would have been people who would have insisted that we don't even give this man a proper burial because He has troubled the nation so much, right? So he would have certainly used some of his influence to make sure that a befitting burial was provided, okay?
[59:40] So you have various women financiers of Jesus Christ, and the texts are there for you to look at later—we don't have too much time. You have the Roman Centurion who was so kind, all his servants loved him. One of his servants is sick, and he has ridden miles to go and find Jesus Christ to heal a servant! Are you with me? And Jesus Christ looks upon him and says, "I have not seen faith like this in all of Israel!" Are we together?
[60:30] Okay, so anybody who tells you that high-class people are not interested, they cannot be reached, they cannot be saved, right, you can point him to this Roman Centurion. You have Cornelius, who is another Roman Centurion in Acts chapter 10, right? His whole household speaks in tongues under the influence of the Holy Spirit, right?
[61:15] Because a certain Peter was standing in his house thinking, "As for me, I will never step in the house of a Gentile." But the Holy Spirit gave him a vision that showed him, "Well, you have to. In fact, go downstairs, they are waiting for you, to take you into the house of a Gentile," right? And this happens.
[62:00] Then you have the Ethiopian—where I like to think of him as the Ethiopian Minister of Finance. The Bible tells us that he was a eunuch who had charge of the treasury of the queen of Ethiopia, right? And this is the man to whom... look, Philip is on his way somewhere, I don't know what Philip was doing that afternoon, but the Holy Spirit comes to Philip and says, "Hey, get up, get up, get up, get up! Go into the desert now! There's a man over there who is reading the scrolls of Isaiah; he doesn't understand. Go and explain to him."
[62:50] Okay, why is this man so important to the Holy Spirit, and yet he's not important to us? Hmm? Why? We would have rather gotten up much quicker and run and gone, you know, set up a podium in some village and preach to maybe the people who were driving the carriage, right? Not the man sitting inside the air-conditioned carriage! Am I speaking to you? Okay.
[63:40] So mission in the early church, I'll summarize it this way: it was Christ-initiated. Christ started it, right? Christ is the one who said, "Wait for Me in Jerusalem, and I will release the Holy Spirit on you; you'll have power, right, and then you'll be My witnesses." So the whole thing was started by Christ, and it's Christ-centered. It's based on Christ's method, and it's well-planned. In terms of human resource management, you can read about it in the early chapters of Acts, right? How all the family came together, mobilized their funds and resources...
[64:30] Please let's go back, there's one final point that's important for us to make, okay? Spirit-led mission, and that's what we are talking about. The Holy Spirit directed their mission; this is why they were reaching out to people in the W3. They did not go into church board meetings and committee meetings and come up with their own way of doing it. Are we together? All right, let's move on.
[65:15] Yeah, this is just a summary of some of them; we've already talked about them, so let's move, let's move on. Okay, now if the Spirit was leading it, no wonder you see a strategic unfolding like this in the book of Acts, okay?
[65:50] Because in Acts chapter 2, when we see that famous episode of Pentecost, right, who was gathered? Jews from every nation around there, right? People from the diaspora! Now, history tells us that there were Jews who had left Israel and were living in foreign lands, right, cities like Rome and Pamphylia and Phrygia and all sorts of places, because of greener pastures. Life was tough at home; they went out to make what? Money!
[66:40] These were people who could travel and come for Passover, like people travel today for vacation, right, and go home. In Islam, our Islamic friends or brothers, they will travel from here to Mecca for a pilgrimage, right? But even their own religion says, understands that not everyone can make it, right? So it says if you can, make the pilgrimage, because it recognizes you need what? Money. You need to be of a certain standing, okay?
[67:30] So these are not common people! Stephen—you're in Acts chapter 6 now—Stephen was an eloquent man, highly analytical. You listen to the sermon that he gave; a man who could stand in front of the people and give them reason for his faith. This is the kind of man God went for, right?
[68:15] And then two chapters later, you have Cornelius—actually Cornelius is in chapter 10. In chapter 9, you have Paul—Paul who was won by Jesus Christ Himself on the road to Damascus. Am I with you? Yes.
[69:00] And then you have Sergius Paulus, the deputy mayor of Paphos, in chapter 13—one of the first W3 people who Paul witnessed to. And next to him, you had Elymas the sorcerer, do you remember him? Who was trying to prevent Paul from doing the work that God... And you see, that's what the devil will do. He will stand in your way because Satan knows that if Sergius Paulus accepts the gospel, his whole province accepts the gospel, right? So he will do his best to stand in the way, and he's certainly doing that today.
[69:50] And then of course, by chapter 16, you have Lydia of Thyatira, who is the first documented convert in Europe.
[70:20] So what is the biblical pattern? What can we derive? That's the purpose of this presentation—not just to look at these various examples in isolation, but to try and ask ourselves: what is the commonality amongst all these people? And I've just listed a few of them, right?
[71:05] But in all the different W3 figures that we have seen, I think the commonality is this: that they were all elite, well-to-do persons called out of their comfort zones to bring truth and light to many. Would you agree with that summary?
[71:50] That they started off in a position of comfort, but God took them out of their comfort zone and deployed their resources and their talents to bring the gospel to many. You can say that of Abraham, certainly. "Get up and go to a land which I will show you"—God not even telling him where to go, right? Out of his comfort zone!
[72:35] Moses: living a life of opulence, had everything he wanted, okay? "Get up and go out into the desert for 40 years." Out of his comfort zone!
[73:15] Daniel and his brothers: living in Jerusalem, peace, nobility, everything going well. Out into captivity, comfort zone, right, gone!
[74:00] Paul was a Pharisee, highly respected, a member of the Sanhedrin, okay? Taken right out of his comfort zone. His first encounter with Christ, he was blind, and he never fully regained his eyesight. Out of his comfort zone! When Paul describes what he has gone through in ministry, you can understand, right? "I have endured beatings many, shipwrecks, bitten by snakes." Out of his comfort zone!
[74:50] That's the pattern! And then I told you we'll talk about our Lord Jesus Christ Himself, right? Because in Philippians chapter 2, we are told in verses 6 to 8 that He left everything. Now, what does everything amount to? It amounts to all the wealth in this universe, not just that, because and beyond, right? That's the wealthy part.
[75:40] But if we want to talk about the well-educated part, He was omniscient as God, wasn't He? And yet He walked on this earth and told us that not even the Son of Man knows the hour, nor the angels, but only the Father in heaven, right? He willingly let off even some of His knowledge; that is why we can read in Luke 2:52 that Jesus Christ grew in wisdom and in stature.
[76:30] If you have all wisdom, you can't grow in wisdom, are you with me? Are you with me? He gave up even that! And if you have all the power and you're omnipotent, how can you grow in stature? You can't, are you with me?
[77:15] Okay, so even Jesus Christ left His comfort zone, all the glories of celestial heaven, and came down; He took the form of what? A man, but not just a man, of a servant, or a slave, and He was obedient even unto the death of the cross.
[78:00] Now, if God the Father in His wisdom can use this pattern throughout 6,000 years of earth history to spread His gospel, who are you and I to think that we ought to change that paradigm?
[78:45] Who are you and I as a church to think that, "No, no, no, no, we ought to focus our evangelism on the poor, and let's focus on them, let the rich men stay in their mansions, they won't listen, let them drive away in their V8s, they won't slow down, let them live their lives, let's leave them alone. We will have a few of them here and there, you know, and we'll give them donor fatigue from asking them to fund every single church program that we want to run." Right?
[79:35] Who are we to change a very clear biblical paradigm of evangelism and mission? This is why in the morning we called it what? "Sabotaging the Kingdom." That's what we are doing, I don't see any other way to describe it. Let's go on, I believe we are almost done.
[80:20] Yes, so did Jesus reverse the pattern with His disciples? Very often we'll look in the New Testament and, like I said, we'll see a certain emphasis on the poor, yes, okay? And Jesus Christ did call twelve men who were not of the highest class in His society, true or false? Yes, He did. But let's observe the interesting thing about them, right?
[81:05] This is what Education tells us, the book Education by Ellen White: "By the work of Christ, these disciples had been led to feel their need of the Spirit..." Is this the first one on the disciples? Please go back. Very good, one step forward, very good, let's start here, because this is the beginning of their calling, okay?
[81:50] "The first pupils of Jesus were chosen from the ranks of the common people. They were humble, unlettered men, these fishermen of Galilee; men unschooled in the learning and customs of the rabbis, but trained by stern discipline of toil and hardship." That's the kind of person they were, that's true.
[82:40] Hardened by what? By the stern discipline of toil and hardship, because many of them were fishermen, don't forget, okay? So physical labor, dragging in tons of fish, following the orders of their father who would have been a master fisherman—that's the kind of life that they lived, okay?
[83:25] They were not schooled in the schools of the rabbis, they were not reciting the Torah, you know? They were unlettered men, don't forget. Even after Jesus Christ had risen, when Peter and John were heard preaching about the temple areas, the Pharisees were surprised and they asked, "Well, how could these people sound so eloquent, being unlettered?" Right? In other words, being unschooled. They were not well educated, right, not according to the schools of their day.
[84:15] But they were given an education, and their standard was raised before they were deployed out into mission, right? So let's go to the next slide.
[84:50] Yes, so by the work of Christ, these disciples...
[85:10] Audience member: At this point, I have a question... that I need clarification on...
[85:25] Speaker: Sure, let's hear it.
[85:35] Audience member: ...every Jewish child at the age of 12... was sent to the temple... learning... starting the law... Every Jewish child. Was that not applied to Christ and His disciples...?
[86:00] Speaker: That's a good observation. So here is the thing: you were given up to the age of 12 to show whether or not you were qualified to continue in that line, okay? At the age of 12, you would go and you would have to recite certain portions of the Torah, you'd have to do certain exercises to prove that you have the capacity for rabbinical learning, okay?
[86:50] Those who did are the ones that eventually became the scribes, okay? And those among the scribes who excelled further then became part of the rulers of the Pharisees, are you with me? Or the Sadducees, depending on which sect you belonged to, okay?
[87:35] But everybody else, which was the majority in many cases, right, would drop out, and then you would have to become a peasant—in the New Testament, they are referred to as ptōchos, right, the peasants, right? Sometimes referred to as the poor, okay? These were farmers and fishermen, right?
[88:20] Okay, so by the time you are 30 years old, I mean, you'd probably have forgotten all your Genesis chapter 1! Are you with me? You are not considered a learned person. In fact, the books of the rabbis included a certain book known as the Mishnah. In that Mishnah, one rabbi wrote that God populates His Israel with both people and cattle, and that the people are those who both know the law—they know the Torah—and they know the works of the rabbis, okay?
[89:10] The animals are those who don't know the work of the rabbis, but at least they know the Torah, are you with me? But for people who don't know the Torah and they also don't know the works of the rabbis, they are the dung that the cattle leaves upon the ground! Can you imagine? So those are the levels of reading that they aspired to, okay?
[90:00] So they would have seen the disciples as nothing, as nothing, okay? Everybody is given that chance, yes, but by the age of 12, we know who is who, okay? And if you are not one of the who-is-who, you are out on the sea fishing, are you with me? Okay, so that's a good observation, thank you for bringing it up.
[90:50] So the kind of learning that the Pharisees actually had at the feet of Christ was substantially different, okay? But the point is that they were brought up to a level by Christ, okay, in order to be successful as His apostles.
[91:35] So yes, no longer—and as a result of that training, the Spirit of Prophecy can say this about them: "No longer were they what? Ignorant and uncultured." So the idea that we should send out ignorant and uncultured people into the field because Christ called twelve poor and unlearned disciples, can that hold? Will that idea hold? No!
[92:20] All right, no longer were they ignorant and uncultured, which takes us back to the Spirit of Prophecy's advice in the morning, right? That if we want to do this kind of work, we must bring our minds up to the greatness of the work. You remember that? We must bring our minds up to the greatness of the work; we must prepare ourselves, we must make an investment, okay, in being excellent in this field.
[93:10] All right, let's move on, we are almost done.
[93:30] Okay, so Testimonies, Volume 6, page 78 to 79: "From the light given me, I know that a plain 'Thus saith the Lord' should now be spoken to men who have influence and authority in the world. They are stewards to whom God has committed important trusts. If they will accept His call, God will use them in His cause." He has used them throughout the Old Testament, He's used them throughout the New Testament—why don't we want Him to use them today?
[94:20] That's the question that ought to edge in our minds after going through this biblical tour. If it's good enough for God, why is it not good enough for us? Next please.
[94:50] All right, final slide before your... Let me just read this.
[95:00] Audience member: Can you give the reference again?
[95:10] Speaker: Volume 6, page 78 to 79, paragraph 4, okay? Cool.
[95:30] At the very end of time, in the book of Revelation, we are told about the New Jerusalem, right? We're told about the New Jerusalem; this is where the saved will be. Okay, and look at what we are told about the population, the inhabitants of that place.
[96:15] In addition to all the poor people you and I can think of from any of the worst villages that you can imagine in your mind, right, in addition to all of them, this is what we are told: "And the nations of them which are saved shall walk in the light of it, and the what? The kings of the earth do bring their glory and honor into it."
[97:00] God is waiting to receive the kings of the earth into the New Jerusalem! Yes! Why not? The only reason they will not make it, He says, is because you will not reach out to them. Amen!
[97:45] So give them the chance! But this is Scripture. God is waiting to receive the kings of the earth in addition to anybody else you can imagine, right? Thank you, we are done, okay? "The kings of the earth do bring their honor into it."
[98:30] So question to end—this is a question that nobody needs to answer verbally, please carry it in your heart, okay? One of the main reasons that we give for not doing this work is we say it's too expensive. It has always been expensive, but God has always found ways to do it. So the question is: will we follow the Bible or our budget?
[99:15] God bless you. Amen.
''';
