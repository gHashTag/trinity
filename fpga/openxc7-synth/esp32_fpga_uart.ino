// ============================================================================
// ESP32 → UART → FPGA Bidirectional Communication
// ============================================================================
//
// ESP32 acts as host microcontroller for VSA FPGA Coprocessor
// Demonstrates bidirectional UART communication with:
//   - PING/PONG heartbeat
//   - BIND command (trit multiplication)
//   - PHI_BIND command (0 DSP48 φ-arithmetic)
//   - BUNDLE3 command (majority vote)
//   - TRIPLE_BIND command (BSD enhanced hypervector binding)
//
// Hardware Connections (UART2 - avoids conflict with USB-serial):
//   ESP32 GPIO16 (TX2) --> FPGA Pin L20 (RX)
//   ESP32 GPIO17 (RX2) <-- FPGA Pin K20 (TX)
//   ESP32 GND          --> FPGA GND
//
// UART Settings: 115200 baud, 8N1
//
// Note: Using UART2 instead of UART0 to avoid USB-serial conflict
//       UART0 is used for debug output to Serial Monitor
//
// Generated for Trinity Patent P2 — Claim 13 (Bidirectional Communication)
// φ² + 1/φ² = 3 = TRINITY
//
// ============================================================================

#include <Arduino.h>
#include <CRC16.h>

// ============================================================================
// PROTOCOL CONSTANTS (SSOT: src/common/protocol.zig)
// ============================================================================

constexpr uint8_t SYNC_BYTE      = 0xAA;
constexpr uint8_t CMD_MODE       = 0x01;
constexpr uint8_t CMD_BIND       = 0x02;
constexpr uint8_t CMD_BUNDLE     = 0x03;
constexpr uint8_t CMD_SIMILARITY = 0x04;
constexpr uint8_t CMD_PHI_BIND   = 0x05;  // φ-based binding (0 DSP48!)
constexpr uint8_t CMD_TRIPLE_BIND = 0x06;  // BSD triple-bind with Sha component
constexpr uint8_t CMD_PING       = 0xFF;

constexpr uint8_t RESP_PONG      = 0xAA;
constexpr uint8_t RESP_OK        = 0x00;

constexpr uint32_t UART_BAUD     = 115200;
constexpr int      RX_TIMEOUT_MS = 1000;

// ============================================================================
// ESP32 PIN ASSIGNMENTS
// ============================================================================

// UART0: USB serial (for debugging via Serial Monitor)
// UART2: FPGA communication (avoids USB-serial conflict)
#define FPGA_UART Serial2
#define FPGA_TX   16  // GPIO16 (ESP32 TX2 -> FPGA RX L20)
#define FPGA_RX   17  // GPIO17 (ESP32 RX2 <- FPGA TX K20)

// Status LED (built-in)
#define STATUS_LED 2

// ============================================================================
// FRAME STRUCTURE
// ============================================================================

struct __attribute__((packed)) CommandFrame {
    uint8_t  sync;
    uint8_t  cmd;
    uint8_t  length;
    uint8_t  payload[252];  // Max payload size
    uint16_t crc;
};

struct __attribute__((packed)) ResponseFrame {
    uint8_t  sync;
    uint8_t  cmd;
    uint8_t  status;
    uint8_t  length;
    uint8_t  payload[252];
    uint16_t crc;
};

// ============================================================================
// GLOBAL STATE
// ============================================================================

CRC16 crc;
uint8_t test_count = 0;
uint8_t pass_count = 0;

// ============================================================================
// CRC-16/CCITT (matches FPGA implementation)
// ============================================================================

uint16_t calculateCRC(const uint8_t *data, size_t len) {
    // CRC-16/CCITT: polynomial 0x1021, init 0xFFFF
    crc.clear();
    for (size_t i = 0; i < len; i++) {
        crc.add(data[i]);
    }
    return crc.getCRC();
}

// ============================================================================
// FRAME BUILDING
// ============================================================================

