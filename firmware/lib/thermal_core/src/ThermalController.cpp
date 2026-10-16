#include "ThermalController.h"

#include <stdio.h>

namespace kinecto {
namespace thermal {

namespace {
constexpr const char* kLogModule = "thermal";
constexpr size_t kLogBufferSize = 96;
}  // namespace

ThermalController::ThermalController(const ControllerDependencies& deps,
                                     const ThermalLimits& limits, uint8_t missesBeforeSilent)
    : insideSensor_(deps.insideSensor),
      ambientSensor_(deps.ambientSensor),
      loadOutputs_(deps.loads),
      events_(deps.events),
      clock_(deps.clock),
      logger_(deps.logger),
      limits_(limits),
      limitsValid_(isValid(limits)),
      insideMonitor_(missesBeforeSilent),
      ambientMonitor_(missesBeforeSilent),
      state_(State::Off),
      fault_(Fault::None),
      loads_(kAllLoadsOff) {}

void ThermalController::start() {
  loadOutputs_.setHeater(false);
  loadOutputs_.setBlower(false);
  loads_ = kAllLoadsOff;
  state_ = State::Off;
  fault_ = Fault::None;

  if (!limitsValid_) {
    logger_.warn(kLogModule, "invalid limits, loads locked off");
  }
  readSensors();
  publish(Reason::PowerOn);
}

void ThermalController::tick() {
  readSensors();
  if (state_ == State::Fault || !limitsValid_) {
    return;
  }

  const Fault detected = detectFault();
  if (detected != Fault::None) {
    enterFault(detected);
    return;
  }

  // A single missed read holds the outputs. Three in a row trip FAULT above.
  const TemperatureReading inside = insideMonitor_.latest();
  if (inside.valid) {
    regulate(inside.celsius);
  }
}

void ThermalController::handleButton(ButtonAction action) {
  if (action == ButtonAction::None || !limitsValid_) {
    return;
  }
  if (state_ == State::Fault) {
    if (action == ButtonAction::ShortPress) {
      tryClearFault();
    }
    return;
  }
  if (action == ButtonAction::Hold2s) {
    if (state_ != State::Off) {
      changeMode(State::Off, Reason::ModeHold2s);
    }
    return;
  }
  changeMode(nextMode(state_), Reason::ModeButton);
}

void ThermalController::readSensors() {
  insideMonitor_.record(insideSensor_.read());
  ambientMonitor_.record(ambientSensor_.read());
}

Fault ThermalController::detectFault() const {
  if (insideMonitor_.isSilent()) {
    return Fault::InsideSensorSilent;
  }
  if (ambientMonitor_.isSilent()) {
    return Fault::AmbientSensorSilent;
  }
  const TemperatureReading inside = insideMonitor_.latest();
  if (inside.valid && inside.celsius >= limits_.cutoffC) {
    return Fault::HeaterOverLimit;
  }
  return Fault::None;
}

void ThermalController::enterFault(Fault fault) {
  const State previous = state_;
  state_ = State::Fault;
  fault_ = fault;
  driveLoads(kAllLoadsOff);

  char message[kLogBufferSize];
  snprintf(message, sizeof(message), "FAULT %s from %s, loads forced off", toString(fault),
           toString(previous));
  logger_.warn(kLogModule, message);

  publish(fault == Fault::HeaterOverLimit ? Reason::OverCutoff : Reason::SensorError);
}

void ThermalController::tryClearFault() {
  const Fault stillActive = detectFault();
  if (stillActive != Fault::None) {
    char message[kLogBufferSize];
    snprintf(message, sizeof(message), "fault clear refused, %s still active",
             toString(stillActive));
    logger_.warn(kLogModule, message);
    return;
  }
  state_ = State::Off;
  fault_ = Fault::None;
  logger_.info(kLogModule, "fault cleared by MODE button, state OFF");
  publish(Reason::FaultClearedModeButton);
}

void ThermalController::changeMode(State next, Reason reason) {
  state_ = next;
  driveLoads(loadsAllowedIn(next, loads_));
  publish(reason);
}

void ThermalController::regulate(float insideC) {
  LoadState next = loads_;
  Reason reason = Reason::ModeButton;
  bool changed = false;

  switch (state_) {
    case State::Auto: changed = regulateAuto(insideC, next, reason); break;
    case State::Cool: changed = regulateCool(next, reason); break;
    case State::Warm: changed = regulateWarm(insideC, next, reason); break;
    case State::Off:
    case State::Fault: break;
  }

  if (changed) {
    driveLoads(next);
    publish(reason);
  }
}

bool ThermalController::regulateAuto(float insideC, LoadState& next, Reason& reason) const {
  if (loads_.heaterOn) {
    if (insideC >= limits_.warmBelowC + limits_.hysteresisC) {
      next.heaterOn = false;
      reason = Reason::AutoHeatOff;
      return true;
    }
    return false;
  }
  if (loads_.blowerOn) {
    if (insideC <= limits_.coolAboveC - limits_.hysteresisC) {
      next.blowerOn = false;
      reason = Reason::AutoCoolOff;
      return true;
    }
    return false;
  }
  if (insideC < limits_.warmBelowC) {
    next.heaterOn = true;
    reason = Reason::AutoHeatOn;
    return true;
  }
  if (insideC > limits_.coolAboveC) {
    next.blowerOn = true;
    reason = Reason::AutoCoolOn;
    return true;
  }
  return false;
}

bool ThermalController::regulateCool(LoadState& next, Reason& reason) const {
  if (loads_.blowerOn) {
    return false;
  }
  next.blowerOn = true;
  reason = Reason::CoolBlowerOn;
  return true;
}

bool ThermalController::regulateWarm(float insideC, LoadState& next, Reason& reason) const {
  if (loads_.heaterOn && insideC >= limits_.warmMaxC) {
    next.heaterOn = false;
    reason = Reason::WarmHeatOff;
    return true;
  }
  if (!loads_.heaterOn && insideC < limits_.warmMaxC - limits_.hysteresisC) {
    next.heaterOn = true;
    reason = Reason::WarmHeatOn;
    return true;
  }
  return false;
}

// Safety gate for every output change: never both ON, and switch OFF before switching ON.
void ThermalController::driveLoads(LoadState requested) {
  if (requested.heaterOn && requested.blowerOn) {
    logger_.warn(kLogModule, "heater and blower both requested, forcing both off");
    requested = kAllLoadsOff;
  }
  if (!requested.heaterOn && loads_.heaterOn) loadOutputs_.setHeater(false);
  if (!requested.blowerOn && loads_.blowerOn) loadOutputs_.setBlower(false);
  if (requested.heaterOn && !loads_.heaterOn) loadOutputs_.setHeater(true);
  if (requested.blowerOn && !loads_.blowerOn) loadOutputs_.setBlower(true);
  loads_ = requested;
}

void ThermalController::publish(Reason reason) {
  const ThermalEvent event{clock_.epochSeconds(),    state_, reason, insideMonitor_.latest(),
                           ambientMonitor_.latest(), loads_, fault_};
  events_.publish(event);
}

State ThermalController::nextMode(State current) {
  switch (current) {
    case State::Off: return State::Auto;
    case State::Auto: return State::Cool;
    case State::Cool: return State::Warm;
    case State::Warm: return State::Off;
    case State::Fault: return State::Fault;
  }
  return State::Off;
}

LoadState ThermalController::loadsAllowedIn(State mode, LoadState current) {
  switch (mode) {
    case State::Auto: return current;
    case State::Cool: return LoadState{false, current.blowerOn};
    case State::Warm: return LoadState{current.heaterOn, false};
    case State::Off:
    case State::Fault: return kAllLoadsOff;
  }
  return kAllLoadsOff;
}

}  // namespace thermal
}  // namespace kinecto
