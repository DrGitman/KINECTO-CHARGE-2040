#pragma once

#include <stdint.h>

#include "ThermalTypes.h"

namespace kinecto {
namespace thermal {

class ITemperatureSensor {
 public:
  virtual ~ITemperatureSensor() = default;
  virtual TemperatureReading read() = 0;
};

class ILoadOutputs {
 public:
  virtual ~ILoadOutputs() = default;
  virtual void setHeater(bool on) = 0;
  virtual void setBlower(bool on) = 0;
};

class IEventSink {
 public:
  virtual ~IEventSink() = default;
  virtual void publish(const ThermalEvent& event) = 0;
};

class IClock {
 public:
  virtual ~IClock() = default;
  virtual uint32_t uptimeMs() = 0;
  virtual int64_t epochSeconds() = 0;
};

class ILogger {
 public:
  virtual ~ILogger() = default;
  virtual void info(const char* module, const char* message) = 0;
  virtual void warn(const char* module, const char* message) = 0;
};

}  // namespace thermal
}  // namespace kinecto