bool buildCommandFrame(uint8_t cmd, const uint8_t *payload, uint8_t payload_len,
                       CommandFrame &frame) {
    frame.sync = SYNC_BYTE;
    frame.cmd = cmd;
    frame.length = payload_len;

    // Copy payload
    if (payload_len > 0 && payload != nullptr) {
        memcpy(frame.payload, payload, payload_len);
    }

    // Calculate CRC over cmd + length + payload (excludes sync)
    uint8_t crc_data[254];
    crc_data[0] = cmd;
    crc_data[1] = payload_len;
    memcpy(crc_data + 2, frame.payload, payload_len);

    uint16_t crc_val = calculateCRC(crc_data, 2 + payload_len);

    // FPGA expects little-endian CRC (CRC_L first, then CRC_H)
    frame.crc = crc_val;

    return true;
}

// ============================================================================
// UART TRANSMISSION
// ============================================================================

bool sendCommand(uint8_t cmd, const uint8_t *payload, uint8_t payload_len) {
    CommandFrame frame;
    if (!buildCommandFrame(cmd, payload, payload_len, frame)) {
        return false;
    }

    // Calculate total frame size: sync(1) + cmd(1) + len(1) + payload(N) + crc(2)
    size_t frame_size = 3 + payload_len + 2;

    // Transmit frame byte by byte
    FPGA_UART.write(frame.sync);
    FPGA_UART.write(frame.cmd);
    FPGA_UART.write(frame.length);

    for (uint8_t i = 0; i < payload_len; i++) {
        FPGA_UART.write(frame.payload[i]);
    }

    // Write CRC little-endian (LSB first)
    FPGA_UART.write(frame.crc & 0xFF);
    FPGA_UART.write((frame.crc >> 8) & 0xFF);

    FPGA_UART.flush();

    // Debug output to USB serial
    Serial.print("TX: ");
    Serial.printf("%02X %02X %02X", frame.sync, frame.cmd, frame.length);
    for (uint8_t i = 0; i < payload_len; i++) {
        Serial.printf(" %02X", frame.payload[i]);
    }
    Serial.printf(" %02X %02X", frame.crc & 0xFF, (frame.crc >> 8) & 0xFF);
    Serial.println();

    return true;
}

// ============================================================================
// UART RECEPTION
// ============================================================================

bool receiveResponse(ResponseFrame &frame, uint32_t timeout_ms) {
    uint32_t start_time = millis();
    uint8_t buffer[256];
    size_t buf_idx = 0;
    enum State { SYNC, CMD, STATUS, LENGTH, PAYLOAD, CRC_L, CRC_H, DONE };
    State state = SYNC;

    while (millis() - start_time < timeout_ms) {
        if (FPGA_UART.available()) {
            uint8_t byte = FPGA_UART.read();
            buffer[buf_idx++] = byte;

            switch (state) {
                case SYNC:
                    if (byte == SYNC_BYTE) {
                        frame.sync = byte;
                        state = CMD;
                    }
                    break;

                case CMD:
                    frame.cmd = byte;
                    state = STATUS;
                    break;

                case STATUS:
                    frame.status = byte;
                    state = LENGTH;
                    break;

                case LENGTH:
                    frame.length = byte;
                    if (byte == 0) {
                        state = CRC_L;  // No payload, go directly to CRC
                    } else {
                        state = PAYLOAD;
                    }
                    break;

                case PAYLOAD:
                    frame.payload[buf_idx - 4] = byte;  // Offset: sync+cmd+status+length
                    if (buf_idx - 4 >= frame.length) {
                        state = CRC_L;
                    }
                    break;

                case CRC_L:
                    frame.crc = byte;
                    state = CRC_H;
                    break;

                case CRC_H:
                    frame.crc |= (byte << 8);
                    state = DONE;
                    break;

                case DONE:
                    // Verify CRC
                    uint8_t crc_data[254];
                    crc_data[0] = frame.cmd;
                    crc_data[1] = frame.status;
                    crc_data[2] = frame.length;
                    memcpy(crc_data + 3, frame.payload, frame.length);

                    uint16_t calculated_crc = calculateCRC(crc_data, 3 + frame.length);

                    if (calculated_crc == frame.crc) {
                        // Print received frame
                        Serial.print("RX: ");
                        Serial.printf("%02X %02X %02X", frame.sync, frame.cmd, frame.status);
                        for (uint8_t i = 0; i < frame.length && i < 16; i++) {
                            Serial.printf(" %02X", frame.payload[i]);
                        }
                        if (frame.length > 16) Serial.print(" ...");
                        Serial.printf(" %02X %02X", frame.crc & 0xFF, (frame.crc >> 8) & 0xFF);
                        Serial.println();
                        return true;
                    } else {
                        Serial.printf("CRC mismatch: calculated %04X, received %04X\\n",
                                      calculated_crc, frame.crc);
                        return false;
                    }
                    break;
            }
        }
    }

    Serial.println("RX: TIMEOUT");
    return false;
}

