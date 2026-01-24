import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'mess_geofence_service.dart';

class MessMenuPage extends StatefulWidget {
  const MessMenuPage({super.key});

  @override
  State<MessMenuPage> createState() => _MessMenuPageState();
}

class _MessMenuPageState extends State<MessMenuPage> {
  String? uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      MessGeofenceService.start(uid!);
    }
  }

  @override
  void dispose() {
    MessGeofenceService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('User data not found')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String? userGender = data['gender'];

        if (userGender == null ||
            (userGender != 'Male' && userGender != 'Female')) {
          return const Scaffold(
            body: Center(child: Text('Gender not set')),
          );
        }

        return _buildMessUI(context, userGender);
      },
    );
  }

  // ============================================================
  // MAIN UI (DATA UNTOUCHED)
  // ============================================================
  Widget _buildMessUI(BuildContext context, String userGender) {
    final Map<String, Map<String, Map<String, Map<String, String>>>>
    messData = {
      'Male': {
        'Monday': {
          'B': {
            'food':
            'Paneer paratha, sauce, sprouts, milk, bread, jam, butter, banana, lemon, coffee powder',
            'time': '07:45 - 09:30 AM',
          },
          'L': {
            'food': 'Dal tadka, aalu fry, chapati, salad, rice, curd, achaar',
            'time': '12:30 - 02:00 PM',
          },
          'S': {'food': 'Cutlet, sauce, tea', 'time': '05:30 - 06:30 PM'},
          'D': {
            'food': 'Chapati, arhar dal, mushroom, rice, salad, ice cream',
            'time': '07:45 - 09:15 PM',
          },
        },
        'Tuesday': {
          'B': {
            'food':
            'Idli sambhar, aalu sabji, tea, sprouts, bread, jam, butter, cornflakes, banana, lemon, coffee',
            'time': '07:40 - 09:30 AM',
          },
          'L': {
            'food': 'Rajma, mix veg, chach, chapati, rice, salad',
            'time': '12:30 - 02:00 PM',
          },
          'S': {'food': 'Maggie, chowmin, tea', 'time': '05:30 - 06:30 PM'},
          'D': {
            'food': 'Chana dal, kadhai paneer, rice, chapati, salad, rasgulla',
            'time': '07:45 - 09:15 PM',
          },
        },
        'Wednesday': {
          'B': {
            'food':
            'Methi paratha, aalu sabji, tea, sprouts, bread, jam, butter, cornflakes, banana, lemon, coffee',
            'time': '07:40 - 09:30 AM',
          },
          'L': {
            'food': 'Curry rice, aalu phoolgobhi, chapati, salad',
            'time': '12:30 - 02:00 PM',
          },
          'S': {
            'food': 'Paneer sandwich, tea, sauce',
            'time': '05:30 - 06:30 PM',
          },
          'D': {
            'food': 'Besan gatta, mix dal, salad, rice, chapati, sevayi',
            'time': '07:45 - 09:15 PM',
          },
        },
        'Thursday': {
          'B': {
            'food':
            'Poori, masala, chama, suji ka halwa, milk, sprouts, bread, jam, butter, cornflakes, lemon, coffee',
            'time': '07:40 - 09:30 AM',
          },
          'L': {
            'food': 'Chhole, aalu pattagobhi, rice, curd, salad, chapati',
            'time': '12:30 - 02:00 PM',
          },
          'S': {'food': 'Pav bhaji, tea', 'time': '05:30 - 06:30 PM'},
          'D': {
            'food': 'Fry arhar dal, rice, chapati, mix veg, salad, gulabjamun',
            'time': '07:45 - 09:15 PM',
          },
        },
        'Friday': {
          'B': {
            'food':
            'Aalu pyaz paratha, sauce, milk, achaar, sprouts, bread, jam, butter, cornflakes, lemon, coffee',
            'time': '07:40 - 09:30 AM',
          },
          'L': {
            'food': 'Fry arhar dal, veg malayi kofta, chapati, salad, rice',
            'time': '12:30 - 02:00 PM',
          },
          'S': {
            'food': 'Fruit chat, masala, mishrambu',
            'time': '05:30 - 06:30 PM',
          },
          'D': {
            'food': 'Mix dal, paneer bhuji, chapati, rice, salad, custard',
            'time': '07:45 - 09:15 PM',
          },
        },
        'Saturday': {
          'B': {
            'food':
            'Samosa, chhole, milk, sprouts, bread, jam, butter, cornflakes, lemon, coffee',
            'time': '07:40 - 09:30 AM',
          },
          'L': {
            'food': 'Shahi paneer, poori, salad, rice, gulabjamun',
            'time': '12:30 - 02:00 PM',
          },
          'S': {'food': 'Break', 'time': '05:30 - 06:30 PM'},
          'D': {
            'food': 'Biryani, rayta, achaar, chutney, papad',
            'time': '07:45 - 09:15 PM',
          },
        },
        'Sunday': {
          'B': {
            'food':
            'Pyaaz kachori, dam aalu, jalebi, milk, sprouts, bread, jam, butter, cornflakes, lemon, coffee',
            'time': '07:40 - 09:30 AM',
          },
          'L': {
            'food': 'Chhole bhathure, rice, chutney, dahi bada, salad',
            'time': '12:30 - 02:00 PM',
          },
          'S': {'food': 'Poha, tea, sauce', 'time': '05:30 - 06:30 PM'},
          'D': {
            'food': 'Dal makhni, rice, broclli, chapati, salad, kheer',
            'time': '07:45 - 09:15 PM',
          },
        },
      },
      'Female': {
        'Monday': {
          'B': {
            'food':
            'Fried idli, nariyal chutney, guava, coffee, jam, butter, cornflakes, sprouts, tomato sauce, milk',
            'time': '07:30 - 09:30 AM',
          },
          'L': {
            'food':
            'Dam aalu, dahi bada, arhar dal, chapati, rice, achaar, salad',
            'time': '12:30 - 02:00 PM',
          },
          'S': {
            'food': 'Maggie, tomato sauce, coffee',
            'time': '05:00 - 06:30 PM',
          },
          'D': {
            'food':
            'Matar paneer, lobiya, rasgulla, chapati, rice, achaar, salad',
            'time': '08:00 - 09:00 PM',
          },
        },
        'Tuesday': {
          'B': {
            'food':
            'Uttapam, tamatar ki chutney, apple, tea, bread, jam, butter, cornflakes, sprouts, tomato sauce, milk',
            'time': '07:30 - 09:30 AM',
          },
          'L': {
            'food':
            'Soya methi aalu, arhar ki dal, chapati, rice, achaar, salad',
            'time': '12:30 - 02:00 PM',
          },
          'S': {'food': 'Aalu samosa, chhole, tea', 'time': '05:00 - 06:30 PM'},
          'D': {
            'food':
            'Masala beans, aalu matar, tamatar ki sabji, roti, rice, rasmalai, achaar, salad',
            'time': '08:00 - 09:00 PM',
          },
        },
        'Wednesday': {
          'B': {
            'food':
            'Plain idli, orange, achaar, tea, bread, jam, butter, cornflakes, sprouts, tomato sauce, milk',
            'time': '07:30 - 09:30 AM',
          },
          'L': {
            'food':
            'Kadhai paneer, moong dal, curd, chapati, rice, achaar, salad',
            'time': '12:30 - 02:00 PM',
          },
          'S': {'food': 'Bhajia, hari chutney', 'time': '05:00 - 06:30 PM'},
          'D': {
            'food':
            'Arhar dal, mix veg, rice, chapati, kheer, achaar, milk, salad',
            'time': '08:00 - 09:00 PM',
          },
        },
        'Thursday': {
          'B': {
            'food':
            'Aalu/gobhi/pyaaz paratha,lehsun chutney, tea, bread, jam, butter, cornflakes, sprouts, tomato sauce, milk',
            'time': '07:30 - 09:30 AM',
          },
          'L': {
            'food': 'Curry, aalu bhujia, chapati, rice, achaar, salad',
            'time': '12:30 - 02:00 PM',
          },
          'S': {'food': 'Veg roll, coffee', 'time': '05:00 - 06:30 PM'},
          'D': {
            'food':
            'Besan gatta, phoolgobhi, gajar ka halwa, chapati, rice, achaar, milk, salad',
            'time': '08:00 - 09:00 PM',
          },
        },
        'Friday': {
          'B': {
            'food':
            'Aalu matar ki poori, apple, coffee, bread, jam, butter, cornflakes, sprouts, tomato sauce, milk',
            'time': '07:30 - 09:30 AM',
          },
          'L': {
            'food': 'Palak aalu, rajma, chapati, rice, achaar, salad',
            'time': '12:30 - 02:00 PM',
          },
          'S': {
            'food': 'Aalu pakoda/aalu tikki chaat, tea',
            'time': '05:00 - 06:30 PM',
          },
          'D': {
            'food':
            'Malai dam aalu, dahi ke aalu, gulabjamun, chapati, rice, achaar, milk, salad',
            'time': '08:00 - 09:00 PM',
          },
        },
        'Saturday': {
          'B': {
            'food':
            'Poha, jalebi, curd, papaya, tea, bread, jam, butter, cornflakes, sprouts, tomato sauce, milk',
            'time': '07:30 - 09:30 AM',
          },
          'L': {
            'food': 'Chhole kulche, custard, rice, achaar, salad',
            'time': '12:30 - 02:00 PM',
          },
          'S': {'food': 'Break', 'time': '05:00 - 06:30 PM'},
          'D': {
            'food':
            'Fried rice, munchurian, boondi rayta, papad/veg biryani, achaar, salad',
            'time': '08:00 - 09:00 PM',
          },
        },
        'Sunday': {
          'B': {
            'food':
            'Poori, halwa, chana, pomegranate, tea, bread, jam, butter, cornflakes, sprouts, tomato sauce, milk',
            'time': '07:30 - 09:30 AM',
          },
          'L': {
            'food': 'Chane ki dal, mix veg, rice, achaar, salad',
            'time': '12:30 - 02:00 PM',
          },
          'S': {'food': 'Golgappe', 'time': '05:00 - 06:30 PM'},
          'D': {
            'food':
            'Paneer bhurji, dal makhni, sevayi, chapati, rice, achaar, milk',
            'time': '08:00 - 09:00 PM',
          },
        },
      },
    };

    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final currentDay = days[DateTime.now().weekday - 1];

    final dayMenu =
        messData[userGender]?[currentDay] ??
            messData[userGender]!['Monday']!;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: 300,
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1504674900247-0877df9cc836',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    "Mess Menu",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Today is $currentDay ($userGender)",
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 24),

                  _messOccupancyCard(),

                  const SizedBox(height: 30),

                  _buildMealBox(
                    "Breakfast",
                    dayMenu['B']!['time']!,
                    dayMenu['B']!['food']!,
                    Colors.orange,
                  ),
                  _buildMealBox(
                    "Lunch",
                    dayMenu['L']!['time']!,
                    dayMenu['L']!['food']!,
                    Colors.green,
                  ),
                  _buildMealBox(
                    "Snacks",
                    dayMenu['S']!['time']!,
                    dayMenu['S']!['food']!,
                    Colors.amber,
                  ),
                  _buildMealBox(
                    "Dinner",
                    dayMenu['D']!['time']!,
                    dayMenu['D']!['food']!,
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OCCUPANCY CARD
  // ============================================================
  Widget _messOccupancyCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('insideMess', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.people, size: 28),
              const SizedBox(width: 12),
              Text(
                '$count students currently in mess',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // MEAL BOX
  // ============================================================
  Widget _buildMealBox(
      String title,
      String time,
      String menu,
      Color accentColor,
      ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
        border: Border(left: BorderSide(color: accentColor, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const Icon(Icons.access_time, size: 16),
            ],
          ),
          Text(time, style: const TextStyle(fontSize: 12)),
          const Divider(height: 20),
          Text(menu, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
