import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_dashboard_page.dart';
import 'welcome_page.dart';
import 'check_email_page.dart';
import 'get_started_page.dart';
import 'main.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _hasCompletedOnboarding(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    return doc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const WelcomePage();
        }

        final user = snapshot.data!;

        if (!user.emailVerified) {
          return const CheckEmailPage();
        }

        return FutureBuilder<bool>(
          future: _hasCompletedOnboarding(user.uid),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snap.data!) {
              return const GetStartedPage();
            }

            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await bootstrapAfterLogin();
            });

            return const HomeDashboardPage();
          },
        );
      },
    );
  }
}
