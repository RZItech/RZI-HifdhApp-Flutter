import 'package:talker_flutter/talker_flutter.dart';
import 'package:rzi_hifdhapp/core/di/injection_container.dart';

class TextUtils {
  static String normalizeArabic(
    String text, [
    Map<String, String>? customRules,
  ]) {
    String normalized = text;

    // 1. Initial basic cleaning (diacritics, tatweel, formatting, punctuation)

    // Remove diacritics/Tashkeel and Quranic signs
    normalized = normalized.replaceAll(
      RegExp(
        '[\u064E\u064F\u0650\u0651\u0652\u064B\u064C\u064D\u0670\u06DF-\u06E4]',
      ),
      '',
    );

    // Remove Tatweel (elongation character)
    normalized = normalized.replaceAll('ـ', '');

    // Remove invisible formatting characters (RLM, LRM, etc.)
    normalized = normalized.replaceAll(
      RegExp('[\u200E\u200F\u202A-\u202E]'),
      '',
    );

    // Remove punctuation
    normalized = normalized.replaceAll(RegExp(r'[.,:;?!\-_"()]'), '');

    // 2. Standardization (Alif, Taa Marbutah, etc.)

    // Replace Taa Marbutah with Haa
    normalized = normalized.replaceAll('ة', 'ه');
    normalized = normalized.replaceAll('ﺔ', 'ه');

    // Replace Alif Maqsurah with Yaa (standard for this app's current config)
    normalized = normalized.replaceAll('ى', 'ي');

    // Replace Alif Hamza/Madda/Wasla with Alif
    normalized = normalized.replaceAll(RegExp('[أإآٱ]'), 'ا');

    // Normalize spacing
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    if (normalized.startsWith('و')) {
      normalized = normalized.replaceFirst(RegExp('و'), '');
    }

    normalized = normalized.trim();

    // 3. Apply Custom Rules (LAST, on fully normalized text)
    if (customRules != null && customRules.isNotEmpty) {
      customRules.forEach((from, to) {
        // We normalize the 'from' and 'to' parts of the rule to match our current text state
        final cleanFrom = normalizeArabic(from);
        final cleanTo = normalizeArabic(to);

        if (normalized.contains(cleanFrom)) {
          sl<Talker>().debug(
            '🔄 Applying Custom Rule: "$cleanFrom" -> "$cleanTo"',
          );
          normalized = normalized.replaceAll(cleanFrom, cleanTo);
        }
      });
    }

    return normalized;
  }
}
