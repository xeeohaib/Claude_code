// ROM holding the RX1 max-gain-45 init sequence for the ADAR1000.
// Each entry is {is_load_pulse, R/W, ADDR[14:0], DATA[7:0]}.
// is_load_pulse=1 means "ignore SPI word, pulse RX_LOAD instead".
// Best-guess composite from datasheet defaults + CH1 max gain (0x7F);
// replace these bytes with the exact RX1_MaxG_45.txt contents if available.
`default_nettype none

module adar1000_init_rom #(
    parameter integer ENTRIES = 12
)(
    input  wire [3:0]  addr,
    output reg  [24:0] data
);
    // packed format: [24]=is_load_pulse, [23]=R/W (0=write), [22:8]=addr, [7:0]=data
    always @(*) begin
        case (addr)
            4'd0:  data = {1'b0, 1'b0, 15'h000, 8'h81}; // soft reset
            4'd1:  data = {1'b0, 1'b0, 15'h000, 8'h18}; // 4-wire SPI, SDO active
            4'd2:  data = {1'b0, 1'b0, 15'h400, 8'h55}; // LDO trim (per ADI bring-up)
            4'd3:  data = {1'b0, 1'b0, 15'h031, 8'h60}; // RX_EN | TX_EN subcircuit enable
            4'd4:  data = {1'b0, 1'b0, 15'h02E, 8'h40}; // RX1 channel enable
            4'd5:  data = {1'b0, 1'b0, 15'h034, 8'h08}; // bias default
            4'd6:  data = {1'b0, 1'b0, 15'h035, 8'h55}; // bias default
            4'd7:  data = {1'b0, 1'b0, 15'h036, 8'h2D}; // bias default
            4'd8:  data = {1'b0, 1'b0, 15'h037, 8'h06}; // bias default
            4'd9:  data = {1'b0, 1'b0, 15'h010, 8'h7F}; // CH1_RX_GAIN = 127 (max)
            4'd10: data = {1'b0, 1'b0, 15'h028, 8'h01}; // LD_WRK_REGS (RX side)
            4'd11: data = {1'b1, 1'b0, 15'h000, 8'h00}; // pulse RX_LOAD
            default: data = 25'd0;
        endcase
    end
endmodule

`default_nettype wire
