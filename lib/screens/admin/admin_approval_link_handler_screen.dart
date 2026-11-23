import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_constants.dart';
import '../../services/approval_link_service.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';

class AdminApprovalLinkHandlerScreen extends StatefulWidget {
  const AdminApprovalLinkHandlerScreen({super.key});

  @override
  State<AdminApprovalLinkHandlerScreen> createState() =>
      _AdminApprovalLinkHandlerScreenState();
}

class _AdminApprovalLinkHandlerScreenState
    extends State<AdminApprovalLinkHandlerScreen> {
  bool _processing = true;
  ApprovalLinkStatus _status = ApprovalLinkStatus.invalidOrExpired;
  bool _handled = false;
  String? _message;
  String? _pendingRedirectPath;

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
    _pendingRedirectPath = uri.toString();

    if (userId == null || token == null || userId.isEmpty || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = ApprovalLinkStatus.invalidOrExpired;
        _message = 'Invalid approval link: missing user ID or token.';
      });
      return;
    }

    final outcome = await ApprovalLinkService.instance
        .consumeTokenAndApproveDetailed(userId: userId, token: token);
    if (!mounted) return;
    setState(() {
      _processing = false;
      _status = outcome.status;
      _message = outcome.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = _status == ApprovalLinkStatus.approved;
    final needsAuth = _status == ApprovalLinkStatus.authRequired;
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Approval Link',
        showBackButton: true,
        showDonationButton: false,
      ),
      body: Center(
        child: _processing
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApproved
                          ? Icons.check_circle
                          : (needsAuth ? Icons.lock_outline : Icons.error),
                      size: ResponsiveUtils.getResponsiveIconSize(context, 64),
                      color: isApproved
                          ? Theme.of(context).colorScheme.tertiary
                          : (needsAuth
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _message ?? '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    if (needsAuth)
                      FilledButton.icon(
                        onPressed: () {
                          final redirect = _pendingRedirectPath;
                          if (redirect != null && redirect.isNotEmpty) {
                            context.go(
                              '${AppConstants.authRoute}?redirect=${Uri.encodeComponent(redirect)}',
                            );
                          } else {
                            context.go(AppConstants.authRoute);
                          }
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Sign In as Administrator'),
                      )
                    else
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