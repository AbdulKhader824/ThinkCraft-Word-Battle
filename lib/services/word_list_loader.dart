import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';

import '../models/category.dart';
import 'rules/word_check.dart';
import 'word_bank.dart';

/// The word list's files, one per category, made by
/// `tool/build_word_list.py`.
String wordListAsset(Category category) => 'assets/words/${category.name}.txt';

/// Loads the word list from the app's files.
///
/// Reading the files is quick; turning tens of thousands of lines into
/// match keys isn't, so [compute] does that on a background isolate, where
/// it can't make the screen stutter.
Future<WordList> loadWordList(AssetBundle bundle) async {
  final texts = <String, String>{
    for (final category in Category.values)
      category.name: await _loadOrEmpty(bundle, wordListAsset(category)),
  };
  return compute(_buildWordList, texts);
}

/// A category without a word file yet still works: its answers are
/// simply voted on.
Future<String> _loadOrEmpty(AssetBundle bundle, String asset) async {
  try {
    return await bundle.loadString(asset);
  } on Object {
    return '';
  }
}

SetWordList _buildWordList(Map<String, String> texts) {
  return SetWordList({
    for (final category in Category.values)
      category: [
        ...texts[category.name]!.split('\n'),
        // The bots' own answers always count.
        for (final letter in WordBank.letters)
          ...WordBank.wordsFor(letter, category),
      ],
  });
}
