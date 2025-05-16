/*
 * Phonetic
 * Copyright 2013 Tom Frost (original Javascript version - MIT)
 * Copyright 2021 Kee Vault Ltd (Dart ported version - AGPLv3)
 */

import 'dart:math';

/// Phonetics that sound best before a vowel.
/// @type {Array}
const PHONETIC_PRE = [
  // Simple phonetics
  'b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'p',
  'qu', 'r', 's', 't',
  // Complex phonetics
  'bl',
  'ch', 'cl', 'cr',
  'dr',
  'fl', 'fr',
  'gl', 'gr',
  'kl', 'kr',
  'ph', 'pr', 'pl',
  'sc', 'sh', 'sl', 'sn', 'sr', 'st', 'str', 'sw',
  'th', 'tr',
  'br',
  'v', 'w', 'y', 'z',
];

/// The number of simple phonetics within the 'pre' set.
/// @type {number}
const PHONETIC_PRE_SIMPLE_LENGTH = 16;

/// Vowel sound phonetics.
/// @type {Array}
const PHONETIC_MID = [
  // Simple phonetics
  'a', 'e', 'i', 'o', 'u',
  // Complex phonetics
  'ee', 'ie', 'oo', 'ou', 'ue',
];

/// The number of simple phonetics within the 'mid' set.
/// @type {number}
const PHONETIC_MID_SIMPLE_LENGTH = 5;

/// Phonetics that sound best after a vowel.
/// @type {Array}
const PHONETIC_POST = [
  // Simple phonetics
  'b', 'd', 'f', 'g', 'k', 'l', 'm', 'n', 'p', 'r', 's', 't', 'y',
  // Complex phonetics
  'ch', 'ck',
  'ln',
  'nk', 'ng',
  'rn',
  'sh', 'sk', 'st',
  'th',
  'x', 'z',
];

/// The number of simple phonetics within the 'post' set.
/// @type {number}
const PHONETIC_POST_SIMPLE_LENGTH = 13;

/// A mapping of regular expressions to replacements, which will be run on the
/// resulting word before it gets returned.  The purpose of replacements is to
/// address language subtleties that the phonetic builder is incapable of
/// understanding, such as 've' more pronounceable than just 'v' at the end of
/// a word, 'ey' more pronounceable than 'iy', etc.
/// @type {{}}

final REPLACEMENTS = [
  RegExp(r'quu'),
  RegExp(r'qu([ae])([ae])'),
  RegExp(r'[iu]y'),
  RegExp(r'eye'),
  RegExp(r'(.)ye$'),
  RegExp(r'(^|e)cie(?!$)'),
  RegExp(r'([vz])$'),
  RegExp(r'[iu]w'),
];

/// Adds a single syllable to the word contained in the wordObj.  A syllable
/// contains, at maximum, a phonetic from each the PRE, MID, and POST phonetic
/// sets.  Some syllables will omit pre or post based on the
/// options.compoundSimplicity.
///
/// @param {{word, numeric, lastSkippedPre, lastSkippedPost, opts}} wordObj The
///      word object on which to operate.
void addSyllable(WordObj wordObj) {
  final deriv = getDerivative(wordObj.numeric);
  final compound = deriv % wordObj.opts.compoundSimplicity == 0;
  final first = wordObj.word == '';
  final preOnFirst = deriv % 6 > 0;
  if ((first && preOnFirst) || wordObj.lastSkippedPost || compound) {
    wordObj.word += getNextPhonetic(PHONETIC_PRE, PHONETIC_PRE_SIMPLE_LENGTH, wordObj, false);
    wordObj.lastSkippedPre = false;
  } else {
    wordObj.lastSkippedPre = true;
  }
  wordObj.word += getNextPhonetic(PHONETIC_MID, PHONETIC_MID_SIMPLE_LENGTH, wordObj, first && wordObj.lastSkippedPre);
  if (wordObj.lastSkippedPre || compound) {
    wordObj.word += getNextPhonetic(PHONETIC_POST, PHONETIC_POST_SIMPLE_LENGTH, wordObj, false);
    wordObj.lastSkippedPost = false;
  } else {
    wordObj.lastSkippedPost = true;
  }
}

/// Gets a derivative of a number by repeatedly dividing it by 7 and adding the
/// remainders together.  It's useful to base decisions on a derivative rather
/// than the wordObj's current numeric, as it avoids making the same decisions
/// around the same phonetics.
///
/// @param {number} num A number from which a derivative should be calculated
/// @returns {number} The derivative.
getDerivative(int num) {
  int derivative = 1;
  while (num > 0) {
    derivative += num % 7;
    num = (num / 7).floor();
  }
  return derivative;
}

