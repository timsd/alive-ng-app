import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/pdf_extractor_service.dart';
import '../../services/firebase_database_service.dart';
import '../../data/missions_data.dart'; // Using local enums initially

class AdminKidsMissionsScreen extends StatefulWidget {
  const AdminKidsMissionsScreen({super.key});

  @override
  State<AdminKidsMissionsScreen> createState() => _AdminKidsMissionsScreenState();
}

class _AdminKidsMissionsScreenState extends State<AdminKidsMissionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pdfExtractor = PdfExtractorService();
  final _dbService = FirebaseDatabaseService.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController(text: 'Home');
  final TextEditingController _durationController = TextEditingController(text: '30 minutes');
  final TextEditingController _pointsController = TextEditingController(text: '100');
  final TextEditingController _instructionsController = TextEditingController();

  MissionDifficulty _selectedDifficulty = MissionDifficulty.beginner;
  MissionCategory _selectedCategory = MissionCategory.character;
  VerificationMethod _selectedVerification = VerificationMethod.photo;
  
  Uint8List? _mediaBytes;
  String? _mediaName;

  bool _isExtracting = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    _pointsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _extractFromDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isExtracting = true);
        
        final text = await _pdfExtractor.extractTextFromBytes(
          result.files.single.bytes!,
          result.files.single.name,
        );

        setState(() {
          _instructionsController.text = text;
        });
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document successfully extracted!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to extract: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _mediaBytes = result.files.single.bytes;
        _mediaName = result.files.single.name;
      });
    }
  }

  Future<void> _saveMission() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      String? uploadedMediaUrl;

      // 1. Upload Media
      if (_mediaBytes != null && _mediaName != null) {
        final path = 'kids_missions/media/${DateTime.now().millisecondsSinceEpoch}_$_mediaName';
        uploadedMediaUrl = await _dbService.uploadFile(path, _mediaBytes!);
      }

      // 2. Build Payload
      final pointsInt = int.tryParse(_pointsController.text.trim()) ?? 50;
      final rawInstructions = _instructionsController.text.trim();
      final instructionsList = rawInstructions.isNotEmpty 
          ? rawInstructions.split('\n').where((s) => s.trim().isNotEmpty).toList()
          : <String>['Follow the mission steps provided.'];
      
      final payload = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'difficulty': _selectedDifficulty.name,
        'duration': _durationController.text.trim(),
        'points': pointsInt,
        'category': _selectedCategory.name,
        'completed': false,
        'instructions': instructionsList,
        'verificationMethod': _selectedVerification.name,
        'prerequisiteMissionIds': [],
        'isLocked': false,
        'mediaUrl': uploadedMediaUrl,
        'created_at': FieldValue.serverTimestamp(),
      };

      // 3. Save to Firebase 
      await _dbService.firestore.collection('kids_missions').add(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mission published successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Kids Mission'),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Zero-Code Mission Extractor',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a PDF of mission instructions to instantly populate the step-by-step checklist.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 200 / 255.0)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _isExtracting ? null : _extractFromDocument,
                              icon: _isExtracting 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.picture_as_pdf),
                              label: Text(_isExtracting ? 'Extracting...' : 'Upload Instruction Doc'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text('Visuals', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickMedia,
                        icon: const Icon(Icons.perm_media),
                        label: Text(_mediaName ?? 'Select Example Media (Image/Video)'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text('Mission Core', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Short Description', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<MissionCategory>(
                            value: _selectedCategory,
                            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                            items: MissionCategory.values.map((c) {
                              return DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()));
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedCategory = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<MissionDifficulty>(
                            value: _selectedDifficulty,
                            decoration: const InputDecoration(labelText: 'Difficulty', border: OutlineInputBorder()),
                            items: MissionDifficulty.values.map((a) {
                              return DropdownMenuItem(value: a, child: Text(a.name.toUpperCase()));
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedDifficulty = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pointsController,
                            decoration: const InputDecoration(labelText: 'Points Awarded', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            decoration: const InputDecoration(labelText: 'Estimated Duration', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<VerificationMethod>(
                            value: _selectedVerification,
                            decoration: const InputDecoration(labelText: 'Verification', border: OutlineInputBorder()),
                            items: VerificationMethod.values.map((v) {
                              return DropdownMenuItem(value: v, child: Text(v.name.toUpperCase()));
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedVerification = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Instructions (One per line)', 
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        hintText: 'Extract via PDF or type them out separated by returns.',
                      ),
                      maxLines: 8,
                    ),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                        onPressed: _saveMission,
                        child: const Text('Create Mission', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
