import 'package:flutter_test/flutter_test.dart';
import 'package:kinecto_care/core/app_strings.dart';
import 'package:kinecto_care/features/home/presentation/widgets/home_header.dart';

void main() {
  test('hero line follows the number of open faults', () {
    expect(HomeHeader.heroLine(0), AppStrings.heroAllGood);
    expect(HomeHeader.heroLine(1), AppStrings.heroOneFault);
    expect(HomeHeader.heroLine(3), AppStrings.heroFaults(3));
  });
}
