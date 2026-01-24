import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CheckEmailPage extends StatefulWidget {
  const CheckEmailPage({super.key});

  @override
  State<CheckEmailPage> createState() => _CheckEmailPageState();
}

class _CheckEmailPageState extends State<CheckEmailPage> {
  bool _loading = false;

  Future<void> _checkVerification() async {
    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (refreshedUser != null && refreshedUser.emailVerified) {
      ///  VERIFIED → GetStarted
      Navigator.pushReplacementNamed(context, '/get-started');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email not verified yet. Check inbox or spam.'),
        ),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_read, size: 80),
            const SizedBox(height: 20),
            const Text(
              'We’ve sent a verification email.\nPlease verify and come back.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _loading ? null : _checkVerification,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('I have verified'),
            ),
          ],
        ),
      ),
    );
  }
}
