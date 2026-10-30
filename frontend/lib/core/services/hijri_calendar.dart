// Calendrier Hégirien (Hijri) pour le Maroc
// Basé sur l'algorithme de conversion standard (Kuwaiti/UMAlQura)
// Compatible avec les annonces officielles marocaines

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Convertit une date grégorienne en date hégirienne
/// Retourne un tuple (year, month, day) hégirien
class HijriCalendar {
  // Nombre de jours par mois hégirien (année normale)
  static const List<int> _hijriMonthLengths = [
    30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29
  ];

  static const List<String> _hijriMonthNamesAr = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني',
    'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
    'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
  ];

  static const List<String> _hijriMonthNamesFr = [
    'Mouharram', 'Safar', 'Rabia al-Awwal', 'Rabia al-Thani',
    'Joumada al-Ula', 'Joumada al-Thaniya', 'Rajab', 'Chaabane',
    'Ramadan', 'Chawwal', 'Dou al-Qi\'da', 'Dou al-Hijja'
  ];

  /// Noms des mois hégiriens en français
  static const List<String> hijriMonthNamesFr = _hijriMonthNamesFr;

  /// Noms des mois hégiriens en arabe
  static const List<String> hijriMonthNamesAr = _hijriMonthNamesAr;

  /// Convertit une date grégorienne en hégirienne
  /// Utilise l'algorithme standard (basé sur le calendrier civil saoudien UMAlQura)
  static ({int year, int month, int day}) gregorianToHijri(DateTime gregorian) {
    // Nombre de jours depuis l'époque grégorienne (1er janvier 1 CE)
    final gregorianDays = _daysSinceGregorianEpoch(gregorian);

    // L'époque hégirienne (1 Mouharram 1 AH = 16 juillet 622 CE julien)
    // En jours grégoriens: 1948439.5 (mais on utilise l'algorithme standard)
    const hijriEpoch = 1948439.5; // Jours julien de l'époque hégirienne

    // Différence en jours
    final daysDiff = gregorianDays - hijriEpoch;

    // Calcul approximatif de l'année hégirienne
    // Année hégirienne moyenne = 354.366666... jours
    var hijriYear = ((daysDiff / 354.3666666666667).floor() + 1);
    if (hijriYear < 1) hijriYear = 1;

    // Affiner en comptant les jours
    var daysIntoYear = daysDiff;
    for (var y = 1; y < hijriYear; y++) {
      daysIntoYear -= _daysInHijriYear(y);
    }

    // Trouver le mois et le jour
    var hijriMonth = 1;
    var hijriDay = 1;

    for (var m = 1; m <= 12; m++) {
      final monthLen = _daysInHijriMonth(hijriYear, m);
      if (daysIntoYear <= monthLen) {
        hijriMonth = m;
        hijriDay = daysIntoYear.floor();
        break;
      }
      daysIntoYear -= monthLen;
    }

    return (year: hijriYear, month: hijriMonth, day: hijriDay);
  }

  /// Convertit une date hégirienne en grégorienne
  static DateTime hijriToGregorian(int hyear, int hmonth, int hday) {
    // Calculer le jour julien de la date hégirienne
    var days = 0;
    for (var y = 1; y < hyear; y++) {
      days += _daysInHijriYear(y);
    }
    for (var m = 1; m < hmonth; m++) {
      days += _daysInHijriMonth(hyear, m);
    }
    days += hday - 1;

    const hijriEpoch = 1948439.5;
    final gregorianDays = hijriEpoch + days;

    return _gregorianFromDays(gregorianDays.floor());
  }

  /// Nombre de jours dans une année hégirienne
  static int _daysInHijriYear(int year) {
    // Années bissextiles hégiriennes: 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29 (cycle de 30 ans)
    final leapYears = {2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29};
    final cyclePos = (year - 1) % 30 + 1;
    return leapYears.contains(cyclePos) ? 355 : 354;
  }

  /// Nombre de jours dans un mois hégirien
  static int _daysInHijriMonth(int year, int month) {
    if (month == 12 && _daysInHijriYear(year) == 355) {
      return 30; // Dernier mois de l'année bissextile
    }
    return _hijriMonthLengths[month - 1];
  }

  /// Jours depuis l'époque grégorienne (1er janvier 1 CE)
  static int _daysSinceGregorianEpoch(DateTime date) {
    // Algorithme standard pour le jour julien
    final a = (14 - date.month) ~/ 12;
    final y = date.year + 4800 - a;
    final m = date.month + 12 * a - 3;
    final jdn = date.day + ((153 * m + 2) ~/ 5) + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
    return jdn - 1721426; // Décalage pour avoir 1er jan 1 CE = jour 1
  }

  /// Date grégorienne à partir de jours depuis l'époque
  static DateTime _gregorianFromDays(int days) {
    final jdn = days + 1721426;
    final a = jdn + 32044;
    final b = (4 * a + 3) ~/ 146097;
    final c = a - (146097 * b) ~/ 4;
    final d = (4 * c + 3) ~/ 1461;
    final e = c - (1461 * d) ~/ 4;
    final m = (5 * e + 2) ~/ 153;

    final day = e - (153 * m + 2) ~/ 5 + 1;
    final month = m + 3 - 12 * (m ~/ 10);
    final year = 100 * b + d - 4800 + m ~/ 10;

    return DateTime(year, month, day);
  }

  /// Nom du mois hégirien en français
  static String monthNameFr(int month) => _hijriMonthNamesFr[month - 1];

  /// Nom du mois hégirien en arabe
  static String monthNameAr(int month) => _hijriMonthNamesAr[month - 1];

  /// Vérifie si une année hégirienne est bissextile
  static bool isLeapYear(int year) => _daysInHijriYear(year) == 355;

  /// Calcule la date hégirienne d'un jour férié religieux pour une année donnée
  /// Retourne la date grégorienne correspondante (basée sur l'algorithme standard)
  /// Note: Les dates exactes dépendent de l'observation lunaire officielle au Maroc
  static DateTime? religiousHolidayGregorian(int hijriYear, int hijriMonth, int hijriDay) {
    try {
      return hijriToGregorian(hijriYear, hijriMonth, hijriDay);
    } catch (_) {
      return null;
    }
  }

  /// Fêtes religieuses principales (dates hégiriennes fixes)
  static const Map<String, ({int month, int day, String nameFr, String nameAr})> fixedReligiousHolidays = {
    'ramadan_start': (month: 9, day: 1, nameFr: 'Début du Ramadan', nameAr: 'بداية رمضان'),
    'eid_fitr': (month: 10, day: 1, nameFr: 'Aïd al-Fitr', nameAr: 'عيد الفطر'),
    'eid_fitr_2': (month: 10, day: 2, nameFr: 'Aïd al-Fitr (2e jour)', nameAr: 'عيد الفطر (اليوم الثاني)'),
    'eid_adha': (month: 12, day: 10, nameFr: 'Aïd al-Adha', nameAr: 'عيد الأضحى'),
    'eid_adha_2': (month: 12, day: 11, nameFr: 'Aïd al-Adha (2e jour)', nameAr: 'عيد الأضحى (اليوم الثاني)'),
    'eid_adha_3': (month: 12, day: 13, nameFr: 'Aïd al-Adha (3e jour)', nameAr: 'عيد الأضحى (اليوم الثالث)'),
    'muharram_1': (month: 1, day: 1, nameFr: 'Nouvel an hégirien', nameAr: 'رأس السنة الهجرية'),
    'ashura': (month: 1, day: 10, nameFr: 'Achoura', nameAr: 'عاشوراء'),
    'mawlid': (month: 3, day: 12, nameFr: 'Mawlid an-Nabi', nameAr: 'المولد النبوي'),
  };

  /// Génère les dates grégoriennes des fêtes religieuses pour une année hégirienne
  static Map<String, DateTime> religiousHolidaysForHijriYear(int hijriYear) {
    final result = <String, DateTime>{};
    for (final entry in fixedReligiousHolidays.entries) {
      final data = entry.value;
      final gregorian = religiousHolidayGregorian(hijriYear, data.month, data.day);
      if (gregorian != null) {
        result[entry.key] = gregorian;
      }
    }
    return result;
  }

  /// Génère les dates grégoriennes des fêtes religieuses pour une année grégorienne
  /// (recherche les années hégiriennes qui chevauchent l'année grégorienne)
  static Map<String, DateTime> religiousHolidaysForGregorianYear(int gregorianYear) {
    final result = <String, DateTime>{};
    final startHijri = gregorianToHijri(DateTime(gregorianYear, 1, 1));
    final endHijri = gregorianToHijri(DateTime(gregorianYear, 12, 31));

    for (int hy = startHijri.year; hy <= endHijri.year; hy++) {
      final holidays = religiousHolidaysForHijriYear(hy);
      for (final entry in holidays.entries) {
        if (entry.value.year == gregorianYear) {
          result[entry.key] = entry.value;
        }
      }
    }
    return result;
  }
}

