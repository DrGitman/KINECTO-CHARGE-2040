#include "GpioLoadOutputs.h"

#include <Arduino.h>

namespace kinecto {

GpioLoadOutputs::GpioLoadOutputs(uint8_t heaterPin, uint8_t blowerPin)
    : heaterPin_(heaterPin), blowerPin_(blowerPin) {}

// Drive LOW before switching to output so the gates never float high at boot.
void GpioLoadOutputs::begin() {
  digitalWrite(heaterPin_, LOW);
  digitalWrite(blowerPin_, LOW);
  pinMode(heaterPin_, OUTPUT);
  pinMode(blowerPin_, OUTPUT);
}

void GpioLoadOutputs::setHeater(bool on) { digitalWrite(heaterPin_, on ? HIGH : LOW); }

void GpioLoadOutputs::setBlower(bool on) { digitalWrite(blowerPin_, on ? HIGH : LOW); }

}  // namespace kinecto
