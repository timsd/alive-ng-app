import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/biometric_auth_service.dart';

/// App-open biometric unlock gate.
/// When a signed-in user opens the app on a biometric-capable mobile device
/// with Biometric Sign-In enabled, this overlay locks the UI until they
/// authenticate with fingerprint/face (or choose to sign out).
class BiometricLockOverlay extends ConsumerStatefulWidget {
  const BiometricLockOverlay({super.key});

  @override
  ConsumerState<BiometricLockOverlay> createState() =>
      _BiometricLockOverlayState();
}

class _BiometricLockOverlayState extends ConsumerState<BiometricLockOverlay> {
  final BiometricAuthService _biometricService = BiometricAuthService.instance;

  bool _hasCheckedInitialSession = false;
  bool _isLocked = false;
  bool _isAuthenticating = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateInitialSession();
    });
  }

  Future<void> _evaluateInitialSession() async {
    if (kIsWeb || _hasCheckedInitialSession) return;

    final authAsync = ref.read(authStateProvider);
    if (authAsync.isLoading) return;

    _hasCheckedInitialSession = true;
    final user = authAsync.valueOrNull ?? ref.read(authGatewayProvider).currentUser;
    if (user == null) return;

    final available = await _biometricService.isBiometricAvailable();
    final enabled = available && await _biometricService.isBiometricEnabled();
    if (!mounted || !enabled) return;

    setState(() {
      _isLocked = true;
      _statusMessage = null;
    });
    await _triggerUnlockPrompt();
  }

  Future<void> _triggerUnlockPrompt() async {
    if (_isAuthenticating || !_isLocked) return;
    setState(() {
      _isAuthenticating = true;
      _statusMessage = null;
    });

    final ok = await _biometricService.promptAppUnlock();
    if (!mounted) return;

    if (ok) {
      setState(() {
        _isLocked = false;
        _isAuthenticating = false;
      });
    } else {
      setState(() {
        _isAuthenticating = false;
        _statusMessage =
            'Verification cancelled or failed. Tap below to try again.';
      });
    }
  }

  Future<void> _signOutFromLock() async {
    setState(() {
      _isLocked = false;
      _isAuthenticating = false;
    });
    await ref.read(authGatewayProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    ref.listen(authStateProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user == null) {
        if (_isLocked && mounted) {
          setState(() {
            _isLocked = false;
            _isAuthenticating = false;
          });
        }
        return;
      }
      if (!_hasCheckedInitialSession) {
        _evaluateInitialSession();
      }
    });

    if (!_isLocked) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Positioned.fill(
      child: Material(
        color: colorScheme.surface,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        size: 46,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ALIVE Nigeria Locked',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verify your fingerprint or face to unlock the app.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _statusMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _isAuthenticating ? null : _triggerUnlockPrompt,
                        icon: _isAuthenticating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.fingerprint_rounded),
                        label: Text(
                          _isAuthenticating
                              ? 'Verifying...'
                              : 'Unlock with Biometrics',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isAuthenticating ? null : _signOutFromLock,
                      child: const Text('Sign Out & Use Password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
