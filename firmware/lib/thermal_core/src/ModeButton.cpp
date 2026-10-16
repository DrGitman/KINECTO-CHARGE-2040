#include "ModeButton.h"

namespace kinecto {
namespace thermal {

ModeButton::ModeButton(uint32_t debounceMs, uint32_t holdMs)
    : debounceMs_(debounceMs),
      holdMs_(holdMs),
      lastRaw_(false),
      stablePressed_(false),
      holdReported_(false),
      lastRawChangeMs_(0),
      pressStartMs_(0) {}

ButtonAction ModeButton::update(bool pressed, uint32_t nowMs) {
  if (pressed != lastRaw_) {
    lastRaw_ = pressed;
    lastRawChangeMs_ = nowMs;
  }

  // Unsigned subtraction keeps working across the millis() wrap.
  const bool settled = nowMs - lastRawChangeMs_ >= debounceMs_;
  if (pressed != stablePressed_ && settled) {
    stablePressed_ = pressed;
    if (pressed) {
      pressStartMs_ = nowMs;
      holdReported_ = false;
      return ButtonAction::None;
    }
    return holdReported_ ? ButtonAction::None : ButtonAction::ShortPress;
  }

  if (stablePressed_ && !holdReported_ && nowMs - pressStartMs_ >= holdMs_) {
    holdReported_ = true;
    return ButtonAction::Hold2s;
  }
  return ButtonAction::None;
}

}  // namespace thermal
}  // namespace kinecto
