#include "EventFormatter.h"

#include <stdio.h>
#include <time.h>

namespace kinecto {
namespace thermal {

namespace {

constexpr size_t kTimestampSize = sizeof("2026-10-15T07:30:00Z");
constexpr size_t kNumberFieldSize = 16;
constexpr size_t kQuotedFieldSize = 32;

bool formatTimestamp(int64_t epochSeconds, char* out, size_t size) {
  const time_t seconds = static_cast<time_t>(epochSeconds);
  struct tm utc;
  if (gmtime_r(&seconds, &utc) == nullptr) {
    return false;
  }
  return strftime(out, size, "%Y-%m-%dT%H:%M:%SZ", &utc) > 0;
}

void formatTemperature(TemperatureReading reading, char* out, size_t size) {
  if (reading.valid) {
    snprintf(out, size, "%.1f", static_cast<double>(reading.celsius));
  } else {
    snprintf(out, size, "null");
  }
}

void formatFault(Fault fault, char* out, size_t size) {
  const char* name = toString(fault);
  if (name == nullptr) {
    snprintf(out, size, "null");
  } else {
    snprintf(out, size, "\"%s\"", name);
  }
}

const char* toJson(bool value) { return value ? "true" : "false"; }

}  // namespace

size_t formatEventJson(const ThermalEvent& event, char* buffer, size_t bufferSize) {
  if (buffer == nullptr || bufferSize == 0) {
    return 0;
  }

  char timestamp[kTimestampSize];
  char inside[kNumberFieldSize];
  char ambient[kNumberFieldSize];
  char fault[kQuotedFieldSize];
  if (!formatTimestamp(event.epochSeconds, timestamp, sizeof(timestamp))) {
    buffer[0] = '\0';
    return 0;
  }
  formatTemperature(event.inside, inside, sizeof(inside));
  formatTemperature(event.ambient, ambient, sizeof(ambient));
  formatFault(event.fault, fault, sizeof(fault));

  const int written = snprintf(
      buffer, bufferSize,
      "{\"ts\":\"%s\",\"state\":\"%s\",\"reason\":\"%s\",\"inside_c\":%s,\"ambient_c\":%s,"
      "\"heater_on\":%s,\"blower_on\":%s,\"fault\":%s}",
      timestamp, toString(event.state), toString(event.reason), inside, ambient,
      toJson(event.loads.heaterOn), toJson(event.loads.blowerOn), fault);

  if (written < 0 || static_cast<size_t>(written) >= bufferSize) {
    buffer[0] = '\0';
    return 0;
  }
  return static_cast<size_t>(written);
}

}  // namespace thermal
}  // namespace kinecto