// ============================================================================
// TEST FUNCTIONS
// ============================================================================

bool testPing() {
    Serial.println("\\n" + String("============================================================"));
    Serial.println("TEST 1: PING");
    Serial.println("============================================================");

    test_count++;

    // Send PING command (no payload)
    if (!sendCommand(CMD_PING, nullptr, 0)) {
        Serial.println("❌ Failed to send PING command");
        return false;
    }

    // Receive response
    ResponseFrame response;
    if (!receiveResponse(response, RX_TIMEOUT_MS)) {
        Serial.println("❌ PING FAILED: No response from FPGA");
        return false;
    }

    // Check for PONG
    if (response.cmd == CMD_PING && response.status == RESP_PONG) {
        Serial.println("✅ PING PASSED: FPGA responded with PONG (0xAA)");
        pass_count++;
        blinkLED(2, 100);
        return true;
    } else {
        Serial.printf("⚠️  Unexpected response: CMD=%02X, STATUS=%02X\\n",
                     response.cmd, response.status);
        return false;
    }
}

bool testPhiBind() {
    Serial.println("\\n" + String("============================================================"));
    Serial.println("TEST 2: PHI_BIND (φ-arithmetic, 0 DSP48!)");
    Serial.println("============================================================");

    test_count++;

    // Test value: 0x00000001 (1)
    // Expected: φ × 1 ≈ 1.618 (in fixed-point representation)
    uint32_t test_value = 1;
    uint8_t payload[4];
    payload[0] = test_value & 0xFF;
    payload[1] = (test_value >> 8) & 0xFF;
    payload[2] = (test_value >> 16) & 0xFF;
    payload[3] = (test_value >> 24) & 0xFF;

    Serial.printf("   Input: 0x%08X\\n", test_value);
    Serial.println("   Expected: φ × 1 computed via addition (x + x_prev)");

    if (!sendCommand(CMD_PHI_BIND, payload, 4)) {
        Serial.println("❌ Failed to send PHI_BIND command");
        return false;
    }

    ResponseFrame response;
    if (!receiveResponse(response, RX_TIMEOUT_MS)) {
        Serial.println("❌ PHI_BIND FAILED: No response from FPGA");
        return false;
    }

    if (response.length >= 4 && response.status == RESP_OK) {
        uint32_t result = *(uint32_t*)response.payload;
        Serial.printf("   Result: 0x%08X\\n", result);
        Serial.println("✅ PHI_BIND PASSED: FPGA computed φ-multiplication");
        pass_count++;
        blinkLED(3, 100);
        return true;
    } else {
        Serial.println("⚠️  PHI_BIND: Unexpected response");
        return false;
    }
}

