// Feather ESP32: reads two photoresistors and sends the numbers to your computer.
// Each line it sends looks like:  812,3055   (sensor 1, sensor 2)
// 0 = dark, 4095 = very bright.

const int SENSOR1_PIN = A2;   // photoresistor 1 middle point goes here
const int SENSOR2_PIN = A3;   // photoresistor 2 middle point goes here

// Reads a pin 8 times and averages the results, which smooths out jitter.
int readSmooth(int pin) {
  long total = 0;
  for (int i = 0; i < 8; i++) {
    total += analogRead(pin);
  }
  return total / 8;
}

void setup() {
  Serial.begin(115200);   // open the USB connection to the computer
}

void loop() {
  Serial.print(readSmooth(SENSOR1_PIN));
  Serial.print(",");
  Serial.println(readSmooth(SENSOR2_PIN));
  delay(20);              // wait 20 ms, so about 50 readings per second
}
