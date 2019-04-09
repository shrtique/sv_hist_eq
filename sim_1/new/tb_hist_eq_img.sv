`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////



module tb_hist_eq_img();

localparam DATA_WIDTH  = 8;
localparam WIDTH       = 1280;
localparam HEIGHT      = 1024;
//
//

//signals
logic clk;
logic aresetn;

logic [DATA_WIDTH-1:0]   tdata;
logic                    tvalid;
logic                    tuser;
logic                    tlast;           
//
//
tb_video_stream #(
  .N                ( DATA_WIDTH ),
  .width            ( WIDTH ),
  .height           ( HEIGHT ) 

) data_generator (
  .sys_clk          ( clk ),
  .sys_aresetn      ( aresetn ),

  .reg_video_tdata  ( tdata ),
  .reg_video_tvalid ( tvalid ),
  .reg_video_tlast  ( tlast ),
  .reg_video_tuser  ( tuser )
);
//
//

//signals
logic [2*DATA_WIDTH-1:0] tdata_eq;
logic                  tvalid_eq;
logic                  tuser_eq;
logic                  tlast_eq; 
// 
  hist_eq_module #(
    .DATA_WIDTH  ( DATA_WIDTH )

  ) hist_eq_module_inst ( 

    .i_sys_clk                ( clk          ),
    .i_sys_aresetn            ( aresetn      ),
                                
    .contrast_threshold_param ( 'd170 ),
    .upper_bound_param        ( 'd250 ),
    .lower_bound_param        ( 'd100 ),
    .thresholding_en          ( 1'b1  ),

    .s_axis_tdata             ( tdata       ),
    .s_axis_tvalid            ( tvalid      ),
    .s_axis_tuser             ( tuser       ),
    .s_axis_tlast             ( tlast       ),
    .s_axis_tready            (       ),
     
    .m_axis_tdata             ( tdata_eq       ),
    .m_axis_tvalid            ( tvalid_eq      ),
    .m_axis_tuser             ( tuser_eq       ),
    .m_axis_tlast             ( tlast_eq       )

  );
//
//


tb_savefile_axis_data #(

  .N      ( DATA_WIDTH ),
  .height ( HEIGHT     ),
  .width  ( WIDTH      )

) save_image_to_file (
  .i_sys_clk          ( clk           ),
  .i_sys_aresetn      ( aresetn       ),

  .i_reg_video_tdata  ( tdata_eq[2*DATA_WIDTH-1:DATA_WIDTH]  ),
  .i_reg_video_tvalid ( tvalid_eq ),
  .i_reg_video_tlast  ( tlast_eq  ),
  .i_reg_video_tuser  ( tuser_eq  )
  );



endmodule
