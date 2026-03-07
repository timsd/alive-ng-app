import 'package:flutter/material.dart';
import '../services/role_access_service.dart';
import '../config/development_config.dart';

/// Widget that guards content based on user roles
class RoleGuard extends StatelessWidget {
  final String requiredRole;
  final Widget child;
  final Widget? fallback;
  final String? resource;
  final bool showFallback;
  final bool bypassGuard;

  const RoleGuard({
    super.key,
    required this.requiredRole,
    required this.child,
    this.fallback,
    this.resource,
    this.showFallback = true,
    this.bypassGuard = false,
  });

  @override
  Widget build(BuildContext context) {
    final roleService = RoleAccessService.instance;
    
    // Check for development mode bypass
    final shouldBypass = bypassGuard || DevelopmentConfig.shouldBypassRoleGuards;
    
    if (shouldBypass) {
      DevelopmentConfig.logDevelopmentWarning('Role guard for $requiredRole');
      roleService.logAccessAttempt(resource ?? 'widget', true);
      return child;
    }
    
    final hasAccess = roleService.hasRole(requiredRole);

    if (hasAccess) {
      roleService.logAccessAttempt(resource ?? 'widget', true);
      return child;
    }

    roleService.logAccessAttempt(resource ?? 'widget', false);

    if (!showFallback) {
      return const SizedBox.shrink();
    }

    return fallback ?? _buildDefaultFallback(context);
  }

  Widget _buildDefaultFallback(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Access Restricted',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You need ${_getRoleDisplayName(requiredRole)} privileges to access this content.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'leader':
        return 'Leadership';
      case 'coordinator':
        return 'Coordinator';
      case 'member':
        return 'Member';
      default:
        return role.toUpperCase();
    }
  }
}

/// Widget that shows content only to specific roles
class RoleVisibility extends StatelessWidget {
  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;
  final bool showFallback;

  const RoleVisibility({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
    this.showFallback = false,
  });

  @override
  Widget build(BuildContext context) {
    final roleService = RoleAccessService.instance;
    final currentRole = roleService.getCurrentUserRole();

    if (currentRole != null && allowedRoles.contains(currentRole)) {
      return child;
    }

    if (showFallback && fallback != null) {
      return fallback!;
    }

    return const SizedBox.shrink();
  }
}

/// Widget that conditionally shows content based on permissions
class PermissionBuilder extends StatelessWidget {
  final bool Function() hasPermission;
  final Widget Function(BuildContext context, bool hasAccess) builder;
  final String? resource;

  const PermissionBuilder({
    super.key,
    required this.hasPermission,
    required this.builder,
    this.resource,
  });

  @override
  Widget build(BuildContext context) {
    final hasAccess = hasPermission();
    
    if (resource != null) {
      RoleAccessService.instance.logAccessAttempt(resource!, hasAccess);
    }
    
    return builder(context, hasAccess);
  }
}

/// Screen wrapper that enforces role-based access
class RoleProtectedScreen extends StatelessWidget {
  final String requiredRole;
  final Widget child;
  final String? screenName;
  final bool bypassGuard;

  const RoleProtectedScreen({
    super.key,
    required this.requiredRole,
    required this.child,
    this.screenName,
    this.bypassGuard = false,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      requiredRole: requiredRole,
      resource: screenName ?? 'screen',
      bypassGuard: bypassGuard,
      fallback: Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red[400],
          foregroundColor: Colors.white,
        ),
        body: _buildAccessDeniedBody(context),
      ),
      child: child,
    );
  }

  Widget _buildAccessDeniedBody(BuildContext context) {
    final roleService = RoleAccessService.instance;
    final currentRole = roleService.getCurrentUserRole();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Access Denied',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.red[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You need ${_getRoleDisplayName(requiredRole)} privileges to access this screen.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Current role: ${_getRoleDisplayName(currentRole ?? 'none')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                    '/home',
                    (route) => false,
                  ),
                  icon: const Icon(Icons.home),
                  label: const Text('Home'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'leader':
        return 'Leadership';
      case 'coordinator':
        return 'Coordinator';
      case 'member':
        return 'Member';
      default:
        return 'Unknown';
    }
  }
}



