import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart';
import 'mess_menu_page.dart';
import 'library_page.dart';
import 'safe_page.dart';
import 'attendance.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'isLoggedIn': false,
        'lastLogoutAt': DateTime.now().toIso8601String(),
      });
    }

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }

    await FirebaseAuth.instance.signOut();
  }

  Future<void> _pickAndSavePhoto(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked == null) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final directory = await getApplicationDocumentsDirectory();
    final localPath = '${directory.path}/profile_$uid.jpg';

    final savedImage = await File(picked.path).copy(localPath);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      'photoPath': savedImage.path,
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4FF),
      appBar: AppBar(
        title: const Text('MNNIT SENTINEL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _greeting(data['fullName']),
                  const SizedBox(height: 16),

                  _idCard(
                    data,
                    onPhotoTap: () => _pickAndSavePhoto(context),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _smallCard(
                        title: 'Mess',
                        icon: Icons.restaurant,
                        color: Colors.orange.shade200,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MessMenuPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      _smallCard(
                        title: 'Attendance',
                        icon: Icons.check_circle,
                        color: Colors.blue.shade200,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AttendancePage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _wideCard(
                    title: 'Library',
                    icon: Icons.library_books,
                    color: Colors.indigo.shade200,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LibraryPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _smallCard(
                        title: 'Entry Status',
                        icon: Icons.location_on,
                        color: Colors.green.shade200,
                        subtitle: data['geofenceStatus'] ?? 'UNKNOWN',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HomePage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      _smallCard(
                        title: 'File Safe',
                        icon: Icons.lock,
                        color: Colors.purple.shade200,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SafePage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _greeting(String name) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getGreeting()}, $name',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Welcome to MNNIT SENTINEL',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _idCard(
      Map<String, dynamic> data, {
        required VoidCallback onPhotoTap,
      }) {
    final photoPath = data['photoPath'];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.lightBlue.shade200,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1B2A6B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Motilal Nehru National Institute of Technology Allahabad \n An Insitute of National Importance Declared by Act. of Parliament',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onPhotoTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade300,
                      child: photoPath != null && File(photoPath).existsSync()
                          ? Image.file(File(photoPath), fit: BoxFit.cover)
                          : const Icon(Icons.person, size: 40),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'IDENTITY CARD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _idText('NAME', data['fullName']),
                      _idText('Reg No.', data['registrationNumber']),
                      _idText('Programme', data['branch']),
                      _idText('Department', data['section']),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _idText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _smallCard({
    required String title,
    required IconData icon,
    required Color color,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null)
                Text(subtitle, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wideCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