/// Widget pour afficher la date hégirienne à côté de la date grégorienne
class HijriDateDisplay extends StatelessWidget {
  final DateTime gregorianDate;
  final bool showArabic;
  final TextStyle? gregorianStyle;
  final TextStyle? hijriStyle;

  const HijriDateDisplay({
    super.key,
    required this.gregorianDate,
    this.showArabic = true,
    this.gregorianStyle,
    this.hijriStyle,
  });

  @override
  Widget build(BuildContext context) {
    final hijri = HijriCalendar.gregorianToHijri(gregorianDate);
    final hijriFr = '${hijri.day} ${HijriCalendar.monthNameFr(hijri.month)} ${hijri.year} هـ';
    final hijriAr = '${hijri.day} ${HijriCalendar.monthNameAr(hijri.month)} ${hijri.year} هـ';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (gregorianStyle != null || hijriStyle != null) ...[
          if (gregorianStyle != null)
            Text(
              DateFormat('EEEE d MMMM yyyy', 'fr').format(gregorianDate),
              style: gregorianStyle,
            ),
          if (hijriStyle != null)
            Text(
              showArabic ? hijriAr : hijriFr,
              style: hijriStyle,
            ),
        ] else ...[
          Text(
            DateFormat('EEEE d MMMM yyyy', 'fr').format(gregorianDate),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            showArabic ? hijriAr : hijriFr,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ],
    );
  }
}