import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/approval_link_service.dart';

class AdminApprovalLinkHandlerScreen extends StatefulWidget {
  const AdminApprovalLinkHandlerScreen({super.key});

  @override
  State<AdminApprovalLinkHandlerScreen> createState() => _AdminApprovalLinkHandlerScreenState();
}

class _AdminApprovalLinkHandlerScreenState extends State<AdminApprovalLinkHandlerScreen> {
  bool _processing = true;
  bool _result = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _handle();
  }

  Future<void> _handle() async {
    final uri = GoRouterState.of(context).uri;
    final userId = uri.queryParameters['userId'];
    final token = uri.queryParameters['token'];

    if (userId == null || token == null) {
      setState(() {
        _processing = false;
        _result = false;
        _message = 'Missing userId or token.';
      });
      return;
    }

    final ok = await ApprovalLinkService.instance.consumeTokenAndApprove(userId: userId, token: token);
    setState(() {
      _processing = false;
      _result = ok;
      _message = ok ? 'User approved successfully.' : 'Approval link is invalid, expired, or already used.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approval Link')),
      body: Center(
        child: _processing
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_result ? Icons.check_circle : Icons.error, size: 64, color: _result ? Colors.green : Colors.red),
                  const SizedBox(height: 16),
                  Text(_message ?? ''),
                ],
              ),
      ),
    );
  }
}