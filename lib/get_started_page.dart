import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _regController = TextEditingController();
  final _sectionController = TextEditingController();

  String? _gender;
  String? _branch;
  String? _semester;

  bool _loading = false;

  final user = FirebaseAuth.instance.currentUser!;

  @override
  void dispose() {
    _nameController.dispose();
    _regController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null || _branch == null || _semester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all dropdowns')),
      );
      return;
    }

    setState(() => _loading = true);

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fullName': _nameController.text.trim(),
      'email': user.email,
      'registrationNumber': _regController.text.trim(),
      'gender': _gender,
      'branch': _branch,
      'semester': _semester,
      'section': _sectionController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF8E9AEF),
                  Color(0xFF6A7FDB),
                  Color(0xFF4F5BD5),
                ],
              ),
            ),
          ),

          /// White Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        'Get Started !!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F5BD5),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildField(
                        controller: _nameController,
                        hint: 'Full Name',
                      ),

                      _buildField(
                        hint: user.email!,
                        enabled: false,
                      ),

                      _buildField(
                        controller: _regController,
                        hint: 'Registration Number',
                      ),

                      _dropdown(
                        hint: 'Gender',
                        value: _gender,
                        items: ['Male', 'Female', 'Other'],
                        onChanged: (v) => setState(() => _gender = v),
                      ),

                      _dropdown(
                        hint: 'Branch',
                        value: _branch,
                        items: [
                          'CSE',
                          'IT',
                          'ECE',
                          'EE',
                          'ME',
                          'CE',
                          'BT',
                        ],
                        onChanged: (v) => setState(() => _branch = v),
                      ),

                      _dropdown(
                        hint: 'Semester',
                        value: _semester,
                        items: [
                          '1','2','3','4','5','6','7','8'
                        ],
                        onChanged: (v) => setState(() => _semester = v),
                      ),

                      _buildField(
                        controller: _sectionController,
                        hint: 'Section',
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8ECae6),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                            'Continue',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    TextEditingController? controller,
    required String hint,
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
          filled: true,
          fillColor: const Color(0xFFF2F3F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(hint),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Required' : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF2F3F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
