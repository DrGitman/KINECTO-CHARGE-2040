// SIMULATED TMP117 for Wokwi: temperature, configuration and device ID registers over I2C.
#include "wokwi-api.h"

enum {
  ADDRESS_ADD0_GND = 0x48,
  ADDRESS_ADD0_VPLUS = 0x49,
};

enum {
  REG_TEMPERATURE = 0x00,
  REG_CONFIGURATION = 0x01,
  REG_DEVICE_ID = 0x0F,
};

static const uint16_t CONFIGURATION_RESET_VALUE = 0x0220;
static const uint16_t DEVICE_ID_VALUE = 0x0117;
// TMP117 datasheet: 1 LSB = 7.8125 m°C.
static const float CELSIUS_PER_LSB = 0.0078125f;
static const float DEFAULT_TEMPERATURE_C = 20.0f;
static const float OFFLINE_THRESHOLD = 0.5f;
static const uint8_t BYTES_PER_REGISTER = 2;

// The chip is built without libc, so instances come from a fixed pool instead of malloc.
#define MAX_INSTANCES 2

typedef struct {
  uint32_t temperature_attr;
  uint32_t offline_attr;
  uint8_t pointer;
  uint8_t byte_index;
  uint16_t latched_value;
} tmp117_t;

static tmp117_t instances[MAX_INSTANCES];
static uint32_t instance_count = 0;

static int16_t celsius_to_raw(float celsius) {
  float lsb = celsius / CELSIUS_PER_LSB;
  if (lsb > INT16_MAX) {
    lsb = INT16_MAX;
  } else if (lsb < INT16_MIN) {
    lsb = INT16_MIN;
  }
  return (int16_t)(lsb >= 0.0f ? lsb + 0.5f : lsb - 0.5f);
}

static uint16_t register_value(const tmp117_t *chip) {
  switch (chip->pointer) {
    case REG_TEMPERATURE:
      return (uint16_t)celsius_to_raw(attr_read_float(chip->temperature_attr));
    case REG_CONFIGURATION:
      return CONFIGURATION_RESET_VALUE;
    case REG_DEVICE_ID:
      return DEVICE_ID_VALUE;
    default:
      return 0;
  }
}

// Returning false NACKs the address, which the firmware sees as a failed read.
static bool on_connect(void *user_data, uint32_t address, bool read) {
  (void)address;
  (void)read;
  tmp117_t *chip = user_data;
  if (attr_read_float(chip->offline_attr) > OFFLINE_THRESHOLD) {
    return false;
  }
  chip->byte_index = 0;
  return true;
}

// The register is latched on the first byte so both halves come from the same sample.
static uint8_t on_read(void *user_data) {
  tmp117_t *chip = user_data;
  if (chip->byte_index == 0) {
    chip->latched_value = register_value(chip);
  }
  const uint8_t byte = chip->byte_index == 0 ? (uint8_t)(chip->latched_value >> 8)
                                             : (uint8_t)(chip->latched_value & 0xFF);
  chip->byte_index = (uint8_t)((chip->byte_index + 1) % BYTES_PER_REGISTER);
  return byte;
}

// The first byte sets the register pointer. Register writes are acknowledged but ignored.
static bool on_write(void *user_data, uint8_t data) {
  tmp117_t *chip = user_data;
  if (chip->byte_index == 0) {
    chip->pointer = data;
  }
  chip->byte_index++;
  return true;
}

void chip_init(void) {
  // A third sensor gets no I2C device and stays silent on the bus.
  if (instance_count >= MAX_INSTANCES) {
    return;
  }
  tmp117_t *chip = &instances[instance_count++];
  chip->temperature_attr = attr_init_float("temperature", DEFAULT_TEMPERATURE_C);
  chip->offline_attr = attr_init_float("offline", 0.0f);
  chip->pointer = REG_TEMPERATURE;
  chip->byte_index = 0;

  // Only the GND and V+ ADD0 options of the real part are modelled.
  const pin_t add0 = pin_init("ADD0", INPUT);
  const i2c_config_t config = {
      .user_data = chip,
      .address = pin_read(add0) == HIGH ? ADDRESS_ADD0_VPLUS : ADDRESS_ADD0_GND,
      .scl = pin_init("SCL", INPUT),
      .sda = pin_init("SDA", INPUT),
      .connect = on_connect,
      .read = on_read,
      .write = on_write,
  };
  i2c_init(&config);
}
