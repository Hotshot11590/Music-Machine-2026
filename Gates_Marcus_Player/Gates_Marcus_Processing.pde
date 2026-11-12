import processing.serial.*;
import processing.sound.*;

Serial myPort;
SinOsc osc;

// Sensor Data
float playerDist = 20.0;
int buttonState = 0;

// Game Variables
float playerY = 0;
float targetFreq = 440;
int score = 0;
boolean isHit = false;

// Note generation
ArrayList<Note> notes = new ArrayList<Note>();

void setup() {
  size(1000, 600);
  
  // --- SERIAL SETUP ---
  printArray(Serial.list()); 
  // Port index set to 3 based on your specific Mac's USB assignment
  int portIndex = 3; 
  String portName = Serial.list()[portIndex];
  myPort = new Serial(this, portName, 115200);
  myPort.bufferUntil('\n'); // Wait for a new line to process data

  // --- AUDIO SETUP ---
  osc = new SinOsc(this);
  osc.play();
  osc.amp(0); // Start silent
}

void draw() {
  background(30);
  
  // 1. Map physical distance (5cm - 35cm) to Screen Y and Pitch
  // Closer to sensor = High pitch (top of screen). Farther = Low pitch (bottom)
  playerY = map(playerDist, 5, 35, 100, height-100);
  playerY = constrain(playerY, 50, height-50);
  
  targetFreq = map(playerDist, 5, 35, 800, 200); 
  targetFreq = constrain(targetFreq, 200, 800);
  
  // 2. Audio Control
  if (buttonState == 1) {
    osc.amp(0.5); // Turn volume on
    osc.freq(targetFreq);
  } else {
    osc.amp(0);   // Mute
  }
  
  // 3. Spawning Notes
  if (frameCount % 90 == 0) {
    // Spawn a new note at a random height on the right side of the screen
    float randomY = random(100, height-100);
    notes.add(new Note(width, randomY, 150));
  }
  
  // 4. Update and Draw Notes
  isHit = false;
  for (int i = notes.size() - 1; i >= 0; i--) {
    Note n = notes.get(i);
    n.update();
    n.display();
    
    // Hit Detection: Note is in the hit-zone (X = 150), button is pressed, and Y overlaps
    if (n.x < 150 + 20 && n.x + n.w > 150 - 20) {
      if (buttonState == 1 && abs(playerY - n.y) < 40) {
        n.isBeingHit = true;
        isHit = true;
        score += 1;
      } else {
        n.isBeingHit = false;
      }
    }
    
    // Remove notes off screen
    if (n.x + n.w < 0) {
      notes.remove(i);
    }
  }
  
  // 5. Draw Player Interface
  // Hit zone line
  stroke(255, 100);
  strokeWeight(2);
  line(150, 0, 150, height);
  
  // Player Cursor
  noStroke();
  if (isHit) {
    fill(0, 255, 0); // Green if scoring
  } else if (buttonState == 1) {
    fill(255, 200, 0); // Yellow if blowing/playing but missing
  } else {
    fill(255); // White if idle
  }
  circle(150, playerY, 40);
  
  // 6. UI / Score & Player Name
  fill(255);
  textSize(32);
  
  // Score in top left
  textAlign(LEFT, TOP);
  text("Score: " + (score/10), 20, 20); 
  
  // Player name in top right
  textAlign(RIGHT, TOP);
  text("Marcus Gates", width - 20, 20);
  
  // Reset text alignment back to default for the next frame
  textAlign(LEFT, BASELINE);
}

// --- SERIAL DATA PARSER ---
void serialEvent(Serial myPort) {
  try {
    String inString = myPort.readStringUntil('\n');
    if (inString != null) {
      inString = trim(inString); // Remove whitespace
      String[] data = split(inString, ','); // Split by comma
      
      if (data.length == 2) {
        playerDist = float(data[0]);
        buttonState = int(data[1]);
      }
    }
  } catch (Exception e) {
    // Ignore garbage data on startup
  }
}

// --- NOTE CLASS ---
class Note {
  float x, y, w, h;
  boolean isBeingHit = false;
  
  Note(float tempX, float tempY, float tempW) {
    x = tempX;
    y = tempY;
    w = tempW;
    h = 60;
  }
  
  void update() {
    x -= 6; // Speed of the note moving left
  }
  
  void display() {
    if (isBeingHit) {
      fill(0, 255, 100, 200); // Glow green when hit
    } else {
      fill(255, 100, 150, 200); // Default pink/red
    }
    rect(x, y - (h/2), w, h, 10);
  }
}
