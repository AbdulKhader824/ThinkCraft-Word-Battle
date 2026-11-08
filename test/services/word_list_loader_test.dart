import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcraft_word_battle/models/category.dart';
import 'package:thinkcraft_word_battle/services/rules/word_check.dart';
import 'package:thinkcraft_word_battle/services/word_bank.dart';
import 'package:thinkcraft_word_battle/services/word_list_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WordList words;

  setUpAll(() async {
    words = await loadWordList(rootBundle);
  });

  // Everyday answers children type, in each category.
  const everyday = {
    Category.animal: ['Dog', 'Cat', 'Elephant', 'Tiger', 'Peacock', 'Cobra'],
    Category.place: ['India', 'Kerala', 'Kochi', 'Paris', 'Everest', 'Nile'],
    Category.person: ['Arjun', 'Priya', 'Aisha', 'Mohammed', 'Sharma'],
    Category.movie: ['Frozen', 'Baahubali', 'Drishyam', 'The Lion King'],
    Category.food: ['Mango', 'Dosa', 'Idli', 'Biryani', 'Pizza', 'Payasam'],
    Category.brand: ['Nike', 'Adidas', 'Amul', 'Samsung', 'Lego', 'Tata'],
    Category.bird: ['Peacock', 'Parrot', 'Crow', 'Eagle', 'Sparrow'],
    Category.celebrity: ['Mohanlal', 'Shah Rukh Khan', 'Virat Kohli'],
    Category.cartoon: ['Doraemon', 'Chhota Bheem', 'Mickey Mouse'],
    Category.vegetable: ['Carrot', 'Potato', 'Brinjal', 'Okra'],
    Category.flower: ['Rose', 'Lotus', 'Jasmine', 'Sunflower'],
    Category.thing: ['Chair', 'Pencil', 'Umbrella', 'Mobile phone'],
    Category.vehicle: ['Car', 'Bus', 'Auto rickshaw', 'Helicopter'],
    Category.sport: ['Cricket', 'Football', 'Kabaddi', 'Badminton'],
    Category.game: ['Chess', 'Ludo', 'Carrom', 'Minecraft'],
  };

  for (final MapEntry(key: category, value: answers) in everyday.entries) {
    test('knows everyday ${category.label.toLowerCase()} answers', () {
      for (final answer in answers) {
        expect(words.contains(category, answer), isTrue, reason: answer);
      }
    });
  }

  test('plurals and capitals of real answers are found', () {
    expect(words.contains(Category.animal, 'TIGERS'), isTrue);
    expect(words.contains(Category.food, 'mangoes'), isTrue);
  });

  test('nonsense and answers in the wrong category are not', () {
    expect(words.contains(Category.animal, 'Blorptastic'), isFalse);
    expect(words.contains(Category.food, 'Elephant'), isFalse);
    expect(words.contains(Category.brand, 'Qwzxv'), isFalse);
  });

  test("the bots' own answers always count", () {
    for (final letter in WordBank.letters) {
      for (final category in Category.values) {
        for (final answer in WordBank.wordsFor(letter, category)) {
          expect(words.contains(category, answer), isTrue, reason: answer);
        }
      }
    }
  });

  test('every category has a big list', () {
    final list = words as SetWordList;
    for (final category in Category.values) {
      // The classic six are big; newer ones, such as Thing, are smaller.
      final minimum = Category.defaults.contains(category) ? 5000 : 150;
      expect(
        list.sizeOf(category),
        greaterThan(minimum),
        reason: category.name,
      );
    }
  });

  test('nothing unsuitable for children is in the list', () {
    const unsuitable = {
      Category.food: ['Vodka', 'Beer', 'Whisky'],
      Category.brand: ['Marlboro', 'Smirnoff', 'Budweiser'],
    };
    for (final MapEntry(key: category, value: answers) in unsuitable.entries) {
      for (final answer in answers) {
        expect(words.contains(category, answer), isFalse, reason: answer);
      }
    }
  });
}
