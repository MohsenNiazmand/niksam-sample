import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/features/tasks/domain/logic/task_validator.dart';

void main() {
  group('TaskValidator.validateTitle', () {
    test('returns TitleError.empty for empty string', () {
      expect(TaskValidator.validateTitle(''), equals(TitleError.empty));
    });

    test('returns TitleError.empty for whitespace-only string', () {
      expect(TaskValidator.validateTitle('   \t\n '), equals(TitleError.empty));
    });

    test('returns null for valid title at lower boundary (1 character)', () {
      expect(TaskValidator.validateTitle('a'), isNull);
      expect(TaskValidator.validateTitle('   a   '), isNull);
    });

    test('returns null for valid title at upper boundary (120 characters)', () {
      final title120 = 'a' * 120;
      expect(TaskValidator.validateTitle(title120), isNull);
      expect(TaskValidator.validateTitle('  $title120  '), isNull);
    });

    test('returns TitleError.tooLong for 121 characters', () {
      final title121 = 'a' * 121;
      expect(TaskValidator.validateTitle(title121), equals(TitleError.tooLong));
      expect(TaskValidator.validateTitle(' $title121 '), equals(TitleError.tooLong));
    });
  });
}
