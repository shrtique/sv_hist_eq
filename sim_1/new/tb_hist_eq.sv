`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.01.2019 18:24:27
// Design Name: 
// Module Name: tb_hist_eq
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


module tb_hist_eq(

    );

localparam DATA_WIDTH  = 8;

logic                  clk;
logic                  aresetn;

logic [DATA_WIDTH-1:0] contrast_threshold;
logic [9:0]            upper_bound;
logic [9:0]            lower_bound;
logic                  thresholding_en; 


logic [DATA_WIDTH-1:0] s_axis_tdata;
logic                  s_axis_tvalid;
logic                  s_axis_tuser;
logic                  s_axis_tlast;


            
hist_eq_module #(
  .DATA_WIDTH  ( DATA_WIDTH )

) hist_eq_module_inst ( 

  .i_sys_clk                ( clk          ),
  .i_sys_aresetn            ( aresetn      ),
                              
  .contrast_threshold_param ( contrast_threshold ),
  .upper_bound_param        ( upper_bound        ),
  .lower_bound_param        ( lower_bound        ),
  .thresholding_en          ( thresholding_en    ),
  
  .s_axis_tdata             ( s_axis_tdata       ),
  .s_axis_tvalid            ( s_axis_tvalid      ),
  .s_axis_tuser             ( s_axis_tuser       ),
  .s_axis_tlast             ( s_axis_tlast       ),
  .s_axis_tready            (       ),
        
  .m_axis_tdata             (        ),
  .m_axis_tvalid            (        ),
  .m_axis_tuser             (        ),
  .m_axis_tlast             (        )
  
);


//simulation
always
  begin
    clk = 1; #5; clk = 0; #5;
  end


initial
  begin

    aresetn            = 1'b0;
    contrast_threshold = '0;
    upper_bound        = '0;
    lower_bound        = '0;
    thresholding_en    = '0;

    s_axis_tdata       = '0;
    s_axis_tvalid      = 1'b0;
    s_axis_tuser       = 1'b0;
    s_axis_tlast       = 1'b0;

    #20;
    aresetn            = 1'b1;

  end 


//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
endmodule
