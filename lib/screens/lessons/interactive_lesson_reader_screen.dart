import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/bible_reference_modal_sheet.dart';
import '../../widgets/custom_image.dart';
import '../../services/interactive_lessons_service.dart';
import '../../services/pdf_extractor_service.dart';
import '../../services/auth_service.dart';
import '../../services/discipleship_service.dart';
import '../../models/discipleship_models.dart';

/// Full interactive study screen for Lesson 1: Something We Can Trust (What The Bible Says Series)
/// as well as any dynamically extracted Tract / Interactive Bible Study uploaded by Admins.
/// Implements dynamic brand colour palettes across sections, interactive reflection inputs,
/// clickable Bible verse popups, decision buttons, study commitment, and Discipleship Tracker sync.
class InteractiveLessonReaderScreen extends StatefulWidget {
  final String lessonId;
  final String title;
  final Map<String, dynamic>? lessonData;

  const InteractiveLessonReaderScreen({
    super.key,
    this.lessonId = 'lesson_something_we_can_trust',
    this.title = 'Lesson 1: Something We Can Trust',
    this.lessonData,
  });

  @override
  State<InteractiveLessonReaderScreen> createState() =>
      _InteractiveLessonReaderScreenState();
}

class _InteractiveLessonReaderScreenState
    extends State<InteractiveLessonReaderScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _prophecyChecked = {};
  final Map<int, bool> _messianicStudied = {};
  List<ExtractedLessonSection> _dynamicSections = [];

  bool get _isLesson1 =>
      widget.lessonId == 'lesson_something_we_can_trust' ||
      widget.title.toLowerCase().contains('something we can trust');

  String get _storagePrefix => _isLesson1
      ? 'interactive_lesson_1_'
      : 'interactive_lesson_${widget.lessonId}_';

  bool? _haveBible;
  bool? _studyBible;
  bool? _believeBible;
  bool _commitmentPrayer = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _prophecySearchController = TextEditingController();

  DiscipleshipLevel _selectedDiscipleshipLevel = DiscipleshipLevel.prospect;
  List<DiscipleshipContact> _userContacts = [];
  DiscipleshipContact? _matchedContact;
  int _matchedContactStudyCount = 0;

  double _progress = 0.0;
  bool _showSavedNotification = false;
  bool _isSaving = false;

  final Map<String, String> _lessonVerseQuotes = {
    '2 timothy 3:16':
        'All scripture is given by inspiration of God, and is profitable for doctrine, for reproof, for correction, for instruction in righteousness:',
    '2 peter 1:21':
        'Prophecy came not in old time by the will of man: but holy men of God spake as they were moved by the Holy Ghost.',
    'john 10:35': 'The scripture cannot be broken.',
    'isaiah 42:8, 9':
        'I am the Lord... new things do I declare: before they spring forth I tell you of them.',
    'isaiah 46:9, 10':
        'Declaring the end from the beginning, and from ancient times the things that are not yet done.',
    'psalms 119:160': 'Thy word is true from the beginning.',
    '2 corinthians 5:17':
        'Therefore if any man be in Christ, he is a new creature: old things are passed away; behold, all things are become new.',
    'luke 24:27':
        'And beginning at Moses and all the prophets, He expounded unto them in all the Scriptures the things concerning Himself.',
    'psalms 119:100':
        'I understand more than the ancients, because I keep thy precepts.',
    'psalms 119:105':
        'Thy word is a lamp unto my feet, and a light unto my path.',
    'john 17:17': 'Sanctify them through thy truth: thy word is truth.',
    'isaiah 8:20':
        'To the law and to the testimony: if they speak not according to this word, it is because there is no light in them.',
  };

  // Messianic prophecies table
  final List<Map<String, String>> _allMessianicProphecies = [
    {
      'subject': 'Born in Bethlehem',
      'ot': 'Micah 5:2',
      'nt': 'Matthew 2:1',
    },
    {
      'subject': 'Born of a virgin',
      'ot': 'Isaiah 7:14',
      'nt': 'Matthew 1:18-23',
    },
    {
      'subject': "David's lineage",
      'ot': 'Jeremiah 23:5',
      'nt': 'Revelation 22:16',
    },
    {
      'subject': "Herod's murder attempt",
      'ot': 'Jeremiah 31:15',
      'nt': 'Matthew 2:16-18',
    },
    {
      'subject': 'Betrayed by friend',
      'ot': 'Psalm 41:9',
      'nt': 'John 13:18, 19, 26',
    },
    {
      'subject': 'Sold for 30 silver coins',
      'ot': 'Zechariah 11:12',
      'nt': 'Matthew 26:14-16',
    },
    {
      'subject': 'Crucified',
      'ot': 'Zechariah 12:10',
      'nt': 'John 19:16-18, 37',
    },
    {
      'subject': 'Lots cast on His clothes',
      'ot': 'Psalm 22:18',
      'nt': 'Matthew 27:35',
    },
    {
      'subject': 'No bones broken',
      'ot': 'Psalm 34:20',
      'nt': 'John 19:31-36',
    },
    {
      'subject': "Buried in rich man's tomb",
      'ot': 'Isaiah 53:9',
      'nt': 'Matthew 27:57-60',
    },
    {
      'subject': 'Year, day, hour of death',
      'ot': 'Daniel 9:26, 27',
      'nt': 'Matthew 27:45-50',
    },
    {
      'subject': 'Raised the third day',
      'ot': 'Hosea 6:2',
      'nt': 'Acts 10:38-40',
    },
  ];

  List<Map<String, String>> _filteredMessianicProphecies = [];

  @override
  void initState() {
    super.initState();
    _filteredMessianicProphecies = List.from(_allMessianicProphecies);

    if (_isLesson1) {
      for (int i = 1; i <= 7; i++) {
        _controllers['q$i'] = TextEditingController();
      }
      _controllers['q8_a'] = TextEditingController();
      _controllers['q8_b'] = TextEditingController();
      _controllers['q8_c'] = TextEditingController();
    } else {
      final rawContent = widget.lessonData?['content']?.toString() ??
          InteractiveLessonsService.instance.lessons
              .where((l) => l.id == widget.lessonId)
              .map((l) => l.content)
              .firstOrNull ??
          widget.lessonData?['description']?.toString() ??
          '';
      final seed = widget.title.codeUnits
          .fold<int>(0, (prev, elem) => prev + elem);
      _dynamicSections = PdfExtractorService.parseInteractiveSections(
        rawContent,
        fallbackTitle: widget.title,
        basePaletteIndex: seed,
      );
      for (final sec in _dynamicSections) {
        if (sec.hasInputTarget) {
          _controllers['q${sec.number}'] = TextEditingController();
        }
        for (final q in sec.verseQuotes) {
          final r = q['reference']?.trim();
          final t = q['quote']?.trim();
          if (r != null && r.isNotEmpty && t != null && t.isNotEmpty) {
            _lessonVerseQuotes[r.toLowerCase()] = t;
          }
        }
      }
      if (_controllers.isEmpty) {
        _controllers['q1'] = TextEditingController();
      }
    }

    _loadSavedResponses();
    _loadDisciples();
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _prophecySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedResponses() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _storagePrefix;

    setState(() {
      for (final key in _controllers.keys) {
        final val = prefs.getString('$prefix$key');
        if (val != null) _controllers[key]?.text = val;
      }

      _nameController.text = prefs.getString('${prefix}name') ?? '';
      _phoneController.text = prefs.getString('${prefix}phone') ?? '';

      if (prefs.containsKey('${prefix}haveBible')) {
        _haveBible = prefs.getBool('${prefix}haveBible');
      }
      if (prefs.containsKey('${prefix}studyBible')) {
        _studyBible = prefs.getBool('${prefix}studyBible');
      }
      if (prefs.containsKey('${prefix}believeBible')) {
        _believeBible = prefs.getBool('${prefix}believeBible');
      }
      _commitmentPrayer = prefs.getBool('${prefix}commitmentPrayer') ?? false;
      _addressController.text = prefs.getString('${prefix}address') ?? '';
      final savedLevel = prefs.getString('${prefix}level');
      if (savedLevel != null) {
        _selectedDiscipleshipLevel = DiscipleshipLevel.values.firstWhere(
          (lvl) => lvl.name == savedLevel,
          orElse: () => DiscipleshipLevel.prospect,
        );
      }

      _calculateProgress();
    });
  }

  Future<void> _loadDisciples() async {
    try {
      final authService = AuthService.instance;
      final user = authService.currentUser ?? await authService.getCurrentUser();
      if (user != null) {
        final contacts = await DiscipleshipService.instance.getContacts(
          discipleMakerId: user.uid,
        );
        if (mounted) {
          setState(() {
            _userContacts = contacts;
          });
          if (_nameController.text.trim().isNotEmpty) {
            _checkExistingDiscipleMatch(_nameController.text.trim());
          }
        }
      }
    } catch (e) {
      debugPrint('Could not load existing disciples: $e');
    }
  }

  void _onNameChanged(String query) {
    _checkExistingDiscipleMatch(query.trim());
  }

  void _checkExistingDiscipleMatch(String query) {
    if (query.isEmpty) {
      if (_matchedContact != null) {
        setState(() {
          _matchedContact = null;
          _matchedContactStudyCount = 0;
        });
      }
      return;
    }

    final q = query.toLowerCase();
    DiscipleshipContact? found;
    for (final c in _userContacts) {
      if (c.fullName.toLowerCase() == q) {
        found = c;
        break;
      }
    }

    if (found != null && found != _matchedContact) {
      _selectContact(found);
    } else if (found == null && _matchedContact != null) {
      setState(() {
        _matchedContact = null;
        _matchedContactStudyCount = 0;
      });
    }
  }

  Future<void> _selectContact(DiscipleshipContact contact) async {
    setState(() {
      _matchedContact = contact;
      _nameController.text = contact.fullName;
      if (contact.phone != null && contact.phone!.isNotEmpty) {
        _phoneController.text = contact.phone!;
      }
      if (contact.address != null && contact.address!.isNotEmpty) {
        _addressController.text = contact.address!;
      }
      _selectedDiscipleshipLevel = contact.currentLevel;
    });

    try {
      final sessions = await DiscipleshipService.instance.getStudySessions(
        contactId: contact.id,
      );
      if (mounted) {
        setState(() {
          _matchedContactStudyCount = sessions.length;
        });
      }
    } catch (_) {}
  }

  void _clearMatchedContact() {
    setState(() {
      _matchedContact = null;
      _matchedContactStudyCount = 0;
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _selectedDiscipleshipLevel = DiscipleshipLevel.prospect;
    });
  }

  String _formatLevelName(DiscipleshipLevel level) {
    switch (level) {
      case DiscipleshipLevel.prospect:
        return 'Prospect';
      case DiscipleshipLevel.studying:
        return 'Studying';
      case DiscipleshipLevel.convinced:
        return 'Convinced';
      case DiscipleshipLevel.committed:
        return 'Committed';
      case DiscipleshipLevel.baptized:
        return 'Baptized';
      case DiscipleshipLevel.disciple:
        return 'Disciple';
    }
  }

  Future<void> _saveResponses() async {
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    final prefix = _storagePrefix;

    for (final entry in _controllers.entries) {
      await prefs.setString('$prefix${entry.key}', entry.value.text);
    }

    await prefs.setString('${prefix}name', _nameController.text);
    await prefs.setString('${prefix}phone', _phoneController.text);
    await prefs.setString('${prefix}address', _addressController.text);
    await prefs.setString('${prefix}level', _selectedDiscipleshipLevel.name);

    if (_haveBible != null) {
      await prefs.setBool('${prefix}haveBible', _haveBible!);
    }
    if (_studyBible != null) {
      await prefs.setBool('${prefix}studyBible', _studyBible!);
    }
    if (_believeBible != null) {
      await prefs.setBool('${prefix}believeBible', _believeBible!);
    }
    await prefs.setBool('${prefix}commitmentPrayer', _commitmentPrayer);

    _calculateProgress();

    // Sync progress to InteractiveLessonsService
    await InteractiveLessonsService.instance.updateLessonProgress(
      widget.lessonId,
      _progress,
    );

    // Sync to Discipleship Tracker if disciple name is provided
    bool discipleshipSynced = false;
    String discipleshipNotice = '';
    final fullName = _nameController.text.trim();

    if (fullName.isNotEmpty) {
      try {
        final authService = AuthService.instance;
        final authUser = authService.currentUser ?? await authService.getCurrentUser();
        if (authUser != null) {
          final discipleship = DiscipleshipService.instance;

          // Check if contact already exists
          DiscipleshipContact? contact = _matchedContact;
          if (contact == null) {
            final existing = await discipleship.getContacts(
              discipleMakerId: authUser.uid,
              searchQuery: fullName,
            );
            for (final c in existing) {
              if (c.fullName.toLowerCase() == fullName.toLowerCase() ||
                  (_phoneController.text.trim().isNotEmpty &&
                      c.phone == _phoneController.text.trim())) {
                contact = c;
                break;
              }
            }
          }

          if (contact != null) {
            // ── EXISTING DISCIPLE ──
            // 1. If stage / level changed, promote them in Discipleship Tracker!
            if (contact.currentLevel != _selectedDiscipleshipLevel) {
              contact = await discipleship.updateContactLevel(
                contact.id,
                _selectedDiscipleshipLevel,
              );
            }

            // 2. Update address or phone if newly provided
            final updatedPhone = _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : contact.phone;
            final updatedAddress = _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : contact.address;

            if (updatedPhone != contact.phone || updatedAddress != contact.address) {
              contact = await discipleship.updateContact(contact.copyWith(
                phone: updatedPhone,
                address: updatedAddress,
                lastContact: DateTime.now().toUtc(),
              ));
            }

            // 3. Log the new study session (increments study count!)
            await discipleship.createStudySession(
              StudySession(
                id: '',
                contactId: contact.id,
                discipleMakerId: authUser.uid,
                type: StudyType.bibleStudy,
                title: widget.title,
                topic: 'What The Bible Says Series',
                bibleTexts: '2 Tim 3:16, 2 Pet 1:21, Dan 9:26-27, John 17:17',
                date: DateTime.now(),
                durationMinutes: 20,
                completed: _progress >= 0.8,
                notes: 'Completed: ${(_progress * 100).toInt()}%. Lesson answers recorded.',
                createdAt: DateTime.now(),
              ),
            );

            // Fetch updated study count
            final sessions = await discipleship.getStudySessions(contactId: contact.id);
            _matchedContactStudyCount = sessions.length;
            _matchedContact = contact;

            discipleshipSynced = true;
            discipleshipNotice = '✓ Logged study #${sessions.length} for ${contact.fullName} (${_formatLevelName(_selectedDiscipleshipLevel)}) in Discipleship Tracker!';
          } else {
            // ── NEW DISCIPLE ──
            final nameParts = fullName.split(' ');
            final first = nameParts.first;
            final last = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Disciple';

            final newContact = await discipleship.createContact(
              DiscipleshipContact(
                id: '',
                discipleMakerId: authUser.uid,
                firstName: first,
                lastName: last,
                phone: _phoneController.text.trim().isNotEmpty
                    ? _phoneController.text.trim()
                    : null,
                address: _addressController.text.trim().isNotEmpty
                    ? _addressController.text.trim()
                    : null,
                currentLevel: _selectedDiscipleshipLevel,
                firstContact: DateTime.now(),
                lastContact: DateTime.now(),
                notes: 'Enrolled via interactive lesson: ${widget.title}',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            // Log their first study session
            await discipleship.createStudySession(
              StudySession(
                id: '',
                contactId: newContact.id,
                discipleMakerId: authUser.uid,
                type: StudyType.bibleStudy,
                title: widget.title,
                topic: 'What The Bible Says Series',
                bibleTexts: '2 Tim 3:16, 2 Pet 1:21, Dan 9:26-27, John 17:17',
                date: DateTime.now(),
                durationMinutes: 20,
                completed: _progress >= 0.8,
                notes: 'Initial study: 100% completed. Enrolled at ${_formatLevelName(_selectedDiscipleshipLevel)} stage.',
                createdAt: DateTime.now(),
              ),
            );

            _matchedContact = newContact;
            _matchedContactStudyCount = 1;
            _userContacts.add(newContact);

            discipleshipSynced = true;
            discipleshipNotice = '✓ Enrolled ${newContact.fullName} as ${_formatLevelName(_selectedDiscipleshipLevel)} & logged Study #1!';
          }
        }
      } catch (e) {
        debugPrint('Discipleship sync error (saved locally): $e');
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
        _showSavedNotification = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            discipleshipSynced
                ? discipleshipNotice
                : '✓ Study responses saved to your device!',
          ),
          backgroundColor: const Color(0xFF166534),
          duration: const Duration(seconds: 4),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showSavedNotification = false;
          });
        }
      });
    }
  }

  Future<void> _confirmResetStudy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.refresh_rounded, color: Color(0xFF166534)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reset Study for New Prospect?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'This will clear all your answers, responses, and disciple details from this screen so you can conduct this study fresh with a new prospect.\n\nAny prior study sessions logged to your Discipleship Tracker remain safely saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF166534)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset to 0%'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final prefix = _storagePrefix;
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }

      setState(() {
        for (final controller in _controllers.values) {
          controller.clear();
        }
        _nameController.clear();
        _phoneController.clear();
        _addressController.clear();
        _matchedContact = null;
        _matchedContactStudyCount = 0;
        _haveBible = null;
        _studyBible = null;
        _believeBible = null;
        _commitmentPrayer = false;
        _selectedDiscipleshipLevel = DiscipleshipLevel.prospect;
        _showSavedNotification = false;
        _calculateProgress();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Study reset to 0%! Ready for your new prospect.'),
            backgroundColor: Color(0xFF166534),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _calculateProgress() {
    int totalItems = _controllers.length + 4; // text fields + 3 toggles + prayer
    int filled = 0;

    for (var c in _controllers.values) {
      if (c.text.trim().isNotEmpty) filled++;
    }
    if (_haveBible != null) filled++;
    if (_studyBible != null) filled++;
    if (_believeBible != null) filled++;
    if (_commitmentPrayer) filled++;

    setState(() {
      _progress = (filled / totalItems).clamp(0.0, 1.0);
    });
  }

  void _filterProphecies(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMessianicProphecies = List.from(_allMessianicProphecies);
      } else {
        final q = query.toLowerCase();
        _filteredMessianicProphecies = _allMessianicProphecies.where((p) {
          return (p['subject'] ?? '').toLowerCase().contains(q) ||
              (p['ot'] ?? '').toLowerCase().contains(q) ||
              (p['nt'] ?? '').toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  String? _lookupQuote(String reference) {
    final key = reference.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return _lessonVerseQuotes[key];
  }

  void _openScripture(String reference, {String? initialQuote}) {
    final quote = initialQuote ?? _lookupQuote(reference);
    BibleReferenceModalSheet.show(
      context,
      reference: reference,
      initialQuote: quote,
      initialVersion: 'KJV',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: _isLesson1 ? 'What The Bible Says: Lesson 1' : widget.title,
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Sticky Top Progress Bar
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            minHeight: 5,
          ),
          Container(
            color: isDark ? const Color(0xFF1B2E1E) : const Color(0xFFE8F5E9),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Interactive Study Guide',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.green[900],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Reset study to 0% for a new prospect',
                      child: InkWell(
                        onTap: _confirmResetStudy,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, color: Colors.green, size: 14),
                              SizedBox(width: 3),
                              Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_progress * 100).toInt()}% Completed',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Study Content Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeroBanner(isDark),
                const SizedBox(height: 16),
                if (_isLesson1) ...[
                  _buildSection1(isDark),
                  const SizedBox(height: 16),
                  _buildSection2(isDark),
                  const SizedBox(height: 16),
                  _buildSection3(isDark),
                  const SizedBox(height: 16),
                  _buildSection4(isDark),
                  const SizedBox(height: 16),
                  _buildSection5(isDark),
                  const SizedBox(height: 16),
                  _buildSection6(isDark),
                  const SizedBox(height: 16),
                  _buildSection7(isDark),
                  const SizedBox(height: 16),
                  _buildSection8(isDark),
                  const SizedBox(height: 16),
                ] else ...[
                  ..._buildDynamicExtractedSections(isDark),
                ],
                _buildSection9Commitment(isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1E16) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E3D2B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 10,
        ),
        child: Row(
          children: [
            // Progress Indicator Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF143021) : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF22C55E).withValues(alpha: 0.4) : const Color(0xFF86EFAC),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _progress >= 1.0 ? Icons.check_circle : Icons.trending_up,
                    size: 16,
                    color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Persistent Save Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveResponses,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.cloud_done_outlined, size: 18, color: Colors.white),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : (_showSavedNotification ? 'Saved Successfully!' : 'Save Lesson Progress'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showSavedNotification
                      ? const Color(0xFF047857)
                      : const Color(0xFF166534),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    final heroPalette = _isLesson1
        ? LessonColorPalette.brandPalettes.first
        : LessonColorPalette.byId(
            _dynamicSections.firstOrNull?.paletteId,
            fallbackIndex: widget.title.hashCode,
          );
    final coverUrl = (widget.lessonData?['coverImage'] ??
                widget.lessonData?['cover_image'] ??
                widget.lessonData?['imageUrl'])
            ?.toString() ??
        (_isLesson1 ? 'assets/images/series/what_the_bible_says_lesson_1.jpg' : '');
    final categoryLabel =
        (widget.lessonData?['category']?.toString() ?? 'ALIVE NIGERIA SERIES')
            .toUpperCase();
    final heroVerse = _isLesson1
        ? 'Psalms 119:105'
        : (_dynamicSections
                .expand((s) => s.scriptureReferences)
                .firstOrNull ??
            '2 Timothy 3:16');
    final introDescription = _isLesson1
        ? 'In these morally challenged times when billions are embezzled through corporate fraud; when trusted spiritual leaders prove false; when lying in politics seems to be the norm... is there anything left you can trust?\n\nYes! You can fully trust the Bible! Just look at the evidence:'
        : (widget.lessonData?['description']?.toString().trim().isNotEmpty == true
            ? widget.lessonData!['description'].toString()
            : 'Explore God\'s Word interactively through scripture references, personal reflection prompts, and practical discipleship commitment.');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(heroPalette.darkGradientStartHex),
            Color(heroPalette.darkGradientEndHex),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        categoryLabel,
                        style: TextStyle(
                          color: Color(heroPalette.accentHex),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isLesson1 ? 'Something We Can Trust' : widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildScriptureChip(
                      heroVerse,
                      accentColor: Color(heroPalette.accentHex),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: coverUrl.isNotEmpty
                    ? (coverUrl.startsWith('assets/')
                        ? Image.asset(
                            coverUrl,
                            width: 90,
                            height: 115,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 90,
                              height: 115,
                              color: Colors.white12,
                              child: const Icon(Icons.book, color: Colors.white, size: 40),
                            ),
                          )
                        : SizedBox(
                            width: 90,
                            height: 115,
                            child: CustomImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                            ),
                          ))
                    : Container(
                        width: 90,
                        height: 115,
                        color: Colors.white12,
                        child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 40),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Color(heroPalette.lightTintHex),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              introDescription,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicExtractedSections(bool isDark) {
    if (_dynamicSections.isEmpty) {
      return [
        _buildSectionCard(
          number: 1,
          title: widget.title,
          isDark: isDark,
          children: [
            Text(
              widget.lessonData?['description']?.toString() ??
                  'Study content extracted from tract.',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            _buildReflectionInput(
              label: 'Your Study Notes & Reflection',
              hint: 'Write your insights and personal response...',
              controller: _controllers.putIfAbsent('q1', () => TextEditingController()),
              isDark: isDark,
              sectionNumber: 1,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ];
    }

    final widgets = <Widget>[];
    for (final sec in _dynamicSections) {
      final palette = LessonColorPalette.byId(
        sec.paletteId,
        fallbackIndex: sec.number - 1,
      );
      final controller = _controllers.putIfAbsent(
        'q${sec.number}',
        () => TextEditingController(),
      );

      widgets.add(
        _buildSectionCard(
          number: sec.number,
          title: sec.title,
          isDark: isDark,
          palette: palette,
          children: [
            for (final q in sec.verseQuotes)
              _buildVerseQuoteCard(
                quote: q['quote'] ?? '',
                reference: q['reference'] ?? '',
                isDark: isDark,
                palette: palette,
              ),
            if (sec.bodyText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                sec.bodyText,
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
            ],
            if (sec.scriptureReferences.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: sec.scriptureReferences
                    .map((ref) => _buildScriptureChip(
                          ref,
                          accentColor: Color(palette.primaryHex),
                        ))
                    .toList(),
              ),
            ],
            if (sec.hasInputTarget)
              _buildReflectionInput(
                label: sec.reflectionPrompt,
                hint: 'Write your answer or personal reflection on Section ${sec.number}...',
                controller: controller,
                isDark: isDark,
                sectionNumber: sec.number,
                palette: palette,
              ),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }
    return widgets;
  }

  Widget _buildSectionCard({
    required int number,
    required String title,
    required List<Widget> children,
    required bool isDark,
    LessonColorPalette? palette,
  }) {
    final effectivePalette =
        palette ?? LessonColorPalette.byId(null, fallbackIndex: number - 1);
    final primaryColor = Color(effectivePalette.primaryHex);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: primaryColor,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildVerseQuoteCard({
    required String quote,
    required String reference,
    required bool isDark,
    LessonColorPalette? palette,
  }) {
    final effectivePalette =
        palette ?? LessonColorPalette.byId(null, fallbackIndex: reference.hashCode);
    final primaryColor = Color(effectivePalette.primaryHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Color(effectivePalette.darkTintHex)
            : Color(effectivePalette.lightTintHex),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: primaryColor, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$quote"',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.4,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: _buildScriptureChip(
              reference,
              quote: quote,
              accentColor: isDark ? Color(effectivePalette.accentHex) : primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptureChip(String reference, {Color? accentColor, String? quote}) {
    final chipColor = accentColor ?? Colors.green;
    return InkWell(
      onTap: () => _openScripture(reference, initialQuote: quote),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: chipColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new, color: chipColor, size: 12),
            const SizedBox(width: 4),
            Text(
              reference,
              style: TextStyle(
                color: chipColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReflectionInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDark,
    int maxLines = 2,
    int sectionNumber = 1,
    LessonColorPalette? palette,
  }) {
    final effectivePalette =
        palette ?? LessonColorPalette.byId(null, fallbackIndex: sectionNumber - 1);
    final focusColor = Color(effectivePalette.primaryHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: isDark ? Colors.white60 : focusColor,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: (_) => _calculateProgress(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white30 : Colors.grey[400],
            ),
            filled: true,
            fillColor: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: focusColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSection1(bool isDark) {
    return _buildSectionCard(
      number: 1,
      title: 'What does the Bible claim about itself?',
      isDark: isDark,
      children: [
        _buildVerseQuoteCard(
          quote: 'All scripture is given by inspiration of God.',
          reference: '2 Timothy 3:16',
          isDark: isDark,
        ),
        _buildVerseQuoteCard(
          quote:
              'Prophecy came not in old time by the will of man: but holy men of God spake as they were moved by the Holy Ghost.',
          reference: '2 Peter 1:21',
          isDark: isDark,
        ),
        _buildVerseQuoteCard(
          quote: 'The scripture cannot be broken.',
          reference: 'John 10:35',
          isDark: isDark,
        ),
        const SizedBox(height: 6),
        const Text(
          'It claims to be inspired. It was written by men who were guided by the Holy Ghost. It cannot be broken or fail.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        _buildReflectionInput(
          label: 'Your Personal Reflection / Summary',
          hint: 'What does divine inspiration mean to your confidence in Scripture?',
          controller: _controllers['q1']!,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSection2(bool isDark) {
    return _buildSectionCard(
      number: 2,
      title: 'How did Jesus demonstrate His confidence and belief in Scripture?',
      isDark: isDark,
      children: [
        _buildVerseQuoteCard(
          quote:
              'Jesus said, "It is written, Man shall not live by bread alone." "It is written again, Thou shalt not tempt the Lord thy God." "It is written, Thou shalt worship the Lord thy God, and him only shalt thou serve."',
          reference: 'Matthew 4:4, 7, 10',
          isDark: isDark,
        ),
        const SizedBox(height: 6),
        const Text(
          'Jesus quoted Scripture when meeting the temptations of Satan. He also stated that the Bible is truth (John 17:17). Jesus often quoted Scripture as authority for the truth He taught.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        _buildReflectionInput(
          label: 'Practical Application',
          hint: 'How can you apply "It is written" in your daily temptations?',
          controller: _controllers['q2']!,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSection3(bool isDark) {
    final prophecies = [
      {'title': 'Four world empires', 'detail': 'Babylon, Medo-Persia, Greece, and Rome (Daniel 2, 7, 8)'},
      {'title': 'Cyrus named', 'detail': 'Named 150 years beforehand to conquer Babylon (Isaiah 45:1-3)'},
      {'title': 'Babylon destroyed', 'detail': 'Never to be inhabited again (Isaiah 13:19, 20; Jeremiah 51:37)'},
      {'title': "Egypt's status", 'detail': 'Never again to rule among nations (Ezekiel 29:14, 15)'},
      {'title': 'End-time fear', 'detail': 'Earth-shaking distress of nations with perplexity (Luke 21:25, 26)'},
      {'title': 'Moral decline', 'detail': 'Spiritual decay in the last days (2 Timothy 3:1-5)'},
    ];

    return _buildSectionCard(
      number: 3,
      title: 'Do Bible prophecies confirm inspiration?',
      isDark: isDark,
      children: [
        _buildVerseQuoteCard(
          quote: 'I am the Lord... new things do I declare: before they spring forth I tell you of them.',
          reference: 'Isaiah 42:8, 9',
          isDark: isDark,
        ),
        _buildVerseQuoteCard(
          quote: 'Declaring the end from the beginning, and from ancient times the things that are not yet done.',
          reference: 'Isaiah 46:9, 10',
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        const Text(
          'Bible predictions confirm inspiration as they come to pass. Check the fulfilled prophecies you have studied:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...prophecies.map((p) {
          final isChecked = _prophecyChecked[p['title']] ?? false;
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.green,
            title: Text(p['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(p['detail']!, style: const TextStyle(fontSize: 12)),
            value: isChecked,
            onChanged: (val) {
              setState(() {
                _prophecyChecked[p['title']!] = val ?? false;
              });
            },
          );
        }),
        _buildReflectionInput(
          label: 'Fulfilled Prophecy Reflection',
          hint: 'Which fulfilled prophecy gives you the greatest conviction?',
          controller: _controllers['q3']!,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSection4(bool isDark) {
    return _buildSectionCard(
      number: 4,
      title: 'Can we expect scientific statements in the Bible to be accurate?',
      isDark: isDark,
      children: [
        _buildVerseQuoteCard(
          quote: 'Thy word is true from the beginning.',
          reference: 'Psalms 119:160',
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Scientific Facts Confirmed by the Bible:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              const Text('• Earth hung on nothing: Job 26:7', style: TextStyle(fontSize: 13)),
              const Text('• Earth is a sphere: Isaiah 40:22', style: TextStyle(fontSize: 13)),
              const Text('• Why the atom holds together: Colossians 1:17 ("By Him all things hold together")',
                  style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        _buildReflectionInput(
          label: 'Science & Faith Reflection',
          hint: 'How does scientific foreknowledge strengthen your trust in Scripture?',
          controller: _controllers['q4']!,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSection5(bool isDark) {
    return _buildSectionCard(
      number: 5,
      title: 'What evidence of Bible inspiration is found in transformed lives?',
      isDark: isDark,
      children: [
        _buildVerseQuoteCard(
          quote:
              'Therefore if any man be in Christ, he is a new creature: old things are passed away; behold, all things are become new.',
          reference: '2 Corinthians 5:17',
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF262314) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.format_quote, color: Colors.amber, size: 20),
                  SizedBox(width: 6),
                  Text('A Father Transformed (1998 Testimony)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '"For many years our father lived a drunkard and traditional community leader. In 1998 the truth of the Bible was revealed to our family. Everything changed. He became a faithful preacher of the Gospel until his death. The Bible truly does change people."',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white70 : const Color(0xFF78350F),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        _buildReflectionInput(
          label: 'Your Personal Experience',
          hint: 'Have you witnessed God\'s Word transform a life or your own habits?',
          controller: _controllers['q5']!,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSection6(bool isDark) {
    return _buildSectionCard(
      number: 6,
      title: 'What evidence for Bible inspiration emerges from Messianic prophecies?',
      isDark: isDark,
      children: [
        _buildVerseQuoteCard(
          quote:
              'And beginning at Moses and all the prophets, He expounded unto them in all the Scriptures the things concerning Himself.',
          reference: 'Luke 24:27',
          isDark: isDark,
        ),
        const SizedBox(height: 6),
        const Text(
          'More than 125 Old Testament prophecies were fulfilled in Jesus Christ down to exact detail.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),

        // Filter search field
        TextField(
          controller: _prophecySearchController,
          onChanged: _filterProphecies,
          decoration: InputDecoration(
            hintText: 'Filter prophecy (e.g. Bethlehem, Virgin, 30 silver)...',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            filled: true,
            fillColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 10),

        // Prophecies Table Card
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: _filteredMessianicProphecies.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final isStudied = _messianicStudied[idx] ?? false;

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white10 : Colors.grey[200]!,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        p['subject']!,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () => _openScripture(p['ot']!),
                        child: Text(
                          p['ot']!,
                          style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () => _openScripture(p['nt']!),
                        child: Text(
                          p['nt']!,
                          style: TextStyle(
                            color: isDark ? Colors.blue[300] : Colors.blue[800],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Checkbox(
                      value: isStudied,
                      activeColor: Colors.green,
                      visualDensity: VisualDensity.compact,
                      onChanged: (val) {
                        setState(() {
                          _messianicStudied[idx] = val ?? false;
                        });
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        _buildReflectionInput(
          label: 'Conclusion Regarding Jesus',
          hint: 'Does mathematical and historical fulfillment prove Jesus is the Son of God?',
          controller: _controllers['q6']!,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSection7(bool isDark) {
    return _buildSectionCard(
      number: 7,
      title: 'What advantage does a person have who accepts the Bible as God\'s Word?',
      isDark: isDark,
      children: [
        _buildVerseQuoteCard(
          quote: 'I understand more than the ancients, because I keep thy precepts.',
          reference: 'Psalms 119:100',
          isDark: isDark,
        ),
        const SizedBox(height: 6),
        const Text(
          'Answers to life\'s foundational questions:\n1. Creation in 6 literal days (Exodus 20:11)\n2. Universal Flood answering geological mysteries (Genesis 7)\n3. Origin of languages at Babel (Genesis 11)',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
        _buildReflectionInput(
          label: 'Biblical Worldview Reflection',
          hint: 'Which area of God\'s revelation guides your worldview most?',
          controller: _controllers['q7']!,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSection8(bool isDark) {
    return _buildSectionCard(
      number: 8,
      title: 'What is the Bible\'s universal appeal to life\'s 3 puzzling questions?',
      isDark: isDark,
      children: [
        _buildVerseQuoteCard(
          quote: 'Thy word is a lamp unto my feet, and a light unto my path.',
          reference: 'Psalms 119:105',
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _buildSubQuestion(
          letter: 'A',
          title: 'Where did I come from?',
          answer:
              'God created us in His image. We are sons and daughters of God (Galatians 3:26).',
          controller: _controllers['q8_a']!,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _buildSubQuestion(
          letter: 'B',
          title: 'Why am I here?',
          answer:
              'To discover God\'s truth and accept Jesus\' offer to restore us into His image (Romans 8:29).',
          controller: _controllers['q8_b']!,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _buildSubQuestion(
          letter: 'C',
          title: 'What does the future hold for me?',
          answer:
              'Jesus will return very soon to take His redeemed home to heaven for eternity (John 14:1-3; Revelation 21:3, 4).',
          controller: _controllers['q8_c']!,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSubQuestion({
    required String letter,
    required String title,
    required String answer,
    required TextEditingController controller,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: Colors.green[800],
                child: Text(letter,
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Text(answer, style: const TextStyle(fontSize: 12, height: 1.4)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            onChanged: (_) => _calculateProgress(),
            decoration: InputDecoration(
              hintText: 'Enter your note on this question...',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: const EdgeInsets.all(8),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSection9Commitment(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F3D24), const Color(0xFF072415)]
              : [const Color(0xFF14532D), const Color(0xFF064E3B)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Response & Commitment',
            style: TextStyle(
              color: Colors.amberAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Making God\'s Word Your Foundation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          // Three Yes/No buttons
          _buildYesNoDecision('Do you have a Bible?', _haveBible, (v) {
            setState(() => _haveBible = v);
            _calculateProgress();
          }),
          const SizedBox(height: 8),
          _buildYesNoDecision('Do you study the Bible?', _studyBible, (v) {
            setState(() => _studyBible = v);
            _calculateProgress();
          }),
          const SizedBox(height: 8),
          _buildYesNoDecision('Do you believe the Bible?', _believeBible, (v) {
            setState(() => _believeBible = v);
            _calculateProgress();
          }),
          const SizedBox(height: 14),

          // Prayer commitment
          CheckboxListTile(
            dense: true,
            activeColor: Colors.amber,
            contentPadding: EdgeInsets.zero,
            value: _commitmentPrayer,
            onChanged: (val) {
              setState(() => _commitmentPrayer = val ?? false);
              _calculateProgress();
            },
            title: const Text(
              'My Study Commitment',
              style: TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            subtitle: const Text(
              'I commit to prayerful study of the Bible from today. Lord, grant me the enabling power of Your Holy Spirit.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),

          // ── Discipleship Tracker Integration Card ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt, color: Colors.amberAccent, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Disciple Details (Discipleship Tracker)',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (_matchedContact != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                        tooltip: 'Clear selection',
                        onPressed: _clearMatchedContact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Record who you studied with. Existing disciples will be updated with this new study; new persons will be enrolled into your Discipleship Tracker.',
                  style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                ),
                const SizedBox(height: 12),

                // Match status pill/badge if existing disciple is matched
                if (_matchedContact != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14532D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Matched: ${_matchedContact!.fullName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$_matchedContactStudyCount prior studies logged • Current Stage: ${_formatLevelName(_matchedContact!.currentLevel)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Name field with autocomplete from existing contacts
                _buildDiscipleNameAutocomplete(),
                const SizedBox(height: 10),

                // Phone and Address Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone / WhatsApp',
                          labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                          hintText: 'e.g. 08012345678',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Campus / Location',
                          labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                          hintText: 'e.g. UNILAG / Hall 3',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Discipleship Stage / Level Dropdown
                Row(
                  children: [
                    const Text(
                      'Stage / Level:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<DiscipleshipLevel>(
                            value: _selectedDiscipleshipLevel,
                            dropdownColor: const Color(0xFF14241B),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.amberAccent),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            items: DiscipleshipLevel.values.map((lvl) {
                              return DropdownMenuItem<DiscipleshipLevel>(
                                value: lvl,
                                child: Text(_formatLevelName(lvl)),
                              );
                            }).toList(),
                            onChanged: (lvl) {
                              if (lvl != null) {
                                setState(() => _selectedDiscipleshipLevel = lvl);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDiscipleNameAutocomplete() {
    return Autocomplete<DiscipleshipContact>(
      initialValue: TextEditingValue(text: _nameController.text),
      displayStringForOption: (contact) => contact.fullName,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.trim().isEmpty) {
          return _userContacts;
        }
        final q = textEditingValue.text.trim().toLowerCase();
        return _userContacts.where((c) {
          return c.fullName.toLowerCase().contains(q) ||
              (c.phone != null && c.phone!.contains(q));
        });
      },
      onSelected: (contact) {
        _selectContact(contact);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          onChanged: (val) {
            _nameController.text = val;
            _onNameChanged(val);
          },
          decoration: InputDecoration(
            labelText: 'Disciple Name (or search existing)',
            labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
            hintText: 'Type to search or enter new name',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
            prefixIcon: const Icon(Icons.person_search, color: Colors.amberAccent, size: 20),
            suffixIcon: _userContacts.isNotEmpty
                ? PopupMenuButton<DiscipleshipContact>(
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    tooltip: 'Choose existing disciple',
                    onSelected: (c) {
                      textEditingController.text = c.fullName;
                      _selectContact(c);
                    },
                    itemBuilder: (ctx) => _userContacts.map((c) {
                      return PopupMenuItem<DiscipleshipContact>(
                        value: c,
                        child: Text('${c.fullName} (${_formatLevelName(c.currentLevel)})'),
                      );
                    }).toList(),
                  )
                : null,
            isDense: true,
            filled: true,
            fillColor: Colors.black26,
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: const Color(0xFF162E20),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final contact = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(contact.fullName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text(
                      '${_formatLevelName(contact.currentLevel)}${contact.phone != null ? ' • ${contact.phone}' : ''}',
                      style: const TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                    trailing: const Icon(Icons.add_task, color: Colors.greenAccent, size: 16),
                    onTap: () => onSelected(contact),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildYesNoDecision(
      String question, bool? currentVal, Function(bool) onSelect) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            question,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => onSelect(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentVal == true ? Colors.green : Colors.white24,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: const Size(50, 32),
              ),
              child: const Text('YES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => onSelect(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentVal == false ? Colors.red : Colors.white24,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: const Size(50, 32),
              ),
              child: const Text('NO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        )
      ],
    );
  }
}

