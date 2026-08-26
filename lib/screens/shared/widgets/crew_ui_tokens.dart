import 'package:flutter/material.dart';

class CrewColors {
  const CrewColors._();

  static const Color navy = Color(0xFF062A43);
  static const Color navySecondary = Color(0xFF0B456B);
  static const Color primary = Color(0xFF0B63F6);
  static const Color gold = Color(0xFFE9BB58);

  static const Color success = Color(0xFF159A62);
  static const Color successSoft = Color(0xFFEAF8F1);
  static const Color danger = Color(0xFFE53935);
  static const Color dangerSoft = Color(0xFFFFF2F2);
  static const Color warning = Color(0xFFFF8A00);
  static const Color turquoise = Color(0xFF00A6A6);
  static const Color purple = Color(0xFF7C3AED);

  static const Color background = Color(0xFFF4F7FA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF082A45);
  static const Color textSecondary = Color(0xFF687386);
  static const Color line = Color(0xFFE1E8EF);
}

class CrewUi {
  const CrewUi._();

  static BorderRadius get cardRadius => BorderRadius.circular(20);

  static List<BoxShadow> get cardShadow => const [
    BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 10)),
  ];
}
