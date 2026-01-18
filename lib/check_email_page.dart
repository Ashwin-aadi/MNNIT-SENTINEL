import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CheckEmailPage extends StatelessWidget {
  const CheckEmailPage({super.key});

  Future<void> _refresh(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    if (user != null && user.emailVerified) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Verify your email',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'A verification link has been sent to your email.\n'
                    'Please verify to continue.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _refresh(context),
                child: const Text('I have verified'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
