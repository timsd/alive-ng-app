import 'package:flutter/material.dart';

import '../../models/payment_models.dart';
import '../../services/payment_service.dart';

/// Lists the signed-in donor's active Paystack subscriptions and lets them
/// cancel individual ones. All work goes through the server function so the
/// Paystack secret never touches the client.
class SubscriptionsSheet extends StatefulWidget {
  final String email;
  final ScrollController scrollController;

  const SubscriptionsSheet({
    super.key,
    required this.email,
    required this.scrollController,
  });

  @override
  State<SubscriptionsSheet> createState() => _SubscriptionsSheetState();
}

class _SubscriptionsSheetState extends State<SubscriptionsSheet> {
  late Future<List<RecurringSubscription>> _future;
  String? _cancellingCode;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RecurringSubscription>> _load() {
    return PaymentService().listMonthlySubscriptions(email: widget.email);
  }

  String _moneyLabel(RecurringSubscription sub) {
    final cur = (sub.currency ?? 'NGN').toUpperCase();
    final value = sub.amount
        .toStringAsFixed(sub.amount == sub.amount.roundToDouble() ? 0 : 2);
    final symbol = cur == 'NGN' ? '₦' : (cur == 'USD' ? r'$' : '$cur ');
    final suffix = (cur == 'NGN' || cur == 'USD') ? cur : '';
    return ('$symbol$value $suffix').trim();
  }

  Future<void> _cancel(RecurringSubscription sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel monthly donation?'),
        content: Text(
          'This stops future charges for "${sub.planName ?? 'monthly donation'}" '
          '(${_moneyLabel(sub)}/month). You can start a new one anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancel donation'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _cancellingCode = sub.subscriptionCode;
      _notice = null;
    });

    final response = await PaymentService().cancelMonthlySubscription(
      email: widget.email,
      subscriptionCode: sub.subscriptionCode,
    );

    if (!mounted) return;
    setState(() => _cancellingCode = null);

    if (response.isSuccess) {
      setState(() {
        _notice = response.message;
        _future = _load();
      });
    } else {
      setState(() => _notice = 'Cancellation failed: ${response.message}');
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Monthly Donations',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Recurring gifts billed via Paystack for ${widget.email}.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_notice!, style: theme.textTheme.bodyMedium),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(child: _buildList(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    return FutureBuilder<List<RecurringSubscription>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 8),
                Text('Could not load subscriptions.\n${snapshot.error}'),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => setState(() => _future = _load()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final subs = snapshot.data ?? const [];
        if (subs.isEmpty) {
          return const Center(
            child: Text(
              'No active monthly donations found.\n'
              'Start one from the Donate screen.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.separated(
          controller: widget.scrollController,
          itemCount: subs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _buildTile(theme, subs[index]),
        );
      },
    );
  }

  Widget _buildTile(ThemeData theme, RecurringSubscription sub) {
    final busy = _cancellingCode == sub.subscriptionCode;
    final next = sub.nextPaymentDate;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.autorenew_rounded),
        title: Text(
          '${_moneyLabel(sub)}/month',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            if (sub.planName != null) sub.planName!,
            'Status: ${sub.status}',
            if (next != null)
              'Next: ${next.toLocal().toString().split(' ').first}',
          ].join('\n'),
        ),
        isThreeLine: next != null,
        trailing: TextButton(
          onPressed: busy ? null : () => _cancel(sub),
          child: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Cancel',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
