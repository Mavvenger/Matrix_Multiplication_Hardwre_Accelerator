`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/11/06 03:03:30
// Design Name: 
// Module Name: top
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
//联合仿真调试完成之后，没有任何我不能设计的数字电路，尤其是前端信号组时序分析能力已经是一流

module top(
    input clk,
    input [1023:0] data_in,
    input rst_n,
    input start,
    input fetch_A_ready,
    input fetch_B_ready,
    input store_C_ready,

    output [1023:0] dataC_out,
    output fetch_A,
    output fetch_B,
    output store_C,
    output finish

    //debug ports
    /*
    output register_ready_out,
    output MACs_ready_out,
    output full_out
    */
    );

    wire register_enable,
         register_ready;
    wire [1023:0] register_data_out;
    
    Register1024 u_Register1024(
        .clk(clk),
        .register_enable(register_enable),
        .register_data_in(data_in [1023:0]),

        .register_ready(register_ready),
        .register_data_out(register_data_out [1023:0])
    );

    wire [4:0] mux_sel;
    wire [31:0] mux_data_out;
    mux32 u_mux32(
        .mux_data_in(register_data_out[1023:0]),
        .mux_sel(mux_sel[4:0]),

        .mux_data_out(mux_data_out[31:0])
    );

    wire MACs_enable,
         MACs_reset,
         MACs_ready;

    MACs u_MACs(
        .dataA_in(mux_data_out[31:0]),
        .dataB_in(data_in[1023:0]),
        .clk(clk),
        .MACs_enable(MACs_enable),
        .MACs_reset(MACs_reset),
        
        .dataC_out(dataC_out[1023:0]),
        .MACs_ready(MACs_ready),
        .mux_sel(mux_sel[4:0])
    );
    
    wire full;
    counter u_counter(
        .register_ready(register_ready),

        .full(full)
    );

    FSM_for_Matrix_Multiplication_Accelerator u_FSM_for_Matrix_Multiplication_Accelerator(
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .full(full),
        .register_ready(register_ready),
        .MACs_ready(MACs_ready),
        .fetch_A_ready(fetch_A_ready),
        .fetch_B_ready(fetch_B_ready),
        .store_C_ready(store_C_ready),

        .register_enable(register_enable),
        .MACs_enable(MACs_enable),
        .MACs_reset(MACs_reset),
        .fetch_A(fetch_A),
        .fetch_B(fetch_B),
        .store_C(store_C),
        .finish(finish)
    );
    /*
    assign register_ready_out = register_ready;
    assign MACs_ready_out = MACs_ready;
    assign full_out = full;
    */
    
    //debug ports
    /*
    assign register_ready_out = register_ready;
    assign MACs_ready_out = MACs_ready;
    assign full_out = full;
    */
endmodule
