import '../l10n/strings.dart';

class ReportService {
  final String locale;
  ReportService(this.locale);

  String tr(String key) => S.t(key, locale);

  String exportSalesPdfHeader() => tr('salesReport');

  String exportStockPdfHeader() => tr('stockReport');

  String exportCsvSalesTitle() => 'Date,Total,Items';

  String exportCsvProductsTitle() => 'ID,Nom,DCI,Prix Stock';
}