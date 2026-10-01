/*
 * ROBIQ reference firmware for ESP32
 * ----------------------------------
 * Speaks the ROBIQ protocol (newline-delimited JSON, see docs/PROTOCOL.md)
 * over BOTH:
 *   - Wi-Fi  : WebSocket server on port 81 (SoftAP "ROBIQ-ESP32" by default)
 *   - BLE    : Nordic UART Service
 *
 * Required libraries (Arduino Library Manager):
 *   - ArduinoJson        (Benoit Blanchon)  v7+
 *   - WebSockets         (Markus Sattler)
 *   - ESP32Servo         (Kevin Harrington)
 * Board: ESP32 Arduino core v3.x
 */

#include <WiFi.h>
#include <WebSocketsServer.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include <ESP32Servo.h>

// ---------- Configuration ---------------------------------------------------
#define DEVICE_NAME   "ROBIQ-ESP32"
#define DEVICE_KIND   "rover"        // "rover", "arm" or "generic"
#define WIFI_AP_MODE  true           // false = join an existing network
const char* WIFI_SSID = "ROBIQ-ESP32";
const char* WIFI_PASS = "robiq1234"; // min 8 chars for SoftAP

// Rover: L298N / TB6612 style driver
const int MOTOR_L_PWM = 25, MOTOR_L_DIR = 26;
const int MOTOR_R_PWM = 27, MOTOR_R_DIR = 14;

// Arm: servo pins, one per joint
const int SERVO_PINS[] = {13, 12, 15, 2};
const int JOINT_COUNT = sizeof(SERVO_PINS) / sizeof(SERVO_PINS[0]);

const int BATTERY_ADC_PIN = 34;      // via 1:2 voltage divider
// ---------------------------------------------------------------------------

#define NUS_SERVICE "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define NUS_RX      "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
#define NUS_TX      "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

WebSocketsServer ws(81);
BLECharacteristic* bleTx = nullptr;
bool bleConnected = false;
String bleBuffer;
Servo servos[JOINT_COUNT];
unsigned long lastTelemetry = 0;
bool motionEnabled = false;  // set by the app's "enable"; motion ignored until then

void broadcast(const String& line) {
  String msg = line;
  ws.broadcastTXT(msg);
  if (bleConnected && bleTx) {
    String framed = line + "\n";
    // Default MTU payload is 20 bytes; chunk to be safe.
    for (size_t i = 0; i < framed.length(); i += 20) {
      String part = framed.substring(i, i + 20);
      bleTx->setValue((uint8_t*)part.c_str(), part.length());
      bleTx->notify();
      delay(3);
    }
  }
}

void setMotor(int pwmPin, int dirPin, float v) {
  digitalWrite(dirPin, v >= 0 ? HIGH : LOW);
  ledcWrite(pwmPin, (int)(fabs(v) * 255));
}

void drive(float x, float y) {
  float l = constrain(y + x, -1.0f, 1.0f);
  float r = constrain(y - x, -1.0f, 1.0f);
  setMotor(MOTOR_L_PWM, MOTOR_L_DIR, l);
  setMotor(MOTOR_R_PWM, MOTOR_R_DIR, r);
}

void sendInfo() {
  JsonDocument doc;
  doc["type"] = "info";
  doc["name"] = DEVICE_NAME;
  doc["kind"] = DEVICE_KIND;
  doc["joints"] = JOINT_COUNT;
  String out; serializeJson(doc, out);
  broadcast(out);
}

