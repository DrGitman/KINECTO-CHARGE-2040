#include "ThermalTypes.h"

namespace kinecto {
namespace thermal {

const char* toString(State state) {
  switch (state) {
    case State::Off: return "OFF";
    case State::Auto: return "AUTO";
    case State::Cool: return "COOL";
    case State::Warm: return "WARM";
    case State::Fault: return "FAULT";
  }
  return "FAULT";
}

const char* toString(Reason reason) {
  switch (reason) {
    case Reason::PowerOn: return "power_on";
    case Reason::ModeButton: return "mode_button";
    case Reason::ModeHold2s: return "mode_hold_2s";
    case Reason::AutoHeatOn: return "auto_heat_on";
    case Reason::AutoHeatOff: return "auto_heat_off";
    case Reason::AutoCoolOn: return "auto_cool_on";
    case Reason::AutoCoolOff: return "auto_cool_off";
    case Reason::CoolBlowerOn: return "cool_blower_on";
    case Reason::WarmHeatOn: return "warm_heat_on";
    case Reason::WarmHeatOff: return "warm_heat_off";
    case Reason::SensorError: return "sensor_error";
    case Reason::OverCutoff: return "over_cutoff";
    case Reason::FaultClearedModeButton: return "fault_cleared_mode_button";
  }
  return "sensor_error";
}

// Returns nullptr for Fault::None, serialized as JSON null.
const char* toString(Fault fault) {
  switch (fault) {
    case Fault::None: return nullptr;
    case Fault::InsideSensorSilent: return "inside_sensor_silent";
    case Fault::AmbientSensorSilent: return "ambient_sensor_silent";
    case Fault::HeaterOverLimit: return "heater_over_limit";
  }
  return nullptr;
}

}  // namespace thermal
}  // namespace kinecto