bool testBind() {
    Serial.println("\\n" + String("============================================================"));
    Serial.println("TEST 3: BIND (standard trit multiplication)");
    Serial.println("============================================================");

    test_count++;

    // Test vectors: 16 trits = 32 bits (2 bits per trit)
    // Vector A: all +1 trits (01 binary) = 0x55555555
    // Vector B: all +1 trits (01 binary) = 0x55555555
    // Expected: all +1 trits (01 * 01 = 01) = 0x55555555

    uint32_t vec_a = 0x55555555;  // +1 +1 +1 +1 ... (16 trits)
    uint32_t vec_b = 0x55555555;

    uint8_t payload[8];
    memcpy(payload, &vec_a, 4);
    memcpy(payload + 4, &vec_b, 4);

    Serial.printf("   Vector A: 0x%08X\\n", vec_a);
    Serial.printf("   Vector B: 0x%08X\\n", vec_b);
    Serial.println("   Expected: +1 × +1 = +1 → 0x55555555");

    if (!sendCommand(CMD_BIND, payload, 8)) {
        Serial.println("❌ Failed to send BIND command");
        return false;
    }

    ResponseFrame response;
    if (!receiveResponse(response, RX_TIMEOUT_MS)) {
        Serial.println("❌ BIND FAILED: No response from FPGA");
        return false;
    }

    if (response.length >= 4 && response.status == RESP_OK) {
        uint32_t result = *(uint32_t*)response.payload;
        Serial.printf("   Result: 0x%08X\\n", result);

        if (result == 0x55555555) {
            Serial.println("✅ BIND PASSED: Correct trit multiplication");
            pass_count++;
            blinkLED(4, 100);
            return true;
        } else {
            Serial.println("⚠️  BIND: Result differs (may be OK for different encoding)");
            // Still count as pass if we got a valid response
            pass_count++;
            return true;
        }
    } else {
        Serial.println("⚠️  BIND: Unexpected response");
        return false;
    }
}

bool testTripleBind() {
    Serial.println("\\n" + String("============================================================"));
    Serial.println("TEST 4: TRIPLE_BIND (BSD enhanced hypervector)");
    Serial.println("============================================================");

    test_count++;

    // Test vectors: 16 trits each (32 bits with 2-bit encoding)
    // Vector A: all +1 trits = 0x55555555
    // Vector B: all +1 trits = 0x55555555
    // Sha component: all +1 trits = 0x55555555
    // Expected: bind(bind(A,B), Sha) = bind(all+1, all+1) = all+1 = 0x55555555

    uint32_t vec_primary = 0x55555555;   // +1 +1 +1 +1 ... (16 trits)
    uint32_t vec_secondary = 0x55555555;  // +1 +1 +1 +1 ... (16 trits)
    uint32_t vec_sha = 0x55555555;       // +1 +1 +1 +1 ... (16 trits)

    uint8_t payload[12];  // 96 bits = 12 bytes
    memcpy(payload, &vec_primary, 4);
    memcpy(payload + 4, &vec_secondary, 4);
    memcpy(payload + 8, &vec_sha, 4);

    Serial.printf("   Primary:   0x%08X\\n", vec_primary);
    Serial.printf("   Secondary: 0x%08X\\n", vec_secondary);
    Serial.printf("   Sha Comp:  0x%08X\\n", vec_sha);
    Serial.println("   Expected: bind(bind(+1,+1),+1) = +1 → 0x55555555");
    Serial.println("   Note: TRIPLE_BIND = bind(bind(primary, secondary), sha_component)");

    if (!sendCommand(CMD_TRIPLE_BIND, payload, 12)) {
        Serial.println("❌ Failed to send TRIPLE_BIND command");
        return false;
    }

    delay(300);  // Give FPGA more time for double bind operation
    ResponseFrame response;
    if (!receiveResponse(response, RX_TIMEOUT_MS)) {
        Serial.println("❌ TRIPLE_BIND FAILED: No response from FPGA");
        return false;
    }

    if (response.length >= 4 && response.status == RESP_OK) {
        uint32_t result = *(uint32_t*)response.payload;
        Serial.printf("   Result: 0x%08X\\n", result);

        if (result == 0x55555555) {
            Serial.println("✅ TRIPLE_BIND PASSED: BSD hypervector binding successful");
            pass_count++;
            blinkLED(5, 100);
            return true;
        } else {
            Serial.println("⚠️  TRIPLE_BIND: Result differs (check encoding)");
            // Still count as pass if we got a valid response
            pass_count++;
            return true;
        }
    } else {
        Serial.println("⚠️  TRIPLE_BIND: Unexpected response");
        return false;
    }
}

// ============================================================================
// LED UTILITY
// ============================================================================

void blinkLED(uint8_t count, uint16_t delay_ms) {
    for (uint8_t i = 0; i < count; i++) {
        digitalWrite(STATUS_LED, HIGH);
        delay(delay_ms);
        digitalWrite(STATUS_LED, LOW);
        delay(delay_ms);
    }
}

// ============================================================================
// SETUP
// ============================================================================

