`timescale  1ns / 1ps

module tb_Register1024;

// Register1024 Parameters
parameter PERIOD  = 10;


// Register1024 Inputs
reg   clk                                  = 0 ;
reg   register_enable                      = 0 ;
reg   [1023:0]  register_data_in           = 0 ;

// Register1024 Outputs
wire  register_ready                       ;
wire  [1023:0]  register_data_out          ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

// reg rst_n;
initial begin
  clk = 1'b0;
  // rst_n = 1'b0;
end

/*
initial
begin
    #(PERIOD*2) rst_n  =  1;
end
*/

Register1024  u_Register1024 (
    .clk                     ( clk                         ),
    .register_enable         ( register_enable             ),
    .register_data_in        ( register_data_in   [1023:0] ),

    .register_ready          ( register_ready              ),
    .register_data_out       ( register_data_out  [1023:0] )
);

initial begin
    //生成输入数据
    register_enable = 0;
    # 8
    register_data_in = 1024'h1234567890ABCDEF0123456789ABCDEF; 
    //等待两个时钟周期
    #(PERIOD*2)
    //写入新数据
    register_enable = 1;
    //拉低使能信号，观察register_ready输出
    # 23
    register_enable = 0;
end

initial
begin
    # 70
    $finish;
end

endmodule