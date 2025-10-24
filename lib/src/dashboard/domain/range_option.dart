enum RangeOption {
  sevenDays(7, '7D'),
  thirtyDays(30, '30D'),
  ninetyDays(90, '90D');

  const RangeOption(this.days, this.label);

  final int days;
  final String label;
}
