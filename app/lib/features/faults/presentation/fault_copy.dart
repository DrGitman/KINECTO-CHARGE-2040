import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/fault.dart';

/// Wearer-facing text for each fault. Comfort wording only.
class FaultCopy {
  const FaultCopy({
    required this.shortTitle,
    required this.title,
    required this.whatHappened,
    required this.whatWeDid,
    required this.whatToDo,
  });

  final String shortTitle;
  final String title;
  final String whatHappened;
  final String whatWeDid;
  final String whatToDo;

  static const String _loggedForFabLab =
      'Kinecto saved the readings so the FabLab can see what happened.';

  static FaultCopy of(FaultCode code) => switch (code) {
    FaultCode.insideSensorSilent => const FaultCopy(
      shortTitle: 'Inside sensor offline',
      title: 'Inside temperature sensor is not responding',
      whatHappened:
          'The inside sensor stopped sending readings, so Auto mode can\'t tell how warm you are.',
      whatWeDid:
          'Heating and cooling were switched off for safety. The rest of your jacket still works.',
      whatToDo: 'Book a FabLab check.',
    ),
    FaultCode.heaterOverLimit => const FaultCopy(
      shortTitle: 'Heater over limit',
      title: 'Heater went over its safety limit',
      whatHappened:
          'The inside of your jacket got warmer than the safety limit.',
      whatWeDid:
          'The heater was switched off and stays off until you clear it.',
      whatToDo: 'Book a FabLab check before using Warm mode again.',
    ),
    FaultCode.blowerCurrentSpike => const FaultCopy(
      shortTitle: 'Blower current spike',
      title: 'Cooling fan drew too much power',
      whatHappened: 'The cooling fan drew much more current than usual.',
      whatWeDid: _loggedForFabLab,
      whatToDo: 'If cooling feels weak, book a FabLab check.',
    ),
    FaultCode.bufferNotCharging => const FaultCopy(
      shortTitle: 'Buffer not charging',
      title: 'Energy buffer is not charging',
      whatHappened:
          'You were moving, but the energy buffer did not gain any charge.',
      whatWeDid:
          'Nothing changes for your comfort: heating and cooling run on their own battery.',
      whatToDo: 'If it happens again, book a FabLab check.',
    ),
    FaultCode.batteryHot => const FaultCopy(
      shortTitle: 'Comfort battery hot',
      title: 'Comfort battery is too warm',
      whatHappened: 'The comfort battery in the pod got warmer than usual.',
      whatWeDid: _loggedForFabLab,
      whatToDo: 'Keep the jacket away from heat and book a FabLab check.',
    ),
    FaultCode.cuffTagUnreadable => const FaultCopy(
      shortTitle: 'Cuff tag unreadable',
      title: 'Cuff tag can\'t be read',
      whatHappened: 'The classroom reader could not read your cuff tag.',
      whatWeDid: 'Your lecturer can still mark you present by hand.',
      whatToDo: 'Book a FabLab check to replace the tag.',
    ),
  };

  static String subsystemLabel(FaultSubsystem subsystem) => switch (subsystem) {
    FaultSubsystem.energy => 'Energy',
    FaultSubsystem.thermal => 'Thermal',
    FaultSubsystem.cuff => 'Cuff',
    FaultSubsystem.pod => 'Pod',
  };

  static String statusLabel(FaultStatus status) => switch (status) {
    FaultStatus.open => 'Open',
    FaultStatus.watch => 'Watch',
    FaultStatus.fixed => 'Fixed',
  };

  static String sourceLabel(FaultSource source) => switch (source) {
    FaultSource.jacket => 'reported by your jacket',
    FaultSource.kinectoCheck => 'detected by Kinecto check',
  };
}

/// Colour and icon of a fault in the log: open faults are pink, others use their subsystem pastel.
abstract final class FaultStyle {
  static Color tileColor(Fault fault) => fault.isOpen
      ? AppColors.faultTile
      : switch (fault.subsystem) {
          FaultSubsystem.energy => AppColors.energyTile,
          FaultSubsystem.thermal => AppColors.comfortTile,
          FaultSubsystem.cuff => AppColors.cuffTile,
          FaultSubsystem.pod => AppColors.okTile,
        };

  static IconData icon(FaultSubsystem subsystem) => switch (subsystem) {
    FaultSubsystem.energy => Icons.bolt,
    FaultSubsystem.thermal => Icons.thermostat_outlined,
    FaultSubsystem.cuff => Icons.contactless_outlined,
    FaultSubsystem.pod => Icons.battery_charging_full,
  };
}
