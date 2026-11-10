// Listens to the Feather over USB. While a flashlight is on a sensor, it plays ONE steady tone.
// The moment the light is gone, the tone stops.
// It checks the room light for 2 seconds at startup, so it works in a lit room.

import processing.serial.*;
import processing.sound.*;

// ===== SETTINGS YOU CAN CHANGE =====
int ACTIVE_SENSORS = 1;           // change to 2 once the second photoresistor is wired
int margin = 100;                 // how much brighter than the room counts as a flash (smaller = more sensitive)
int CALIBRATION_MS = 2000;        // how long the startup room-light check lasts
float[] toneHz = {523, 784};      // pitch of each sensor's tone (higher number = higher sound)
// ====================================

Serial port;
String status = "";

int[] light = new int[2];          // latest reading from each sensor
boolean gotData = false;           // becomes true once the board starts talking
float[] baseline = new float[2];   // the "normal" room light for each sensor
boolean[] isBright = new boolean[2];

boolean calibrating = true;
int calStart;
int calCount = 0;
float[] calSum = new float[2];

// One square-wave tone generator per sensor.
SqrOsc[] osc = new SqrOsc[2];
boolean[] oscOn = new boolean[2];

void setup() {
  size(600, 380);
  for (int i = 0; i < 2; i++) {
    osc[i] = new SqrOsc(this);
    osc[i].amp(0.25);
  }
  connectToBoard();
  startCalibration();
}

void connectToBoard() {
  String[] ports = Serial.list();
  printArray(ports);
  for (String p : ports) {
    if (p.contains("cu.usb") || p.contains("cu.SLAB") || p.contains("cu.wchusb")) {
      try {
        port = new Serial(this, p, 115200);
        port.bufferUntil('\n');
        status = "Connected: " + p;
      } catch (Exception e) {
        status = "Could not open the port. Close the Arduino Serial Monitor and try again.";
      }
      return;
    }
  }
  status = "Board not found. Check the USB cable, and close the Arduino Serial Monitor.";
}

void startCalibration() {
  calibrating = true;
  calStart = millis();
  calCount = 0;
  calSum[0] = 0;
  calSum[1] = 0;
  for (int i = 0; i < 2; i++) {
    isBright[i] = false;
    setTone(i, false);
  }
}

// Runs by itself every time a new line arrives from the board.
void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  String[] parts = split(trim(line), ',');
  if (parts.length < 2) return;
  if (match(trim(parts[0]), "^\\d+$") == null) return;   // ignore garbage lines
  if (match(trim(parts[1]), "^\\d+$") == null) return;
  light[0] = int(trim(parts[0]));
  light[1] = int(trim(parts[1]));
  gotData = true;
}

void draw() {
  background(30);
  fill(255);
  textSize(14);
  text(status, 20, 28);

  if (calibrating) {
    if (gotData) {
      for (int i = 0; i < 2; i++) calSum[i] += light[i];
      calCount++;
    }
    fill(255, 220, 0);
    textSize(20);
    text("Checking room light... keep the flashlight OFF", 20, 150);
    if (millis() - calStart > CALIBRATION_MS) {
      if (calCount < 30) {
        startCalibration();          // not enough data yet, try again
      } else {
        for (int i = 0; i < 2; i++) baseline[i] = calSum[i] / calCount;
        calibrating = false;
      }
    }
    return;
  }

  for (int i = 0; i < ACTIVE_SENSORS; i++) {
    float onLevel = baseline[i] + margin;
    float offLevel = baseline[i] + margin / 2.0;
    if (!isBright[i] && light[i] > onLevel) {
      isBright[i] = true;
    } else if (isBright[i] && light[i] < offLevel) {
      isBright[i] = false;
    }
    setTone(i, isBright[i]);         // tone on while bright, off the moment it's not
    // slowly follow changes in room light, but not while the flashlight is on
    if (!isBright[i]) baseline[i] = lerp(baseline[i], light[i], 0.002);
  }

  drawSensor(0, 90);
  drawSensor(1, 190);

  fill(180);
  textSize(13);
  text("Red line = trigger level. The bar turns yellow while the tone is playing.", 20, 290);
  text("Sensitivity margin: " + margin + "   (UP key = less sensitive, DOWN key = more sensitive)", 20, 312);
  text("Press C to re-check the room light.", 20, 334);
}

void drawSensor(int i, int y) {
  noStroke();
  if (i >= ACTIVE_SENSORS) {
    fill(130);
    textSize(14);
    text("Sensor " + (i + 1) + " (A3): not wired yet. Set ACTIVE_SENSORS to 2 in the code after wiring.", 20, y);
    return;
  }
  fill(255);
  textSize(16);
  text("Sensor " + (i + 1) + " (" + (i == 0 ? "A2" : "A3") + "):  " + light[i], 20, y);
  fill(60);
  rect(20, y + 12, 560, 24);
  fill(isBright[i] ? color(255, 220, 0) : color(80, 200, 120));
  rect(20, y + 12, constrain(map(light[i], 0, 4095, 0, 560), 0, 560), 24);
  stroke(255, 80, 80);
  strokeWeight(2);
  float tx = 20 + map(constrain(baseline[i] + margin, 0, 4095), 0, 4095, 0, 560);
  line(tx, y + 8, tx, y + 40);
  strokeWeight(1);
  noStroke();
}

void keyPressed() {
  if (key == 'c' || key == 'C') startCalibration();
  if (keyCode == UP) margin += 20;
  if (keyCode == DOWN) margin = max(20, margin - 20);
}

// Turns a sensor's tone on or off.
void setTone(int s, boolean on) {
  if (on && !oscOn[s]) {
    osc[s].freq(toneHz[s]);
    osc[s].play();
    oscOn[s] = true;
  } else if (!on && oscOn[s]) {
    osc[s].stop();
    oscOn[s] = false;
  }
}
