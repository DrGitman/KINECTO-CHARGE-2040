import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);
