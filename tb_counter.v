`timescale  1ns / 1ps

module tb_counter;

// counter Parameters
parameter PERIOD  = 10;


// counter Inputs
reg   register_ready                       = 0 ;

// counter Outputs
wire  full                                 ;

initial
begin
    forever #(PERIOD/2)  register_ready=~register_ready;
end
/*
initial
begin
    #(PERIOD*2) rst_n  =  1;
end
*/
counter  u_counter (
    .register_ready          ( register_ready   ),

    .full                    ( full             )
);

initial
begin
    # 340
    $finish;
end

endmodule