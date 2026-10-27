import 'package:flutter/material.dart';

/// Padding for tab screens, leaving room for the floating tab bar.
abstract final class TabPage {
  static const double sidePadding = 20;
  static const double bottomInset = 104;

  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(
    sidePadding,
    16,
    sidePadding,
    bottomInset,
  );
}
