import 'package:intl/intl.dart';

class AppFormat {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  static final _onlyDateFormat = DateFormat('dd MMM yyyy', 'id_ID');

  static String currency(num value) {
    return _currencyFormat.format(value);
  }

  static String dateTime(DateTime date) {
    return _dateFormat.format(date);
  }

  static String date(DateTime date) {
    return _onlyDateFormat.format(date);
  }

  static final _sqlDateFormat = DateFormat('yyyy-MM-dd');
  static String dateSql(DateTime date) {
    return _sqlDateFormat.format(date);
  }
}
