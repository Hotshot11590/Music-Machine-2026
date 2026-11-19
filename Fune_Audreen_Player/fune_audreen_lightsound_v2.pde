// Three photoresistors, three racing-game sounds, one LED.
//
// While a flashlight is on a sensor, that sensor's sound loops and the LED lights up.
// The moment the flashlight is taken away, the sound and the LED stop.
//
// At startup it learns two things, so it works in any room:
//   Step 1: your normal room light (flashlight OFF)
//   Step 2: what your flashlight looks like to each sensor (flashlight ON, one sensor at a time)
// It also learns whether each sensor's number goes UP or DOWN with light,
// so it works no matter which way round the parts are wired.
//
// SOUNDS: these are original racing-game-style sounds made by the computer.
//   Sensor 1 = countdown beeps, Sensor 2 = boost sweep, Sensor 3 = engine buzz.
// To use your own audio clips instead, put files named kart1.wav, kart2.wav and kart3.wav
// (or any that you have the rights to use) in a folder called "data" inside this sketch's folder.
// A clip replaces that sensor's built-in sound and loops while the flashlight is on.

import processing.serial.*;
import processing.sound.*;

// ===== SETTINGS YOU CAN CHANGE =====
int ACTIVE_SENSORS = 3;           // how many photoresistors are wired right now (1, 2 or 3)
float triggerFraction = 0.35;     // how far toward your flashlight level counts as "on" (smaller = more sensitive)
// ====================================

int NUM = 3;
String[] pinNames = {"A2", "A3", "A4"};
String[] soundNames = {"countdown", "boost", "engine"};
String[] clipFiles = {"kart1.wav", "kart2.wav", "kart3.wav"};

// Built-in sounds. Each list repeats while the light is on. A note of 0 means silence.
float[][] notes = {
  {440, 0, 440, 0, 440, 0, 880, 0},          // sensor 1: three low beeps, then a high GO
  {392, 494, 587, 784, 988, 1175, 0},        // sensor 2: quick rising sweep
  {110, 0, 110, 0, 110, 0, 110, 0}           // sensor 3: low engine-like buzz
};
int[][] durations = {                        // how long each note lasts, in milliseconds
  {180, 120, 180, 120, 180, 120, 500, 500},
  {70, 70, 70, 70, 70, 200, 400},
  {70, 50, 70, 50, 70, 50, 70, 250}
};

int ROOM_MS = 2000;               // length of step 1
int FLASH_MS = 4000;              // length of step 2 for each sensor
float MIN_CHANGE = 150;           // smallest flashlight change that counts as clear

Serial port;
String status = "";
String message = "";

int[] light = new int[NUM];          // latest reading from each sensor
boolean gotData = false;             // becomes true once the board starts talking

int stage = 0;                       // 0 = room check, 1 = flashlight check, 2 = running
int stageStart;
int currentSensor = 0;               // which sensor step 2 is checking
int calCount = 0;
float[] calSum = new float[NUM];

float[] baseline = new float[NUM];   // the normal room light for each sensor
float[] extreme = new float[NUM];    // the biggest change seen during step 2
float[] span = new float[NUM];       // how far the flashlight moves the number
float[] dir = {1, 1, 1};             // +1 if light raises the number, -1 if it lowers it
boolean[] enabled = new boolean[NUM];

boolean[] isBright = new boolean[NUM];
int[] brightStart = new int[NUM];
boolean ledOn = false;

SqrOsc[] osc = new SqrOsc[NUM];
SoundFile[] clip = new SoundFile[NUM];
boolean[] soundOn = new boolean[NUM];
int[] totalMs = new int[NUM];

