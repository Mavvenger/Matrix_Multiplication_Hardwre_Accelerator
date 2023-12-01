`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/25 14:36:55
// Design Name: 
// Module Name: MACs
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
//写出这个MACs模块真的出人意料！
//写这个MACs模块需要联合testbench，dataA_in是mux的输出，在j循环中是取矩阵A对应行的对应元素，dataB_in是取矩阵B的相应行
//连续赋值语句的左值必须是线网类型
//过程赋值语句(阻塞=，非阻塞<=，常在initial和always中使用)的对象是寄存器，整数，实数或时间变量，不能是线网数据类型
//过程赋值语句（阻塞=）在initial块中常用
//时序电路中，clk视为各动作的指挥棒，通常设置一些内部寄存器型变量或外部输入信号屏蔽某个时间的clk指挥棒，达到控制的作用
//对该模块拉出一个MUX选择信号控制MUX选通
module MACs(
    input [31:0] dataA_in,
    input [1023:0] dataB_in,
    input MACs_reset, //MACs_reset信号在计算矩阵C对应行时只在最开始时有效（高电平有效）
    input MACs_enable,//MACs_enable信号在计算矩阵C对应行时一直有效，直到MACs_ready信号拉高，状态机跳转，拉低MACs_enable信号，此时MACs_reset信号亦被拉低
    input clk,
    output [1023:0] dataC_out,
    output MACs_ready,
    //拉出内部寄存器看以便调试,这个在vivado提供的波形查看工具里面有相关功能，不需要这里手动操作
    /*
    output [1023:0] mult_result_out,
    output [1023:0] add_result_out,
    output [5:0] count_out,
    */
    //拉出MUX选择信号控制MUX选通
    output [4:0] mux_sel
    );
    
    reg [31:0] dataA_reg; // 用于保存dataA_in的寄存器
    reg [31:0] dataB_reg [31:0]; // 用于保存dataB_in的寄存器
    reg [31:0] dataC_reg [31:0]; // 用于存储乘累加结果的寄存器

    reg [5:0] count; // 用于计数乘法累加次数的寄存器 
    reg [4:0] count_for_mux_sel;//用于拉出mux_控制信号
    reg [31:0] mult_result [31:0]; // 单次乘法结果
    reg [31:0] add_result [31:0];  // 单次累加结果
    reg MACs_ready_reg;//用于指示乘累加完成的寄存器
    reg flag_reset ;//用于控制MACs_reset信号的有效时间
    integer i;
    // 同步复位逻辑，这里先取数，取数32次
    always @(posedge clk or posedge MACs_reset) begin
        if(MACs_enable)begin
             if (MACs_reset&&~flag_reset) begin
                dataA_reg <= 32'h00000000; // 复位dataA_reg的寄存器
                count <= 6'b000000; // 复位计数器
                count_for_mux_sel <= 5'b000_00;//复位输出的mux选择信号
                //MACs模块计算开始时对MACs_ready_reg信号和flag_reset信号做一些处理，使之不再有效,乘累加状态，MACs_enable和MACs_reset信号始终为高
                flag_reset <= 1'b1;
                MACs_ready_reg <= 1'b0;
                for(i = 0;i < 32;i = i+1) begin
                    dataB_reg[i] <= 32'h0000_0000; // 复位dataB_reg的寄存器
                    dataC_reg[i] <= 32'h0000_0000; // 复位为0
                end
             end else begin
                //count的值表示取数次数，比如count等于1,表示取了一次数，一次j循环需要取数32次
                // 更新dataB_reg的寄存器
                for(i = 0;i < 32; i = i+1) begin
                    dataB_reg[i] <= dataB_in[32*i+:32];
                end
                // 更新dataA_reg的寄存器
                dataA_reg <= dataA_in;
                if (count < 6'b100010) begin//6'b10010 = 6'd34
                    count <= count + 1'b1; // 计数加1
                end
                if(count_for_mux_sel < 6'b111_11)begin //5'b111_11 = 5'd31
                   count_for_mux_sel <= count_for_mux_sel + 1'b1;
                end
            end
        end
    end
    //count的值表示取了多少次数
    // 每个时钟周期执行一次乘法累加操作，后执行乘法累加操作，乘法32次，累加32次（因为第一次复位清零）
    always @(posedge clk) begin
        if(MACs_enable) begin
            if (count == 6'b000_000) begin
                for(i = 0;i <32;i = i + 1)begin
                    mult_result[i] <= 32'h0000_0000; //配置
                    add_result[i] <= 32'h0000_0000;//配置
                    dataC_reg[i] <= 32'h0000_0000;//配置
                end
            end else if(count == 6'b000_001) begin
                for(i = 0;i <32;i = i + 1)begin
                    mult_result[i] <= dataA_reg * dataB_reg[i]; //计算乘法结果
                    add_result[i] <= 32'h0000_0000;//配置
                    dataC_reg[i] <= 32'h0000_0000;//配置
                end
            end else if(count == 6'b000_010) begin
                for(i = 0;i <32;i = i + 1)begin
                    mult_result[i] <= dataA_reg * dataB_reg[i]; //计算乘法结果
                    add_result[i] <= dataC_reg[i] + mult_result[i];//计算加法结果
                    dataC_reg[i] <= 32'h0000_0000;//配置
                end
            end else if((count > 6'b000_010) && (count < 6'b100_001)) begin
                for(i = 0;i <32;i = i + 1)begin
                    mult_result[i] <= dataA_reg * dataB_reg[i]; //计算乘法结果
                    add_result[i] <= dataC_reg[i] + mult_result[i];//计算加法结果
                    dataC_reg[i] <= add_result[i];//更新dataC_reg相应的子元素
                end
            end else if(count == 6'b100_001) begin
                for(i = 0;i <32;i = i + 1)begin
                    mult_result[i] <= 32'h0000_0000; //配置
                    add_result[i] <= dataC_reg[i] + mult_result[i];//计算加法结果
                    dataC_reg[i] <= add_result[i];//更新dataC_reg相应的子元素
                end
            end else begin
                //MACs模块计算结束时，对内部控制寄存器flag_reset和MACs_ready_reg进行处理
                MACs_ready_reg <= 1'b1;
                flag_reset <= 1'b0; //这里在计算结束时，拉低flag_reset信号不会导致MACs模块复位再次发生，因为count = 6'b100_000时，fetch_B_ready信号已经拉高，当MACs_ready信号拉高时，状态机已经跳转到写矩阵C的行状态，此时MACs_enable信号拉低
                for(i = 0;i <32;i = i + 1)begin
                    mult_result[i] <= 32'h0000_0000; //配置
                    add_result[i] <= 32'h0000_0000;//配置
                    dataC_reg[i] <= add_result[i] + dataC_reg[i];//更新dataC_reg相应的子元素,循环尾端需要做特殊处理
                end
            end
        end 
    end

    //使用generate语句生成连续赋值语句实例
    genvar j;
    generate for (j = 0;j < 32 ;j = j + 1 ) begin:gen_dataC_out
        assign dataC_out[32*j+:32] = dataC_reg[j]; // dataC_out的最高32位是矩阵行中列号最高的元素，输入端口dataB_in也是
    end
    endgenerate

    assign MACs_ready = MACs_ready_reg;
    assign mux_sel = count_for_mux_sel;

endmodule
