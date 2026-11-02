import 'package:flutter/material.dart';

/// Specimen Audio & Transcript Data used for testing ALIVE Scribe and
/// demonstrating Spotify-style time-synced podcast transcription.
///
/// Can be easily enabled, customized, or removed after testing.
class ScribeAudioSpecimen {
  /// Toggle to enable or disable the specimen test mode across the app
  static const bool isSpecimenEnabled = true;

  /// Direct sample audio URL hosted in Appwrite Storage
  static const String specimenAudioUrl =
      'https://api.alivenigeria.org/v1/storage/buckets/podcast_media/files/test_podcast_agana_01/view?project=6a3bef53002f5090dedf';

  static const String specimenTitle =
      'The Power of Prayer & Leadership Fellowship (Sample Specimen)';

  static const String specimenSpeaker = 'Pastor John & Leadership Council';

  /// Timed segments for simulation and Spotify-style line-by-line highlighting
  static const List<Map<String, dynamic>> timedSegments = [
    {
      'seconds': 0,
      'time': '00:00',
      'speaker': 'Pastor John',
      'role': 'Host / Speaker',
      'color': 0xFF2563EB,
      'type': 'general',
      'text':
          'Welcome, dear leaders and brethren. Today we reflect on the divine mandate of prayer and coordinated stewardship across ALIVE Nigeria.',
    },
    {
      'seconds': 8,
      'time': '00:08',
      'speaker': 'Elder Timothy',
      'role': 'National Coordinator',
      'color': 0xFF10B981,
      'type': 'motion',
      'text':
          'I move that every chapter establishes a dedicated monthly prayer fellowship and aligns outreach initiatives with national guidelines.',
    },
    {
      'seconds': 18,
      'time': '00:18',
      'speaker': 'Sis Mary',
      'role': 'Director of Welfare',
      'color': 0xFFF59E0B,
      'type': 'decision',
      'text':
          'I second the motion. It is resolved that prayer vigils will commence on the first Friday of each month with welfare support provided.',
    },
    {
      'seconds': 28,
      'time': '00:28',
      'speaker': 'Pastor John',
      'role': 'Host / Speaker',
      'color': 0xFF2563EB,
      'type': 'actionItem',
      'task': 'Circulate monthly prayer schedule to all chapter coordinators',
      'assignee': 'Elder Timothy',
      'text':
          'Action item: Elder Timothy to circulate the monthly prayer schedule and welfare logistics to all chapter coordinators by Monday.',
    },
    {
      'seconds': 40,
      'time': '00:40',
      'speaker': 'Elder Timothy',
      'role': 'National Coordinator',
      'color': 0xFF10B981,
      'type': 'general',
      'text':
          'Agreed. We will also ensure all minutes and recorded resolutions are archived safely in the leadership Meeting Files repository.',
    },
  ];
}
