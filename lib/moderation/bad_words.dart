class BadWords {
  static const List<String> words = [
    'fuck',
    'Fuck',
    'fcuk',
    'fck',
    'F',
    'motherfucker',
    'fucked',
    'whore',
    'bullshit',
    'son of a bitch',
    'shit',
    'bitch',
    'asshole',
    'slut',
    'retard',
    'bastard',
  ];

  static final RegExp _badWordRegex = RegExp(
    r'\b(' + words.join('|') + r')\b',
    caseSensitive: false,
  );

  static bool containsBadWords(String text) {
    return _badWordRegex.hasMatch(text);
  }
}