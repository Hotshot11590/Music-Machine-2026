// Violin — Adafruit HUZZAH32 (ESP32 Feather)
// An HC-SR04 ultrasonic sensor tracks your hand like a finger on a fingerboard.
// The sound and the picture are made on the laptop (Violin.pde in Processing);
// this sketch only reports how far away your hand is and which buttons are held.
//   HC-SR04: VCC to USB (5V), GND to GND, Trig to A1, Echo to A0
//   Buttons (G, D, A, E strings): GPIO 14, 27, 33, 32 — other leg to GND
//   Sends one line per reading: "cm,mask"  e.g. "23.4,5"
//     cm   = hand distance, or -1 if no hand
//     mask = bit 0 for button 1 ... bit 3 for button 4

const int TRIG_PIN = 25;  // A1
const int ECHO_PIN = 26;  // A0
const int NUM_BUTTONS = 4;
const int BUTTON_PINS[NUM_BUTTONS] = {14, 27, 33, 32};
const float MAX_CM = 80;  // anything farther counts as "no hand"
const unsigned long SEND_MS = 30;

float readCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  unsigned long us = pulseIn(ECHO_PIN, HIGH, 6000);  // 6 ms ~ 100 cm
  if (us == 0) return -1;
  float cm = us / 58.0;
  return cm > MAX_CM ? -1 : cm;
}

// Median of three readings throws out the odd stray echo.
float median3(float a, float b, float c) {
  return max(min(a, b), min(max(a, b), c));
}

float r1 = -1, r2 = -1;

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  for (int i = 0; i < NUM_BUTTONS; i++) pinMode(BUTTON_PINS[i], INPUT_PULLUP);
}

int readButtons() {
  int mask = 0;
  for (int i = 0; i < NUM_BUTTONS; i++)
    if (digitalRead(BUTTON_PINS[i]) == LOW) mask |= 1 << i;
  return mask;
}

void loop() {
  float r3 = readCm();
  float cm = median3(r1, r2, r3);
  r1 = r2;
  r2 = r3;
  Serial.print(cm, 1);
  Serial.print(',');
  Serial.println(readButtons());
  delay(SEND_MS);
}
