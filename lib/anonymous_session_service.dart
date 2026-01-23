import 'dart:math';

class AnonymousSessionService {
  static Map<String, String> createSession() {
    final random = Random();

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final alias = 'User${1000 + random.nextInt(9000)}';

    return {
      'sessionId': sessionId,
      'alias': alias,
    };
  }
}