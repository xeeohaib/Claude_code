// Sequencer: walks the init ROM, drives the SPI master, pulses RX_LOAD when asked.
`default_nettype none

module adar1000_seq_ctrl #(
    parameter integer ENTRIES   = 12,
    parameter integer LOAD_HOLD = 16,   // sys_clk cycles to hold RX_LOAD high
    parameter integer SCLK_DIV  = 50
)(
    input  wire clk,
    input  wire rst_n,

    output wire csb,
    output wire sclk,
    output wire sdio,
    input  wire sdo,

    output reg  rx_load,
    output reg  done
);
    localparam [2:0] S_IDLE   = 3'd0,
                     S_FETCH  = 3'd1,
                     S_START  = 3'd2,
                     S_WAIT   = 3'd3,
                     S_LOAD   = 3'd4,
                     S_NEXT   = 3'd5,
                     S_DONE   = 3'd6;

    reg  [2:0]  state;
    reg  [3:0]  rom_addr;
    reg  [15:0] load_timer;

    wire [24:0] rom_data;
    wire        is_load = rom_data[24];
    wire [23:0] spi_word = rom_data[23:0];

    reg         spi_start;
    wire        spi_busy;
    wire        spi_done;

    adar1000_init_rom #(.ENTRIES(ENTRIES)) u_rom (
        .addr(rom_addr),
        .data(rom_data)
    );

    adar1000_spi_master #(.SCLK_DIV(SCLK_DIV)) u_spi (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (spi_start),
        .tx_word (spi_word),
        .busy    (spi_busy),
        .done    (spi_done),
        .csb     (csb),
        .sclk    (sclk),
        .sdio    (sdio),
        .sdo_in  (sdo)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            rom_addr   <= 4'd0;
            load_timer <= 16'd0;
            spi_start  <= 1'b0;
            rx_load    <= 1'b0;
            done       <= 1'b0;
        end else begin
            spi_start <= 1'b0;
            case (state)
                S_IDLE:  state <= S_FETCH;

                S_FETCH: state <= S_START;

                S_START: begin
                    if (is_load) begin
                        rx_load    <= 1'b1;
                        load_timer <= 16'd0;
                        state      <= S_LOAD;
                    end else begin
                        spi_start <= 1'b1;
                        state     <= S_WAIT;
                    end
                end

                S_WAIT: begin
                    if (spi_done) state <= S_NEXT;
                end

                S_LOAD: begin
                    if (load_timer == LOAD_HOLD - 1) begin
                        rx_load <= 1'b0;
                        state   <= S_NEXT;
                    end else begin
                        load_timer <= load_timer + 16'd1;
                    end
                end

                S_NEXT: begin
                    if (rom_addr == ENTRIES - 1) begin
                        state <= S_DONE;
                    end else begin
                        rom_addr <= rom_addr + 4'd1;
                        state    <= S_FETCH;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
