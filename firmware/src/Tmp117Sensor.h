#pragma once

#include <Wire.h>

#include "Ports.h"

namespace kinecto {

class Tmp117Sensor : public thermal::ITemperatureSensor {
 public:
  Tmp117Sensor(TwoWire& bus, uint8_t address);

  thermal::TemperatureReading read() override;

 private:
  bool readRegister(uint8_t reg, uint16_t& value);

  TwoWire& bus_;
  uint8_t address_;
};

}  // namespace kinecto
