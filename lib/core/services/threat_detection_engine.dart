import 'package:flutter/foundation.dart';

class ThreatResult {
  final bool detected;
  final double confidence;
  final String threatCategory;
  final String matchedPhrase;

  const ThreatResult({
    required this.detected,
    required this.confidence,
    required this.threatCategory,
    required this.matchedPhrase,
  });

  static const empty = ThreatResult(
    detected: false,
    confidence: 0.0,
    threatCategory: 'none',
    matchedPhrase: '',
  );
}

class ThreatDetectionEngine {
  // ─── Direct Threats List (Base confidence 0.95) ───
  static final List<String> directThreats = [
    "i will kill you", "i go kill you", "i go kill you now", "ill kill you",
    "i will shoot you", "i will stab you", "i go stab you", "i will hurt you",
    "i will beat you", "you will die today", "today na your last day", "you go die",
    "you dey mad", "are you mad", "you think say you smart", "i go deal with you",
    "you go regret this", "i will make you regret", "i will finish you",
    "you are finished", "your life is over", "i go end you", "i swear i go hurt you",
    "on my life i go hurt you", "i go wound you", "i will wound you",
    "i will break your head", "i go break your head", "i go smash your head",
    "i will burn your house", "i go burn your house", "i go burn everything",
    "you will not leave here alive", "you no go leave here", "you no go comot here",
    "nobody go find you", "no one will find you", "i will bury you", "i go bury you",
    "i will destroy you", "i go destroy you", "you dey joke with me",
    "you dey play with me", "you dey try me", "dont try me", "dont test me",
    "you no know who i be", "you no know who i am", "i go show you",
    "i will show you who i am", "i go teach you lesson", "i will teach you a lesson",
    "you go learn today", "you will learn today", "i go beat you finish",
    "i go beat the life out of you", "i will beat the life out of you",
    "make i see you outside", "make you comot outside", "come outside now",
    "come outside make i deal with you", "i go find you", "i will find you",
    "i know where you live", "i know where you stay", "i dey come for you",
    "im coming for you", "run if you can", "nowhere to run", "you cannot escape",
    "you no fit run", "i go catch you", "i will catch you"
  ];

  // ─── Robbery & Extortion List (Base confidence 0.90) ───
  static final List<String> robberyPhrases = [
    "give me your money", "give me your phone", "give me everything",
    "drop everything", "drop it now", "put it down now", "empty your pockets",
    "empty your bag", "your bag oya", "your phone oya", "oya give me",
    "give me give me", "hand it over", "hand over everything", "where is the money",
    "where is your money", "oya bring money", "bring money now", "bring the cash",
    "i go shoot you if you shout", "shout and i kill you", "if you scream i go shoot",
    "dont make noise", "shut up or i kill you", "shut your mouth", "close your mouth",
    "cooperate and nothing go happen", "follow us quietly", "follow us make nothing happen",
    "enter the car", "enter the vehicle", "move move move", "move now",
    "get down", "lie down now", "face down", "face the floor", "get on the floor",
    "nobody move", "everybody down", "this is a robbery", "this na robbery",
    "we are not here to play", "we no come to play", "this is not a joke",
    "this no be joke", "give us everything", "empty the register", "open the safe",
    "open the vault", "bring out the money", "where is the safe", "take us to the money",
    "bring the atm card", "give me your atm card", "your pin number",
    "what is your pin", "enter the pin", "withdraw the money", "transfer the money",
    "send the money now"
  ];

  // ─── Sexual Assault Indicators (Base confidence 0.95) ───
  static final List<String> sexualAssaultPhrases = [
    "dont shout", "if you shout i kill you", "cooperate and nothing go happen",
    "nobody will hear you", "nobody can hear you here", "nobody dey come",
    "no one is coming", "you are alone", "you dey alone", "i know you are alone",
    "i know you dey alone", "remove your clothes", "take off your clothes",
    "undress now", "dont fight it", "stop struggling", "stop fighting",
    "this will only take a minute", "if you cooperate i wont hurt you",
    "i will not hurt you if you cooperate", "keep quiet", "i will let you go after",
    "i go let you go after", "no one needs to know", "nobody need to know"
  ];

  // ─── Distress Signals (Base confidence 0.95 — Instant Alert Trigger) ───
  static final List<String> distressSignals = [
    "help", "help me", "somebody help me", "help please", "please help", "help help help",
    "save me", "please save me", "somebody save me", "i am in danger", "in danger", "i'm in danger",
    "call police", "call the police", "police", "armed robbers", "thief", "thieves",
    "help oh", "somebody come", "come and help me", "dem wan kill me", "na me dem wan kill",
    "somebody help", "i dont feel safe", "i feel unsafe", "please dont hurt me",
    "please dont kill me", "leave me alone", "i am being followed", "someone is following me",
    "i am scared", "i'm scared", "stop", "leave me", "abeg leave me", "abeg no do me anything",
    "abeg help", "abeg help me", "i dont want to die", "i dont want trouble",
    "please i beg you", "i beg you please", "i am begging you", "i have children",
    "i have kids", "i have a family", "i swear i wont tell anyone", "i wont say anything",
    "i promise i wont tell", "please take everything", "take everything just dont hurt me",
    "i will give you everything", "this person is trying to hurt me", "someone is threatening me",
    "i need help", "shout police", "ole ole ole", "dem dey threaten me", "distress", "emergency"
  ];

