import 'package:flutter/material.dart';

/// NUST navy and gold palette from the App UI boards 04 and 04b.
// Values sampled from the hi-fi export until the board 01 tokens are available.
abstract final class AppColors {
  static const Color navy = Color(0xFF0B2545);
  static const Color gold = Color(0xFFF2A900);
  static const Color alert = Color(0xFFC0392B);

  static const Color pageLight = Color(0xFFF4F6FB);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color pageDark = Color(0xFF0E1526);
  static const Color cardDark = Color(0xFF1A2338);
  static const Color tabBar = Color(0xFF111318);
  static const Color tabPill = Color(0xFFFFFFFF);

  // One pastel per subsystem, shared by tiles, logs and the admin desk.
  static const Color energyTile = Color(0xFFFBEAA0);
  static const Color comfortTile = Color(0xFFD9D3FB);
  static const Color cuffTile = Color(0xFFC9EEF2);
  static const Color faultTile = Color(0xFFFBD0E6);
  static const Color okTile = Color(0xFFCFF2D6);
}
