// =============================================================================
// UART Bridge v2 — FT232RL ↔ FPGA (FIXED)
// Pin mapping for QMTech XC7A100T-1FGG676C
// =============================================================================
// FT232RL Wiring:
//   RXD (green)  → J2 pin 5  → L20 → FPGA uart_tx
//   TXD (white)  → J2 pin 6  → K20 → FPGA uart_rx
//   GND (black) → J2 pin 1  → GND
// =============================================================================
// Fixes v2:
//   1. Added TX busy flag (prevents overwrite)
//   2. Fixed RX shift direction (right shift for LSB-first)
//   3. Fixed RX byte collection (correct bit order)
//   4. Explicit idle HIGH state
// =============================================================================

module uart_bridge_v2 (
    input  wire clk,           // 50 MHz (M22)
    input  wire uart_rx,       // From FT232RL TXD (K20)
    output wire uart_tx,       // To FT232RL RXD (L20)
    output wire led            // Status LED (T23)
);

    // ========================================================================
    // UART Configuration — 115200 baud @ 50 MHz
    // ========================================================================
    localparam CLK_FREQ = 50_000_000;
    localparam BAUD_RATE = 115200;
    localparam BIT_DIV = CLK_FREQ / BAUD_RATE;  // 434

    // ========================================================================
    // UART Receiver (from FT232RL TXD) — LSB-first UART standard
    // ========================================================================
    reg [15:0] rx_cnt = 0;
    reg [3:0]  rx_bit = 0;      // 0=idle, 1=start, 2-9=data, 10=stop
    reg [7:0]  rx_shift = 0;      // Сдвиговый регистр (LSB-first)
    reg [7:0]  rx_byte = 0;      // Принятый байт
    reg        rx_valid = 0;      // Байт принят

    // Двухступенчатый синхронизатор
    reg rx_sync1 = 1, rx_sync2 = 1;
    always @(posedge clk) begin
        rx_sync1 <= uart_rx;
        rx_sync2 <= rx_sync1;
    end

    // UART State Machine (LSB-first: LSB comes first)
    always @(posedge clk) begin
        rx_valid <= 0;  // Пульс одного такта

        if (rx_bit == 0) begin
            // IDLE — ждем стартовый бит (LOW)
            if (rx_sync2 == 0) begin
                rx_bit <= 1;      // Начинаем прием (START бит)
                rx_cnt <= BIT_DIV / 2 - 1;  // Сэмплируем по центру бита
            end
        end else if (rx_bit == 1) begin
            // START бит — переход к данным
            if (rx_cnt == 0) begin
                rx_cnt <= BIT_DIV;
                rx_bit <= 2;      // Первый бит данных
            end else begin
                rx_cnt <= rx_cnt - 1;
            end
        end else if (rx_bit >= 2 && rx_bit <= 9) begin
            // DATA биты (LSB-first: бит 2 = LSB, бит 9 = MSB)
            if (rx_cnt == 0) begin
                rx_cnt <= BIT_DIV;
                // Сдвигаем вправо: новый бит в MSB, остальные вниз
                rx_shift <= {rx_sync2, rx_shift[7:1]};
                rx_bit <= rx_bit + 1;
            end else begin
                rx_cnt <= rx_cnt - 1;
            end
        end else if (rx_bit == 10) begin
            // STOP бит — валидация
            if (rx_cnt == 0) begin
                if (rx_sync2 == 1) begin  // Стоп бит должен быть HIGH
                    // rx_shift содержит все 8 битов данных в правильном порядке
                    rx_byte <= rx_shift;
                    rx_valid <= 1;
                end
                rx_cnt <= BIT_DIV;
                rx_bit <= 0;  // Возврат в IDLE
            end else begin
                rx_cnt <= rx_cnt - 1;
            end
        end else begin
            // Некорректное состояние — сброс
            rx_bit <= 0;
            rx_cnt <= 0;
        end
    end

    // ========================================================================
    // UART Transmitter (to FT232RL RXD) — LSB-first UART standard
    // ========================================================================
    reg [15:0] tx_cnt = 0;
    reg [3:0]  tx_bit = 0;      // 0=idle, 1-10=передача
    reg [9:0]  tx_shift = 10'b1111111111;  // Idle = HIGH все биты
    reg [7:0]  tx_byte = 0;
    reg        tx_start = 0;     // Запуск передачи
    reg        tx_busy = 0;      // Флаг занятости (ФИКС v2)
    reg        tx_ready = 1;     // Готов к приему нового байта

    assign uart_tx = tx_shift[0];  // Младший бит выходит первым

    always @(posedge clk) begin
        tx_start <= 0;  // Сброс после записи

        if (tx_bit == 0) begin
            // IDLE — ждем команду на передачу
            tx_ready <= 1;  // Готов к приему
            if (tx_start && !tx_busy) begin
                // Формируем пакет: STOP(1) + D7...D0 + START(0)
                // LSB-first: бит 0 = START(0), бит 9 = STOP(1)
                tx_shift <= {1'b1, tx_byte, 1'b0};  // [STOP, DATA, START]
                tx_bit <= 1;      // Начинаем передачу
                tx_cnt <= BIT_DIV;
                tx_busy <= 1;     // Занят!
                tx_ready <= 0;
            end
        end else begin
            // Передача битов (1..10)
            if (tx_cnt == 0) begin
                tx_cnt <= BIT_DIV;
                tx_shift <= {1'b1, tx_shift[9:1]};  // Циклический сдвиг
                if (tx_bit == 10) begin
                    // Все биты переданы
                    tx_bit <= 0;      // Возврат в IDLE
                    tx_shift <= 10'b1111111111;  // Возврат в HIGH
                    tx_busy <= 0;     // Освобождаем
                end else begin
                    tx_bit <= tx_bit + 1;
                end
            end else begin
                tx_cnt <= tx_cnt - 1;
            end
        end
    end

    // ========================================================================
    // Echo Logic — принятый байт передается обратно
    // ========================================================================
    always @(posedge clk) begin
        if (rx_valid && tx_ready) begin
            tx_byte <= rx_byte;
            tx_start <= 1;
        end
    end

    // ========================================================================
    // LED — вспыхивает на каждом принятом байте (active-low)
    // ========================================================================
    reg [23:0] led_cnt = 0;
    reg led_on = 0;

    always @(posedge clk) begin
        if (rx_valid) begin
            led_on <= 1;
            led_cnt <= 24'd5_000_000;  // 100ms @ 50MHz
        end else if (led_cnt > 0) begin
            led_cnt <= led_cnt - 1;
        end else begin
            led_on <= 0;
        end
    end

    assign led = ~led_on;  // active-low

endmodule
