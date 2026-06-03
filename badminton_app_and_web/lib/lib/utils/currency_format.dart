class CurrencyFormat {
  CurrencyFormat._();

  static String number(num amount) {
    return amount.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  static String vnd(num amount) {
    return '${number(amount)} đ';
  }
}
