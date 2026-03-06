// =============================================================================
// ESP32 <-> FPGA UART Bridge
// =============================================================================
//
// Подключение:
//   ESP32 GPIO4 (TX) -----> FPGA Pin L20 (UART_RX)
//   ESP32 GPIO5 (RX) <----- FPGA Pin K20 (UART_TX)
//   ESP32 GND      -----> FPGA GND (ОБЯЗАТЕЛЬНО!)
//
// Команды (отправлять через Serial Monitor):
//   p - PING (FPGA отвечает с 0x83)
//   o - LED ON
//   f - LED OFF
//   b - LED BLINK
//   h - Help
//
// Бодрейт: 115200
// Формат: 8N1 (8 data bits, No parity, 1 stop bit)
// =============================================================================

#include <Arduino.h>

// Пины
#define RX_PIN 5
#define TX_PIN 4
#define BAUD_RATE 115200

// Команды FPGA
const uint8_t CMD_PING      = 0x03;
const uint8_t CMD_LED_ON    = 0x10;
const uint8_t CMD_LED_OFF   = 0x11;
const uint8_t CMD_LED_BLINK = 0x12;

// Ответы FPGA
const uint8_t RESP_PONG     = 0x83;
const uint8_t RESP_OK       = 0xFF;
const uint8_t RESP_ACK      = 0xAA;

// Вторый Serial для связи с FPGA (UART1)
HardwareSerial SerialFPGA(1);

// Статистика
struct {
    unsigned long packets_sent;
    unsigned long packets_received;
    unsigned long errors;
    unsigned long last_ping_ms;
} stats = {0, 0, 0, 0};

// Время отклика
unsigned long last_send_time = 0;
unsigned long last_response_time = 0;

void setup() {
    // Инициализация Serial Monitor
    Serial.begin(115200);
    delay(1000);

    // Инициализация UART для FPGA
    SerialFPGA.begin(BAUD_RATE, SERIAL_8N1, RX_PIN, TX_PIN);

    // Приветствие
    printBanner();
    printHelp();
}

void loop() {
    // Обработка команд из Serial Monitor
    if (Serial.available()) {
        char cmd = Serial.read();
        processCommand(cmd);
    }

    // Обработка ответов от FPGA
    if (SerialFPGA.available()) {
        uint8_t resp = SerialFPGA.read();
        handleResponse(resp);
    }

    // Автоматический ping каждые 5 секунд
    static unsigned long last_auto_ping = 0;
    if (millis() - last_auto_ping > 5000) {
        last_auto_ping = millis();
        sendPing(true);  // silent mode
    }
}

// ============================================================================
// Обработка команд
// ============================================================================

void processCommand(char cmd) {
    // Игнорировать пробелы и переносы строк
    if (cmd == ' ' || cmd == '\n' || cmd == '\r') return;

    switch (cmd) {
        case 'p':  // PING
            sendPing(false);
            break;

        case 'o':  // LED ON
            Serial.println("Sending LED ON...");
            sendCommand(CMD_LED_ON);
            break;

        case 'f':  // LED OFF
            Serial.println("Sending LED OFF...");
            sendCommand(CMD_LED_OFF);
            break;

        case 'b':  // LED BLINK
            Serial.println("Sending LED BLINK...");
            sendCommand(CMD_LED_BLINK);
            break;

        case 's':  // Status
            printStatus();
            break;

        case 'h':  // Help
            printHelp();
            break;

        case 't':  // Test sequence
            runTestSequence();
            break;

        default:
            Serial.print("Unknown command: ");
            Serial.println(cmd);
            Serial.println("Type 'h' for help");
            break;
    }
}

void sendPing(bool silent) {
    if (!silent) Serial.print("PING -> FPGA... ");
    sendCommand(CMD_PING);
    if (!silent) {
        stats.last_ping_ms = millis();
    }
}

