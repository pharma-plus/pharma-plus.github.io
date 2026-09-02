import 'package:intl/intl.dart';

/// Formatage monétaire (MAD) et de dates pour FR / AR / EN.
class Fmt {
  Fmt._();

  static String money(num value) {
    final formatted = NumberFormat.currency(
      locale: 'fr_MA',
      symbol: 'MAD',
      decimalDigits: value.roundToDouble() == value ? 0 : 2,
    ).format(value);
    return formatted;
  }

  static String number(num value, {int decimals = 0}) =>
      NumberFormat.decimalPatternDigits(
              locale: 'fr_MA', decimalDigits: decimals)
          .format(value);

  static String date(DateTime? date, {String locale = 'fr'}) {
    if (date == null) return '—';
    return DateFormat.yMMMMd(locale).format(date.toLocal());
  }

  static String shortDate(DateTime? date, {String locale = 'fr'}) {
    if (date == null) return '—';
    return DateFormat('dd/MM/yyyy', locale).format(date.toLocal());
  }

  static String time(DateTime? date) {
    if (date == null) return '—';
    return DateFormat.Hm().format(date.toLocal());
  }

  static String dateTime(DateTime? date, {String locale = 'fr'}) {
    if (date == null) return '—';
    return '${shortDate(date, locale: locale)} ${time(date)}';
  }

  static String percent(num value) => '${number(value, decimals: 1)} %';
}
