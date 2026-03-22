// =============================================================================
// UART Echo Testbench — Simulate uart_echo_top.v
// =============================================================================
// Проверка:
//   - TX корректно формирует 115200 бод
//   - RX корректно принимает байты
//   - Echo работает правильно
// =============================================================================

`timescale 1ns/1ps

module uart_echo_tb;
    reg clk = 0;
    reg uart_rx = 1;  // Изначально HIGH (idle)
    wire uart_tx;
    wire led;

    // Генерация тактов 50 MHz (20 ns период)
    initial forever #10 clk = ~clk;

    // Подключение модуля
    uart_echo_top dut (
        .clk(clk),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .led(led)
    );

    // Тестовая логика
    reg [31:0] test_data;
    integer bit_index;

    // Мониторинг
    initial begin
        $dumpfile("uart_echo_tb.vcd");
        $dumpvars(0, dut);
        $display("=== UART Echo Testbench ===");
        $display("Clock: 50 MHz (20 ns period)");
        $display("Baud: 115200 (8680 ns per bit)");
        $display();

        // Ждем инициализации
        #1000;
        $display("[TEST] Starting...");

        // Тест 1: Отправка байта 0x41 ('A')
        test_data = 8'h41;  // 'A'
        send_uart_byte(test_data);
        #1000000;

        // Тест 2: Отправка 0x55 (alternating)
        test_data = 8'h55;
        send_uart_byte(test_data);
        #1000000;

        // Тест 3: Отправка 0xAA (alternating inverted)
        test_data = 8'hAA;
        send_uart_byte(test_data);
        #1000000;

        // Тест 4: Отправка 0x00
        test_data = 8'h00;
        send_uart_byte(test_data);
        #1000000;

        // Тест 5: Отправка 0xFF
        test_data = 8'hFF;
        send_uart_byte(test_data);
        #1000000;

        $display();
        $display("[TEST] All tests completed");
        $finish;
    end

    // Отправка байта через UART (115200 бод)
    task send_uart_byte;
        input [7:0] data_byte;
        reg [7:0] byte_to_send;

        begin
            byte_to_send = data_byte;
            $display("[TX] Sending: 0x%02h ('%c)", byte_to_send, byte_to_send);

            // START бит (LOW) - 8680 ns
            uart_rx = 0;
            #434;  // 50MHz / 115200 = 434 тактов на бит

            // 8 DATA битов (LSB-first) - каждый 434 тактов
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rx = byte_to_send[bit_index];
                #434;
            end

            // STOP бит (HIGH) - 434 тактов
            uart_rx = 1;
            #434;

            $display("[TX] Byte complete");
        end
    endtask

    // Мониторинг выхода
    always @(posedge uart_tx) begin
        if ($time > 1000) begin  // Игнорируем инициализацию
            $display("[RX] Line changed to %b at time %0t", uart_tx, $time);
        end
    end

    // Мониторинг LED
    always @(posedge led) begin
        if ($time > 1000) begin
            $display("[LED] ON at time %0t", $time);
        end
    end

    always @(negedge led) begin
        if ($time > 1000) begin
            $display("[LED] OFF at time %0t", $time);
        end
    end

endmodule
