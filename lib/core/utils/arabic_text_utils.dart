class ArabicTextUtils {
  static List<String> splitArabicTextIntoWords(String text) {
    // This is a basic split. Might need more sophisticated logic
    // to handle punctuation, diacritics, and other Arabic specific rules.
    // For now, split by space and remove common punctuation.
    return text
        .replaceAll(RegExp(r'[.,;!؟ـ]'), '') // Remove common punctuation
        .split(RegExp(r'\s+')) // Split by one or more spaces
        .where((word) => word.isNotEmpty)
        .toList();
  }

  static String normalizeArabicWord(String word) {
    // Normalize Arabic word for comparison.
    // This might involve removing diacritics (harakat),
    // standardizing hamza forms, etc.
    // For VOSK, the output usually doesn't have harakat.
    String normalized = word;
    // Remove Tatweel (ـ)
    normalized = normalized.replaceAll('\u0640', '');
    // Remove diacritics (harakat)
    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
    // Standardize Hamza (ء ا أ ؤ إ ئ)
    normalized = normalized.replaceAll(RegExp(r'[أإؤئ]'), 'ا');
    normalized = normalized.replaceAll('ة', 'ه'); // ta marbuta to ha
    normalized = normalized.replaceAll('ى', 'ي'); // alef maksura to ya

    return normalized.trim();
  }
}
