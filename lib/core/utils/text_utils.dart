class TextUtils {
  static String normalizeArabic(String text) {
    String normalized = text;
    // Convert digits to Arabic words first, to match the target text format
    // normalized = normalized.replaceAll('صفر','0');
    // normalized = normalized.replaceAll('واحد','1');
    // normalized = normalized.replaceAll('اثنين','2');
    // normalized = normalized.replaceAll('ثلاثة','3');
    // normalized = normalized.replaceAll('اربعة','4');
    // normalized = normalized.replaceAll('خمسة','5');
    // normalized = normalized.replaceAll('ستة','6');
    // normalized = normalized.replaceAll('سبعة','7');
    // normalized = normalized.replaceAll('ثمانية','8');
    // normalized = normalized.replaceAll('تسعة','9');

    // Replace Taa Marbutah with Haa
    normalized = normalized.replaceAll('ة', 'ه');
    normalized = normalized.replaceAll('ﺔ', 'ه');
    // Replace Alif Maqsurah with Alif
    normalized = normalized.replaceAll('ى', 'ا');

    // Remove diacritics/Tashkeel by explicitly listing common ones
    // Fatha, Damma, Kasra, Shadda, Sukun, Fathatan, Dammatan, Kasratan
    normalized = normalized.replaceAll(
      RegExp('[\u064E\u064F\u0650\u0651\u0652\u064B\u064C\u064D]'),
      '',
    );

    // Remove punctuation and spaces
    // Explicitly listing special characters for RegExp character class
    // Matches: . , : ; ? ! - _ " ( ) and whitespace (including newlines)
    normalized = normalized.replaceAll(RegExp(r'[.,:;?!\-_"()]'), '');
    normalized = normalized.replaceAll(RegExp(r'\s'), ' ');

    // Remove invisible formatting characters (RLM, LRM, etc.) that iOS might insert
    // \u200E: Left-to-Right Mark
    // \u200F: Right-to-Left Mark
    // \u202A-\u202E: Directional formatting
    normalized = normalized.replaceAll(
      RegExp('[\u200E\u200F\u202A-\u202E]'),
      '',
    );

    // Remove Tatweel (elongation character)
    normalized = normalized.replaceAll('ـ', '');

    // Trim any remaining whitespace from ends
    return normalized.trim();
  }
}
