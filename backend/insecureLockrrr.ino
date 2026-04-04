/*
 * =============================================================================
 * insecureLockrrr.ino — Webserver UNSECURE MQTT Publish/Subcribe for our ESP32
 * =============================================================================
 *
 * PURPOSE
 *   Reads a digital input from our lock to a GPIO and reports
 *   whether a box is OPEN or CLOSED to a remote MQTT endpoint. Each update
 *   is sent as a JSON PUBLISH body: "status":"UNLOCKED" or "status":"LOCKED".
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
 *   - Server MQTT Config should be listening on Port 1883 0.0.0.0 for hosts
 *   - This is for testing purposes, so use something like MQTT Explorer to send
 *     PUBLISH requests to the ESP32 which unlocks the lock (which pops open)
 *     and updates the STATUS if it's locked or unlocked.
 *
 * FLOW (summary)
 *   setup()  → Serial, pin mode, Wi‑Fi connect, hardware timer, connect to MQTT Server.
 *   loop()   → If Wi‑Fi down, retry periodically, connect to MQTT Broker, debounce,
 *              map to logical open/closed, send PUBLISH when state is new, check
 *              sensor periodically due to ISR.
 */

#include <WiFi.h>           // Manages ESP32 Wi-Fi connectivity
#include <PubSubClient.h>   // MQTT protocol (Publish/Subscribe)
#include <ArduinoJson.h>    // Used for parsing and generating JSON formatted strings

// -------------------- WiFi Configuration --------------------
// Be advised, ESP32 cannot connect to 5G Networks
const char* WIFI_SSID = "YOUR_WIFI_SSID";          // Your Network Name, Case Sensitive.
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";  // Your Network Password, Case Sensitive

// -------------------- MQTT Configuration --------------------
const char* MQTT_HOST = "lockrrr.site";     // IP Address or URL Endpoint for our Webserver which has MQTT Broker
const int MQTT_PORT = 1883;                 // Default non-secure MQTT port

// -------------------- Hardware & ID --------------------
const int LOCK_SENSOR_PIN = 13;             // Pin connected to the lock to detect open/close state; can be changed.
const int SOLENOID_RELAY_PIN = 12;          // Pin controlling the relay that activates the solenoid lock; can be changed.
const char* DEVICE_ID = "esp32_lockrrr_01"; // Unique identifier for this Lockbox.

// -------------------- Timer Variables --------------------
// These allow the ESP32 to track time without using delay(), which would freeze the program
hw_timer_t* sensorTimer = NULL;             // Pointer to a hardware timer object
portMUX_TYPE timerMux = portMUX_INITIALIZER_UNLOCKED; // Synchronizes data between the ISR and Main Loop
volatile bool shouldCheckSensor = false;    // A 'flag' that tells the main loop when it's time to read the sensor

// -------------------- Network Objects --------------------
WiFiClient espClient;                       // Handles the underlying TCP connection
PubSubClient mqttClient(espClient);         // Wraps the WiFi client to provide MQTT functionality
int lastKnownLockState = -1;                // Stores the previous state to prevent spamming the server with updates

// -------------------- Interrupt Service Routine (ISR) --------------------
// This function runs automatically in the background every 100ms.
// Sets flags to INDICATE to check the sensor 10 times a second.
// Enter/Exit Critical to ensure that the variables will NOT be interrupted while being updated.
void IRAM_ATTR onTimer() {
  portENTER_CRITICAL_ISR(&timerMux);
  shouldCheckSensor = true;       // Signal to the main loop that we need to check the hardware
  portEXIT_CRITICAL_ISR(&timerMux);
}

// -------------------- MQTT Functions --------------------

