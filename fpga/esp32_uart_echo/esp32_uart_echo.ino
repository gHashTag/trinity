/*
 * ESP32 UART Echo Test - Cable Verification
 * White+Blue wires twisted = loopback test
 */

#include <HardwareSerial.h>

// USB Serial for PC communication
#define BAUD_RATE 115200

// Hardware Serial to FPGA (TX on GPIO4, RX on GPIO5)
#define FPGA_RX_PIN 5   // Blue wire (RXD)
#define FPGA_TX_PIN 4   // White wire (TXD)

HardwareSerial SerialFPGA(1); // UART1

int charsReceived = 0;

void setup() {
  Serial.begin(BAUD_RATE);
  delay(500);

  Serial.println("\n\n========================================");
  Serial.println("  ESP32 UART ECHO TEST - Cable Check");
  Serial.println("========================================");

  // Initialize Hardware Serial to FPGA
  SerialFPGA.begin(BAUD_RATE, SERIAL_8N1, FPGA_RX_PIN, FPGA_TX_PIN);

  Serial.println("SERIALS INITIALIZED:");
  Serial.print("  PC <-> ESP32 (USB): ");
  Serial.print(BAUD_RATE);
  Serial.println(" baud");
  Serial.print("  ESP32 <-> FPGA: RX=");
  Serial.print(FPGA_RX_PIN);
  Serial.print(", TX=");
  Serial.println(FPGA_TX_PIN);
  Serial.println("\nReady for cable test!");
  Serial.println("Type anything - it will echo from FPGA");
  Serial.println("If twisted together - you should see echo!");
  Serial.println("Press Ctrl+A then K to exit screen");
  Serial.println("========================================\n");
}

void loop() {
  // Forward from PC to FPGA
  if (Serial.available()) {
    char c = Serial.read();
    SerialFPGA.write(c);
    charsReceived++;
  }

  // Receive from FPGA and echo back to PC
  if (SerialFPGA.available()) {
    char c = SerialFPGA.read();
    Serial.print("ECHO: ");
    Serial.print(c);
    Serial.print(" [");
    Serial.print(charsReceived);
    Serial.println(" chars received]");
  }

  // Delay a bit
  delay(1);
}
