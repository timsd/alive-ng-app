import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/board_models.dart';
import '../../services/firebase_database_service.dart';
import '../../services/auth_service.dart';
import '../../config/meeting_links_config.dart';
import '../conference/enhanced_jitsi_meet_screen.dart';

class BoardDecisionsScreen extends StatefulWidget {
  const BoardDecisionsScreen({super.key});

  @override
  State<BoardDecisionsScreen> createState() => _BoardDecisionsScreenState();
}

class _BoardDecisionsScreenState extends State<BoardDecisionsScreen> {
  final FirebaseDatabaseService _databaseService = FirebaseDatabaseService.instance;
  final AuthService _authService = AuthService.instance;
  List<BoardDecision> _decisions = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedCategory = 'all';

  final List<String> _statuses = [
    'all',
    'proposed',
    'voting',
    'approved',
    'rejected',
    'deferred'
  ];
  final List<String> _categories = [
    'all',
    'policy',
    'financial',
    'strategic',
    'operational'
  ];

  @override
  void initState() {
    super.initState();
    _loadDecisions();
  }

  Future<void> _loadDecisions() async {
    setState(() => _isLoading = true);

    try {
      final decisions = await _databaseService.getBoardDecisions();
      final mapped = decisions.map((e) => BoardDecision.fromJson(e)).toList();
      setState(() {
        _decisions = mapped;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading decisions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ignore: use_build_context_synchronously
  Future<DateTime?> _selectVotingDeadline(BuildContext dialogContext) async {
    final date = await showDatePicker(
      context: dialogContext,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date == null) return null;
    
    // Use the same context for time picker without async gap
    final time = await showTimePicker(
      context: dialogContext, // ignore: use_build_context_synchronously
      initialTime: TimeOfDay.now(),
    );
    
    if (time == null) return null;
    
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  List<BoardDecision> get _filteredDecisions {
    return _decisions.where((decision) {
      final statusMatch =
          _selectedStatus == 'all' || decision.status == _selectedStatus;
      final categoryMatch =
          _selectedCategory == 'all' || decision.category == _selectedCategory;
      return statusMatch && categoryMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Board Decisions'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDecisionDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // BOD quick-join banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.video_call, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Board of Directors Meeting is available',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const EnhancedJitsiMeetScreen(
                              meetingType: MeetingType.board,
                              isModerator: true,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Join'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedStatus = value!);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value!);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Decisions List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  )
                : _filteredDecisions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.how_to_vote_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No decisions found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDecisions,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredDecisions.length,
                          itemBuilder: (context, index) {
                            final decision = _filteredDecisions[index];
                            return _buildDecisionCard(decision);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionCard(BoardDecision decision) {
    Color statusColor;
    IconData statusIcon;

    switch (decision.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'voting':
        statusColor = Colors.blue;
        statusIcon = Icons.how_to_vote;
        break;
      case 'deferred':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.pending;
    }

    final approveVotes =
        decision.votes.where((v) => v.vote == 'approve').length;
    final rejectVotes = decision.votes.where((v) => v.vote == 'reject').length;
    final abstainVotes =
        decision.votes.where((v) => v.vote == 'abstain').length;
    final totalVotes = decision.votes.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _viewDecision(decision),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      decision.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      decision.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                decision.description,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),

              // Voting Progress (for active votes)
              if (decision.status == 'voting' && totalVotes > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voting Progress ($totalVotes votes)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('Approve: $approveVotes',
                                  style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 12),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('Reject: $rejectVotes',
                                  style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 12),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('Abstain: $abstainVotes',
                                  style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Proposed by ${decision.proposedBy}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(decision.proposedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (decision.votingDeadline != null) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Colors.orange.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Deadline: ${DateFormat('MMM dd').format(decision.votingDeadline!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ],
              ),

              if (decision.requiresUnanimous)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'REQUIRES UNANIMOUS APPROVAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewDecision(BoardDecision decision) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(decision.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Proposed by: ${decision.proposedBy}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Proposed: ${DateFormat('MMM dd, yyyy HH:mm').format(decision.proposedAt)}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              if (decision.votingDeadline != null) ...[
                Text(
                  'Voting Deadline: ${DateFormat('MMM dd, yyyy HH:mm').format(decision.votingDeadline!)}',
                  style: TextStyle(color: Colors.orange.shade600),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                decision.description,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              if (decision.votes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Votes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...decision.votes.map((vote) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            vote.vote == 'approve'
                                ? Icons.thumb_up
                                : vote.vote == 'reject'
                                    ? Icons.thumb_down
                                    : Icons.remove,
                            size: 16,
                            color: vote.vote == 'approve'
                                ? Colors.green
                                : vote.vote == 'reject'
                                    ? Colors.red
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${vote.voterName} - ${vote.vote.toUpperCase()}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                if (vote.comment != null &&
                                    vote.comment!.isNotEmpty)
                                  Text(
                                    vote.comment!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
              if (decision.resolution != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Resolution:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(decision.resolution!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (decision.status == 'voting' && !_hasUserVoted(decision))
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showVoteDialog(decision);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Vote', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  bool _hasUserVoted(BoardDecision decision) {
    final currentUserId = _authService.currentUser?.uid ?? '';
    return decision.votes.any((vote) => vote.voterId == currentUserId);
  }

  void _showVoteDialog(BoardDecision decision) {
    String selectedVote = 'approve';
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cast Your Vote'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              decision.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedVote,
              decoration: const InputDecoration(
                labelText: 'Your Vote',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'approve', child: Text('APPROVE')),
                DropdownMenuItem(value: 'reject', child: Text('REJECT')),
                DropdownMenuItem(value: 'abstain', child: Text('ABSTAIN')),
              ],
              onChanged: (value) => selectedVote = value!,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Comment (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _castVote(decision, selectedVote, commentController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Submit Vote',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _castVote(BoardDecision decision, String vote, String comment) {
    final newVote = DecisionVote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      decisionId: decision.id,
      voterId: _authService.currentUser?.uid ?? '',
      voterName: _authService.currentUser?.email ?? 'Unknown',
      vote: vote,
      comment: comment.isNotEmpty ? comment : null,
      votedAt: DateTime.now(),
    );

    setState(() {
      final index = _decisions.indexWhere((d) => d.id == decision.id);
      if (index != -1) {
        _decisions[index] = BoardDecision(
          id: decision.id,
          title: decision.title,
          description: decision.description,
          proposedBy: decision.proposedBy,
          proposerId: decision.proposerId,
          proposedAt: decision.proposedAt,
          votingDeadline: decision.votingDeadline,
          status: decision.status,
          votes: [...decision.votes, newVote],
          resolution: decision.resolution,
          resolvedAt: decision.resolvedAt,
          category: decision.category,
          requiresUnanimous: decision.requiresUnanimous,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vote cast successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showCreateDecisionDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'operational';
    bool requiresUnanimous = false;
    DateTime? votingDeadline;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Propose New Decision'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Decision Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.skip(1).map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) => selectedCategory = value!,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Requires Unanimous Approval'),
                  value: requiresUnanimous,
                  onChanged: (value) {
                    setDialogState(() => requiresUnanimous = value!);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Voting Deadline'),
                  subtitle: Text(
                    votingDeadline != null
                        ? DateFormat('MMM dd, yyyy HH:mm')
                            .format(votingDeadline!)
                        : 'No deadline set',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final dialogContext = context;
                    final selectedDeadline = await _selectVotingDeadline(dialogContext);
                    if (selectedDeadline != null) {
                      setDialogState(() {
                        votingDeadline = selectedDeadline;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty &&
                    descriptionController.text.isNotEmpty) {
                  _createDecision(
                    titleController.text,
                    descriptionController.text,
                    selectedCategory,
                    requiresUnanimous,
                    votingDeadline,
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child:
                  const Text('Propose', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _createDecision(String title, String description, String category,
      bool requiresUnanimous, DateTime? votingDeadline) {
    final newDecision = BoardDecision(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      proposedBy: _authService.currentUser?.email ?? 'Unknown',
      proposerId: _authService.currentUser?.uid ?? '',
      proposedAt: DateTime.now(),
      votingDeadline: votingDeadline,
      status: 'proposed',
      category: category,
      requiresUnanimous: requiresUnanimous,
    );

    setState(() {
      _decisions.insert(0, newDecision);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Decision proposed successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}




