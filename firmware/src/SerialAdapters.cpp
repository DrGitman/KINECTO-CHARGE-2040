#include "SerialAdapters.h"

#include "EventFormatter.h"

namespace kinecto {

namespace {
constexpr uint32_t kMsPerSecond = 1000;
}  // namespace

SerialEventSink::SerialEventSink(Print& out) : out_(out) {}

void SerialEventSink::publish(const thermal::ThermalEvent& event) {
  char line[thermal::kEventJsonMaxLength];
  if (thermal::formatEventJson(event, line, sizeof(line)) == 0) {
    out_.println("[WARN] events: event dropped, JSON line too long");
    return;
  }
  out_.println(line);
}

SerialLogger::SerialLogger(Print& out) : out_(out) {}

void SerialLogger::info(const char* module, const char* message) {
  write("INFO", module, message);
}

void SerialLogger::warn(const char* module, const char* message) {
  write("WARN", module, message);
}

void SerialLogger::write(const char* level, const char* module, const char* message) {
  out_.printf("[%s] %s: ", level, module);
  out_.println(message);
}

SimulatedClock::SimulatedClock(int64_t startEpochSeconds)
    : startEpochSeconds_(startEpochSeconds) {}

uint32_t SimulatedClock::uptimeMs() { return millis(); }

int64_t SimulatedClock::epochSeconds() { return startEpochSeconds_ + millis() / kMsPerSecond; }

}  // namespace kinecto
