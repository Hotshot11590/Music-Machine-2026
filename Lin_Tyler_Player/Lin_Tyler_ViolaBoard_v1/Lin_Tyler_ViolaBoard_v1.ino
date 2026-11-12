// Rainbow Road viola controller (Adafruit ESP32 Feather HUZZAH32)
//
// Reads 3 buttons and an ultrasonic distance sensor (the "bow") and sends
// their state to the laptop over USB 100 times per second, as a line like:
//   S 12345 2048 100
//   S     = state
//   12345 = time since the board started (ms)
//   2048  = bow position, 0 (hand close) to 4095 (hand far)
//   100   = buttons 1, 2, 3 (1 = pressed)
// The music logic is all in the Processing sketch.

const int BUTTON_PINS[3] = {32, 33, 27};
const int TRIG_PIN = 14;   // sensor Trig
const int ECHO_PIN = A3;   // sensor Echo

const float MIN_CM = 5;             // closest hand position used
const float MAX_CM = 65;            // farthest hand position used
const float IGNORE_BEYOND_CM = 80;  // farther readings are the background, not the hand
const float JITTER_CM = 0.8;        // hand movements smaller than this are ignored
const unsigned long SEND_EVERY_MS = 10;
const unsigned long MEASURE_EVERY_MS = 30;
const unsigned long ECHO_TIMEOUT_US = 6000;  // stop waiting for an echo after about 1 m

unsigned long lastSend = 0;
unsigned long lastMeasure = 0;
float readings[3] = {25, 25, 25};  // the last three distances (cm)
int nextReading = 0;
float handCm = 25;                 // filtered hand distance (cm)

void setup() {
  Serial.begin(115200);
  for (int i = 0; i < 3; i++) {
    pinMode(BUTTON_PINS[i], INPUT_PULLUP);  // HIGH = not pressed, LOW = pressed
  }
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
}

void loop() {
  unsigned long now = millis();

  if (now - lastMeasure >= MEASURE_EVERY_MS) {
    lastMeasure = now;
    float cm = measureCm();
    if (cm > 0 && cm < IGNORE_BEYOND_CM) {  // skip "no echo" and the background
      readings[nextReading] = cm;
      nextReading = (nextReading + 1) % 3;
      followHand(median3(readings[0], readings[1], readings[2]));
    }
  }

  if (now - lastSend >= SEND_EVERY_MS) {
    lastSend = now;
    sendState(now);
  }
}

// Distance to the hand in cm, or -1 if no echo came back.
float measureCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);  // a 10-microsecond pulse starts a measurement
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  unsigned long us = pulseIn(ECHO_PIN, HIGH, ECHO_TIMEOUT_US);  // how long the echo took
  if (us == 0) return -1;
  return us * 0.0343 / 2;  // sound travels 0.0343 cm per microsecond, there and back
}

// The middle value of three readings, so one bad reading is ignored.
float median3(float a, float b, float c) {
  if (a > b) { float t = a; a = b; b = t; }
  if (b > c) { float t = b; b = c; c = t; }
  if (a > b) { float t = a; a = b; b = t; }
  return b;
}

// Dead zone: the hand position only moves once a reading is more than
// JITTER_CM away from it, so a still hand doesn't count as bowing.
void followHand(float cm) {
  if (cm > handCm + JITTER_CM) handCm = cm - JITTER_CM;
  if (cm < handCm - JITTER_CM) handCm = cm + JITTER_CM;
}

// Sends "S <time> <bow position> <buttons>".
void sendState(unsigned long now) {
  float cm = constrain(handCm, MIN_CM, MAX_CM);
  int bowPosition = (int)((cm - MIN_CM) / (MAX_CM - MIN_CM) * 4095);

  Serial.print("S ");
  Serial.print(now);
  Serial.print(' ');
  Serial.print(bowPosition);
  Serial.print(' ');
  for (int i = 0; i < 3; i++) {
    if (digitalRead(BUTTON_PINS[i]) == LOW) {
      Serial.print('1');
    } else {
      Serial.print('0');
    }
  }
  Serial.println();
}
