import 'package:flutter/material.dart';

import '../core/models/user.dart';
import '../core/services/auth_service.dart';
import '../core/services/data_service.dart';
import '../features/admin/admin_home_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/pin_setup_screen.dart';
import '../features/auth/pin_entry_screen.dart';

class AppRoot extends StatefulWidget {
  final AuthService authService;
  final DataService dataService;

  const AppRoot({super.key, required this.authService, required this.dataService});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  bool _initialized = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock app when it goes to background (optional - can be enabled later)
    // if (state == AppLifecycleState.paused) {
    //   widget.authService.lockApp();
    // }
  }

  Future<void> _initializeAuth() async {
    await widget.authService.initialize();
    if (mounted) {
      setState(() {
        _initialized = true;
        _initializing = false;
      });
    }
  }

  void _handlePinSet() {
    setState(() {});
  }

  void _handleUnlock() {
    setState(() {});
  }

  Future<void> _handleSignOut() async {
    await widget.authService.signOut();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while initializing
    if (_initializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<AppUser?>(
      stream: widget.authService.userStream,
      initialData: widget.authService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        // No user - show login
        if (user == null) {
          return LoginScreen(authService: widget.authService);
        }
        
        // User exists but needs to unlock (has PIN set)
        if (widget.authService.needsUnlock) {
          return PinEntryScreen(
            authService: widget.authService,
            onUnlocked: _handleUnlock,
            onSignOut: _handleSignOut,
          );
        }
        
        // User logged in but needs PIN setup (first time after login)
        if (widget.authService.needsPinSetup) {
          return PinSetupScreen(
            authService: widget.authService,
            onPinSet: _handlePinSet,
          );
        }
        
        // Fully authenticated - show admin home
        return AdminHomeScreen(
          authService: widget.authService, 
          dataService: widget.dataService,
        );
      },
    );
  }
}


