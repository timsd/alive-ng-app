import 'package:flutter/material.dart';
import 'enhanced_jitsi_meet_screen.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firebase_database_service.dart';
import '../../models/app_models.dart';
import '../../utils/responsive_utils.dart';
import '../../config/app_config.dart';
import '../../config/meeting_links_config.dart';

class ConferencePlatformScreen extends StatefulWidget {
  const ConferencePlatformScreen({super.key});

  @override
  State<ConferencePlatformScreen> createState() => _ConferencePlatformScreenState();
}

class _ConferencePlatformScreenState extends State<ConferencePlatformScreen> {
  final FirebaseDatabaseService _firebaseService = FirebaseDatabaseService.instance;
  bool _isLoading = true;
  bool _hasAccess = false;
  User? _currentUser;
  UserProfile? _userProfile;
  List<ConferenceMeeting> _upcomingMeetings = [];
  List<ConferenceMeeting> _pastMeetings = [];
  int _selectedTabIndex = 0;

  bool _canStartGeneralMeeting() {
    final role = (_userProfile?.role ?? '').toLowerCase();
    return role == 'admin' ||
        role == 'bod' ||
        role == 'director' ||
        role == 'chapter_leader' ||
        role == 'moderator';
  }

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get user profile from Firebase
        final userProfile = await _firebaseService.getUserProfile(user.uid);
        _currentUser = user;
        _userProfile = userProfile;
        
        // For now, allow access - role checking should be implemented with UserProfile
        _hasAccess = true;
        
