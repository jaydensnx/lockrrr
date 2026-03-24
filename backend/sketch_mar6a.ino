// Pin definitions
const int hallPin = 17;   // Hall sensor output pin
const int ledPin  = 2;    // Built-in OPTIONAL LED (can change)
const int relayPin = 18;   // GPIO connected to relay
const int unlockTime = 5000; // Door unlock time (milliseconds)

void setup() {
  Serial.begin(115200); 

  pinMode(hallPin, INPUT); // Set hallPin to input.
  pinMode(ledPin, OUTPUT); // Set led to output.

  Serial.begin(115200);
  pinMode(relayPin, OUTPUT); // Set relay to output.

  // Ensure door starts locked
  digitalWrite(relayPin, LOW);
}

// Main loop
void loop() {
  int sensorState = digitalRead(hallPin);

  if (sensorState == LOW) {  // If the magnets are touching.
    Serial.println("Box opened");
    digitalWrite(ledPin, HIGH); // Change the magnet pin to HIGH.
  } 
  else {
    Serial.println("Box closed");
    digitalWrite(ledPin, LOW); // Change the magnet pin to LOW.
  }

  delay(200);

  // Simulate unlock command
  Serial.println("Unlocking door...");
  
  digitalWrite(relayPin, HIGH); // Activate relay
  delay(unlockTime);            // Keep door unlocked
  
  digitalWrite(relayPin, LOW);  // Lock door again
  
  Serial.println("Door locked.");
  
  delay(10000); // Wait before next unlock (for testing)
}
