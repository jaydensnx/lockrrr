/*
 * =============================================================================
 * TLS_Lockrrr.ino — Webserver SECURE MQTT Publish/Subcribe for our ESP32
 * =============================================================================
 *
 * PURPOSE
 *   Reads a digital input from our lock to a GPIO and reports
 *   whether a box is OPEN or CLOSED to a remote MQTT endpoint. Each update
 *   is sent as a JSON PUBLISH body: "status":"UNLOCKED" or "status":"LOCKED".
 *   - Secure over Port 8883 and use of certificates and TLS Verification.
 *   - Still unsure if this works entirely, need more troubleshooting.
 *
 * HARDWARE (typical)
 *   - Use ESP32 Ground as the Common Ground, connect 12V power negative to Ground,
 *     Lock negative to ground, Lock white wire to ground, and 5V Relay to ground.
 *   - INPUT_PULLUP holds the pin HIGH when the switch is open; closing the switch
 *     pulls it LOW (common for reed switches with NO contact to GND).
 *
 * NETWORK
 *   - Requires Wi‑Fi (station mode). Fill in WIFI_SSID and WIFI_PASSWORD.
 *   - Ensure network is 2.4 Ghz as 5 Ghz will not work for ESP32.
 *   - MQTT_HOST set to our webpage with has our MQTT Broker.
 *   - MQTT_PORT set to 1883 for unsecure for testing.
 *   - DEVICE_ID set to a unique id for our device as MQTT technically sends to every
 *     subscribed host but only the unique id will act on it.
 *
 * SERVER
 *   - Server MQTT Config should be listening on Port 8883 0.0.0.0 for hosts
 *   - For testing purposes, use something like MQTT Explorer connected to our
 *     webserver MQTT Broker to send PUBLISH requests to the ESP32 which unlocks
 *     the lock (which pops open) and updates the STATUS if it's locked or unlocked.
 *   - Webserver needs password file so that we can have a Username and Password.
 *   - Also needs CA Certificate, Server Certificate, and Server Key files.
 *
 * FLOW (summary)
 *   setup()  → Serial, pin mode, Wi‑Fi connect, hardware timer, connect to MQTT Server.
 *   loop()   → If Wi‑Fi down, retry periodically, connect to MQTT Broker, debounce,
 *              map to logical open/closed, send PUBLISH when state is new, check
 *              sensor periodically due to ISR.
 */

#include <WiFi.h> // Connect to WiFi
#include <WiFiClientSecure.h> // Necessary for SSL/TLS encrypted communication
#include <PubSubClient.h>     // Standard library for MQTT protocol
#include <ArduinoJson.h>      // String to JSON and vice versa
#include <time.h>             // Used to sync NTP time for SSL certificate validation

// -------------------- WiFi Configuration --------------------
// Be advised, ESP32 cannot connect to 5G Networks
const char* WIFI_SSID = "YOUR_WIFI_SSID";          // Your Network Name, Case Sensitive.
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";  // Your Network Password, Case Sensitive.

// MQTT Broker details
const char* MQTT_HOST = "lockrrr.site";  // IP Address or URL Endpoint for our Webserver which has MQTT Broker
const int MQTT_PORT = 8883;              // Secure MQTT Port
const char* MQTT_USER = "YOUR_USERNAME"; // Username for authentication
const char* MQTT_PASS = "YOUR_PASSWORD"; // Password for Authentication

// Let's Encrypt Root Certificate
// Root Certificate of CA that signed our Server Certificate
static const char CA_CERT[] PROGMEM = R"EOF(
-----BEGIN CERTIFICATE-----
--- Sample Certificate PEM ---
-----END CERTIFICATE-----
)EOF";

// -------------------- Hardware Mapping --------------------
const int LOCK_SENSOR_PIN = 13;   // Green wire from Solenoid (White to GND)
const int SOLENOID_RELAY_PIN = 12; // Pin triggering your Relay or MOSFET
const char* DEVICE_ID = "esp32_lockrrr_01"; // Your unique device identifier

// -------------------- Timer Variables --------------------
// Hardware timers run independently of the main loop, ensuring the 
// sensor is checked even if the Wi-Fi is busy or lagging.
hw_timer_t* sensorTimer = NULL;
portMUX_TYPE timerMux = portMUX_INITIALIZER_UNLOCKED;
volatile bool shouldCheckSensor = false;

// -------------------- Network Objects --------------------
// Notably Secure Wifi Client
WiFiClientSecure secureClient;
PubSubClient mqttClient(secureClient);
int lastKnownLockState = -1; // -1 ensures first read always triggers an update
bool isTlsSynced = false; // TLS is not synced yet so will Synce

