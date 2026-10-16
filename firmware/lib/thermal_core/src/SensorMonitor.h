#pragma once

#include <stdint.h>

#include "ThermalTypes.h"

namespace kinecto {
namespace thermal {

// Tracks consecutive failed reads. A sensor is silent after missesBeforeSilent misses in a row.
class SensorMonitor {
 public:
  explicit SensorMonitor(uint8_t missesBeforeSilent);

  void record(TemperatureReading reading);
  bool isSilent() const;
  TemperatureReading latest() const;

 private:
  static bool isPlausible(TemperatureReading reading);

  uint8_t missesBeforeSilent_;
  uint8_t consecutiveMisses_;
  TemperatureReading latest_;
};

}  // namespace thermal
}  // namespace kinecto
