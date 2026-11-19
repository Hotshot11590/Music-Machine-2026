/*
  HONKY TONK PIANO: Processing sketch

  What it does:
  Each button plays a chord on a honky-tonk piano.
  Every note is played twice, the second copy slightly out of tune,
  which is what makes a piano sound honky-tonk.

  Before you run it:
  1. Install the Sound library (same as the joystick starter).
  2. Put one clean piano note in this sketch's data folder, named piano_D4.wav.
     Every other note is made by changing its playback speed.
  3. Upload piano_board_v2.ino. Close the Arduino Serial Monitor.

  Keys (test without the board):
  1 to 7   play chords 0 to 6
*/

import processing.serial.*;
import processing.sound.*;

// ---------- SETTINGS ----------
String  PORT_MATCH = "";             // leave "" to search automatically
int     BAUD       = 115200;
String  NOTE_FILE  = "piano_D4.aiff"; // one piano note, recorded at D4
float   DETUNE     = 1.007;          // the out-of-tune copy. Try 1.004 to 1.012
float   MAIN_VOL   = 0.6;
float   DETUNE_VOL = 0.4;
// ------------------------------

// Each row is one button's chord, in semitones above D4 (negative = below).
// Currently the D major chords: D, Em, F#m, G, A, Bm, C#dim.
// To match Rainbow Road, change these numbers (D=0, E=2, F#=4, G=5, A=7, B=9, C#=11).
int[][] CHORDS = {
  {0, 4, 7},      // D
  {2, 5, 9},      // Em
  {4, 7, 11},     // F#m
  {5, 9, 12},     // G
  {-5, -1, 2},    // A
  {-3, 0, 4},     // Bm
  {-1, 2, 5}      // C#dim
};
String[] NAMES = {"D", "Em", "F#m", "G", "A", "Bm", "C#dim"};

final int POOL = 48;         // lets many notes ring at once
SoundFile[] pool = new SoundFile[POOL];
int poolIdx = 0;

Serial board;
String status = "";
String lastChord = "-";

void setup() {
  size(640, 300);
  for (int i = 0; i < POOL; i++) pool[i] = new SoundFile(this, NOTE_FILE);
  connect();
}

void playChord(int i) {
  if (i < 0 || i >= CHORDS.length) return;
  for (int semis : CHORDS[i]) {
    float rate = pow(2, semis / 12.0);
    voice(rate, MAIN_VOL);
    voice(rate * DETUNE, DETUNE_VOL);   // the honky-tonk layer
  }
  lastChord = NAMES[i];
}

void voice(float rate, float amp) {
  SoundFile f = pool[poolIdx];
  poolIdx = (poolIdx + 1) % POOL;
  f.stop();
  f.rate(rate);
  f.amp(amp);
  f.play();
}

// RECEIVE: lines like P,3 arrive here. Read every line that is waiting.
void serialEvent(Serial p) {
  String line;
  while ((line = p.readStringUntil('\n')) != null) {
    line = trim(line);
    String[] parts = split(line, ',');
    if (parts.length == 2 && parts[0].equals("P")) {
      playChord(int(parts[1]));
    }
  }
}

void keyPressed() {
  if (key >= '1' && key <= '7') playChord(key - '1');
}

void draw() {
  background(240, 236, 228);
  fill(22, 40, 59);
  textSize(16);
  text(status, 20, 20, width - 40, 60);
  textSize(48);
  text(lastChord, 20, 160);
}

// ---------- CONNECT TO THE BOARD ----------
void connect() {
  String[] ports = Serial.list();
  println("Ports on this computer:");
  printArray(ports);

  String name = findPort(ports);
  if (name == null) {
    status = "No board found. Check that the board is plugged in with a data cable. Use keys 1 to 7 to test the sound.";
    return;
  }
  try {
    board = new Serial(this, name, BAUD);
    board.bufferUntil('\n');
    status = "Connected to " + name;
  } catch (Exception e) {
    status = "Found " + name + " but could not open it. Close the Arduino Serial Monitor, then run again.";
  }
}

String findPort(String[] ports) {
  if (PORT_MATCH.length() > 0) {
    for (String p : ports) {
      if (p.contains(PORT_MATCH)) return p;
    }
    return null;
  }
  String[] guesses = { "cu.usbserial", "cu.SLAB_USBtoUART", "cu.wchusbserial", "cu.usbmodem", "ttyUSB", "ttyACM" };
  for (String g : guesses) {
    for (String p : ports) {
      if (p.contains(g)) return p;
    }
  }
  for (int i = ports.length - 1; i >= 0; i--) {
    if (ports[i].startsWith("COM")) return ports[i];
  }
  return null;
}