class Options {
  final int length;
  final Random randomSource;
  final int phoneticSimplicity;
  final int compoundSimplicity;

  Options({int? length, Random? randomSource, int? phoneticSimplicity, int? compoundSimplicity})
    : length = length ?? 16,
      randomSource = randomSource ?? Random.secure(),
      phoneticSimplicity = phoneticSimplicity ?? 5,
      compoundSimplicity = compoundSimplicity ?? 5;
}

/// Gets the next pseudo-random phonetic from a given phonetic set,
/// intelligently determining whether to include "complex" phonetics in that
/// set based on the options.phoneticSimplicity.
///
/// @param {Array} phoneticSet The array of phonetics from which to choose
/// @param {number} simpleCap The number of 'simple' phonetics at the beginning
///      of the phoneticSet
/// @param {{word, numeric, lastSkippedPre, lastSkippedPost, opts}} wordObj The
///      wordObj for which the phonetic is being chosen
/// @param {boolean} [forceSimple] true to force a simple phonetic to be
///      chosen; otherwise, the function will choose whether to include complex
///      phonetics based on the derivative of wordObj.numeric.
/// @returns {string} The chosen phonetic.
String getNextPhonetic(List<String> phoneticSet, int simpleCap, WordObj wordObj, bool forceSimple) {
  final deriv = getDerivative(wordObj.numeric);
  final simple = (wordObj.numeric + deriv) % wordObj.opts.phoneticSimplicity > 0;
  final cap = simple || forceSimple ? simpleCap : phoneticSet.length;
  final phonetic = phoneticSet[wordObj.numeric % cap];
  wordObj.numeric = getNumericHash(wordObj.numeric.toString() + wordObj.word);
  return phonetic;
}

/// Generates a numeric hash based on the input data.  The hash is an md5, with
/// each block of 32 bits converted to an integer and added together.
///
/// @param {string|number} data The string or number to be hashed.
/// @returns {number}
int getNumericHash(String data) {
  int numeric = 0;
  data += '-Phonetic';
  for (var i = 0, len = data.length; i < len; i++) {
    final chr = data.codeUnits[i];
    numeric = ((numeric << 5) - numeric) + chr;
    numeric >>= 0;
  }
  return numeric;
}

/// Applies post-processing to a word after it has already been generated.  In
/// this phase, the REPLACEMENTS are executed, applying language intelligence
/// that can make generated words more pronounceable.  The first letter is
/// also capitalized.
///
/// @param {{word, numeric, lastSkippedPre, lastSkippedPost, opts}} wordObj The
///      word object to be processed.
/// @returns {string} The processed word.
String postProcess(WordObj wordObj) {
  wordObj.word = wordObj.word.replaceAllMapped(REPLACEMENTS[0], (m) => 'que');
  wordObj.word = wordObj.word.replaceAllMapped(REPLACEMENTS[1], (m) => 'qu${m[2]}');
  wordObj.word = wordObj.word.replaceAllMapped(REPLACEMENTS[2], (m) => 'ey');
  wordObj.word = wordObj.word.replaceAllMapped(REPLACEMENTS[3], (m) => 'ye');
  wordObj.word = wordObj.word.replaceAllMapped(REPLACEMENTS[4], (m) => '${m[1]}y');
  wordObj.word = wordObj.word.replaceAllMapped(REPLACEMENTS[5], (m) => '${m[1]}cei');
  wordObj.word = wordObj.word.replaceAllMapped(REPLACEMENTS[6], (m) => '${m[1]}e');
  wordObj.word = wordObj.word.replaceAllMapped(REPLACEMENTS[7], (m) => 'ow');
  return wordObj.word;
}

class WordObj {
  int numeric;
  bool lastSkippedPost;
  bool lastSkippedPre;
  String word;
  final Options opts;

  WordObj({
    required this.numeric,
    required this.lastSkippedPost,
    required this.lastSkippedPre,
    required this.word,
    required this.opts,
  });
}

/// Generates a new word based on the given options.  For available options,
/// see getOptions.
///
/// @param {*} [options] A collection of options to control the word generator.
/// @returns {string} A generated word.
generate(Options options) {
  final length = options.length;
  final wordObj = WordObj(
    numeric: getNumericHash(options.randomSource.nextDouble().toString()),
    lastSkippedPost: false,
    lastSkippedPre: false,
    word: '',
    opts: options,
  );

  // Occasionally post processing will result in a slightly shorter string; we add two
  // extra syllables to help but can't guarantee that will be enough.
  while (wordObj.word.length < length + 2) {
    addSyllable(wordObj);
  }
  final postProcessed = postProcess(wordObj);
  return postProcessed.substring(0, min(postProcessed.length, length));
}