void setup() {
  size(600, 440);
  ACTIVE_SENSORS = constrain(ACTIVE_SENSORS, 1, NUM);
  for (int i = 0; i < NUM; i++) {
    osc[i] = new SqrOsc(this);
    osc[i].amp(0.2);
    for (int k = 0; k < durations[i].length; k++) totalMs[i] += durations[i][k];
    File f = new File(dataPath(clipFiles[i]));
    if (f.exists()) clip[i] = new SoundFile(this, clipFiles[i]);
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
  stage = 0;
  stageStart = millis();
  calCount = 0;
  message = "";
  for (int i = 0; i < NUM; i++) {
    calSum[i] = 0;
    isBright[i] = false;
    enabled[i] = (i < ACTIVE_SENSORS);
    playSound(i, false);
  }
  setLed(false);
}

// Runs by itself every time a new line arrives from the board.
void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  String[] parts = split(trim(line), ',');
  if (parts.length < NUM) return;
  for (int i = 0; i < NUM; i++) {
    if (match(trim(parts[i]), "^\\d+$") == null) return;   // ignore garbage lines
  }
  for (int i = 0; i < NUM; i++) light[i] = int(trim(parts[i]));
  gotData = true;
}

void draw() {
  background(30);
  fill(255);
  textSize(14);
  text(status, 20, 28);

  if (stage == 0) {
    roomCheck();
  } else if (stage == 1) {
    flashCheck();
  } else {
    runDetector();
  }
}

// Step 1: average the room light for a couple of seconds.
void roomCheck() {
  if (gotData) {
    for (int i = 0; i < NUM; i++) calSum[i] += light[i];
    calCount++;
  }
  fill(255, 220, 0);
  textSize(20);
  text("Step 1: checking room light. Keep the flashlight OFF.", 20, 150);
  if (millis() - stageStart > ROOM_MS) {
    if (calCount < 30) {
      startCalibration();            // not enough data yet, try again
      return;
    }
    for (int i = 0; i < NUM; i++) baseline[i] = calSum[i] / calCount;
    stage = 1;
    currentSensor = nextEnabled(0);
    extreme[currentSensor] = baseline[currentSensor];
    stageStart = millis();
    message = "";
  }
}

// Step 2: watch what the flashlight does to each active sensor, one at a time.
void flashCheck() {
  int s = currentSensor;
  if (abs(light[s] - baseline[s]) > abs(extreme[s] - baseline[s])) extreme[s] = light[s];

  fill(255, 220, 0);
  textSize(20);
  text("Step 2: shine your flashlight on Sensor " + (s + 1) + " (" + pinNames[s] + ") and hold it there", 20, 120);
  fill(255);
  textSize(14);
  int left = max(0, (FLASH_MS - (millis() - stageStart) + 999) / 1000);
  text("Seconds left: " + left + "     (press S to skip this sensor if it isn't wired yet)", 20, 150);
  if (message.length() > 0) {
    fill(255, 120, 120);
    text(message, 20, 180);
  }
  drawSensor(s, 240);

  if (millis() - stageStart > FLASH_MS) {
    float delta = extreme[s] - baseline[s];
    if (abs(delta) < MIN_CHANGE) {
      message = "I didn't see a clear change. Hold the flashlight close to the sensor.";
      extreme[s] = baseline[s];
      stageStart = millis();
    } else {
      span[s] = abs(delta);
      dir[s] = (delta > 0) ? 1 : -1;
      advanceSensor();
    }
  }
}

// Move on to the next sensor that still needs its flashlight check.
void advanceSensor() {
  message = "";
  currentSensor = nextEnabled(currentSensor + 1);
  if (currentSensor >= NUM) {
    stage = 2;
  } else {
    extreme[currentSensor] = baseline[currentSensor];
    stageStart = millis();
  }
}

int nextEnabled(int from) {
  for (int i = from; i < NUM; i++) {
    if (enabled[i]) return i;
  }
  return NUM;
}

boolean anyEnabled() {
  for (int i = 0; i < NUM; i++) {
    if (enabled[i]) return true;
  }
  return false;
}

