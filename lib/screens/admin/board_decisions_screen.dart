import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/board_models.dart';
import '../../services/firebase_database_service.dart';
import '../../services/auth_service.dart';

class BoardDecisionsScreen extends StatefulWidget {
  const BoardDecisionsScreen({super.key});

  @override
  State<BoardDecisionsScreen> createState() => _BoardDecisionsScreenState();
}

class _BoardDecisionsScreenState extends State<BoardDecisionsScreen> {
  final FirebaseDatabaseService _firebaseService =
      FirebaseDatabaseService.instance;
  List<BoardDecision> _decisions = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';

  final List<String> _statuses = [
    'all',
    'proposed',
    'voting',
    'approved',
    'rejected',
    'deferred'
  ];

  @override
  void initState() {
    super.initState();
    _loadDecisions();
  }

  Future<void> _loadDecisions() async {
    setState(() => _isLoading = true);
    try {
      final decisions = await _firebaseService.getBoardDecisions();
      final mapped = decisions.map((e) => BoardDecision.fromJson(e)).toList();
      setState(() {
        _decisions = mapped;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading decisions: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<BoardDecision> get _filteredDecisions {
    if (_selectedStatus == 'all') return _decisions;
    return _decisions.where((d) => d.status == _selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Board Decisions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo.shade800, Colors.indigo.shade600],
            ),
          ),
        ),
        elevation: 2,
        shadowColor: Colors.black26,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.add_task, color: Colors.white),
              onPressed: () => _showProposeDecisionDialog(),
              tooltip: 'Propose New Decision',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 56,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _statuses.length,
              itemBuilder: (context, index) {
                final status = _statuses[index];
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    label: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color:
                            isSelected ? Colors.white : Colors.indigo.shade700,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) =>
                        setState(() => _selectedStatus = status),
                    selectedColor: Colors.indigo.shade700,
                    backgroundColor: Colors.indigo.shade50,
                    checkmarkColor: Colors.white,
                    elevation: isSelected ? 4 : 0,
                    pressElevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.indigo.shade700
                            : Colors.indigo.shade100,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDecisions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.gavel_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No decisions found',
                                style: TextStyle(color: Colors.grey.shade600)),
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
    final approveVotes =
        decision.votes.where((v) => v.vote == 'approve').length;
    final rejectVotes = decision.votes.where((v) => v.vote == 'reject').length;
    final abstainVotes =
        decision.votes.where((v) => v.vote == 'abstain').length;
    final totalVotes = decision.votes.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: Colors.indigo.shade50, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewDecisionDetails(decision),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.gavel_rounded,
                          color: Colors.indigo.shade700, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            decision.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: Colors.indigo.shade900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          _buildStatusBadge(decision.status),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  decision.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                ),
                if (decision.status == 'voting') ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'VOTING PROGRESS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Text(
                        '${(totalVotes == 0 ? 0 : (approveVotes / totalVotes) * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor:
                            totalVotes == 0 ? 0 : approveVotes / totalVotes,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.green, Colors.teal],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildVoteStat('Approve', approveVotes, Colors.green),
                      _buildVoteStat('Reject', rejectVotes, Colors.red),
                      _buildVoteStat('Abstain', abstainVotes, Colors.grey),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.indigo.shade100,
                        child: Text(
                          decision.proposedBy[0].toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Proposed by ${decision.proposedBy}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700),
                        ),
                      ),
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(decision.proposedAt),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoteStat(String label, int count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade500,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          count.toString(),
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = Colors.green.shade600;
        break;
      case 'rejected':
        color = Colors.red.shade600;
        break;
      case 'voting':
        color = Colors.indigo.shade600;
        break;
      case 'deferred':
        color = Colors.orange.shade700;
        break;
      default:
        color = Colors.grey.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _viewDecisionDetails(BoardDecision decision) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor:
              theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          title: Text(decision.title,
              style: TextStyle(color: theme.colorScheme.onSurface)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Description:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800)),
                Text(decision.description,
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                const SizedBox(height: 16),
                if (decision.resolution != null) ...[
                  Text('Resolution:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800)),
                  Text(decision.resolution!,
                      style: TextStyle(color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 16),
                ],
                Text('Meta Info:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800)),
                Text('Proposer: ${decision.proposedBy}',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7))),
                Text('Status: ${decision.status.toUpperCase()}',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7))),
                Text(
                    'Proposed: ${DateFormat('MMM dd, yyyy').format(decision.proposedAt)}',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7))),
                if (decision.votingDeadline != null)
                  Text(
                      'Deadline: ${DateFormat('MMM dd, yyyy').format(decision.votingDeadline!)}',
                      style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (decision.status == 'voting')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final authService = AuthService.instance;
                      final success =
                          await _firebaseService.castBoardVote(decision.id, {
                        'voter_id': authService.currentUser?.uid ?? 'unknown',
                        'voter_name':
                            authService.currentUser?.displayName ?? 'Admin',
                        'vote': 'approve',
                      });
                      if (success && context.mounted) {
                        Navigator.pop(context);
                        _loadDecisions();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final authService = AuthService.instance;
                      final success =
                          await _firebaseService.castBoardVote(decision.id, {
                        'voter_id': authService.currentUser?.uid ?? 'unknown',
                        'voter_name':
                            authService.currentUser?.displayName ?? 'Admin',
                        'vote': 'reject',
                      });
                      if (success && context.mounted) {
                        Navigator.pop(context);
                        _loadDecisions();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    child: const Text('Reject'),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _showProposeDecisionDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? selectedDeadline;
    String selectedCat = 'operational';

    await showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor:
                theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
            title: Text('Propose New Decision',
                style: TextStyle(color: theme.colorScheme.onSurface)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration:
                        const InputDecoration(labelText: 'Decision Title'),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration:
                        const InputDecoration(labelText: 'Full Description'),
                    maxLines: 4,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCat,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: ['policy', 'financial', 'strategic', 'operational']
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedCat = val!),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      selectedDeadline == null
                          ? 'Set Voting Deadline (Optional)'
                          : 'Deadline: ${DateFormat('MMM dd, yyyy').format(selectedDeadline!)}',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface, fontSize: 14),
                    ),
                    trailing: Icon(Icons.calendar_month,
                        color: theme.colorScheme.primary),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setDialogState(() => selectedDeadline = date);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    final authService = AuthService.instance;
                    final decision = {
                      'title': titleController.text,
                      'description': descriptionController.text,
                      'category': selectedCat,
                      'status': 'proposed',
                      'proposed_by':
                          authService.currentUser?.displayName ?? 'Admin',
                      'proposer_id': authService.currentUser?.uid ?? 'unknown',
                      'proposed_at': DateTime.now().toIso8601String(),
                      if (selectedDeadline != null)
                        'voting_deadline': selectedDeadline!.toIso8601String(),
                    };

                    final success =
                        await _firebaseService.addBoardDecision(decision);
                    if (success && context.mounted) {
                      Navigator.pop(context);
                      _loadDecisions();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Decision proposed successfully')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white),
                child: const Text('Propose'),
              ),
            ],
          ),
        );
      },
    );
  }
}