// Encapsulates the current lock status into a JSON object and sends it to the broker.
void publishStatus(bool isLocked) {
  JsonDocument doc;                         // Create a JSON container
  doc["deviceId"] = DEVICE_ID;              // Add device identity to the payload
  doc["status"] = isLocked ? "LOCKED" : "UNLOCKED"; // Status String
  
  char buffer[128];                         // Temporary storage for the serialized string
  serializeJson(doc, buffer);               // Convert JSON object to a raw string
  
  // Topic structure: lockrrr/esp32_lockrrr_01/status
  // MQTT operates via Topics instead of Endpoints in REST
  String topic = "lockrrr/" + String(DEVICE_ID) + "/status";
  
  // Publish with 'retain' set to true so new subscribers immediately see the current state
  mqttClient.publish(topic.c_str(), buffer, true); 
  Serial.printf("Published: %s\n", isLocked ? "LOCKED" : "UNLOCKED");
}

// Callback runs whenever the ESP32 receives a message on a topic it has subscribed to.
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  JsonDocument doc;
  deserializeJson(doc, payload, length);    // Decode the incoming JSON message
  const char* action = doc["action"] | "";  // Extract the "action" key, default to empty string if missing

  // If the command is "UNLOCK", pulse the solenoid relay
  if (strcmp(action, "UNLOCK") == 0) {
    Serial.println("Command: UNLOCKING");
    digitalWrite(SOLENOID_RELAY_PIN, HIGH); // Trigger relay
    delay(200);                             // Hold for 200ms
    digitalWrite(SOLENOID_RELAY_PIN, LOW);  // Release relay
  }
}

// -------------------- Main Logic --------------------

void setup() {
  Serial.begin(115200);
  delay(2000); 
  
  Serial.println("\n--- esp32_lockrrr_01 BOOTING ---");
  
  // Configure Hardware Pins
  // INPUT_PULLUP to keep the pin HIGH
  pinMode(LOCK_SENSOR_PIN, INPUT_PULLUP);
  pinMode(SOLENOID_RELAY_PIN, OUTPUT);
  digitalWrite(SOLENOID_RELAY_PIN, LOW);    // Ensure lock is closed on startup

  // --- Hardware Timer Setup ---
  sensorTimer = timerBegin(1000000); 
  timerAttachInterrupt(sensorTimer, &onTimer); // Link the timer to our onTimer function
  
  // Trigger the interrupt every 100,000 ticks (100ms)
  timerAlarm(sensorTimer, 100000, true, 0); 

  // Configure MQTT Server and the response function (callback)
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);

  // Initialize Wi-Fi connection
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi: ");
  Serial.println(WIFI_SSID);

  // Halt code execution until Wi-Fi is successfully connected
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWi-Fi Connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  // If Wi-Fi drops, skip the rest of the loop to prevent crashes
  if (WiFi.status() != WL_CONNECTED) return;

  // If MQTT connection is lost, attempt to reconnect
  if (!mqttClient.connected()) {
    Serial.println("Connecting to MQTT...");
    // Attempt to connect using the Device ID
    if (mqttClient.connect(DEVICE_ID)) {
      // Subscribe to the command topic for this specific device
      String cmdTopic = "lockrrr/" + String(DEVICE_ID) + "/command";
      mqttClient.subscribe(cmdTopic.c_str());
      Serial.println("Connected!");
    }
  }
  
  // Required to maintain the MQTT connection and process incoming messages
  mqttClient.loop();

  // --- Sensor Polling Logic ---
  // If the 100ms hardware timer has set the flag to true:
  if (shouldCheckSensor) {
    // Reset the flag safely using critical section
    portENTER_CRITICAL(&timerMux);
    shouldCheckSensor = false; // Reset flag to false
    portEXIT_CRITICAL(&timerMux);

    // Read the lock sensor (LOW usually means magnet is locked)
    bool currentState = (digitalRead(LOCK_SENSOR_PIN) == LOW);
    
    // Logic: Only send a message if the state HAS CHANGED since we last checked
    if (currentState != lastKnownLockState) {
      lastKnownLockState = currentState;
      publishStatus(lastKnownLockState); // Notify the cloud of the change
    }
  }
}