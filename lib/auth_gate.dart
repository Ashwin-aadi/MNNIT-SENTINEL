import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'welcome_page.dart';
import 'check_email_page.dart';
import 'get_started_page.dart';
import 'main.dart'; // for HomePage

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 🔄 Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ Not signed in
        if (!snapshot.hasData) {
          return const WelcomePage();
        }

        final user = snapshot.data!;

        // ❌ Email not verified
        if (!user.emailVerified) {
          return const CheckEmailPage();
        }

        // 🔄 Check onboarding
        return FutureBuilder<bool>(
          future: _isOnboardingDone(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // ❌ Not onboarded
            if (!snap.data!) {
              return const GetStartedPage();
            }

            // ✅ All conditions satisfied
            return const HomePage();
          },
        );
      },
    );
  }
}
