#pragma once

#include <stdint.h>

#include "Ports.h"

namespace kinecto {

class GpioLoadOutputs : public thermal::ILoadOutputs {
 public:
  GpioLoadOutputs(uint8_t heaterPin, uint8_t blowerPin);

  void begin();
  void setHeater(bool on) override;
  void setBlower(bool on) override;

 private:
  uint8_t heaterPin_;
  uint8_t blowerPin_;
};

}  // namespace kinecto
