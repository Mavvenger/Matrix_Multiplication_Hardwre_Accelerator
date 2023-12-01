`timescale  1ns / 1ps

 module tb_FSM_for_Matrix_Multiplication_Accelerator;
//通过分析自动售货机TestBench写法和它的仿真波形图：可以总结如下：选择一些典型的状态转移路径仿真验证正确性，如果是四个独立的场景，前一个场景结束和后一个场景开始需要间隔一些时钟周期，需要在TestBench中认为编写一些语句控制
//仿真波形信号只需选取最重要的一些信号看即可，一些计数变量或是配置变量可以从波形图中删去
// FSM_for_Matrix_Multiplication_Accelerator Parameters
parameter PERIOD = 10,
          IDLE  = 4'b0001,
          Buffer_row_A = 4'b0010,
          Multiply_accumulate = 4'b0100,
          Write_row_C = 4'b1000;

// FSM_for_Matrix_Multiplication_Accelerator Inputs
reg   clk                                  =0;
reg   rst_n                                ;
reg   start                                ;
reg   register_ready                       ;
reg   fetch_A_ready                        ;
reg   MACs_ready                           ;
reg   fetch_B_ready                        ;
reg   full                                 ;
reg   store_C_ready                        ;

// FSM_for_Matrix_Multiplication_Accelerator Outputs
wire  register_enable                      ;
wire  MACs_enable                          ;
wire  MACs_reset                           ;
//wire  [4:0]  mux_sel                       ;
wire  fetch_A                              ;
wire  fetch_B                              ;
wire  store_C                              ;
wire  finish                               ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    rst_n  =  0;
    #8 
    rst_n  =  1;
end
//VScode自动生成TestBench,下面传参数太高明了,这个没有什么用，一开始进入IDLE状态是rst_n信号拉低所致
FSM_for_Matrix_Multiplication_Accelerator #(
    .IDLE ( IDLE )) 
 u_FSM_for_Matrix_Multiplication_Accelerator (
    .clk                     ( clk                    ),
    .rst_n                   ( rst_n                  ),
    .start                   ( start                  ),
    .register_ready          ( register_ready         ),
    .fetch_A_ready           ( fetch_A_ready          ),
    .MACs_ready              ( MACs_ready             ),
    .fetch_B_ready           ( fetch_B_ready          ),
    .full                    ( full                   ),
    .store_C_ready           ( store_C_ready          ),

    .register_enable         ( register_enable        ),
    .MACs_enable             ( MACs_enable            ),
    .MACs_reset              ( MACs_reset             ),
 //   .mux_sel                 ( mux_sel          [4:0] ),
    .fetch_A                 ( fetch_A                ),
    .fetch_B                 ( fetch_B                ),
    .store_C                 ( store_C                ),
    .finish                  ( finish                 )
);

//为了方便在仿真波形图中查看，使用字符串描述状态
reg [151:0] state_name;
always@(*)
    begin
        case(u_FSM_for_Matrix_Multiplication_Accelerator.state)
            IDLE:
                state_name = "IDLE";
            Buffer_row_A:
                state_name = "Buffer_row_A";
            Multiply_accumulate:
                state_name = "Multiply_Accumulate";
            Write_row_C:
                state_name = "Write_row_C";
            default :
            state_name = "IDLE";
        endcase
    end

//施加激励信号，先看看状态能不能正确跳转，状态跳转对了输出影响上下级模块达不到预期可以微调
//在三角形路径中循环3次然后在第四次进入到IDLE状态
/*输入信号
reg   clk                                  = 0 ;
reg   rst_n                                = 0 ;
reg   start                                = 0 ;
reg   register_ready                       = 0 ;
reg   fetch_A_ready                        = 0 ;
reg   MACs_ready                           = 0 ;
reg   fetch_B_ready                        = 0 ;
reg   full                                 = 0 ;
reg   store_C_ready                        = 0 ;
*/
//下面是仿真开始时，状态机输入信号初始值的集合
initial begin
    //来自BRAM控制器的信号，暂且来自TestBench
    start = 0;
    fetch_A_ready = 0;
    fetch_B_ready = 0;
    store_C_ready = 0;
    //来自计数器模块
    full = 0;
    //来自寄存器模块
    register_ready = 0;
    //来自乘法累加器模块
    MACs_ready = 0;
end
 //生成一个二维向量数组，存储每次repeat语句所需要的输入信号值，[0:6]是行号，表示状态机有7个需要控制的输入，[0:3]是列号，表示待验证四条路径
 //向量位宽为[0:4]表示每次都是按照IDLE->Buffer_row_A->Multiply_Accumulate->Write_row_C->IDLE这样一个路径循环,给了这么大一个存储空间,每个输入变量在状态跳转时都有一个值，此外加上一个时钟周期的路径间间隔，位宽为5
 reg [0:4] FSM_Input_value [0:6][0:3];
 //integer i,j,k;

initial begin
    /*
    for(i = 0;i < 4;i = i+1)begin
        for (j = 0;j < 7;j = j+1 ) begin
    */
    //第一次：IDLE->Buffer_row_A->Multiply_Accumulate->Write_row_C
    //第二次：Write_Row_C->Buffer_row_A->Multiply_Accumulate->Write_Row_C
    //第三次: Write_Row_C->Buffer_row_A->Multiply_Accumulate->Write_Row_C
    //第四次：Write_Row_C->Buffer_row_A->Multiply_Accumulate->Write_Row_C->IDLE
    //下面时对start信号的待投送值配置，1代表有效，0代表无效，也可表示多路径间多余的周期，后面信号也按照这样的规则
    
           FSM_Input_value[0][0] = 5'b10000;
           FSM_Input_value[0][1] = 5'b00000;
           FSM_Input_value[0][2] = 5'b00000;
           FSM_Input_value[0][3] = 5'b00000;
           
    //signal fetch_A_ready configuration
           FSM_Input_value[1][0] = 5'b01000;
           FSM_Input_value[1][1] = 5'b01000;
           FSM_Input_value[1][2] = 5'b01000;
           FSM_Input_value[1][3] = 5'b01000;
    //signal register_ready coonfiguration
           FSM_Input_value[2][0] = 5'b01000;
           FSM_Input_value[2][1] = 5'b01000;
           FSM_Input_value[2][2] = 5'b01000;
           FSM_Input_value[2][3] = 5'b01000;

    //signal fetch_B_ready configuration
           FSM_Input_value[3][0] = 5'b00100;
           FSM_Input_value[3][1] = 5'b00100;
           FSM_Input_value[3][2] = 5'b00100;
           FSM_Input_value[3][3] = 5'b00100;
    //signal MACs_ready coonfiguration
           FSM_Input_value[4][0] = 5'b00100;
           FSM_Input_value[4][1] = 5'b00100;
           FSM_Input_value[4][2] = 5'b00100;
           FSM_Input_value[4][3] = 5'b00100;

    //signal store_C_ready coonfiguration
           FSM_Input_value[5][0] = 5'b00000;
           FSM_Input_value[5][1] = 5'b10000;
           FSM_Input_value[5][2] = 5'b10000;
           FSM_Input_value[5][3] = 5'b10010;
    //signal full coonfiguration
           FSM_Input_value[6][0] = 5'b00000;
           FSM_Input_value[6][1] = 5'b00000;
           FSM_Input_value[6][2] = 5'b00000;
           FSM_Input_value[6][3] = 5'b00010;
   //依据波形排查上面的配置
    /*
        end
    end
    */
    # 16 
    //第一次：IDLE->Buffer_row_A->Multiply_Accumulate->Write_row_C
    repeat(5)begin
       @(negedge clk);
            start = FSM_Input_value[0][0][0];
            fetch_A_ready = FSM_Input_value[1][0][0];
            register_ready = FSM_Input_value[2][0][0];
            fetch_B_ready = FSM_Input_value[3][0][0];
            MACs_ready = FSM_Input_value[4][0][0];
            store_C_ready = FSM_Input_value[5][0][0];
            full = FSM_Input_value[6][0][0];

            FSM_Input_value[0][0] = FSM_Input_value[0][0] << 1;
            FSM_Input_value[1][0] = FSM_Input_value[1][0] << 1;
            FSM_Input_value[2][0] = FSM_Input_value[2][0] << 1;
            FSM_Input_value[3][0] = FSM_Input_value[3][0] << 1;
            FSM_Input_value[4][0] = FSM_Input_value[4][0] << 1;
            FSM_Input_value[5][0] = FSM_Input_value[5][0] << 1;
            FSM_Input_value[6][0] = FSM_Input_value[6][0] << 1;
    end


    //第二次：Write_Row_C->Buffer_row_A->Multiply_Accumulate->Write_Row_C
    repeat(5)begin
        @(negedge clk);
            start = FSM_Input_value[0][1][0];
            fetch_A_ready = FSM_Input_value[1][1][0];
            register_ready = FSM_Input_value[2][1][0];
            fetch_B_ready = FSM_Input_value[3][1][0];
            MACs_ready = FSM_Input_value[4][1][0];
            store_C_ready = FSM_Input_value[5][1][0];
            full = FSM_Input_value[6][1][0];

            FSM_Input_value[0][1] = FSM_Input_value[0][1] << 1;
            FSM_Input_value[1][1] = FSM_Input_value[1][1] << 1;
            FSM_Input_value[2][1] = FSM_Input_value[2][1] << 1;
            FSM_Input_value[3][1] = FSM_Input_value[3][1] << 1;
            FSM_Input_value[4][1] = FSM_Input_value[4][1] << 1;
            FSM_Input_value[5][1] = FSM_Input_value[5][1] << 1;
            FSM_Input_value[6][1] = FSM_Input_value[6][1] << 1;
    end
    //第三次: Write_Row_C->Buffer_row_A->Multiply_Accumulate->Write_Row_C
    repeat(5)begin
        @(negedge clk);
            start = FSM_Input_value[0][2][0];
            fetch_A_ready = FSM_Input_value[1][2][0];
            register_ready = FSM_Input_value[2][2][0];
            fetch_B_ready = FSM_Input_value[3][2][0];
            MACs_ready = FSM_Input_value[4][2][0];
            store_C_ready = FSM_Input_value[5][2][0];
            full = FSM_Input_value[6][2][0];

            FSM_Input_value[0][2] = FSM_Input_value[0][2] << 1;
            FSM_Input_value[1][2] = FSM_Input_value[1][2] << 1;
            FSM_Input_value[2][2] = FSM_Input_value[2][2] << 1;
            FSM_Input_value[3][2] = FSM_Input_value[3][2] << 1;
            FSM_Input_value[4][2] = FSM_Input_value[4][2] << 1;
            FSM_Input_value[5][2] = FSM_Input_value[5][2] << 1;
            FSM_Input_value[6][2] = FSM_Input_value[6][2] << 1;
    end
    //第四次：Write_Row_C->Buffer_row_A->Multiply_Accumulate->Write_Row_C->IDLE
    repeat(5)begin
        @(negedge clk);
            start = FSM_Input_value[0][3][0];
            fetch_A_ready = FSM_Input_value[1][3][0];
            register_ready = FSM_Input_value[2][3][0];
            fetch_B_ready = FSM_Input_value[3][3][0];
            MACs_ready = FSM_Input_value[4][3][0];
            store_C_ready = FSM_Input_value[5][3][0];
            full = FSM_Input_value[6][3][0];

            FSM_Input_value[0][3] = FSM_Input_value[0][3] << 1;
            FSM_Input_value[1][3] = FSM_Input_value[1][3] << 1;
            FSM_Input_value[2][3] = FSM_Input_value[2][3] << 1;
            FSM_Input_value[3][3] = FSM_Input_value[3][3] << 1;
            FSM_Input_value[4][3] = FSM_Input_value[4][3] << 1;
            FSM_Input_value[5][3] = FSM_Input_value[5][3] << 1;
            FSM_Input_value[6][3] = FSM_Input_value[6][3] << 1;
    end

end

initial
begin
    #220
    $finish;
end

endmodule
