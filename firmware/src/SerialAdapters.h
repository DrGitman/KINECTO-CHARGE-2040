#pragma once

#include <Arduino.h>

#include "Ports.h"

namespace kinecto {

// Event lines start with '{' and log lines with '[', so a host script can split them.
class SerialEventSink : public thermal::IEventSink {
 public:
  explicit SerialEventSink(Print& out);
  void publish(const thermal::ThermalEvent& event) override;

 private:
  Print& out_;
};

class SerialLogger : public thermal::ILogger {
 public:
  explicit SerialLogger(Print& out);
  void info(const char* module, const char* message) override;
  void warn(const char* module, const char* message) override;

 private:
  void write(const char* level, const char* module, const char* message);
  Print& out_;
};

// SIMULATED: no RTC or network time, so wall time starts from a fixed simulated date.
class SimulatedClock : public thermal::IClock {
 public:
  explicit SimulatedClock(int64_t startEpochSeconds);
  uint32_t uptimeMs() override;
  int64_t epochSeconds() override;

 private:
  int64_t startEpochSeconds_;
};

}  // namespace kinecto
