#pragma once

#include <stdint.h>

#include "Ports.h"
#include "SensorMonitor.h"
#include "ThermalConfig.h"
#include "ThermalTypes.h"

namespace kinecto {
namespace thermal {

struct ControllerDependencies {
  ITemperatureSensor& insideSensor;
  ITemperatureSensor& ambientSensor;
  ILoadOutputs& loads;
  IEventSink& events;
  IClock& clock;
  ILogger& logger;
};

// Thermal state machine. FAULT is checked first on every tick and always forces both loads OFF.
class ThermalController {
 public:
  ThermalController(const ControllerDependencies& deps, const ThermalLimits& limits,
                    uint8_t missesBeforeSilent);

  void start();
  void tick();
  void handleButton(ButtonAction action);

  State state() const { return state_; }
  LoadState loads() const { return loads_; }
  Fault fault() const { return fault_; }

 private:
  void readSensors();
  Fault detectFault() const;
  void enterFault(Fault fault);
  void tryClearFault();
  void changeMode(State next, Reason reason);
  void regulate(float insideC);
  bool regulateAuto(float insideC, LoadState& next, Reason& reason) const;
  bool regulateCool(LoadState& next, Reason& reason) const;
  bool regulateWarm(float insideC, LoadState& next, Reason& reason) const;
  void driveLoads(LoadState requested);
  void publish(Reason reason);

  static State nextMode(State current);
  static LoadState loadsAllowedIn(State mode, LoadState current);

  ITemperatureSensor& insideSensor_;
  ITemperatureSensor& ambientSensor_;
  ILoadOutputs& loadOutputs_;
  IEventSink& events_;
  IClock& clock_;
  ILogger& logger_;
  ThermalLimits limits_;
  bool limitsValid_;
  SensorMonitor insideMonitor_;
  SensorMonitor ambientMonitor_;
  State state_;
  Fault fault_;
  LoadState loads_;
};

}  // namespace thermal
}  // namespace kinecto
