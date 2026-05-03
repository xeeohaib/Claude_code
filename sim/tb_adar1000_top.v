// Smoke test: instantiates the sequencer + SPI master directly (no IBUFDS),
// captures the SPI bus, and decodes the first few 24-bit frames.
`timescale 1ns/1ps

module tb_adar1000_top;
    reg clk = 0;
    reg rst_n = 0;

    always #5 clk = ~clk;  // 100 MHz

    wire csb, sclk, sdio;
    wire rx_load, done;

    adar1000_seq_ctrl #(
        .ENTRIES   (12),
        .LOAD_HOLD (4),
        .SCLK_DIV  (4)    // fast SCLK so the test finishes in reasonable sim time
    ) u_dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .csb     (csb),
        .sclk    (sclk),
        .sdio    (sdio),
        .sdo     (1'b0),
        .rx_load (rx_load),
        .done    (done)
    );

    // SPI capture: shift on rising SCLK while CSB is low
    reg [23:0] capture;
    integer    bit_idx;
    integer    frame_idx;
    reg [23:0] expected [0:11];

    initial begin
        expected[0]  = 24'h00_0081;
        expected[1]  = 24'h00_0118;  // addr 0x000, data 0x18 -> {1'b0,15'h000,8'h18} = 0x000018; with R/W=0 frame is 0x000018
        expected[2]  = 24'h04_0055;  // 0x400 -> {1'b0,15'h400,8'h55} -> shifted: addr 0x400 << 8 | 0x55 = 0x040055
        expected[3]  = 24'h00_3160;
        expected[4]  = 24'h00_2E40;
        expected[5]  = 24'h00_3408;
        expected[6]  = 24'h00_3555;
        expected[7]  = 24'h00_362D;
        expected[8]  = 24'h00_3706;
        expected[9]  = 24'h00_107F;
        expected[10] = 24'h00_2801;
        // entry 11 is RX_LOAD pulse, no SPI frame
    end

    // Frame 1 should be {R/W=0, ADDR=0x000, DATA=0x81} = 24'h000081
    // Frame structure: bit23 = R/W, bits22:8 = addr, bits7:0 = data.
    // For 0x000 + 0x81: 0x000 << 8 = 0x000000, OR 0x81 = 0x000081

    initial begin
        bit_idx = 0;
        frame_idx = 0;
        capture = 24'd0;
    end

    reg sclk_d;
    always @(posedge clk) sclk_d <= sclk;

    always @(posedge clk) begin
        if (csb == 1'b0 && sclk == 1'b1 && sclk_d == 1'b0) begin
            capture <= {capture[22:0], sdio};
            bit_idx <= bit_idx + 1;
        end
    end

    reg csb_d;
    integer errors = 0;
    always @(posedge clk) begin
        csb_d <= csb;
        if (csb == 1'b1 && csb_d == 1'b0) begin
            // CSB just rose: a frame just completed
            $display("FRAME %0d: 0x%06h  (expected 0x%06h)", frame_idx, capture, frame_at(frame_idx));
            if (capture !== frame_at(frame_idx)) begin
                $display("  MISMATCH");
                errors = errors + 1;
            end
            frame_idx <= frame_idx + 1;
            bit_idx   <= 0;
        end
    end

    function [23:0] frame_at;
        input integer idx;
        begin
            case (idx)
                0:  frame_at = 24'h000081;
                1:  frame_at = 24'h000018;
                2:  frame_at = 24'h040055;
                3:  frame_at = 24'h003160;
                4:  frame_at = 24'h002E40;
                5:  frame_at = 24'h003408;
                6:  frame_at = 24'h003555;
                7:  frame_at = 24'h00362D;
                8:  frame_at = 24'h003706;
                9:  frame_at = 24'h00107F;
                10: frame_at = 24'h002801;
                default: frame_at = 24'd0;
            endcase
        end
    endfunction

    // Watch for RX_LOAD pulse
    reg rx_load_seen = 0;
    always @(posedge rx_load) rx_load_seen <= 1'b1;

    initial begin
        $dumpfile("tb_adar1000_top.vcd");
        $dumpvars(0, tb_adar1000_top);

        #50 rst_n = 1;

        // give it plenty of time
        wait (done == 1'b1);
        #1000;

        if (frame_idx != 11) begin
            $display("ERROR: expected 11 SPI frames, saw %0d", frame_idx);
            errors = errors + 1;
        end
        if (!rx_load_seen) begin
            $display("ERROR: RX_LOAD never pulsed");
            errors = errors + 1;
        end

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d errors", errors);

        $finish;
    end

    initial begin
        #5_000_000 $display("TIMEOUT"); $finish;
    end
endmodule
