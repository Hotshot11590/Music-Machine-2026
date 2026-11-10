// Feather ESP32: reads two photoresistors and sends the numbers to your computer.
// Each line it sends looks like:  812,3055   (sensor 1, sensor 2)
// 0 = dark, 4095 = very bright.
// It sends about 200 readings per second so the sound reacts almost instantly.

const int SENSOR1_PIN = A2;   // photoresistor 1 middle point goes here
const int SENSOR2_PIN = A3;   // photoresistor 2 middle point goes here

// Reads a pin 4 times and averages the results, which smooths out jitter.
int readSmooth(int pin) {
  long total = 0;
  for (int i = 0; i < 4; i++) {
    total += analogRead(pin);
  }
  return total / 4;
}

void setup() {
  Serial.begin(115200);   // open the USB connection to the computer
}

void loop() {
  Serial.print(readSmooth(SENSOR1_PIN));
  Serial.print(",");
  Serial.println(readSmooth(SENSOR2_PIN));
  delay(5);               // wait 5 ms, so about 200 readings per second
}