        if (_hasAccess) {
          await _loadMeetings();
        }
      }
    } catch (e) {
      _hasAccess = false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadMeetings() async {
    try {
      // Fetch meetings from Firebase
      final now = DateTime.now();
      final snapshot = await FirebaseFirestore.instance
          .collection('conference_meetings')
          .where('scheduled_time', isGreaterThanOrEqualTo: now.toIso8601String())
          .orderBy('scheduled_time')
          .get();
      
      final response = snapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList();
      
      // If no data from Firebase, use placeholder data only when not in live mode
      if (response.isEmpty && !AppConfig.isLiveMode) {
        setState(() {
          _upcomingMeetings = [
            ConferenceMeeting(
              id: '1',
              title: 'Chapter Coordinators Monthly Meeting',
              description: 'Monthly coordination meeting for all chapter coordinators',
              scheduledTime: now.add(const Duration(days: 2)),
              duration: 60,
              hostId: 'host1',
              hostName: 'Nwoko Patience Mfon',
              meetingType: 'chapter_coordination',
              participants: ['coord1', 'coord2', 'coord3'],
              maxParticipants: 20,
              isRecurring: true,
              meetingLink: 'https://meet.alive.ng/chapter-coord-001',
              status: 'scheduled',
              roomName: 'chapter-coord-monthly-${DateTime.now().millisecondsSinceEpoch}',
            ),
            ConferenceMeeting(
              id: '2',
              title: 'Board of Directors Quarterly Review',
              description: 'Quarterly review of organizational progress and strategic planning',
              scheduledTime: now.add(const Duration(days: 7)),
              duration: 120,
              hostId: 'host2',
              hostName: 'Caleb Peters',
              meetingType: 'bod_meeting',
              participants: ['bod1', 'bod2', 'trustee1'],
              maxParticipants: 10,
              isRecurring: false,
              meetingLink: 'https://meet.alive.ng/bod-quarterly-002',
              status: 'scheduled',
              roomName: 'bod-quarterly-${DateTime.now().millisecondsSinceEpoch}',
            ),
          ];
          
          _pastMeetings = [
            ConferenceMeeting(
              id: '3',
              title: 'Lagos Chapters Joint Meeting',
              description: 'Joint meeting for Lagos 1, Lagos 2, and Lagos 3 chapters',
              scheduledTime: now.subtract(const Duration(days: 3)),
              duration: 90,
              hostId: 'host3',
              hostName: 'Timothy Olodude',
              meetingType: 'chapter_meeting',
              participants: ['member1', 'member2', 'coord1'],
              maxParticipants: 15,
              isRecurring: false,
              meetingLink: 'https://meet.alive.ng/lagos-joint-003',
              status: 'completed',
              roomName: 'lagos-joint-meeting-past',
            ),
          ];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading meetings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Conference Platform'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 64.0,
                  tablet: 72.0,
                  desktop: 80.0,
                ),
                color: Colors.grey,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16.0,
                tablet: 20.0,
                desktop: 24.0,
              )),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 24.0,
                    tablet: 28.0,
                    desktop: 32.0,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              )),
              const Text(
                'You do not have permission to access the conference platform.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conference Platform'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMeetings,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!AppConfig.isLiveMode)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
                vertical: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 8.0,
                  tablet: 10.0,
                  desktop: 12.0,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 12.0,
                      tablet: 14.0,
                      desktop: 16.0,
                    ),
                  ),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                  ),
                ),
                padding: EdgeInsets.all(
                  ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    SizedBox(width: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    )),
                    Expanded(
                      child: Text(
                        'Demo mode: showing sample meetings. Connect Firebase to view and schedule live meetings.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _loadMeetings,
                      child: const Text('Refresh'),
                    )
                  ],
                ),
              ),
            ),
          // Quick join buttons for configured live meeting links
          if (AppConfig.isLiveMode && (
            MeetingLinksConfig.bodMeetingUrl.isNotEmpty ||
            MeetingLinksConfig.leadershipMeetingUrl.isNotEmpty ||
            MeetingLinksConfig.prayerMeetingUrl.isNotEmpty ||
            MeetingLinksConfig.generalMeetingUrl.isNotEmpty
          ))
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
                vertical: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 8.0,
                  tablet: 10.0,
                  desktop: 12.0,
                ),
              ),
              child: Row(
                children: [
                  if (MeetingLinksConfig.bodMeetingUrl.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _joinPredefinedMeeting(MeetingType.board),
                        icon: const Icon(Icons.groups),
                        label: const Text('Join BOD Meeting'),
                      ),
                    ),
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0,
                  )),
                  if (MeetingLinksConfig.leadershipMeetingUrl.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _joinPredefinedMeeting(MeetingType.leadership),
                        icon: const Icon(Icons.manage_accounts),
                        label: const Text('Join Leadership Meeting'),
                      ),
                    ),
                ],
              ),
            ),
          if (AppConfig.isLiveMode && (
            MeetingLinksConfig.prayerMeetingUrl.isNotEmpty ||
            MeetingLinksConfig.generalMeetingUrl.isNotEmpty
          ))
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
                vertical: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 4.0,
                  tablet: 6.0,
                  desktop: 8.0,
                ),
              ),
              child: Row(
                children: [
                  if (MeetingLinksConfig.prayerMeetingUrl.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _joinPredefinedMeeting(MeetingType.prayer),
                        icon: const Icon(Icons.volunteer_activism),
                        label: const Text('Join Prayer Meeting'),
                      ),
                    ),
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0,
                  )),
                  if (MeetingLinksConfig.generalMeetingUrl.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _canStartGeneralMeeting() ? () => _joinPredefinedMeeting(MeetingType.general) : null,
                        icon: const Icon(Icons.people_alt),
                        label: const Text('Join General Meeting'),
                      ),
                    ),
                ],
              ),
            ),
          // Action Buttons
          Container(
            padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            )),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _canScheduleMeeting() ? _showScheduleMeetingDialog : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Schedule Meeting'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0,
                      )),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 12.0,
                  tablet: 16.0,
                  desktop: 20.0,
                )),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showJoinMeetingDialog,
                    icon: const Icon(Icons.video_call),
                    label: const Text('Join Meeting'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0,
                      )),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            margin: EdgeInsets.symmetric(horizontal: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            )),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 25.0,
                tablet: 28.0,
                desktop: 32.0,
              )),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0,
                      )),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 25.0,
                          tablet: 28.0,
                          desktop: 32.0,
                        )),
                      ),
                      child: Text(
                        'Upcoming (${_upcomingMeetings.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTabIndex == 0
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0,
                      )),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 25.0,
                          tablet: 28.0,
                          desktop: 32.0,
                        )),
                      ),
                      child: Text(
                        'Past (${_pastMeetings.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTabIndex == 1
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 16.0,
            tablet: 20.0,
            desktop: 24.0,
          )),
          
          // Meeting List
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildUpcomingMeetings()
                : _buildPastMeetings(),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMeetings() {
    if (_upcomingMeetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 64.0,
                tablet: 72.0,
                desktop: 80.0,
              ),
              color: Colors.grey,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            )),
            Text(
              'No Upcoming Meetings',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 20.0,
                  tablet: 24.0,
                  desktop: 28.0,
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            )),
            const Text(
              'Schedule a new meeting to get started',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            )),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _canScheduleMeeting() ? _showScheduleMeetingDialog : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Schedule Meeting'),
                ),
                SizedBox(width: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 12.0,
                  tablet: 14.0,
                  desktop: 16.0,
                )),
                OutlinedButton.icon(
                  onPressed: _loadMeetings,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.getResponsiveValue(
        context: context,
        mobile: 16.0,
        tablet: 20.0,
        desktop: 24.0,
      )),
      itemCount: _upcomingMeetings.length,
      itemBuilder: (context, index) {
        final meeting = _upcomingMeetings[index];
        return _buildMeetingCard(meeting, isUpcoming: true);
      },
    );
  }

  Widget _buildPastMeetings() {
    if (_pastMeetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 64.0,
                tablet: 72.0,
                desktop: 80.0,
              ),
              color: Colors.grey,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            )),
            Text(
              'No Past Meetings',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 20.0,
                  tablet: 24.0,
                  desktop: 28.0,
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            )),
            const Text(
              'Your meeting history will appear here once meetings are completed.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            )),
            OutlinedButton.icon(
              onPressed: _loadMeetings,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.getResponsiveValue(
        context: context,
        mobile: 16.0,
        tablet: 20.0,
        desktop: 24.0,
      )),
      itemCount: _pastMeetings.length,
      itemBuilder: (context, index) {
        final meeting = _pastMeetings[index];
        return _buildMeetingCard(meeting, isUpcoming: false);
      },
    );
  }

  Widget _buildMeetingCard(ConferenceMeeting meeting, {required bool isUpcoming}) {
    final timeUntil = meeting.scheduledTime.difference(DateTime.now());
    final isStartingSoon = isUpcoming && timeUntil.inMinutes <= 15 && timeUntil.inMinutes >= 0;

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveValue(
        context: context,
        mobile: 16.0,
        tablet: 20.0,
        desktop: 24.0,
      )),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 16.0,
          tablet: 18.0,
          desktop: 20.0,
        )),
      ),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 16.0,
          tablet: 20.0,
          desktop: 24.0,
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meeting Type Badge
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    ),
                    vertical: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 4.0,
                      tablet: 5.0,
                      desktop: 6.0,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: _getMeetingTypeColor(meeting.meetingType).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 12.0,
                      tablet: 14.0,
                      desktop: 16.0,
                    )),
                  ),
                  child: Text(
                    _getMeetingTypeLabel(meeting.meetingType),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 12.0,
                        tablet: 13.0,
                        desktop: 14.0,
                      ),
                      fontWeight: FontWeight.w600,
                      color: _getMeetingTypeColor(meeting.meetingType),
                    ),
                  ),
                ),
                if (isStartingSoon) ...[
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 8.0,
                    tablet: 10.0,
                    desktop: 12.0,
                  )),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 8.0,
                        tablet: 10.0,
                        desktop: 12.0,
                      ),
                      vertical: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 4.0,
                        tablet: 5.0,
                        desktop: 6.0,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0,
                      )),
                    ),
                    child: Text(
                      'STARTING SOON',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 12.0,
                          tablet: 13.0,
                          desktop: 14.0,
                        ),
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 12.0,
              tablet: 14.0,
              desktop: 16.0,
            )),
            
            // Meeting Title
            Text(
              meeting.title,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 18.0,
                  tablet: 20.0,
                  desktop: 22.0,
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            )),
            
            // Meeting Description
            Text(
              meeting.description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 14.0,
                  tablet: 15.0,
                  desktop: 16.0,
                ),
              ),
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            )),
            
            // Meeting Details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          children: [
                            Icon(Icons.person, 
                              size: ResponsiveUtils.getResponsiveValue(
                                context: context,
                                mobile: 16.0,
                                tablet: 18.0,
                                desktop: 20.0,
                              ), 
                              color: Colors.grey
                            ),
                            SizedBox(width: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 4.0,
                              tablet: 5.0,
                              desktop: 6.0,
                            )),
                            Text(
                              'Host: ${meeting.hostName}',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getResponsiveValue(
                                  context: context,
                                  mobile: 12.0,
                                  tablet: 13.0,
                                  desktop: 14.0,
                                ),
                                color: Colors.grey,
                              ),
                            ),
                          ],
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 4.0,
                        tablet: 5.0,
                        desktop: 6.0,
                      )),
                      Row(
                        children: [
                          Icon(Icons.schedule, 
                            size: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 16.0,
                              tablet: 18.0,
                              desktop: 20.0,
                            ), 
                            color: Colors.grey
                          ),
                          SizedBox(width: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 4.0,
                            tablet: 5.0,
                            desktop: 6.0,
                          )),
                          Text(
                            _formatDateTime(meeting.scheduledTime),
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getResponsiveValue(
                                context: context,
                                mobile: 12.0,
                                tablet: 13.0,
                                desktop: 14.0,
                              ),
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 4.0,
                        tablet: 5.0,
                        desktop: 6.0,
                      )),
                      Row(
                        children: [
                          Icon(Icons.timer, 
                            size: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 16.0,
                              tablet: 18.0,
                              desktop: 20.0,
                            ), 
                            color: Colors.grey
                          ),
                          SizedBox(width: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 4.0,
                            tablet: 5.0,
                            desktop: 6.0,
                          )),
                          Text(
                            '${meeting.duration} min',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getResponsiveValue(
                                context: context,
                                mobile: 12.0,
                                tablet: 13.0,
                                desktop: 14.0,
                              ),
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 4.0,
                        tablet: 5.0,
                        desktop: 6.0,
                      )),
                      Row(
                        children: [
                          Icon(Icons.group, 
                            size: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 16.0,
                              tablet: 18.0,
                              desktop: 20.0,
                            ), 
                            color: Colors.grey
                          ),
                          SizedBox(width: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 4.0,
                            tablet: 5.0,
                            desktop: 6.0,
                          )),
                          Text(
                            '${meeting.participants.length}/${meeting.maxParticipants} participants',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getResponsiveValue(
                                context: context,
                                mobile: 12.0,
                                tablet: 13.0,
                                desktop: 14.0,
                              ),
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            )),
            
            // Action Buttons
            Row(
              children: [
                if (isUpcoming) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _joinMeeting(meeting),
                      icon: Icon(Icons.video_call, size: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 18.0,
                        tablet: 20.0,
                        desktop: 22.0,
                      )),
                      label: const Text('Join'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 8.0,
                          tablet: 10.0,
                          desktop: 12.0,
                        )),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 8.0,
                    tablet: 10.0,
                    desktop: 12.0,
                  )),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareMeeting(meeting),
                    icon: Icon(Icons.share, size: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 18.0,
                      tablet: 20.0,
                      desktop: 22.0,
                    )),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 8.0,
                        tablet: 10.0,
                        desktop: 12.0,
                      )),
                    ),
                  ),
                ),
                if (!isUpcoming) ...[
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 8.0,
                    tablet: 10.0,
                    desktop: 12.0,
                  )),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewMeetingRecording(meeting),
                      icon: Icon(Icons.play_circle_outline, size: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 18.0,
                        tablet: 20.0,
                        desktop: 22.0,
                      )),
                      label: const Text('Recording'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 8.0,
                          tablet: 10.0,
                          desktop: 12.0,
                        )),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays == 0) {
      return 'Today at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays > 0 && difference.inDays <= 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[dateTime.weekday - 1]} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Color _getMeetingTypeColor(String type) {
    switch (type) {
      case 'bod_meeting':
        return Colors.red;
      case 'director_meeting':
        return Colors.purple;
      case 'chapter_coordination':
        return Colors.blue;
      case 'chapter_meeting':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getMeetingTypeLabel(String type) {
    switch (type) {
      case 'bod_meeting':
        return 'BOD MEETING';
      case 'director_meeting':
        return 'DIRECTOR MEETING';
      case 'chapter_coordination':
        return 'COORDINATION';
      case 'chapter_meeting':
        return 'CHAPTER MEETING';
      default:
        return 'MEETING';
    }
  }

  bool _canScheduleMeeting() {
    // Implement role-based access control
    if (_currentUser == null) return false;
    // Check user role from stored profile
    final userRole = _userProfile?.role ?? 'member';

    // Allow coordinators, directors, and BOD members to schedule meetings
    return ['coordinator', 'director', 'bod_member', 'admin'].contains(userRole);
  }
  
  Future<void> _showScheduleMeetingDialog() async {
    final rootCtx = context;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ScheduleMeetingDialog(),
    );
    
    if (result != null) {
      // Save meeting to Firebase
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }
        
        final userProfile = await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(user.uid)
            .get();
            
        await FirebaseFirestore.instance.collection('conference_meetings').add({
          'title': result['title'],
          'description': result['description'],
          'scheduled_time': result['scheduledTime'].toIso8601String(),
          'duration': result['duration'],
          'host_id': user.uid,
          'host_name': userProfile.data()?['full_name'] ?? user.displayName ?? 'Unknown Host',
          'meeting_type': result['meetingType'],
          'max_participants': result['maxParticipants'] ?? 50,
          'is_recurring': result['isRecurring'] ?? false,
          'meeting_link': 'https://meet.alive.ng/${result['title'].toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}',
          'status': 'scheduled',
          'room_name': '${result['title'].toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}',
          'created_at': DateTime.now().toIso8601String(),
        });
        
        // Refresh meetings list
        await _loadMeetings();
        
        if (!rootCtx.mounted) return;
        ScaffoldMessenger.of(rootCtx).showSnackBar(
            const SnackBar(
              content: Text('Meeting scheduled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
      } catch (e) {
        if (!rootCtx.mounted) return;
        ScaffoldMessenger.of(rootCtx).showSnackBar(
            SnackBar(
              content: Text('Error scheduling meeting: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }
  
  Future<void> _showJoinMeetingDialog() async {
    final meetingId = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(
            'Join Meeting',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 18.0,
                tablet: 20.0,
                desktop: 22.0,
              ),
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Meeting ID or Room Name',
              hintText: 'Enter meeting ID or room name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 14.0,
                    tablet: 15.0,
                    desktop: 16.0,
                  ),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(
                'Join',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 14.0,
                    tablet: 15.0,
                    desktop: 16.0,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    
    if (meetingId != null && meetingId.isNotEmpty) {
      await _joinMeetingByRoomName(meetingId);
    }
  }

  // Unified join handler (route everything through EnhancedJitsi)
  Future<void> _joinMeeting(ConferenceMeeting meeting) async {
    await _joinMeetingWithEnhancedJitsi(meeting.roomName);
  }

  Future<void> _joinMeetingWithEnhancedJitsi(String roomName) async {
    if (!mounted) return;

    // Navigate to enhanced Jitsi Meet screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedJitsiMeetScreen(
          customRoomName: roomName,
          isModerator: _userProfile?.role == 'admin' || _userProfile?.role == 'moderator',
        ),
      ),
    );
  }

  Future<void> _joinPredefinedMeeting(MeetingType meetingType) async {
    if (!mounted) return;

    // Navigate to enhanced Jitsi Meet screen with predefined meeting
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedJitsiMeetScreen(
          meetingType: meetingType,
          isModerator: _userProfile?.role == 'admin' || _userProfile?.role == 'moderator',
        ),
      ),
    );
  }

  Future<void> _joinMeetingByRoomName(String roomName) async {
    // Route room-name joins through the enhanced Jitsi Meet screen
    await _joinMeetingWithEnhancedJitsi(roomName);
  }

  // Removed legacy URL launcher for meetings; all joins use EnhancedJitsi
  
  Future<void> _shareMeeting(ConferenceMeeting meeting) async {
    final shareText = '''Join our ALIVE meeting!

Title: ${meeting.title}
Description: ${meeting.description}
Scheduled: ${meeting.scheduledTime.toString()}
Duration: ${meeting.duration} minutes

Join here: ${meeting.meetingLink}

See you there!''';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Meeting'),
        content: SingleChildScrollView(
          child: Text(shareText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 14.0,
                  tablet: 15.0,
                  desktop: 16.0,
                ),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Clipboard.setData(ClipboardData(text: shareText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Meeting details copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(
              'Copy to Clipboard',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 14.0,
                  tablet: 15.0,
                  desktop: 16.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _viewMeetingRecording(ConferenceMeeting meeting) async {
    // Open recording link directly if available
    if (meeting.recordingLink != null && meeting.recordingLink!.isNotEmpty) {
      final uri = Uri.parse(meeting.recordingLink!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Otherwise show details
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Recording: ${meeting.title}',
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 18.0,
              tablet: 20.0,
              desktop: 22.0,
            ),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meeting Details:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 14.0,
                    tablet: 15.0,
                    desktop: 16.0,
                  ),
                ),
              ),
              SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 8.0,
                  tablet: 10.0,
                  desktop: 12.0,
                ),
              ),
              Text(
                'Date: ${meeting.scheduledTime.toString().split(' ')[0]}',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 13.0,
                    desktop: 14.0,
                  ),
                ),
              ),
              Text(
                'Duration: ${meeting.duration} minutes',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 13.0,
                    desktop: 14.0,
                  ),
                ),
              ),
              Text(
                'Host: ${meeting.hostName}',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 13.0,
                    desktop: 14.0,
                  ),
                ),
              ),
              SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
              ),
              Text(
                'Recording Status: Available',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 13.0,
                    desktop: 14.0,
                  ),
                ),
              ),
              SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 8.0,
                  tablet: 10.0,
                  desktop: 12.0,
                ),
              ),
              Text(
                'Note: Recording playback will open in your default browser or video player.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 10.0,
                    tablet: 11.0,
                    desktop: 12.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 14.0,
                  tablet: 15.0,
                  desktop: 16.0,
                ),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final rootCtx = context;
              Navigator.of(rootCtx).pop();
              if (meeting.recordingLink != null && meeting.recordingLink!.isNotEmpty) {
                final uri = Uri.parse(meeting.recordingLink!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  return;
                }
              }
              if (!rootCtx.mounted) return;
              ScaffoldMessenger.of(rootCtx).showSnackBar(
                const SnackBar(
                  content: Text('Recording link not available.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            icon: Icon(
              Icons.play_arrow,
              size: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 18.0,
                tablet: 20.0,
                desktop: 22.0,
              ),
            ),
            label: Text(
              'Play Recording',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 14.0,
                  tablet: 15.0,
                  desktop: 16.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Remove Jitsi Meet listeners
    // _jitsiMeet.removeAllListeners(); // Method not available
    super.dispose();
  }
}

