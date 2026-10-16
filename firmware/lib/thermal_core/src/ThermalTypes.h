#pragma once

#include <stdint.h>

namespace kinecto {
namespace thermal {

enum class State : uint8_t { Off, Auto, Cool, Warm, Fault };

enum class Reason : uint8_t {
  PowerOn,
  ModeButton,
  ModeHold2s,
  AutoHeatOn,
  AutoHeatOff,
  AutoCoolOn,
  AutoCoolOff,
  CoolBlowerOn,
  WarmHeatOn,
  WarmHeatOff,
  SensorError,
  OverCutoff,
  FaultClearedModeButton
};

enum class Fault : uint8_t { None, InsideSensorSilent, AmbientSensorSilent, HeaterOverLimit };

enum class ButtonAction : uint8_t { None, ShortPress, Hold2s };

struct TemperatureReading {
  bool valid;
  float celsius;
};

inline TemperatureReading validReading(float celsius) { return TemperatureReading{true, celsius}; }
inline TemperatureReading failedReading() { return TemperatureReading{false, 0.0f}; }

struct LoadState {
  bool heaterOn;
  bool blowerOn;
};

constexpr LoadState kAllLoadsOff{false, false};

inline bool operator==(const LoadState& a, const LoadState& b) {
  return a.heaterOn == b.heaterOn && a.blowerOn == b.blowerOn;
}
inline bool operator!=(const LoadState& a, const LoadState& b) { return !(a == b); }

struct ThermalEvent {
  int64_t epochSeconds;
  State state;
  Reason reason;
  TemperatureReading inside;
  TemperatureReading ambient;
  LoadState loads;
  Fault fault;
};

// Strings match the _allowed_values of docs/contracts/thermal.json.
const char* toString(State state);
const char* toString(Reason reason);
const char* toString(Fault fault);

}  // namespace thermal
}  // namespace kinecto
