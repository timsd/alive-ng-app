import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_constants.dart';
import '../../services/approval_link_service.dart';
import '../../utils/responsive_utils.dart';

class AdminApprovalLinkHandlerScreen extends StatefulWidget {
  const AdminApprovalLinkHandlerScreen({super.key});

  @override
  State<AdminApprovalLinkHandlerScreen> createState() =>
      _AdminApprovalLinkHandlerScreenState();
}

class _AdminApprovalLinkHandlerScreenState
    extends State<AdminApprovalLinkHandlerScreen> {
  bool _processing = true;
  bool _result = false;
  bool _handled = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_handled) {
      _handled = true;
      _handle();
    }
  }

  Future<void> _handle() async {
    final uri = GoRouterState.of(context).uri;
    final userId = uri.queryParameters['userId']?.trim();
    final token = uri.queryParameters['token']?.trim();

    if (userId == null || token == null || userId.isEmpty || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _result = false;
        _message = 'Invalid approval link: missing user ID or token.';
      });
      return;
    }

    final ok = await ApprovalLinkService.instance
        .consumeTokenAndApprove(userId: userId, token: token);
    if (!mounted) return;
    setState(() {
      _processing = false;
      _result = ok;
      _message = ok
          ? 'User approved successfully.'
          : 'Approval link is invalid, expired, or already used.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approval Link')),
      body: Center(
        child: _processing
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _result ? Icons.check_circle : Icons.error,
                      size: ResponsiveUtils.getResponsiveIconSize(context, 64),
                      color: _result
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _message ?? '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go(AppConstants.adminRoute),
                      icon: const Icon(Icons.dashboard_outlined),
                      label: const Text('Back to Admin Dashboard'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}