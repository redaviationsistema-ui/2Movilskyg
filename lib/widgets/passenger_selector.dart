import 'package:flutter/material.dart';

class PassengerSelector extends StatelessWidget {
  final int passengers;
  final Function(int) onChanged;

  const PassengerSelector({
    super.key,
    required this.passengers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text("Pasajeros"),

        const SizedBox(width: 20),

        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: () {
            if (passengers > 1) {
              onChanged(passengers - 1);
            }
          },
        ),

        Text(passengers.toString()),

        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            onChanged(passengers + 1);
          },
        ),
      ],
    );
  }
}
