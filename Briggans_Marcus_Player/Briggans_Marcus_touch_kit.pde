/*
  Lesson 4: THREE-PAD DRUM KIT
  Processing sketch

  What it does:
  Listens to the board. Each word plays its own sound from the data folder
  and flashes its own circle:
    "kick"  -> kick.wav
    "snare" -> snare.wav
    "hihat" -> hihat.wav

  Before you run it:
  1. Upload the board code in the touch_kit_board folder.
  2. Close the Arduino Serial Monitor and Serial Plotter.

  Test without the board: keys 1, 2, 3 play kick, snare, hi-hat.
  To use better sounds later, replace a .wav in the data folder with a new
  file of the same name.
*/

import processing.serial.*;
import processing.sound.*;

// ---------- SETTINGS ----------
String   PORT_MATCH = "";        // leave "" to search automatically
int      BAUD       = 115200;    // must match Serial.begin() in the board code
String[] WORDS  = { "kick",     "snare",     "hihat"     };  // must match PAD_WORD in the board code
String[] FILES  = { "kick.wav", "snare.wav", "hihat.wav" };  // sound files in the data folder
String[] LABELS = { "kick",     "snare",     "hi-hat"    };
// ------------------------------

Serial board;
SoundFile[] sounds = new SoundFile[3];
boolean[] playNow = new boolean[3];   // set when a word arrives, used in draw()
float[] flash = new float[3];         // brightness of each circle's flash
String status = "";

void setup() {
  size(780, 480);
  for (int i = 0; i < 3; i++) sounds[i] = new SoundFile(this, FILES[i]);
  connect();
}

// Runs each time a full line arrives from the board.
void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;
  line = trim(line);
  for (int i = 0; i < 3; i++) {
    if (line.equals(WORDS[i])) playNow[i] = true;   // RECEIVE: which drum was hit
  }
}

void draw() {
  background(240, 236, 228);

  for (int i = 0; i < 3; i++) {
    if (playNow[i]) {
      sounds[i].play();                             // USE: play that drum
      playNow[i] = false;
      flash[i] = 255;
    }

    float cx = width * (i + 1) / 4.0;
    float cy = height / 2 + 30;
    noStroke();
    fill(118, 93, 113, flash[i]);
    circle(cx, cy, 190);
    flash[i] = max(0, flash[i] - 20);
    noFill();
    stroke(22, 40, 59);
    strokeWeight(3);
    circle(cx, cy, 190);

    noStroke();
    fill(22, 40, 59);
    textSize(18);
    textAlign(CENTER);
    text(LABELS[i] + "  (" + (i + 1) + ")", cx, cy + 130);
  }

  textAlign(LEFT);
  textSize(16);
  text(status, 20, 20, width - 40, 60);
}

void keyPressed() {
  if (key == '1') playNow[0] = true;
  if (key == '2') playNow[1] = true;
  if (key == '3') playNow[2] = true;
}

// ---------- CONNECT TO THE BOARD ----------
// Finds the board's port by its name and opens it.
// You should not need to change this part. To choose the port yourself,
// set PORT_MATCH in the settings at the top.

void connect() {
  String[] ports = Serial.list();
  println("Ports on this computer:");
  printArray(ports);

  String name = findPort(ports);
  if (name == null) {
    status = "No board found. Check that the board is plugged in with a data cable. The ports on this computer are listed in the console below.";
    return;
  }

  try {
    board = new Serial(this, name, BAUD);
    board.bufferUntil('\n');          // run serialEvent() each time a full line arrives
    status = "Connected to " + name;
  } catch (Exception e) {
    status = "Found " + name + " but could not open it. Close the Arduino Serial Monitor, then run this sketch again.";
  }
}

String findPort(String[] ports) {
  // Your setting comes first.
  if (PORT_MATCH.length() > 0) {
    for (String p : ports) {
      if (p.contains(PORT_MATCH)) return p;
    }
    return null;
  }

  // Common names for this board on a Mac, then on Linux.
  String[] guesses = { "cu.usbserial", "cu.SLAB_USBtoUART", "cu.wchusbserial", "cu.usbmodem", "ttyUSB", "ttyACM" };
  for (String g : guesses) {
    for (String p : ports) {
      if (p.contains(g)) return p;
    }
  }

  // On Windows the board is usually the last COM port in the list.
  for (int i = ports.length - 1; i >= 0; i--) {
    if (ports[i].startsWith("COM")) return ports[i];
  }
  return null;
}
