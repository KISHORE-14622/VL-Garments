import 'package:flutter/material.dart';

import '../core/models/user.dart';
import '../core/services/auth_service.dart';
import '../core/services/data_service.dart';
import '../features/admin/admin_home_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/staff/staff_home_screen.dart';

class AppRoot extends StatefulWidget {
  final AuthService authService;
  final DataService dataService;

  const AppRoot({super.key, required this.authService, required this.dataService});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: widget.authService.userStream,
      initialData: widget.authService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(authService: widget.authService);
        }
        if (user.role == UserRole.admin) {
          return AdminHomeScreen(authService: widget.authService, dataService: widget.dataService);
        }
        return StaffHomeScreen(authService: widget.authService, dataService: widget.dataService, user: user);
      },
    );
  }
}


