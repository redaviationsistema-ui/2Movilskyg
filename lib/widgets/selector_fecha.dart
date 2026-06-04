import 'package:flutter/material.dart';

class DateSelector extends StatelessWidget {
  final DateTime? date;
  final String label;
  final Function(DateTime) onSelect;

  const DateSelector({
    super.key,
    required this.date,
    required this.label,
    required this.onSelect,
  });

  Future pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      onSelect(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(date == null ? label : date.toString()),

      trailing: const Icon(Icons.calendar_today),

      onTap: () => pickDate(context),
    );
  }
}