// Normal running: sound + LED while the flashlight is on, silent when it is off.
void runDetector() {
  boolean any = false;
  for (int i = 0; i < NUM; i++) {
    if (!enabled[i]) continue;
    float change = (light[i] - baseline[i]) * dir[i];     // positive means "more light"
    float onDist = max(triggerFraction * span[i], 60);
    float offDist = onDist * 0.6;
    if (!isBright[i] && change > onDist) {
      isBright[i] = true;
      brightStart[i] = millis();
    } else if (isBright[i] && change < offDist) {
      isBright[i] = false;
    }
    playSound(i, isBright[i]);
    if (isBright[i]) any = true;
    // slowly follow changes in room light, but not while the flashlight is on
    if (!isBright[i]) baseline[i] = lerp(baseline[i], light[i], 0.002);
  }
  setLed(any);

  for (int i = 0; i < NUM; i++) drawSensor(i, 90 + i * 80);

  fill(180);
  textSize(13);
  text("Red line = trigger level. A bar turns yellow while its sound plays and the LED is on.", 20, 340);
  text("Trigger at " + round(triggerFraction * 100) + "% of flashlight level   (UP key = less sensitive, DOWN key = more)", 20, 362);
  text("Press C to redo the setup steps.", 20, 384);
}

void drawSensor(int i, int y) {
  noStroke();
  if (!enabled[i]) {
    fill(130);
    textSize(14);
    text("Sensor " + (i + 1) + " (" + pinNames[i] + "): off. Wire it, then raise ACTIVE_SENSORS in the code.", 20, y);
    return;
  }
  fill(255);
  textSize(16);
  String dirText = "";
  if (stage == 2) dirText = "   (goes " + (dir[i] > 0 ? "UP" : "DOWN") + " with light)";
  text("Sensor " + (i + 1) + " " + soundNames[i] + " (" + pinNames[i] + "):  " + light[i] + dirText, 20, y);
  fill(60);
  rect(20, y + 12, 560, 24);
  fill(isBright[i] ? color(255, 220, 0) : color(80, 200, 120));
  rect(20, y + 12, constrain(map(light[i], 0, 4095, 0, 560), 0, 560), 24);
  if (stage == 2) {
    float onDist = max(triggerFraction * span[i], 60);
    float tx = 20 + map(constrain(baseline[i] + dir[i] * onDist, 0, 4095), 0, 4095, 0, 560);
    stroke(255, 80, 80);
    strokeWeight(2);
    line(tx, y + 8, tx, y + 40);
    strokeWeight(1);
    noStroke();
  }
}

void keyPressed() {
  if (key == 'c' || key == 'C') startCalibration();
  if (key == 's' || key == 'S') {
    if (stage == 1) {
      enabled[currentSensor] = false;
      if (anyEnabled()) {
        advanceSensor();
      } else {
        startCalibration();
      }
    }
  }
  if (keyCode == UP) triggerFraction = min(0.9, triggerFraction + 0.05);
  if (keyCode == DOWN) triggerFraction = max(0.1, triggerFraction - 0.05);
}

// ---------- LED ----------

void setLed(boolean on) {
  if (on != ledOn) {
    if (port != null) port.write(on ? '1' : '0');
    ledOn = on;
  }
}

// ---------- sound ----------

// Plays or stops a sensor's sound. Call it every frame.
void playSound(int s, boolean on) {
  if (clip[s] != null) {                       // your own audio clip
    if (on && !soundOn[s]) {
      clip[s].loop();
      soundOn[s] = true;
    } else if (!on && soundOn[s]) {
      clip[s].stop();
      soundOn[s] = false;
    }
    return;
  }

  if (!on) {                                   // built-in sound: stop
    if (soundOn[s]) {
      osc[s].stop();
      soundOn[s] = false;
    }
    return;
  }

  // built-in sound: find which note of the repeating pattern we are on right now
  int t = (millis() - brightStart[s]) % totalMs[s];
  int acc = 0;
  float f = 0;
  for (int k = 0; k < notes[s].length; k++) {
    acc += durations[s][k];
    if (t < acc) {
      f = notes[s][k];
      break;
    }
  }
  if (f > 0) {
    osc[s].freq(f);
    if (!soundOn[s]) {
      osc[s].play();
      soundOn[s] = true;
    }
  } else if (soundOn[s]) {
    osc[s].stop();
    soundOn[s] = false;
  }
}