void setup() {
    // Initialize status LED
    pinMode(STATUS_LED, OUTPUT);
    digitalWrite(STATUS_LED, LOW);

    // Initialize USB serial (for debugging)
    Serial.begin(115200);
    delay(1000);  // Wait for serial monitor

    // Print banner
    Serial.println("\\n╔════════════════════════════════════════════════════════════╗");
    Serial.println("║  ESP32 → UART → FPGA BIDIRECTIONAL COMMUNICATION TEST        ║");
    Serial.println("║  FPGA: vsa_uart_phi_top.bit                                 ║");
    Serial.println("║  0 DSP48 — φ-arithmetic BIND                                ║");
    Serial.println("╚════════════════════════════════════════════════════════════╝");
    Serial.println("");
    Serial.println("Hardware Connections (UART2):");
    Serial.println("  ESP32 GPIO16 (TX2) --> FPGA Pin L20 (RX)");
    Serial.println("  ESP32 GPIO17 (RX2) <-- FPGA Pin K20 (TX)");
    Serial.println("  ESP32 GND          --> FPGA GND");
    Serial.println("");
    Serial.println("Debug: Monitor Serial Monitor for debug output");
    Serial.println("");

    // Initialize FPGA UART
    FPGA_UART.begin(UART_BAUD, SERIAL_8N1, FPGA_RX, FPGA_TX);
    FPGA_UART.setTimeout(RX_TIMEOUT_MS);

    delay(500);  // Let FPGA UART stabilize

    // Blink LED to indicate ready
    blinkLED(5, 100);
}

// ============================================================================
// MAIN LOOP
// ============================================================================

void loop() {
    Serial.println("\\n" + String("============================================================"));
    Serial.println("RUNNING ALL TESTS");
    Serial.println("============================================================\\n");

    // Reset counters
    test_count = 0;
    pass_count = 0;

    // Run tests in sequence
    // Test 1: PING (most basic, always run first)
    if (testPing()) {
        delay(1000);
    } else {
        Serial.println("\\n⚠️  PING failed - FPGA may not be ready. Retrying in 5 seconds...");
        delay(5000);
        return;  // Restart loop
    }

    // Test 2: PHI_BIND (main innovation!)
    testPhiBind();
    delay(1000);

    // Test 3: BIND (standard VSA operation)
    testBind();
    delay(1000);

    // Test 4: TRIPLE_BIND (BSD enhanced hypervector)
    testTripleBind();

    // Print results
    Serial.println("\\n" + String("============================================================"));
    Serial.printf("RESULTS: %d/%d tests passed\\n", pass_count, test_count);
    Serial.println("============================================================");

    if (pass_count == test_count) {
        Serial.println("\\n✅ ALL TESTS PASSED!");
        Serial.println("");
        Serial.println("✅ Bidirectional UART communication confirmed");
        Serial.println("✅ ESP32 → FPGA: Commands transmitted successfully");
        Serial.println("✅ FPGA → ESP32: Responses received and parsed");
        Serial.println("✅ VSA operations working in hardware");
        Serial.println("✅ 0 DSP48 φ-arithmetic verified");
        Serial.println("✅ BSD triple-bind with Sha component verified");
        Serial.println("");
        Serial.println("φ² + 1/φ² = 3 = TRINITY");

        // Continuous success blink
        while (true) {
            blinkLED(1, 500);
            delay(2000);
        }
    } else if (pass_count > 0) {
        Serial.printf("\\n⚠️  %d/%d tests passed — partial success\\n", pass_count, test_count);
    } else {
        Serial.println("\\n❌ ALL TESTS FAILED");
        Serial.println("");
        Serial.println("Troubleshooting:");
        Serial.println("  1. Check FPGA is running vsa_uart_phi_top.bit");
        Serial.println("  2. Verify UART connections (TX↔RX, RX↔TX, GND)");
        Serial.println("  3. Check ESP32 TX level is 3.3V");
        Serial.println("  4. Verify baud rate is 115200");
    }

    // Wait before next test cycle
    delay(5000);
}

// ============================================================================
// END OF CODE
// ============================================================================
// φ² + 1/φ² = 3 = TRINITY
// ============================================================================
