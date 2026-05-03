// Top-level for ZC702 -> ADAR1000-EVALZ bring-up.
// J63 (PMOD1) carries the 4-wire SPI; J62 (PMOD2) carries RX_LOAD and unused control lines tied low.
`default_nettype none

module zc702_adar1000_top (
    input  wire sysclk_p,        // Y9  -- 200 MHz LVDS
    input  wire sysclk_n,        // AB11
    input  wire cpu_resetn,      // G19 -- active-low CPU_RESET button

    // J63 (PMOD1) -- SPI
    output wire pmod1_csb,       // E15 -> P3.1
    output wire pmod1_sdio,      // D15 -> P3.2
    input  wire pmod1_sdo,       // W17 <- P3.3
    output wire pmod1_sclk,      // W5  -> P3.4

    // J62 (PMOD2) -- load and control
    output wire pmod2_rx_load,   // V7  -> P3.7
    output wire pmod2_tx_load,   // W10 -> P3.8  (held low)
    output wire pmod2_tr,        // P18 -> P3.9  (held low = RX mode)
    output wire pmod2_pa_on      // P17 -> P3.10 (held low)
);
    wire seq_done;
    // 200 MHz differential -> single-ended -> /2 -> 100 MHz fabric clock
    wire sysclk_ibuf;
    IBUFDS u_ibufds (.I(sysclk_p), .IB(sysclk_n), .O(sysclk_ibuf));

    wire sysclk_bufg;
    BUFG u_bufg (.I(sysclk_ibuf), .O(sysclk_bufg));

    // simple /2 to land at ~100 MHz so SCLK math in the SPI master is round
    reg clk100 = 1'b0;
    always @(posedge sysclk_bufg) clk100 <= ~clk100;

    wire clk100_g;
    BUFG u_bufg100 (.I(clk100), .O(clk100_g));

    // 2-FF reset synchronizer
    reg [1:0] rst_sync;
    always @(posedge clk100_g or negedge cpu_resetn) begin
        if (!cpu_resetn) rst_sync <= 2'b00;
        else             rst_sync <= {rst_sync[0], 1'b1};
    end
    wire rst_n = rst_sync[1];

    adar1000_seq_ctrl u_seq (
        .clk     (clk100_g),
        .rst_n   (rst_n),
        .csb     (pmod1_csb),
        .sclk    (pmod1_sclk),
        .sdio    (pmod1_sdio),
        .sdo     (pmod1_sdo),
        .rx_load (pmod2_rx_load),
        .done    (seq_done)
    );

    (* keep = "true" *) wire seq_done_keep = seq_done;

    assign pmod2_tx_load = 1'b0;
    assign pmod2_tr      = 1'b0;
    assign pmod2_pa_on   = 1'b0;
endmodule

`default_nettype wire
