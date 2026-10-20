import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_maroc_gold/core/utils/validators.dart';

void main() {
  group('validateurs de formulaire partagés', () {
    test('validateRequired : vide ou espaces => message', () {
      expect(validateRequired(null, 'req'), 'req');
      expect(validateRequired('', 'req'), 'req');
      expect(validateRequired('   ', 'req'), 'req');
      expect(validateRequired('Doliprane', 'req'), isNull);
    });

    test('validatePhone : optionnel, format vérifié si renseigné', () {
      expect(validatePhone(null, 'ph'), isNull);
      expect(validatePhone('', 'ph'), isNull);
      expect(validatePhone('0612345678', 'ph'), isNull);
      expect(validatePhone('+212 6 61 23 45 67', 'ph'), isNull);
      expect(validatePhone('0522-123 456', 'ph'), isNull);
      expect(validatePhone('abc', 'ph'), 'ph');
      expect(validatePhone('12', 'ph'), 'ph');
    });

    test('validateEmail : optionnel, format vérifié si renseigné', () {
      expect(validateEmail(null, 'em'), isNull);
      expect(validateEmail('', 'em'), isNull);
      expect(validateEmail('a@b.co', 'em'), isNull);
      expect(validateEmail('pharma.client@gmail.com', 'em'), isNull);
      expect(validateEmail('pas-un-email', 'em'), 'em');
      expect(validateEmail('a@b', 'em'), 'em');
      expect(validateEmail('a @b.co', 'em'), 'em');
    });

    test('validateNonNegativeNumber : virgule française acceptée', () {
      expect(validateNonNegativeNumber(null, 'nb'), isNull);
      expect(validateNonNegativeNumber('', 'nb'), isNull);
      expect(validateNonNegativeNumber('10', 'nb'), isNull);
      expect(validateNonNegativeNumber('10,5', 'nb'), isNull);
      expect(validateNonNegativeNumber('0', 'nb'), isNull);
      expect(validateNonNegativeNumber('-1', 'nb'), 'nb');
      expect(validateNonNegativeNumber('abc', 'nb'), 'nb');
    });
  });
}
