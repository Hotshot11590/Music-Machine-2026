/*
  MUSIC MACHINE STARTER 2: JOYSTICK
  Board code for the Adafruit HUZZAH32 (ESP32 Feather)

  What it does:
  About 30 times a second, the board reads the joystick and sends one
  line to your laptop, like this:   LR:1520,UD:3100
  LR is left-right and UD is up-down. Each is a number from 0 to 4095.

  Wiring (everything on the breadboard):
  Joystick L/R+  ->  3V
  Joystick U/D+  ->  3V
  Joystick GND   ->  GND (either GND pin on the joystick)
  Joystick L/R   ->  A2
  Joystick U/D   ->  A3
*/

// ---------- SETTINGS ----------
const int LR_PIN        = A2;    // the pin labeled A2: joystick L/R
const int UD_PIN        = A3;    // the pin labeled A3: joystick U/D
const int SEND_EVERY_MS = 30;    // send the joystick position every 30 ms
// ------------------------------

unsigned long lastSend = 0;      // when the joystick position was last sent

void setup() {
  Serial.begin(115200);          // open the USB connection at 115200
}

void loop() {
  if (millis() - lastSend >= SEND_EVERY_MS) {
    lastSend = millis();

    int lr = analogRead(LR_PIN);   // READ: left-right, a number from 0 to 4095
    int ud = analogRead(UD_PIN);   // READ: up-down, a number from 0 to 4095

    // SEND: one line, like LR:1520,UD:3100
    Serial.print("LR:");
    Serial.print(lr);
    Serial.print(",UD:");
    Serial.println(ud);
  }
}
