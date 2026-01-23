import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_gate.dart';

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _regController = TextEditingController();

  String? _gender;
  String? _branch;
  String? _semester;
  String? _section;

  bool _loading = false;

  User get user => FirebaseAuth.instance.currentUser!;

  @override
  void dispose() {
    _nameController.dispose();
    _regController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_gender == null ||
        _branch == null ||
        _semester == null ||
        _section == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _loading = true);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(
      {
        'fullName': _nameController.text.trim(),
        'email': user.email,
        'registrationNumber': _regController.text.trim(),
        'gender': _gender,
        'branch': _branch,
        'semester': _semester,
        'section': _section, // A1, A2, B1, B2, C1, C2, E1, E2
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true), // IMPORTANT
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'Get Started',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              _field(_nameController, 'Full Name'),
              _field(null, user.email!, enabled: false),
              _field(_regController, 'Registration Number'),

              _dropdown(
                hint: 'Gender',
                value: _gender,
                items: const ['Male', 'Female', 'Other'],
                onChanged: (v) => setState(() => _gender = v),
              ),

              _dropdown(
                hint: 'Branch',
                value: _branch,
                items: const ['CSE', 'IT', 'ECE', 'EE', 'ME', 'CE', 'BT'],
                onChanged: (v) => setState(() => _branch = v),
              ),

              _dropdown(
                hint: 'Semester',
                value: _semester,
                items: const ['1', '2', '3', '4', '5', '6', '7', '8'],
                onChanged: (v) => setState(() => _semester = v),
              ),

              _dropdown(
                hint: 'Section',
                value: _section,
                items: const [
                  'A1', 'A2',
                  'B1', 'B2',
                  'C1', 'C2',
                  'E1', 'E2',
                ],
                onChanged: (v) => setState(() => _section = v),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
      TextEditingController? controller,
      String hint, {
        bool enabled = true,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        validator: enabled
            ? (v) => v == null || v.isEmpty ? 'Required' : null
            : null,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(hint),
        items: items
            .map(
              (e) => DropdownMenuItem<String>(
            value: e,
            child: Text(e),
          ),
        )
            .toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Required' : null,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