void handleLine(const String& line) {
  JsonDocument doc;
  if (deserializeJson(doc, line)) return;
  const char* cmd = doc["cmd"] | "";

  if (!strcmp(cmd, "drive")) {
    if (motionEnabled) drive(doc["x"] | 0.0f, doc["y"] | 0.0f);
  } else if (!strcmp(cmd, "joint")) {
    if (!motionEnabled) return;
    int id = doc["id"] | -1;
    if (id >= 0 && id < JOINT_COUNT) servos[id].write(constrain((int)(doc["angle"] | 90), 0, 180));
  } else if (!strcmp(cmd, "digital")) {
    int pin = doc["pin"] | -1;
    if (pin >= 0) { pinMode(pin, OUTPUT); digitalWrite(pin, (doc["value"] | 0) ? HIGH : LOW); }
  } else if (!strcmp(cmd, "pwm")) {
    int pin = doc["pin"] | -1;
    if (pin >= 0) analogWrite(pin, constrain((int)(doc["value"] | 0), 0, 255));
  } else if (!strcmp(cmd, "stop")) {
    drive(0, 0);
  } else if (!strcmp(cmd, "enable")) {
    motionEnabled = true;
  } else if (!strcmp(cmd, "disable")) {
    motionEnabled = false;
    drive(0, 0);
  } else if (!strcmp(cmd, "ping")) {
    broadcast("{\"type\":\"pong\"}");
  } else if (!strcmp(cmd, "info")) {
    sendInfo();
  }
}

void onWsEvent(uint8_t client, WStype_t type, uint8_t* payload, size_t len) {
  if (type == WStype_TEXT) handleLine(String((char*)payload, len));
  if (type == WStype_DISCONNECTED) { motionEnabled = false; drive(0, 0); } // fail-safe
}

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override { bleConnected = true; }
  void onDisconnect(BLEServer* s) override {
    bleConnected = false;
    motionEnabled = false;
    drive(0, 0);                  // fail-safe
    s->getAdvertising()->start(); // allow reconnection
  }
};

class RxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    bleBuffer += String(c->getValue().c_str());
    int nl;
    while ((nl = bleBuffer.indexOf('\n')) >= 0) {
      handleLine(bleBuffer.substring(0, nl));
      bleBuffer.remove(0, nl + 1);
    }
  }
};

void setupBle() {
  BLEDevice::init(DEVICE_NAME);
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  BLEService* service = server->createService(NUS_SERVICE);
  bleTx = service->createCharacteristic(NUS_TX, BLECharacteristic::PROPERTY_NOTIFY);
  bleTx->addDescriptor(new BLE2902());
  BLECharacteristic* rx = service->createCharacteristic(
      NUS_RX, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  rx->setCallbacks(new RxCallbacks());
  service->start();
  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(NUS_SERVICE);
  adv->setScanResponse(true);
  adv->start();
}

void setup() {
  Serial.begin(115200);

  pinMode(MOTOR_L_DIR, OUTPUT);
  pinMode(MOTOR_R_DIR, OUTPUT);
  ledcAttach(MOTOR_L_PWM, 5000, 8);
  ledcAttach(MOTOR_R_PWM, 5000, 8);
  for (int i = 0; i < JOINT_COUNT; i++) { servos[i].attach(SERVO_PINS[i]); servos[i].write(90); }

  if (WIFI_AP_MODE) {
    WiFi.softAP(WIFI_SSID, WIFI_PASS);
    Serial.printf("AP started. Connect to %s and use %s:81\n", WIFI_SSID, WiFi.softAPIP().toString().c_str());
  } else {
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    while (WiFi.status() != WL_CONNECTED) delay(250);
    Serial.printf("Connected. Use %s:81\n", WiFi.localIP().toString().c_str());
  }
  ws.begin();
  ws.onEvent(onWsEvent);
  setupBle();
}

void loop() {
  ws.loop();

  if (millis() - lastTelemetry > 500) {
    lastTelemetry = millis();
    JsonDocument doc;
    doc["type"] = "telemetry";
    JsonObject data = doc["data"].to<JsonObject>();
    data["battery"] = analogReadMilliVolts(BATTERY_ADC_PIN) * 2 / 1000.0;
    data["uptime"] = millis() / 1000;
    data["rssi"] = WIFI_AP_MODE ? 0 : WiFi.RSSI();
    data["heap_kb"] = ESP.getFreeHeap() / 1024;
    String out; serializeJson(doc, out);
    broadcast(out);
  }
}
