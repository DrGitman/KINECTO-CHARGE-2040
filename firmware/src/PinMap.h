#pragma once

#include <stdint.h>

// Mirrors docs/contracts/pinmap.md. Keep both in sync.
namespace kinecto {
namespace pins {

constexpr uint8_t kI2cSda = 6;
constexpr uint8_t kI2cScl = 7;
constexpr uint8_t kHeaterGate = 5;
constexpr uint8_t kBlowerGate = 10;
constexpr uint8_t kModeButton = 4;
constexpr uint8_t kStatusLed = 8;

constexpr uint8_t kTmp117InsideAddress = 0x48;
constexpr uint8_t kTmp117AmbientAddress = 0x49;

}  // namespace pins
}  // namespace kinecto
