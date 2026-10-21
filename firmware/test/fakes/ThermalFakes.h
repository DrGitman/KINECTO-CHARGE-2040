#pragma once

#include <stddef.h>
#include <stdint.h>

#include "Ports.h"

namespace kinecto {
namespace thermal {
namespace testing {

class FakeSensor : public ITemperatureSensor {
 public:
  TemperatureReading read() override { return next; }
  void set(float celsius) { next = validReading(celsius); }
  void fail() { next = failedReading(); }

  TemperatureReading next = validReading(20.0f);
};

// Records every output call and flags any moment where both loads were ON.
class FakeLoads : public ILoadOutputs {
 public:
  void setHeater(bool on) override {
    heaterOn = on;
    check();
  }
  void setBlower(bool on) override {
    blowerOn = on;
    check();
  }

  bool heaterOn = false;
  bool blowerOn = false;
  bool bothEverOn = false;

 private:
  void check() { bothEverOn = bothEverOn || (heaterOn && blowerOn); }
};

class FakeEvents : public IEventSink {
 public:
  static constexpr size_t kCapacity = 32;

  void publish(const ThermalEvent& event) override {
    if (count < kCapacity) events[count] = event;
    count++;
  }
  const ThermalEvent& last() const { return events[count - 1]; }

  ThermalEvent events[kCapacity] = {};
  size_t count = 0;
};

class FakeClock : public IClock {
 public:
  uint32_t uptimeMs() override { return nowMs; }
  int64_t epochSeconds() override { return epoch; }

  uint32_t nowMs = 0;
  int64_t epoch = 1792049400;
};

class FakeLogger : public ILogger {
 public:
  void info(const char*, const char*) override { infoCount++; }
  void warn(const char*, const char*) override { warnCount++; }

  int infoCount = 0;
  int warnCount = 0;
};

}  // namespace testing
}  // namespace thermal
}  // namespace kinecto
