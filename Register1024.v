`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/25 18:27:35
// Design Name: 
// Module Name: Register1024
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
//时序电路中，clk视为各动作的指挥棒，通常设置一些内部寄存器型变量或外部输入信号屏蔽某个时间的clk指挥棒，达到控制的作用

module Register1024(
    input clk,
    input register_enable,
    input wire [1023:0] register_data_in,//register_data_in的最高32位是矩阵行中列号最高的元素
    output reg register_ready,
    output [1023:0] register_data_out
    );

    reg [1023:0] reg_data;
    //下面代码实现在使能信号register_enable拉高后的第一个时钟上升沿register_ready信号拉低
    /*
    reg register_enable_last,
        register_enable_rising_edge;
    always @(posedge clk) begin
        register_enable_last <= register_enable;
        register_enable_rising_edge <= (!register_enable_last && register_enable);
    end
    always @(posedge register_enable_rising_edge) begin
        register_ready <= 1'b0;
    end
    */
    //给值的时候控制好时序吧
    //非阻塞赋值的左值必须是reg型变量，下面always块保证在register_enable信号为高的时间段内，每个时钟上升沿都会有新数据打入寄存器，最后一次为最新的，不用担心
    always @(posedge clk) begin
      if(register_enable /*&& !register_ready*/)begin
        reg_data <= register_data_in;
        register_ready <= 1'b1; //写入新值后拉高register_ready信号，register_enable拉高指示写入新值
      end else begin
        register_ready <= 1'b0;
      end
        
    end
    //输出数据
    assign register_data_out = reg_data;
endmodule
