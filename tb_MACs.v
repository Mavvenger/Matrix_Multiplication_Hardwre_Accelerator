`timescale  1ns / 1ps

module tb_MACs;

// MACs Parameters
parameter PERIOD  = 10;


// MACs Inputs
reg   [31:0]  dataA_in                     = 0 ;
reg   [1023:0]  dataB_in                   = 0 ;
reg   MACs_reset                           = 0 ;
reg   MACs_enable                          = 0 ;
reg   clk                                  = 0 ;


// MACs Outputs
wire  [1023:0]  dataC_out                  ;
wire  MACs_ready                           ;
wire  [4:0]   mux_sel                      ;
//拉出设计内部信号查看以便调试
/*
wire  [1023:0]  mult_result_out                  ;
wire  [1023:0]  add_result_out                  ;
wire  [5:0]    count_out                        ;
*/
initial
begin
    forever #(PERIOD/2)  clk=~clk;
end


//对于MACs初始状态不确定的问题，是否可以借鉴状态机那样，在例化的时候传入一个参数，确定初始状态
MACs  u_MACs (
    .dataA_in                ( dataA_in     [31:0]   ),
    .dataB_in                ( dataB_in     [1023:0] ),
    .MACs_reset              ( MACs_reset            ),
    .MACs_enable             ( MACs_enable           ),
    .clk                     ( clk                   ),

    .dataC_out               ( dataC_out    [1023:0] ),
    .MACs_ready              ( MACs_ready            ),
    .mux_sel                 (mux_sel       [4:0]    )
    /*
    .add_result_out          (add_result_out[1023:0] ),
    .mult_result_out         (mult_result_out[1023:0]),
    .count_out               (count_out[5:0]         )
    */
);
//dataA_value和dataB_value是测试过程中待使用的矩阵用例
reg [31:0] dataA_value [0:31]; //后面的下标按照这样写是为了与数组元素常规排列方式匹配
reg [31:0] dataB_value [0:31] [0:31];
integer i,j;
//给矩阵元素赋初值，初始化MACs_enable,MACs_reset信号
initial begin
    for(i=0;i<32;i=i+1) begin
        dataA_value[i] = 32'd1;
    end
    for(i=0;i<32;i=i+1)begin
      for(j=0;j<32;j=j+1)begin
        if(i==j)begin
          dataB_value[i][j] = 32'd2;
        end else begin
          dataB_value[i][j] = 32'd0;
        end
      end
    end
    #8
    MACs_reset = 1'b1;
    MACs_enable = 1'b1;
    #385
    MACs_reset = 1'b0;
    MACs_enable = 1'b0;
end
//你不劳动就没机会劳动了
//模拟现实中的行为，拉高后数据按时钟周期进入dataA_in和dataB_in
integer k = 0;
initial begin
    # 35
    //在时钟下降沿送数，MACs模块在时钟上升沿取数，波形报告显示dataA_in和dataB_in符合要求
    repeat(32) begin
      @(negedge clk);
      dataA_in = dataA_value[k];
      
      dataB_in = {dataB_value[k][31],dataB_value[k][30],dataB_value[k][29],dataB_value[k][28],dataB_value[k][27],dataB_value[k][26],dataB_value[k][25],dataB_value[k][24],
      dataB_value[k][23],dataB_value[k][22],dataB_value[k][21],dataB_value[k][20],dataB_value[k][19],dataB_value[k][18],dataB_value[k][17],dataB_value[k][16],
      dataB_value[k][15],dataB_value[k][14],dataB_value[k][13],dataB_value[k][12],dataB_value[k][11],dataB_value[k][10],dataB_value[k][9],dataB_value[k][8],
      dataB_value[k][7],dataB_value[k][6],dataB_value[k][5],dataB_value[k][4],dataB_value[k][3],dataB_value[k][2],dataB_value[k][1],dataB_value[k][0]};
      //这里dataB_in的元素排列顺序和MACs.v文件中dataC_in的排列要求对应起来了
      k = k+1;
    end
end

initial
begin
    #430 $finish;
end

endmodule