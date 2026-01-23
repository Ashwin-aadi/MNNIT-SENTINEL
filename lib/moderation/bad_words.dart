class BadWords {
  static const List<String> words = [
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'slut',
    'retard',
    'bastard'
  ];

  static bool containsBadWords(String text) {
    final lower = text.toLowerCase();
    return words.any((w) => lower.contains(w));
  }
}