void sendCommand(uint8_t cmd) {
    SerialFPGA.write(cmd);
    stats.packets_sent++;
    last_send_time = millis();
}

// ============================================================================
// Обработка ответов
// ============================================================================

void handleResponse(uint8_t resp) {
    last_response_time = millis();
    stats.packets_received++;

    unsigned long latency = last_response_time - last_send_time;

    Serial.print("FPGA Response: 0x");
    Serial.print(resp, HEX);
    Serial.print(" (");

    switch (resp) {
        case RESP_PONG:
            Serial.print("PONG");
            break;
        case RESP_OK:
            Serial.print("OK");
            break;
        case RESP_ACK:
            Serial.print("ACK");
            break;
        default:
            Serial.print("UNKNOWN");
            break;
    }

    Serial.print(") Latency: ");
    Serial.print(latency);
    Serial.println(" ms");
}

// ============================================================================
// Тестовая последовательность
// ============================================================================

void runTestSequence() {
    Serial.println("\n=== Running Test Sequence ===\n");

    // Test 1: Ping
    Serial.println("Test 1: PING");
    sendPing(false);
    waitForResponse(1000);

    delay(500);

    // Test 2: LED ON
    Serial.println("\nTest 2: LED ON");
    sendCommand(CMD_LED_ON);
    waitForResponse(1000);

    delay(1000);

    // Test 3: LED OFF
    Serial.println("\nTest 3: LED OFF");
    sendCommand(CMD_LED_OFF);
    waitForResponse(1000);

    delay(500);

    // Test 4: LED BLINK
    Serial.println("\nTest 4: LED BLINK (3x)");
    for (int i = 0; i < 3; i++) {
        sendCommand(CMD_LED_BLINK);
        waitForResponse(1000);
        delay(500);
    }

    Serial.println("\n=== Test Sequence Complete ===\n");
}

void waitForResponse(unsigned long timeout) {
    unsigned long start = millis();
    while (millis() - start < timeout) {
        if (SerialFPGA.available()) {
            handleResponse(SerialFPGA.read());
            return;
        }
        delay(10);
    }
    Serial.println("Timeout - No response");
    stats.errors++;
}

// ============================================================================
// Вспомогательные функции
// ============================================================================

void printBanner() {
    Serial.println("\n╔════════════════════════════════════════════════════════╗");
    Serial.println("║    ESP32 <-> FPGA UART Bridge                         ║");
    Serial.println("║    Trinity FPGA Development                           ║");
    Serial.println("║    φ² + 1/φ² = 3 = TRINITY                            ║");
    Serial.println("╚════════════════════════════════════════════════════════╝\n");
}

void printHelp() {
    Serial.println("Available Commands:");
    Serial.println("  p - PING (test communication)");
    Serial.println("  o - LED ON");
    Serial.println("  f - LED OFF");
    Serial.println("  b - LED BLINK");
    Serial.println("  t - Run test sequence");
    Serial.println("  s - Show statistics");
    Serial.println("  h - Show this help");
    Serial.println("\nAuto-ping every 5 seconds...\n");
}

void printStatus() {
    Serial.println("\n=== Statistics ===");
    Serial.print("Packets Sent:     ");
    Serial.println(stats.packets_sent);
    Serial.print("Packets Received: ");
    Serial.println(stats.packets_received);
    Serial.print("Errors:           ");
    Serial.println(stats.errors);
    Serial.print("Success Rate:     ");
    Serial.print(stats.packets_sent > 0 ?
                 (100.0 * stats.packets_received / stats.packets_sent) : 0);
    Serial.println("%");

    if (stats.last_ping_ms > 0) {
        Serial.print("Last Ping:        ");
        Serial.print(millis() - stats.last_ping_ms / 1000);
        Serial.println(" seconds ago");
    }

    Serial.print("Uptime:           ");
    Serial.print(millis() / 1000);
    Serial.println(" seconds");
    Serial.println();
}
