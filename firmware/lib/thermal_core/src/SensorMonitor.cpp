#include "SensorMonitor.h"

#include <math.h>

#include "ThermalConfig.h"

namespace kinecto {
namespace thermal {

SensorMonitor::SensorMonitor(uint8_t missesBeforeSilent)
    : missesBeforeSilent_(missesBeforeSilent > 0 ? missesBeforeSilent : 1),
      consecutiveMisses_(0),
      latest_(failedReading()) {}

void SensorMonitor::record(TemperatureReading reading) {
  if (!isPlausible(reading)) {
    latest_ = failedReading();
    if (consecutiveMisses_ < missesBeforeSilent_) {
      consecutiveMisses_++;
    }
    return;
  }
  latest_ = reading;
  consecutiveMisses_ = 0;
}

bool SensorMonitor::isSilent() const { return consecutiveMisses_ >= missesBeforeSilent_; }

TemperatureReading SensorMonitor::latest() const { return latest_; }

bool SensorMonitor::isPlausible(TemperatureReading reading) {
  return reading.valid && !isnan(reading.celsius) && reading.celsius >= kMinPlausibleC &&
         reading.celsius <= kMaxPlausibleC;
}

}  // namespace thermal
}  // namespace kinecto
