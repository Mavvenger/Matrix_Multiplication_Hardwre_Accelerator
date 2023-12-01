`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/11/05 19:47:02
// Design Name: 
// Module Name: counter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module counter(
    input register_ready,
    output full
    ); 
    reg [4:0] cnt = 5'b000_00; //由于一开始在IDLE状态，full=1对全局的功能没有影响，不会导致状态不正常跳变
    always @(posedge register_ready) begin
        cnt <= cnt + 1'b1;
    end

    assign full = (cnt == 5'b000_00);
endmodule
