`timescale  1ns / 1ps

module tb_top;
//很长的代码段考虑用循环解决
// top Parameters
parameter PERIOD = 10,
          IDLE  = 4'b0001,
          Buffer_row_A = 4'b0010,
          Multiply_accumulate = 4'b0100,
          Write_row_C = 4'b1000;


// top Inputs
reg   clk                                  = 0 ;
reg   [1023:0]  data_in                    = 0 ;
reg   rst_n                                = 0 ;
reg   start                                = 0 ;
reg   fetch_A_ready                        = 0 ;
reg   fetch_B_ready                        = 0 ;
reg   store_C_ready                        = 0 ;

// top Outputs
wire  [1023:0]  dataC_out                  ;
wire  fetch_A                              ;
wire  fetch_B                              ;
wire  store_C                              ;
wire  finish                               ;
//Debug Ports
/*
wire register_ready_out                    ;
wire MACs_ready_out                        ;
wire full_out                              ;
*/

initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #18 rst_n  =  1;
end

top  u_top (
    .clk                     ( clk                     ),
    .data_in                 ( data_in        [1023:0] ),
    .rst_n                   ( rst_n                   ),
    .start                   ( start                   ),
    .fetch_A_ready           ( fetch_A_ready           ),
    .fetch_B_ready           ( fetch_B_ready           ),
    .store_C_ready           ( store_C_ready           ),

    .dataC_out               ( dataC_out      [1023:0] ),
    .fetch_A                 ( fetch_A                 ),
    .fetch_B                 ( fetch_B                 ),
    .store_C                 ( store_C                 ),
    .finish                  ( finish                  )
);
//为了方便在仿真波形图中查看，使用字符串描述状态
reg [151:0] state_name;
always@(*)
    begin
        case(u_top.u_FSM_for_Matrix_Multiplication_Accelerator.state)
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
/*第一部分：
写文件思路，dataA_value和dataB_value的值先配置好
然后给出dataC_value的写入空间
第二部分：
给start信号置高，状态机跳转，输出fetch_A信号，测试台文件中将数据送到top模块输入端口后使得fetch_A_ready信号拉高，使状态机跳转到下一状态
后面持续这个过程，需要一个循环来控制次数

借鉴前面写tb的经验，tb_MACs学会了向量数组的配置，和1024位宽的端口元素对应关系
tb_FSM_for_Matrix_Multiplication_Accelerator学会了怎么给状态机输入信号送数，还是使用二维向量数组和repeat语句
*/
reg [31:0] dataA_value [0:31][0:31];
reg [31:0] dataB_value [0:31][0:31];
reg [31:0] dataC_value [0:31][0:31];
//给dataA_value，dataB_value,dataC_value赋初值
integer i,j;
initial begin
    for (i = 0;i < 32;i = i + 1)begin
        for(j = 0;j < 32;j = j + 1)begin
            dataA_value[i][j] = 32'h0000_0001;
            dataC_value[i][j] = 32'h0000_0000;// MACs模块在启动时，reset信号也拉高，输出端口复位为零，这里测试台文件中写dataC_value的寄存器初始值置零没有什么关系
            if(i == j)begin
                dataB_value[i][j] = 32'h0000_0002;
            end else begin
                dataB_value[i][j] = 32'h0000_0000;
            end
        end
    end
end

//先写伪代码，后写代码，就是测试台给top一个start信号，完成取矩阵A中的元素的操作后，状态机接收到fetch_A_ready和register_ready信号后发出fetch_B信号，状态机接收到fetch_B_ready信号后和MACs_ready信号后发出store_C信号，状态机接受到
//store_C_ready信号和full=0信号后发出fetch_A信号，如此循环32次最终状态机接收到store_C_ready信号和full=1信号后发出finish信号，矩阵乘法加速运算完成

initial begin
    #23 start = 1'b1;
    @(negedge clk)
    start = 1'b0;
end
//定义一个计数器
integer k = 0;//选择矩阵A的对应行
integer p = 0;//取矩阵B的全部行时的计数变量
//循环不断地检测top module的输出信号值，做出相应的测试台给top module输入端口送数(在clk上升沿进行)或是测试台从top module输出端口取数操作
//下面这个always块给出的测试台给top输入的送数时序和从top输出取数的时序


//根据多次调试，下面代码段弃用，应为Verilog仿真器处理不了在测试台中的always块，要么把这个always块封装成一个测试模块，要么写很长的initial块，别无它法
/*
always @(*)
//always @ (fetch_A or fetch_B or store_C or finish)
    begin
        case({fetch_A,fetch_B,store_C,finish})
            4'b1000: //取矩阵A的对应行
                begin
                      @(posedge clk);
                      for ( j = 0 ; j < 32 ; j = j + 1) begin
                        data_in[32*j+:32] = dataA_value [k][j];
                        end
                      fetch_A_ready = 1'b1;
                      # (PERIOD*2) fetch_A_ready = 1'b0;
                end
            4'b0100://取矩阵B的全部行
                begin
                    #35
                    repeat(32)begin
                      @(posedge clk);
                      for ( j = 0 ; j < 32 ; j = j + 1) begin
                        data_in[32*j+:32] = dataB_value [p][j];
                        end
                      p = p + 1;
                    end
                    // dataC_value[0][0] = 32'd2; 测试dataC_value能否写入的代码
                    p = 0;
                    fetch_B_ready = 1'b1;
                    # (PERIOD*2) fetch_B_ready = 1'b0;
                end
            4'b0010://存矩阵C的对应行
                begin
                   // dataC_value[0][0] = 32'd3; 测试dataC_value能否写入的代码
                    @(posedge clk);//这里少了时序控制句柄
                    for ( j = 0 ; j < 32 ; j = j + 1) begin
                        dataC_value[k][j] = dataC_out [32*j+:32];
                    end
                    k = k+1;
                    store_C_ready = 1'b1;
                    # (PERIOD*2) store_C_ready = 1'b0;
                end
            4'b0001:
                begin
                    k = 0;
                end
            default:
                begin
                    k = 0;
                end
        endcase
    end
*/
//和邓哥商量之后，还是一段段写initial语句较为稳妥
//vivado仿真器可能不支持在测试台中写always语句建模一个重复不断时序过程
//就算把这个基于Verilog仿真的testbench研究的很好也没用，因为外面用UVM,你只需要跑通一个就行了，所以在initial里面做就行了
//把每个initial对应的矩阵C输出行输出的时刻记录下来，在下一个initial时刻延长对应的值，执行矩阵C新行的生成
//initial 配合if else语句控制是比较现实的解决方案
//采用命名事件控制的时序控制方式编写联合仿真的TestBench文件

event pos_fetchA_1, pos_fetchA_2, pos_fetchA_3, pos_fetchA_4, pos_fetchA_5, pos_fetchA_6, pos_fetchA_7, pos_fetchA_8,
      pos_fetchA_9, pos_fetchA_10, pos_fetchA_11, pos_fetchA_12, pos_fetchA_13, pos_fetchA_14, pos_fetchA_15, pos_fetchA_16,
      pos_fetchA_17, pos_fetchA_18, pos_fetchA_19, pos_fetchA_20, pos_fetchA_21, pos_fetchA_22, pos_fetchA_23, pos_fetchA_24,
      pos_fetchA_25, pos_fetchA_26, pos_fetchA_27, pos_fetchA_28, pos_fetchA_29, pos_fetchA_30, pos_fetchA_31, pos_fetchA_32;

event pos_fetchB_1, pos_fetchB_2, pos_fetchB_3, pos_fetchB_4, pos_fetchB_5, pos_fetchB_6, pos_fetchB_7, pos_fetchB_8,
      pos_fetchB_9, pos_fetchB_10, pos_fetchB_11, pos_fetchB_12, pos_fetchB_13, pos_fetchB_14, pos_fetchB_15, pos_fetchB_16,
      pos_fetchB_17, pos_fetchB_18, pos_fetchB_19, pos_fetchB_20, pos_fetchB_21, pos_fetchB_22, pos_fetchB_23, pos_fetchB_24,
      pos_fetchB_25, pos_fetchB_26, pos_fetchB_27, pos_fetchB_28, pos_fetchB_29, pos_fetchB_30, pos_fetchB_31, pos_fetchB_32;

event pos_storeC_1, pos_storeC_2, pos_storeC_3, pos_storeC_4, pos_storeC_5, pos_storeC_6, pos_storeC_7, pos_storeC_8,
      pos_storeC_9, pos_storeC_10, pos_storeC_11, pos_storeC_12, pos_storeC_13, pos_storeC_14, pos_storeC_15, pos_storeC_16,
      pos_storeC_17, pos_storeC_18, pos_storeC_19, pos_storeC_20, pos_storeC_21, pos_storeC_22, pos_storeC_23, pos_storeC_24,
      pos_storeC_25, pos_storeC_26, pos_storeC_27, pos_storeC_28, pos_storeC_29, pos_storeC_30, pos_storeC_31, pos_storeC_32;

reg [5:0] count_fetchA = 0,
          count_fetchB = 0,
          count_storeC = 0;
//设置这些事件的触发条件
always@(posedge fetch_A) begin
    count_fetchA = count_fetchA + 1'b1;
    case(count_fetchA)
        6'd1: -> pos_fetchA_1;
        6'd2: -> pos_fetchA_2;
        6'd3: -> pos_fetchA_3;
        6'd4: -> pos_fetchA_4;
        6'd5: -> pos_fetchA_5;
        6'd6: -> pos_fetchA_6;
        6'd7: -> pos_fetchA_7;
        6'd8: -> pos_fetchA_8;
        6'd9: -> pos_fetchA_9;
        6'd10: -> pos_fetchA_10;
        6'd11: -> pos_fetchA_11;
        6'd12: -> pos_fetchA_12;
        6'd13: -> pos_fetchA_13;
        6'd14: -> pos_fetchA_14;
        6'd15: -> pos_fetchA_15;
        6'd16: -> pos_fetchA_16;
        6'd17: -> pos_fetchA_17;
        6'd18: -> pos_fetchA_18;
        6'd19: -> pos_fetchA_19;
        6'd20: -> pos_fetchA_20;
        6'd21: -> pos_fetchA_21;
        6'd22: -> pos_fetchA_22;
        6'd23: -> pos_fetchA_23;
        6'd24: -> pos_fetchA_24;
        6'd25: -> pos_fetchA_25;
        6'd26: -> pos_fetchA_26;
        6'd27: -> pos_fetchA_27;
        6'd28: -> pos_fetchA_28;
        6'd29: -> pos_fetchA_29;
        6'd30: -> pos_fetchA_30;
        6'd31: -> pos_fetchA_31;
        6'd32: -> pos_fetchA_32;
        default : count_fetchA = 6'b000_000;
    endcase
end

always@(posedge fetch_B) begin
    count_fetchB = count_fetchB + 1'b1;
    case(count_fetchB)
        6'd1: -> pos_fetchB_1;
        6'd2: -> pos_fetchB_2;
        6'd3: -> pos_fetchB_3;
        6'd4: -> pos_fetchB_4;
        6'd5: -> pos_fetchB_5;
        6'd6: -> pos_fetchB_6;
        6'd7: -> pos_fetchB_7;
        6'd8: -> pos_fetchB_8;
        6'd9: -> pos_fetchB_9;
        6'd10: -> pos_fetchB_10;
        6'd11: -> pos_fetchB_11;
        6'd12: -> pos_fetchB_12;
        6'd13: -> pos_fetchB_13;
        6'd14: -> pos_fetchB_14;
        6'd15: -> pos_fetchB_15;
        6'd16: -> pos_fetchB_16;
        6'd17: -> pos_fetchB_17;
        6'd18: -> pos_fetchB_18;
        6'd19: -> pos_fetchB_19;
        6'd20: -> pos_fetchB_20;
        6'd21: -> pos_fetchB_21;
        6'd22: -> pos_fetchB_22;
        6'd23: -> pos_fetchB_23;
        6'd24: -> pos_fetchB_24;
        6'd25: -> pos_fetchB_25;
        6'd26: -> pos_fetchB_26;
        6'd27: -> pos_fetchB_27;
        6'd28: -> pos_fetchB_28;
        6'd29: -> pos_fetchB_29;
        6'd30: -> pos_fetchB_30;
        6'd31: -> pos_fetchB_31;
        6'd32: -> pos_fetchB_32;
        default : count_fetchB = 6'b000_000;
    endcase
end

always@(posedge store_C) begin
    count_storeC = count_storeC + 1'b1;
    case(count_storeC)
        6'd1: -> pos_storeC_1;
        6'd2: -> pos_storeC_2;
        6'd3: -> pos_storeC_3;
        6'd4: -> pos_storeC_4;
        6'd5: -> pos_storeC_5;
        6'd6: -> pos_storeC_6;
        6'd7: -> pos_storeC_7;
        6'd8: -> pos_storeC_8;
        6'd9: -> pos_storeC_9;
        6'd10: -> pos_storeC_10;
        6'd11: -> pos_storeC_11;
        6'd12: -> pos_storeC_12;
        6'd13: -> pos_storeC_13;
        6'd14: -> pos_storeC_14;
        6'd15: -> pos_storeC_15;
        6'd16: -> pos_storeC_16;
        6'd17: -> pos_storeC_17;
        6'd18: -> pos_storeC_18;
        6'd19: -> pos_storeC_19;
        6'd20: -> pos_storeC_20;
        6'd21: -> pos_storeC_21;
        6'd22: -> pos_storeC_22;
        6'd23: -> pos_storeC_23;
        6'd24: -> pos_storeC_24;
        6'd25: -> pos_storeC_25;
        6'd26: -> pos_storeC_26;
        6'd27: -> pos_storeC_27;
        6'd28: -> pos_storeC_28;
        6'd29: -> pos_storeC_29;
        6'd30: -> pos_storeC_30;
        6'd31: -> pos_storeC_31;
        6'd32: -> pos_storeC_32;
        default : count_storeC = 6'b000_000;
    endcase
end

//生成矩阵C的第一行
initial begin
    @(pos_fetchA_1) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_1)begin
        # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*8) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_1)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第二行
initial begin
    @(pos_fetchA_2) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_2)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_2)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第三行
initial begin
    @(pos_fetchA_3) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_3)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_3)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第四行
initial begin
    @(pos_fetchA_4) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_4)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_4)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第五行
initial begin
    @(pos_fetchA_5) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_5)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_5)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第六行
initial begin
    @(pos_fetchA_6) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_6)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_6)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第七行
initial begin
    @(pos_fetchA_7) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_7)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_7)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第八行
initial begin
    @(pos_fetchA_8) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_8)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_8)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第九行
initial begin
    @(pos_fetchA_9) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_9)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_9)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第十行
initial begin
    @(pos_fetchA_10) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_10)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_10)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第十一行
initial begin
    @(pos_fetchA_11) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_11)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_11)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第十二行
initial begin
    @(pos_fetchA_12) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_12)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_12)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第十三行
initial begin
    @(pos_fetchA_13) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_13)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_13)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第十四行
initial begin
    @(pos_fetchA_14) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_14)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_14)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第十五行
initial begin
    @(pos_fetchA_15) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_15)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_15)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第十六行
initial begin
    @(pos_fetchA_16) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_16)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_16)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第十七行
initial begin
    @(pos_fetchA_17) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_17)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_17)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第十八行
initial begin
    @(pos_fetchA_18) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_18)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_18)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第十九行
initial begin
    @(pos_fetchA_19) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_19)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_19)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第二十行
initial begin
    @(pos_fetchA_20) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_20)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_20)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第二十一行
initial begin
    @(pos_fetchA_21) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_21)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_21)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第二十二行
initial begin
    @(pos_fetchA_22) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_22)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_22)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第二十三行
initial begin
    @(pos_fetchA_23) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_23)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_23)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第二十四行
initial begin
    @(pos_fetchA_24) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_24)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_24)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第二十五行
initial begin
    @(pos_fetchA_25) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_25)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_25)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第二十六行
initial begin
    @(pos_fetchA_26) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_26)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_26)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第二十七行
initial begin
    @(pos_fetchA_27) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_27)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_27)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第二十八行
initial begin
    @(pos_fetchA_28) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_28)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_28)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第二十九行
initial begin
    @(pos_fetchA_29) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_29)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_29)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第三十行
initial begin
    @(pos_fetchA_30) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_30)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_30)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第三十一行
initial begin
    @(pos_fetchA_31) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_31)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_31)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

//生成矩阵C的第三十二行
initial begin
    @(pos_fetchA_32) begin
        @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataA_value [k][j];
            end
        fetch_A_ready = 1'b1;
        # (1.7*PERIOD) fetch_A_ready = 1'b0;
    end
end

initial begin
    @(pos_fetchB_32)begin
      //  # (3*PERIOD) //这一步是为了满足MACs模块单独仿真时。第二次依据波形图，已经不需要该延迟
        repeat(32)begin
            @(negedge clk)
            for ( j = 0 ; j < 32 ; j = j + 1) begin
                data_in[32*j+:32] = dataB_value [p][j];
            end
            p = p + 1;
        end
    end
    p = 0;
    fetch_B_ready = 1'b1;
    # (PERIOD*5) fetch_B_ready = 1'b0;
end

initial begin
    @(pos_storeC_32)begin
        @(posedge clk)
        for ( j = 0 ; j < 32 ; j = j + 1) begin
            dataC_value[k][j] = dataC_out [32*j+:32];
        end
        k = k+1;
        store_C_ready <= 1'b1;//这里阻塞赋值和非阻塞赋值反应在波形图上是不一样的
        # (PERIOD*2) store_C_ready <= 1'b0;
    end
end

initial
begin
    // vivado Verilog 仿真器默认只支持1000ns的仿真时长，这里最多设置1000ns
    # 14400
    $finish;
end

endmodule
