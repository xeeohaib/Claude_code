// SPI master for ADAR1000.
// Mode 0: CPOL=0, CPHA=0. 24-bit frame: R/W | ADDR[14:0] | DATA[7:0], MSB first.
// SDIO is driven on falling SCLK so it's stable for the chip's rising-edge sample.
`default_nettype none

module adar1000_spi_master #(
    parameter integer SCLK_DIV = 50,   // sys_clk / (2*SCLK_DIV) = SCLK; 100MHz/100 = 1MHz
    parameter integer CSB_SETUP = 4,   // sys_clk cycles CSB low before first SCLK edge
    parameter integer CSB_HOLD  = 4    // sys_clk cycles CSB low after last SCLK edge
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [23:0] tx_word,
    output reg         busy,
    output reg         done,
    output reg         csb,
    output reg         sclk,
    output reg         sdio,
    input  wire        sdo_in       // unused for write-only init; reserved for readback
);
    localparam [2:0] S_IDLE   = 3'd0,
                     S_SETUP  = 3'd1,
                     S_SHIFT  = 3'd2,
                     S_HOLD   = 3'd3,
                     S_DONE   = 3'd4;

    reg [2:0]  state;
    reg [15:0] div_cnt;
    reg [5:0]  bit_cnt;
    reg [15:0] timer;
    reg [23:0] shreg;

    wire sdo_unused = sdo_in;  // silence lint

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            div_cnt <= 0;
            bit_cnt <= 0;
            timer   <= 0;
            shreg   <= 24'd0;
            csb     <= 1'b1;
            sclk    <= 1'b0;
            sdio    <= 1'b0;
            busy    <= 1'b0;
            done    <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    csb  <= 1'b1;
                    sclk <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        shreg   <= tx_word;
                        sdio    <= tx_word[23];
                        csb     <= 1'b0;
                        timer   <= 0;
                        bit_cnt <= 6'd24;
                        div_cnt <= 0;
                        busy    <= 1'b1;
                        state   <= S_SETUP;
                    end
                end

                S_SETUP: begin
                    if (timer == CSB_SETUP - 1) begin
                        timer   <= 0;
                        div_cnt <= 0;
                        sclk    <= 1'b0;
                        state   <= S_SHIFT;
                    end else begin
                        timer <= timer + 16'd1;
                    end
                end

                S_SHIFT: begin
                    if (div_cnt == SCLK_DIV - 1) begin
                        div_cnt <= 0;
                        sclk    <= ~sclk;
                        if (sclk == 1'b1) begin
                            // falling edge of SCLK: shift next bit out (chip samples on rising)
                            if (bit_cnt == 6'd1) begin
                                timer <= 0;
                                state <= S_HOLD;
                            end else begin
                                shreg   <= {shreg[22:0], 1'b0};
                                sdio    <= shreg[22];
                                bit_cnt <= bit_cnt - 6'd1;
                            end
                        end
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                S_HOLD: begin
                    sclk <= 1'b0;
                    if (timer == CSB_HOLD - 1) begin
                        csb   <= 1'b1;
                        timer <= 0;
                        state <= S_DONE;
                    end else begin
                        timer <= timer + 16'd1;
                    end
                end

                S_DONE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