  // ─── Nigerian Pidgin Additional Phrases (Base confidence 0.90) ───
  static final List<String> pidginPhrases = [
    "wetin dey do you", "you dey craze", "you don die", "your time don reach",
    "oya oya oya", "enter inside", "comot your cloth", "where you put the money",
    "i go comot your eye", "i go scatter your head", "you no sabi who i be",
    "i go deal with you finish", "you no get sense", "you think say you wise",
    "na today you go learn", "i go report you", "make you no talk",
    "e go be for you", "you go answer for this", "this one na your last warning",
    "na warning i dey give you"
  ];

  // ─── Keyword Amplifiers (+0.10 confidence when within 5 words) ───
  static final Set<String> keywordAmplifiers = {
    "gun", "knife", "cutlass", "machete", "weapon", "blade", "bullet",
    "shoot", "stab", "cut", "attack", "harm", "danger", "police", "run",
    "escape", "trapped", "alone", "night", "dark", "nobody", "empty", "isolated"
  };

  /// Main detection function receiving raw transcribed text string
  static ThreatResult evaluate(String rawText) {
    if (rawText.trim().isEmpty) return ThreatResult.empty;

    final normalized = _normalize(rawText);
    final words = normalized.split(RegExp(r'\s+'));

    final Map<String, String> categoryMatches = {};
    final Map<String, double> categoryConfidences = {};

    // Scan Direct Threats
    final dtMatch = _findMatch(normalized, directThreats);
    if (dtMatch != null) {
      categoryMatches['direct_threat'] = dtMatch;
      categoryConfidences['direct_threat'] = 0.95;
    }

    // Scan Robbery
    final robMatch = _findMatch(normalized, robberyPhrases);
    if (robMatch != null) {
      categoryMatches['robbery'] = robMatch;
      categoryConfidences['robbery'] = 0.90;
    }

    // Scan Sexual Assault
    final saMatch = _findMatch(normalized, sexualAssaultPhrases);
    if (saMatch != null) {
      categoryMatches['sexual_assault'] = saMatch;
      categoryConfidences['sexual_assault'] = 0.95;
    }

    // Scan Distress
    final disMatch = _findMatch(normalized, distressSignals);
    if (disMatch != null) {
      categoryMatches['distress'] = disMatch;
      categoryConfidences['distress'] = 0.95;
    }

    // Scan Pidgin
    final pidMatch = _findMatch(normalized, pidginPhrases);
    if (pidMatch != null) {
      categoryMatches['pidgin_threat'] = pidMatch;
      categoryConfidences['pidgin_threat'] = 0.90;
    }

    if (categoryMatches.isEmpty) {
      return ThreatResult.empty;
    }

    // Determine primary match category and base confidence
    double bestConfidence = 0.0;
    String primaryCategory = 'direct_threat';
    String primaryMatchedPhrase = '';

    categoryConfidences.forEach((cat, conf) {
      if (conf > bestConfidence) {
        bestConfidence = conf;
        primaryCategory = cat;
        primaryMatchedPhrase = categoryMatches[cat]!;
      }
    });

    // Rule: Two simultaneous matches across different categories return 1.0 confidence!
    if (categoryMatches.length >= 2) {
      bestConfidence = 1.0;
    } else {
      // Check for Keyword Amplifiers within 5 words of matched phrase
      bool hasAmplifierNearby = _hasAmplifierWithinRange(words, primaryMatchedPhrase);
      if (hasAmplifierNearby) {
        bestConfidence = (bestConfidence + 0.10).clamp(0.0, 1.0);
      }
    }

    return ThreatResult(
      detected: true,
      confidence: bestConfidence,
      threatCategory: primaryCategory,
      matchedPhrase: primaryMatchedPhrase,
    );
  }

  static String _normalize(String input) {
    // Lowercase, remove punctuation except apostrophes, trim extra spaces
    String lower = input.toLowerCase();
    String clean = lower.replaceAll(RegExp(r"[^\w\s']"), '');
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _findMatch(String text, List<String> phraseList) {
    for (final phrase in phraseList) {
      final normPhrase = _normalize(phrase);
      // 1. Exact Substring Match
      if (text.contains(normPhrase)) {
        return phrase;
      }
      // 2. Fuzzy Match (allow 1 character difference)
      if (text.length >= 4 && normPhrase.length >= 4) {
        final textWords = text.split(' ');
        final phraseWords = normPhrase.split(' ');
        if (textWords.length >= phraseWords.length) {
          for (int i = 0; i <= textWords.length - phraseWords.length; i++) {
            final window = textWords.sublist(i, i + phraseWords.length).join(' ');
            if (_levenshteinDistance(window, normPhrase) <= 1) {
              return phrase;
            }
          }
        }
      }
    }
    return null;
  }

  static bool _hasAmplifierWithinRange(List<String> words, String matchedPhrase) {
    final normPhraseWords = _normalize(matchedPhrase).split(' ');
    int matchIndex = -1;

    for (int i = 0; i <= words.length - normPhraseWords.length; i++) {
      if (words.sublist(i, i + normPhraseWords.length).join(' ') == normPhraseWords.join(' ')) {
        matchIndex = i;
        break;
      }
    }

    if (matchIndex == -1) return false;

    int start = (matchIndex - 5).clamp(0, words.length);
    int end = (matchIndex + normPhraseWords.length + 5).clamp(0, words.length);

    for (int i = start; i < end; i++) {
      if (keywordAmplifiers.contains(words[i])) {
        return true;
      }
    }
    return false;
  }

  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}
