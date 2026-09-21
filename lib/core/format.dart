import 'package:intl/intl.dart';

class AppFormat {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  static String currency(num value) {
    return _currencyFormat.format(value);
  }

  static String dateTime(DateTime date) {
    return _dateFormat.format(date);
  }
}
