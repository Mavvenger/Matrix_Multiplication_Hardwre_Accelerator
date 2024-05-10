# Matrix_Multiplication_Hardwre_Accelerator             
Baseline_for_Low-overhead_Fault-tolerant_Logic_for_Field-programmable_Gate_Arrays                          
This project is based on Verilog HDL modeling a matrix multiplication hardware accelerator                                      
Design files contain:                                                                             
(1)top.v ： Condensing of submodules                                                         
(2)counter.v ：Counts the number of rows of matrix A taken                                                                     
(3)Register1024.v ： Buffers the rows of matrix A                                                
(4)FSM_for_Matrix_Multiplication_Accelerator.v : Control data path data processing timing                                      
(5)MACs.v : Multiply_Accumulate                          
(6)mux.v : Data Seletor               
Simulation files contain:                                                                                   
(1)tb_top.sv : Joint functional simulation                                                                                     
(2)tb_counter : Counter simulation                                                  
(3)tb_MACs : MACs simulation                                              
(4)tb_Register1024 : register1024 simulation                                                                            
(5)tb_mux : mux simulation                              
(6)tb_FSM_for_Matrix_Multiplication_Accelerator : Controller Simulation 