// -------------------- Timer Interrupt --------------------
// This function runs every 100ms to set a "flag" for the main loop
void IRAM_ATTR onTimer() {
  portENTER_CRITICAL_ISR(&timerMux);
  shouldCheckSensor = true; 
  portEXIT_CRITICAL_ISR(&timerMux);
}

// -------------------- MQTT --------------------
// Sends the current lock status to the frontend.
// uses 'retained = true' so the dashboard shows the state immediately on login.
void publishLockStatus(bool isLocked) {
  JsonDocument doc;
  doc["deviceId"] = DEVICE_ID;
  doc["status"] = isLocked ? "LOCKED" : "UNLOCKED";
  doc["rssi"] = WiFi.RSSI(); // Sends signal strength to monitor connection health
  
  char buffer[256];
  serializeJson(doc, buffer);
  
  String topic = "lockrrr/" + String(DEVICE_ID) + "/status"; // Topic String for Status
  
  mqttClient.publish(topic.c_str(), buffer, true);
  Serial.printf("State Change: %s\n", isLocked ? "LOCKED" : "UNLOCKED");
}

/**
 * Handles incoming messages from your frontend/app.
 * Expects: {"action": "UNLOCK"} sent to lockrrr/esp32_lockrrr_01/command
 */
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, payload, length);
  if (err) return; // Handles errors when converting JSON to string

  const char* action = doc["action"] | "";

// Unlocking the Box
  if (strcmp(action, "UNLOCK") == 0) {
    Serial.println("MQTT: Remote Unlock Triggered");
    digitalWrite(SOLENOID_RELAY_PIN, HIGH);
    delay(200); // Only powers for 200ms per Manufacturers Warning
    digitalWrite(SOLENOID_RELAY_PIN, LOW);
  }
}

// -------------------- Setup --------------------

void setup() {
  Serial.begin(115200);

  // Pin Initial States
  pinMode(LOCK_SENSOR_PIN, INPUT_PULLUP);
  pinMode(SOLENOID_RELAY_PIN, OUTPUT);
  digitalWrite(SOLENOID_RELAY_PIN, LOW);
  
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);

  //secureClient.setInsecure(); // Used if want to skip certificate
  secureClient.setCACert(CA_CERT); // Setting the Certificate

  // Initialize the Timer to 1mHz
  sensorTimer = timerBegin(1000000); 

  // Attach the callback function 
  timerAttachInterrupt(sensorTimer, &onTimer);

  // Set the alarm to trigger every 100,000 ticks (100ms)
  timerAlarm(sensorTimer, 100000, true, 0);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

// -------------------- Main Loop --------------------

void loop() {

  // Maintain WiFi and Sync Time
  if (WiFi.status() != WL_CONNECTED) return;
  
  // Syncs time if not already Synced
  if (!isTlsSynced) {
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    time_t now = time(nullptr);
    if (now > 1000000000) { 
      isTlsSynced = true;
      Serial.println("Secure connection ready.");
    }
    return;
  }

  // Manage MQTT Connection

  if (!mqttClient.connected()) {
    Serial.println("Reconnecting to MQTT...");
    if (mqttClient.connect(DEVICE_ID, MQTT_USER, MQTT_PASS)) {
        Serial.println("CONNECTED to Broker!");
        String commandTopic = "lockbox/" + String(DEVICE_ID) + "/command";
        mqttClient.subscribe(commandTopic.c_str());
        Serial.println("Connected!");
    } else {
        // This will tell us WHY it failed (e.g., -2 for CID, -4 for timeout)
        Serial.print("Failed, rc=");
        Serial.print(mqttClient.state());
        Serial.println(" try again in 5 seconds");
        delay(5000); 
        }
    }
  mqttClient.loop();

  // Process Sensor via Hardware Timer Flag
  if (shouldCheckSensor) {
    // Critical sections prevent the timer from interrupting during the flag reset
    portENTER_CRITICAL(&timerMux);
    shouldCheckSensor = false;
    portEXIT_CRITICAL(&timerMux);

    // LOW = Lock is engaged (LOCKED)
    bool currentPhysicalState = (digitalRead(LOCK_SENSOR_PIN) == LOW);

    // Only update the frontend if the state actually changes
    if (currentPhysicalState != lastKnownLockState) {
      lastKnownLockState = currentPhysicalState;
      publishLockStatus(lastKnownLockState);
    }
  }
}