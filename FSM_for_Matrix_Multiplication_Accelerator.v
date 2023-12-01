`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/27 13:41:05
// Design Name: 
// Module Name: FSM_for_Matrix_Multiplication_Accelerator
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
//连续赋值语句的左值必须是线网类型
//过程赋值语句(阻塞=，非阻塞<=，常在initial和always中使用)的对象是寄存器，整数，实数或时间变量，不能是线网数据类型
//过程赋值语句（阻塞=）在initial块中常用
//时序电路中，clk视为各动作的指挥棒，通常设置一些内部寄存器型变量或外部输入信号屏蔽某个时间的clk指挥棒，达到控制的作用
//always块的触发条件是边沿触发时，非阻塞赋值符的左值在信号沿之后改变，在条件判断处的信号值使用的是信号沿之前的旧值，并且多个always块并行执行（为常见的硬件电路行为建立模型，一个事件发生后，多个数据并发传输的行为），这就是Verilog设计中基本的时序理解
//always@(*)表示对其后语句块中的所有输入变量的变化是敏感的（注意这里的描述，不是所有模块端口信号，故而在tb中也可使用）
//现在前端RTL级时序分析能力，设计能力，验证能力已经是一流
module FSM_for_Matrix_Multiplication_Accelerator(
    input clk,
    input rst_n, //rst_n低有效，这里的其它输入信号都是高有效
    input start,
    input register_ready,
    input fetch_A_ready,
    input MACs_ready,
    input fetch_B_ready,
    input full,
    input store_C_ready,
    output register_enable,
    output MACs_enable,
    output MACs_reset,
  //  output [4:0] mux_sel,
    output fetch_A,
    output fetch_B,
    output store_C,
    output finish
    );
    //根据状态机个数确定状态机编码,使用OneHot编码，多消耗一些面积，实现状态切换时的最低延迟
    parameter   IDLE = 4'b0001,
                Buffer_row_A = 4'b0010,
                Multiply_accumulate = 4'b0100,
                Write_row_C =4'b1000;

    reg reg_register_enable,
        reg_MACs_enable,
        reg_MACs_reset,
        reg_fetch_A,
        reg_fetch_B,
        reg_store_C,
        reg_finish;

 //   reg [4:0] reg_mux_sel;
    reg [3:0] state,
              next_state;
    //第一段，时序逻辑，非阻塞赋值，传递寄存器状态
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    //第二段，组合逻辑，阻塞赋值，根据当前状态和当前输入，确定下一个状态机状态
    always@(*) begin
      case(state)
        IDLE: 
            next_state = (start) ? Buffer_row_A : IDLE;
        Buffer_row_A:
            next_state = (register_ready&&fetch_A_ready) ? Multiply_accumulate : Buffer_row_A;
        Multiply_accumulate:
            next_state = (MACs_ready&&fetch_B_ready) ? Write_row_C : Multiply_accumulate;
        Write_row_C:
            next_state = (!store_C_ready) ? Write_row_C : ((full) ? IDLE : Buffer_row_A);
        default:
            next_state = IDLE;
      endcase
    end
    //第三段，时序逻辑，非阻塞赋值，根据当前状态和当前输入，确定输出信号
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            reg_register_enable <=0;
            reg_fetch_A <=0;
            reg_MACs_enable <=0;
            reg_MACs_reset <=0;
         //   reg_mux_sel <=5'b000_00;
            reg_fetch_B <=0;
            reg_store_C <=0;
            reg_finish  <=0;
        end
        else begin
          case(state) //在时钟上升沿，状态寄存器state的值需要刷新，但在执行case(state)语句时，state仍使用旧值，这符合状态机跳转到新状态后输出值刷新这一特点，即这些输出信号是状态机跳转到新状态的输出信号值
                IDLE: //这一点是前端RTL级时序分析中可以说是最重要的一点
                    begin
                      if(start)begin
                            reg_register_enable <=1;
                            reg_fetch_A <=1;
                            reg_MACs_enable <=0;
                            reg_MACs_reset <=0;
                           // reg_mux_sel <=5'b000_00;
                            reg_fetch_B <=0;
                            reg_store_C <=0;
                            reg_finish  <=0;
                      end
                      else begin
                            reg_register_enable <=0;
                            reg_fetch_A <=0;
                            reg_MACs_enable <=0;
                            reg_MACs_reset <=0;
                         //   reg_mux_sel <=5'b000_00;
                            reg_fetch_B <=0;
                            reg_store_C <=0;
                            reg_finish  <=0;
                      end
                    end
                Buffer_row_A:
                    begin
                      if(register_ready&&fetch_A_ready)begin
                            reg_register_enable <=0;
                            reg_fetch_A <=0;
                            reg_MACs_enable <=1;
                            reg_MACs_reset <=1;
                       //     reg_mux_sel <=5'b000_00;
                            reg_fetch_B <=1;
                            reg_store_C <=0;
                            reg_finish  <=0;
                      end
                      else begin
                            reg_register_enable <=1;
                            reg_fetch_A <=1;
                            reg_MACs_enable <=0;
                            reg_MACs_reset <=0;
                          //  reg_mux_sel <=5'b000_00;
                            reg_fetch_B <=0;
                            reg_store_C <=0;
                            reg_finish  <=0;
                      end
                    end
                Multiply_accumulate:
                    begin
                      if(MACs_ready&&fetch_B_ready)begin
                            reg_register_enable <=0;
                            reg_fetch_A <=0;
                            reg_MACs_enable <=0;
                            reg_MACs_reset <=0;
                         //   reg_mux_sel <=5'b000_00;
                            reg_fetch_B <=0;
                            reg_store_C <=1;
                            reg_finish  <=0;
                      end
                      else begin
                            reg_register_enable <=0;
                            reg_fetch_A <=0;
                            reg_MACs_enable <=1;
                            reg_MACs_reset <=1;  //你这个是什么意思呢，我MACs设计都说明了MACs_reset信号一直为高
                         //   reg_mux_sel <=5'b000_00;
                            reg_fetch_B <=1;
                            reg_store_C <=0;
                            reg_finish  <=0;
                      end
                    end
                Write_row_C:
                    begin
                      if(!store_C_ready)begin //仍然回到Write_row_C这个状态
                            reg_register_enable <=0;
                            reg_fetch_A <=0;
                            reg_MACs_enable <=0;
                            reg_MACs_reset <=0;
                        //    reg_mux_sel <=5'b000_00;
                            reg_fetch_B <=0;
                            reg_store_C <=1;
                            reg_finish  <=0;
                      end
                      else if(store_C_ready&&full) begin//跳转到IDLE状态
                            reg_register_enable <=0;
                            reg_fetch_A <=0;
                            reg_MACs_enable <=0;
                            reg_MACs_reset <=0;
                        //    reg_mux_sel <=5'b000_00;
                            reg_fetch_B <=0;
                            reg_store_C <=0;
                            reg_finish  <=1;
                      end
                      else begin//跳转到Buffer_Row_A状态
                            reg_register_enable <=1;
                            reg_fetch_A <=1;
                            reg_MACs_enable <=0;
                            reg_MACs_reset <=0;
                        //    reg_mux_sel <=5'b000_00;
                            reg_fetch_B <=0;
                            reg_store_C <=0;
                            reg_finish  <=0;
                      end
                    end
                default :
                    begin
                            reg_register_enable <=0;
                            reg_fetch_A <=0;
                            reg_MACs_enable <=0;
                            reg_MACs_reset <=0;
                        //    reg_mux_sel <=5'b000_00;
                            reg_fetch_B <=0;
                            reg_store_C <=0;
                            reg_finish  <=0;
                    end
          endcase
        end
    end
    
    assign  register_enable = reg_register_enable,
            fetch_A = reg_fetch_A,
            MACs_enable = reg_MACs_enable,
            MACs_reset = reg_MACs_reset,
          //  mux_sel = reg_mux_sel,
            fetch_B = reg_fetch_B,
            store_C = reg_store_C,
            finish = reg_finish;

endmodule