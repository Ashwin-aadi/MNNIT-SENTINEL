import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'main.dart'; // for HomePage

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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4FF),

      /// 🔐 LOGOUT LIVES HERE
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

                  _idCard(data),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _smallCard(
                        title: 'Mess',
                        icon: Icons.restaurant,
                        color: Colors.orange.shade200,
                        onTap: () {},
                      ),
                      const SizedBox(width: 12),
                      _smallCard(
                        title: 'Attendance',
                        icon: Icons.check_circle,
                        color: Colors.blue.shade200,
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _wideCard(
                    title: 'Library',
                    icon: Icons.library_books,
                    color: Colors.indigo.shade200,
                    onTap: () {},
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
                              builder: (_) => const HomePage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      _smallCard(
                        title: 'File Safe',
                        icon: Icons.lock,
                        color: Colors.purple.shade200,
                        onTap: () {},
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
            'Good Morning, $name',
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

  Widget _idCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, size: 40),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _idRow('Name', data['fullName']),
              _idRow('Reg No', data['registrationNumber']),
              _idRow('Programme', data['branch']),
              _idRow('Section', data['section']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _idRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w600),
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
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12),
                ),
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
