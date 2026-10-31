import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/board_models.dart';
import '../../services/appwrite_board_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_access_service.dart';

class BoardDecisionsScreen extends StatefulWidget {
  const BoardDecisionsScreen({super.key});

  @override
  State<BoardDecisionsScreen> createState() => _BoardDecisionsScreenState();
}

class _BoardDecisionsScreenState extends State<BoardDecisionsScreen> {
  final AppwriteBoardService _boardService = AppwriteBoardService.instance;
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
      final decisions = await _boardService.getBoardDecisions();
      final mapped = decisions.map((e) => BoardDecision.fromJson(e)).toList();
      setState(() {
        _decisions = mapped;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading decisions: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool get _isAdmin => RoleAccessService.instance.canAccessAdmin();

  Future<void> _confirmDeleteDecision(BoardDecision decision,
      {bool popDialogFirst = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Decision'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${decision.title}"? This action cannot be undone.',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      if (popDialogFirst && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      try {
        final success = await _boardService.deleteBoardDecision(decision.id);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Decision deleted successfully')),
          );
          _loadDecisions();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting decision: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  List<BoardDecision> get _filteredDecisions {
    if (_selectedStatus == 'all') return _decisions;
    return _decisions.where((d) => d.status == _selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Board Decisions',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.primary.withValues(alpha: 0.82),
              ],
            ),
          ),
        ),
        elevation: 2,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.26),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(Icons.add_task, color: colorScheme.onPrimary),
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
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) =>
                        setState(() => _selectedStatus = status),
                    selectedColor: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    checkmarkColor: colorScheme.onPrimary,
                    elevation: isSelected ? 4 : 0,
                    pressElevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
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
                                size: 64, color: colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text('No decisions found',
                                style: TextStyle(
                                    color: colorScheme.onSurfaceVariant)),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final approveVotes =
        decision.votes.where((v) => v.vote == 'approve').length;
    final rejectVotes = decision.votes.where((v) => v.vote == 'reject').length;
    final abstainVotes =
        decision.votes.where((v) => v.vote == 'abstain').length;
    final totalVotes = decision.votes.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.28 : 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
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
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.gavel_rounded,
                          color: colorScheme.onPrimaryContainer, size: 24),
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
                                  letterSpacing: 0,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          _buildStatusBadge(decision.status),
                        ],
                      ),
                    ),
                    if (_isAdmin)
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            color: colorScheme.error),
                        tooltip: 'Delete Decision',
                        onPressed: () => _confirmDeleteDecision(decision),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  decision.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
                          letterSpacing: 0,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${(totalVotes == 0 ? 0 : (approveVotes / totalVotes) * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.tertiary,
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
                          color: colorScheme.surfaceContainerHighest,
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
                                color:
                                    colorScheme.tertiary.withValues(alpha: 0.3),
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
                      _buildVoteStat(
                        'Abstain',
                        abstainVotes,
                        colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(color: colorScheme.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          decision.proposedBy[0].toUpperCase(),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Proposed by ${decision.proposedBy}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(decision.proposedAt),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    Color color;
    switch (status) {
      case 'approved':
        color = Colors.green.shade600;
        break;
      case 'rejected':
        color = Colors.red.shade600;
        break;
      case 'voting':
        color = colorScheme.primary;
        break;
      case 'deferred':
        color = Colors.orange.shade700;
        break;
      default:
        color = colorScheme.onSurfaceVariant;
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
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _viewDecisionDetails(BoardDecision decision) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
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
                        color: colorScheme.primary)),
                Text(decision.description,
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                const SizedBox(height: 16),
                if (decision.resolution != null) ...[
                  Text('Resolution:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.tertiary)),
                  Text(decision.resolution!,
                      style: TextStyle(color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 16),
                ],
                Text('Meta Info:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary)),
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
                      style: TextStyle(color: colorScheme.error)),
              ],
            ),
          ),
          actions: [
            if (_isAdmin)
              TextButton.icon(
                onPressed: () => _confirmDeleteDecision(
                  decision,
                  popDialogFirst: true,
                ),
                icon: Icon(Icons.delete_outline_rounded,
                    color: colorScheme.error, size: 18),
                label: Text('Delete',
                    style: TextStyle(color: colorScheme.error)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (_isAdmin && decision.status == 'proposed')
              OutlinedButton.icon(
                onPressed: () async {
                  final success = await _boardService.updateBoardDecisionStatus(
                    decision.id,
                    'voting',
                  );
                  if (success && context.mounted) {
                    Navigator.pop(context);
                    _loadDecisions();
                  }
                },
                icon: const Icon(Icons.how_to_vote_outlined, size: 18),
                label: const Text('Open Voting'),
              ),
            if (decision.status == 'proposed' || decision.status == 'voting')
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final authService = AuthService.instance;
                      final success =
                          await _boardService.castBoardVote(decision.id, {
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
                        backgroundColor: colorScheme.tertiary,
                        foregroundColor: colorScheme.onTertiary),
                    child: const Text('Vote Approve'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final authService = AuthService.instance;
                      final success =
                          await _boardService.castBoardVote(decision.id, {
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
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError),
                    child: const Text('Vote Reject'),
                  ),
                  if (_isAdmin && decision.status == 'voting') ...[
                    OutlinedButton(
                      onPressed: () async {
                        final success =
                            await _boardService.updateBoardDecisionStatus(
                          decision.id,
                          'approved',
                          resolution: 'Approved by Board vote',
                        );
                        if (success && context.mounted) {
                          Navigator.pop(context);
                          _loadDecisions();
                        }
                      },
                      child: const Text('Finalize Approved'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final success =
                            await _boardService.updateBoardDecisionStatus(
                          decision.id,
                          'rejected',
                          resolution: 'Rejected by Board vote',
                        );
                        if (success && context.mounted) {
                          Navigator.pop(context);
                          _loadDecisions();
                        }
                      },
                      child: Text('Finalize Rejected',
                          style: TextStyle(color: colorScheme.error)),
                    ),
                  ],
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
        final colorScheme = theme.colorScheme;
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
                        await _boardService.addBoardDecision(decision);
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
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary),
                child: const Text('Propose'),
              ),
            ],
          ),
        );
      },
    );
  }
}