// Schedule Meeting Dialog
class _ScheduleMeetingDialog extends StatefulWidget {
  @override
  _ScheduleMeetingDialogState createState() => _ScheduleMeetingDialogState();
}

class _ScheduleMeetingDialogState extends State<_ScheduleMeetingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _duration = 60;
  String _meetingType = 'chapter_meeting';
  int _maxParticipants = 15;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Schedule New Meeting',
        style: TextStyle(
          fontSize: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 18.0,
            tablet: 20.0,
            desktop: 22.0,
          ),
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a meeting title';
                    }
                    return null;
                  },
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 16.0,
                    tablet: 18.0,
                    desktop: 20.0,
                  ),
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 16.0,
                    tablet: 18.0,
                    desktop: 20.0,
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _meetingType,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'chapter_meeting', child: Text('Chapter Meeting')),
                    DropdownMenuItem(value: 'bod_meeting', child: Text('BOD Meeting')),
                    DropdownMenuItem(value: 'director_meeting', child: Text('Director Meeting')),
                    DropdownMenuItem(value: 'chapter_coordination', child: Text('Chapter Coordination')),
                  ],
                  onChanged: (value) => setState(() => _meetingType = value!),
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 16.0,
                    tablet: 18.0,
                    desktop: 20.0,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text('Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text('Time: ${_selectedTime.format(context)}'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (time != null) {
                            setState(() => _selectedTime = time);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 16.0,
                    tablet: 18.0,
                    desktop: 20.0,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _duration.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _duration = int.tryParse(value) ?? 60;
                        },
                      ),
                    ),
                    SizedBox(
                      width: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 16.0,
                        tablet: 18.0,
                        desktop: 20.0,
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: _maxParticipants.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Max Participants',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _maxParticipants = int.tryParse(value) ?? 15;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 14.0,
                tablet: 15.0,
                desktop: 16.0,
              ),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final scheduledDateTime = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                _selectedTime.hour,
                _selectedTime.minute,
              );
              
              Navigator.of(context).pop({
                'title': _titleController.text,
                'description': _descriptionController.text,
                'scheduledTime': scheduledDateTime,
                'duration': _duration,
                'meetingType': _meetingType,
                'maxParticipants': _maxParticipants,
              });
            }
          },
          child: Text(
            'Schedule',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 14.0,
                tablet: 15.0,
                desktop: 16.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}




