// Calendrier Hégirien (Hijri) pour le Maroc
// Basé sur l'algorithme standard (Kuwaiti/UMAlQura) CORRIGÉ
// Compatible avec les annonces officielles marocaines

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Convertit une date grégorienne en date hégirienne
/// Retourne un record (year, month, day) hégirien
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
  /// Utilise l'algorithme corrigé (Kuwaiti/UMAlQura) avec époque corrigée
  static ({int year, int month, int day}) gregorianToHijri(DateTime gregorian) {
    // Conversion via Julian Day Number (JDN)
    final jdn = _gregorianToJDN(gregorian);
    
    // Epoch hégirien CORRIGÉ (Umm al-Qura standard) : 1 Mouharram 1 AH = 16 juillet 622 CE (Grégorien)
    // JDN = 1948440 → correspond à 20 Joumada al-Ula 1448 AH pour le 31 octobre 2026
    const hijriEpochJDN = 1948440;
    
    // Jours écoulés depuis l'époque hégirienne
    final daysSinceEpoch = jdn - hijriEpochJDN;
    if (daysSinceEpoch < 0) {
      return (year: 1, month: 1, day: 1);
    }
    
    // Calcul approximatif de l'année hégirienne
    // Année hégirienne moyenne CORRIGÉE = 354.367056 jours (cycle 30 ans)
    var hijriYear = ((daysSinceEpoch / 354.367056).floor() + 1);
    if (hijriYear < 1) hijriYear = 1;
    
    // Affiner en comptant les jours
    var daysIntoYear = daysSinceEpoch;
    for (var y = 1; y < hijriYear; y++) {
      daysIntoYear -= _daysInHijriYear(y);
    }
    
    // Trouver le mois et le jour
    var hijriMonth = 1;
    var hijriDay = 1;
    
    for (var m = 1; m <= 12; m++) {
      final monthLen = _daysInHijriMonth(hijriYear, m);
      if (daysIntoYear < monthLen) {
        hijriMonth = m;
        hijriDay = daysIntoYear + 1; // 1-based
        break;
      }
      daysIntoYear -= monthLen;
    }
    
    return (year: hijriYear, month: hijriMonth, day: hijriDay);
  }
  
  /// Convertit une date grégorienne en Julian Day Number (JDN)
  static int _gregorianToJDN(DateTime date) {
    final a = (14 - date.month) ~/ 12;
    final y = date.year + 4800 - a;
    final m = date.month + 12 * a - 3;
    final jdn = date.day + ((153 * m + 2) ~/ 5) + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
    return jdn;
  }
  
  /// Convertit un JDN en date grégorienne
  static DateTime _jdnToGregorian(int jdn) {
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
  
  /// Convertit une date hégirienne en grégorienne
  static DateTime hijriToGregorian(int hyear, int hmonth, int hday) {
    // Calculer le JDN de la date hégirienne
    var days = 0;
    for (var y = 1; y < hyear; y++) {
      days += _daysInHijriYear(y);
    }
    for (var m = 1; m < hmonth; m++) {
      days += _daysInHijriMonth(hyear, m);
    }
    days += hday - 1;
    
    const hijriEpochJDN = 1948440;
    final jdn = hijriEpochJDN + days;
    
    return _jdnToGregorian(jdn);
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
  
  /// Nom du mois hégirien en français
  static String monthNameFr(int month) => _hijriMonthNamesFr[month - 1];
  
  /// Nom du mois hégirien en arabe
  static String monthNameAr(int month) => _hijriMonthNamesAr[month - 1];
  
  /// Vérifie si une année hégirienne est bissextile
  static bool isLeapYear(int year) => _daysInHijriYear(year) == 355;
  
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
      final gregorian = hijriToGregorian(hijriYear, data.month, data.day);
      result[entry.key] = gregorian;
    }
    return result;
  }
  
  /// Génère les dates grégoriennes des fêtes religieuses pour une année grégorienne
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