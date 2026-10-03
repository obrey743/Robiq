/*
 * ROBIQ reference firmware for Arduino (Uno / Nano / Mega)
 * --------------------------------------------------------
 * Talks the ROBIQ protocol over an HM-10 (or compatible) BLE module.
 *
 * Wiring (HM-10):  VCC -> 5V, GND -> GND, TX -> D10, RX -> D11 (via divider)
 *
 * Required libraries: ArduinoJson v7+, Servo (built in)
 *
 * Note: ROBIQ uses Bluetooth LE. Classic-Bluetooth modules such as the
 * HC-05/HC-06 are not supported by the app; use an HM-10, or an ESP32.
 */

#include <SoftwareSerial.h>
#include <ArduinoJson.h>
#include <Servo.h>

SoftwareSerial ble(10, 11); // RX, TX

const int SERVO_PINS[] = {3, 5, 6, 9};
const int JOINT_COUNT = sizeof(SERVO_PINS) / sizeof(SERVO_PINS[0]);
Servo servos[JOINT_COUNT];

String buffer;
unsigned long lastTelemetry = 0;

void handleLine(const String& line) {
  JsonDocument doc;
  if (deserializeJson(doc, line)) return;
  const char* cmd = doc["cmd"] | "";

  if (!strcmp(cmd, "joint")) {
    int id = doc["id"] | -1;
    if (id >= 0 && id < JOINT_COUNT) servos[id].write(constrain((int)(doc["angle"] | 90), 0, 180));
  } else if (!strcmp(cmd, "digital")) {
    int pin = doc["pin"] | -1;
    if (pin >= 0) { pinMode(pin, OUTPUT); digitalWrite(pin, (doc["value"] | 0) ? HIGH : LOW); }
  } else if (!strcmp(cmd, "pwm")) {
    int pin = doc["pin"] | -1;
    if (pin >= 0) analogWrite(pin, constrain((int)(doc["value"] | 0), 0, 255));
  } else if (!strcmp(cmd, "ping")) {
    ble.println(F("{\"type\":\"pong\"}"));
  } else if (!strcmp(cmd, "info")) {
    ble.print(F("{\"type\":\"info\",\"name\":\"ROBIQ-Arduino\",\"kind\":\"arm\",\"joints\":"));
    ble.print(JOINT_COUNT);
    ble.println(F("}"));
  }
}

void setup() {
  ble.begin(9600);
  for (int i = 0; i < JOINT_COUNT; i++) { servos[i].attach(SERVO_PINS[i]); servos[i].write(90); }
}

void loop() {
  while (ble.available()) {
    char c = ble.read();
    if (c == '\n') { handleLine(buffer); buffer = ""; }
    else if (buffer.length() < 128) buffer += c;
  }

  if (millis() - lastTelemetry > 1000) {
    lastTelemetry = millis();
    ble.print(F("{\"type\":\"telemetry\",\"data\":{\"a0\":"));
    ble.print(analogRead(A0));
    ble.print(F(",\"uptime\":"));
    ble.print(millis() / 1000);
    ble.println(F("}}"));
  }
}
