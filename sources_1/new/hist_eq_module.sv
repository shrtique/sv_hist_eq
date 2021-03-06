`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.01.2019 17:56:51
// Design Name: 
// Module Name: hist_eq_module
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

//DESCRIPTION:
//Histogram equalization : linear expanding
// f(I) = (I - min_I) * (255)/(cut_max_I - cut_min_I);
// (255)/(cut_max_I - cut_min_I) = mult;


module hist_eq_module #(
  parameter DATA_WIDTH = 8
)(  

  input  logic                    i_sys_clk,
  input  logic                    i_sys_aresetn,

  input  logic [DATA_WIDTH-1:0]   contrast_threshold_param,
  input  logic [9:0]              upper_bound_param,
  input  logic [9:0]              lower_bound_param,
  input  logic                    thresholding_en,
  
  input  logic [DATA_WIDTH-1:0]   s_axis_tdata,
  input  logic                    s_axis_tvalid,
  input  logic                    s_axis_tuser,
  input  logic                    s_axis_tlast,
  output logic                    s_axis_tready,

  output logic [2*DATA_WIDTH-1:0] m_axis_tdata, //[15:8] - image mask, [7:0] - original image
  output logic                    m_axis_tvalid,
  output logic                    m_axis_tuser,
  output logic                    m_axis_tlast

);

localparam PIPELINE_LENGTH    = 7;
localparam MAXIMUM_BRIGHTNESS = 2**DATA_WIDTH - 1;
//
//

//////////////////////////////////////////////////////////////////////////////////
//show that we're ready to receive pixels
always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin 
    if ( ~i_sys_aresetn ) begin
      s_axis_tready <= 1'b0;
    end else begin
      s_axis_tready <= 1'b1;
    end
end
//
//

//grabbing all AXI-Stream signals and pushing them through delay line.
//length of delay line is amount of processing stages for input pixels
//Main idea: output incoming interface signals synchroniusly with processed data;

logic [DATA_WIDTH-1:0] tdata  [0:PIPELINE_LENGTH-1];
logic                  tvalid [0:PIPELINE_LENGTH-1];
logic                  tuser  [0:PIPELINE_LENGTH-1];
logic                  tlast  [0:PIPELINE_LENGTH-1];


always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
    if ( ~i_sys_aresetn ) begin
      tdata  <= '{default:'0};
      tvalid <= '{default:'0};
      tuser  <= '{default:'0};
      tlast  <= '{default:'0};
    end else begin

      tdata                       <= {s_axis_tdata,  tdata[0:PIPELINE_LENGTH-2]}; 
      tvalid                      <= {s_axis_tvalid, tvalid[0:PIPELINE_LENGTH-2]};
      tuser                       <= {s_axis_tuser,  tuser[0:PIPELINE_LENGTH-2]};
      tlast                       <= {s_axis_tlast,  tlast[0:PIPELINE_LENGTH-2]};
      
    end   
  end
//
//

//STAGE_0
//In current frame we're estimating next_min_I and next_max_I value which are going to be used in calculation for next frame
//max_I and min_I for current calculation are updated with tuser

//Example:
//Histogram:
//  ^
//  |          +++
//  |       ++++++++
//  |     +++++++++++
//  |    ++++++++++++
//  |    ++++++++++++
//  |____|__________|______>
//  0    20         120    255

//So: min_I = 20, max_I = 120

logic [DATA_WIDTH-1:0] next_max_I, max_I;
logic [DATA_WIDTH-1:0] next_min_I, min_I;
logic                  ip_is_after_reset;

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin 
    if ( ~i_sys_aresetn ) begin
      ip_is_after_reset <= 1'b1;

      max_I             <= '1;
      min_I             <= '0;

      next_max_I        <= '0; 
      next_min_I        <= '1;
    end else begin

      if ( tvalid[0] ) begin

        if ( tuser[0] ) begin //update max_I, min_I with tuser and reset next_max_I to 0 and next_min_I to 255 //miss one pixel but we dnt mind
        
          if ( ~ip_is_after_reset ) begin
            max_I      <= next_max_I;
            min_I      <= next_min_I;
          end

           next_max_I        <= '0;
           next_min_I        <= '1;
           ip_is_after_reset <= 1'b0;

        end else begin 

          if ( tdata[0] > next_max_I ) begin
            next_max_I <= tdata[0];
          end 
          
          if ( ( tdata[0]  < next_min_I ) && ( tdata[0] != 0) ) begin //we don't use 0 as min value, cause it could be found on a border of the image
            next_min_I <= tdata[0];
          end

        end
      end
    end
end
//
//

//STAGE_1

//Example:
//min_I = 20, max_I = 120
//(max_I-min_I) = 100;
// 

logic [DATA_WIDTH-1:0] diff_max_I_min_I;

//use reg with sync reset, cause it's the input of DSP
always_ff @( posedge i_sys_clk )
  begin 
    if ( ~i_sys_aresetn ) begin
      diff_max_I_min_I <= '0;
    end else begin
      diff_max_I_min_I <= max_I - min_I;
    end
end
//
//

//STAGE_2
//Evaluating expanding range, part_1
//
//NOTE: We use here comb logic for mult and after that register only [DATA_WIDTH+9:10] to divide by 1024;
//      Also we use here regs with sync reset -> this helps us to optimize DSP inst.

//Example:
//upper_bound_param = 70% 
//lower_bound_param = 20%
//
//cut_from_upper_bound = diff_max_I_min_I * 0.7 = diff_max_I_min_I * 717 / 1024;
//cut_from_lower_bound = diff_max_I_min_I * 0.2 = diff_max_I_min_I * 205 / 1024;
//
//Multiplying:
//1: cut_from_upper_bound_interm_step = diff_max_I_min_I * 717;
//1: cut_from_lower_bound_interm_step = diff_max_I_min_I * 205;
//

logic [DATA_WIDTH+9:0] cut_from_upper_bound_interm_step_r, cut_from_upper_bound_interm_step;
logic [DATA_WIDTH+9:0] cut_from_lower_bound_interm_step_r, cut_from_lower_bound_interm_step;

always_comb begin
  cut_from_upper_bound_interm_step = diff_max_I_min_I * upper_bound_param;
  cut_from_lower_bound_interm_step = diff_max_I_min_I * lower_bound_param;
end

//continuation of STAGE_2: shifting (div 1024)
//2: cut_from_upper_bound <= cut_from_upper_bound_interm_step >> 10 or just take [DATA_WIDTH+9:10];
//2: cut_from_lower_bound <= cut_from_upper_bound_interm_step >> 10 or just take [DATA_WIDTH+9:10];

logic [DATA_WIDTH+9:0] cut_from_upper_bound;
logic [DATA_WIDTH+9:0] cut_from_lower_bound;

//make it with sync reset to use DSP;
always_ff @( posedge i_sys_clk )
  begin 
    if ( ~i_sys_aresetn ) begin
      cut_from_upper_bound <= '{default:'0};
      cut_from_lower_bound <= '{default:'0};
    end else begin

      cut_from_upper_bound <= cut_from_upper_bound_interm_step;//cut_from_upper_bound_interm_step[DATA_WIDTH+9:10];
      cut_from_lower_bound <= cut_from_lower_bound_interm_step;//cut_from_lower_bound_interm_step[DATA_WIDTH+9:10];
    end
end

//
//

//STAGE_3
//DSP needs an extra pipeline register on it's output
logic [DATA_WIDTH-1:0] cut_from_upper_bound_reg;
logic [DATA_WIDTH-1:0] cut_from_lower_bound_reg;

//make it with sync reset to use DSP;
always_ff @( posedge i_sys_clk )
  begin 
    if ( ~i_sys_aresetn ) begin
      cut_from_upper_bound_reg <= '{default:'0};
      cut_from_lower_bound_reg <= '{default:'0};
    end else begin

      cut_from_upper_bound_reg <= cut_from_upper_bound[DATA_WIDTH+9:10];
      cut_from_lower_bound_reg <= cut_from_lower_bound[DATA_WIDTH+9:10];
    end
end




//STAGE_4
//Evaluating expanding range, part_2
//cut_min_I = min_I + cut_from_lower_bound;
//cut_max_I = min_I + cut_from_upper_bound;

//Example:
//Histogram:
//  ^
//  |          +++
//  |       ++++++++
//  |     +++++++++++
//  |    ++++++++++++
//  |    ++++++++++++
//  |____|__|____|__|______>
//  0    20 40   90 120    255

//So: min_I = 20, max_I = 120 ...
//... diff_max_I_min_I = 100 ...
//... cut_from_upper_bound = 100 * 0.7 = 70;
//... cut_from_lower_bound = 100 * 0.2 = 20;
//
// cut_min_I = 20 + 20 = 40;
// cut_max_I = 20 + 70 = 90;


logic [DATA_WIDTH-1:0] cut_max_I;
logic [DATA_WIDTH-1:0] cut_min_I;

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin 
    if ( ~i_sys_aresetn ) begin
      cut_max_I <= '{default:'0};
      cut_min_I <= '{default:'0};
    end else begin
      if ( ( max_I - min_I ) > cut_from_upper_bound_reg) begin
        cut_max_I <= min_I + cut_from_upper_bound_reg;
      end else begin
      	cut_max_I <= max_I;
      end 
      cut_min_I <= min_I + cut_from_lower_bound_reg;
    end
end
//
//

//STAGE_5
//cut_diff_max_I_min_I = (cut_max_I - cut_min_I)
logic [DATA_WIDTH-1:0] cut_diff_max_I_min_I;

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin 
    if ( ~i_sys_aresetn ) begin
      cut_diff_max_I_min_I <= '{default:'0};
    end else begin
      cut_diff_max_I_min_I <= cut_max_I - cut_min_I;
    end
end
//
//

//STAGE_6.1
//(255)/(cut_max_I - cut_min_I) = mult;
//We decided not to use devision, so we estimated mult according to cut_diff_max_I_min_I
logic [4:0] mult;


//use reg with sync reset, cause it's the input of multiplier
always_ff @( posedge i_sys_clk )
  begin 
    if ( ~i_sys_aresetn ) begin
      mult <= '{default:'0};
      
    end else begin
      if (cut_diff_max_I_min_I != 0) begin
                                
        if (cut_diff_max_I_min_I > 127) begin
          mult <= 1;
        end else if (cut_diff_max_I_min_I > 85) begin
          mult <= 2;
        end else if (cut_diff_max_I_min_I > 63) begin 
          mult <= 3;
        end else if (cut_diff_max_I_min_I > 51) begin
          mult <= 4;
        end else if (cut_diff_max_I_min_I > 42) begin    
          mult <= 5;
        end else if (cut_diff_max_I_min_I > 36) begin
          mult <= 6; 
        end else if (cut_diff_max_I_min_I > 31) begin   
          mult <= 7;
        end else if (cut_diff_max_I_min_I > 28) begin
          mult <= 8;
        end else if (cut_diff_max_I_min_I > 25) begin   
          mult <= 9;
        end else if (cut_diff_max_I_min_I > 23) begin 
          mult <= 10;
        end else if (cut_diff_max_I_min_I > 21) begin
          mult <= 11;
        end else if (cut_diff_max_I_min_I > 19) begin
          mult <= 12;
        end else if (cut_diff_max_I_min_I > 18) begin
          mult <= 13;
        end else if (cut_diff_max_I_min_I > 17) begin
          mult <= 14;
        end else if (cut_diff_max_I_min_I > 15) begin
          mult <= 15;
        end else if (cut_diff_max_I_min_I <= 15) begin
          mult <= 17;
        end
                            
      end else begin
        mult <= '{default:'0};
      end
    end
end
//
//

//STAGE_6.2
//data_minus_min_I = (I - min_I)
//calculation during this stage is done simultainiously with stage_5,..
//..so mult and data_minus_min_I appear together

logic [DATA_WIDTH-1:0] data_minus_min_I;
logic test1;
logic test2;

//use reg with sync reset, cause it's the input of multiplier
always_ff @( posedge i_sys_clk )
  begin 
    if ( ~i_sys_aresetn ) begin
      data_minus_min_I <= '{default:'0};
    end else begin
      if ( tdata[3] <  cut_min_I ) begin
        data_minus_min_I <= '{default:'0};
      end else begin	
        data_minus_min_I <= tdata[3] - cut_min_I;
     end

    end
end
//
//

//STAGE_7
// f(I) = data_minus_min_I * mult;
logic [DATA_WIDTH+4:0] f_I;
logic test3;
logic test4;

//use reg with sync reset, cause it's the output of multiplier
always_ff @( posedge i_sys_clk )
  begin 
    if ( ~i_sys_aresetn ) begin
      f_I <= '{default:'0};
    end else begin
      f_I <= data_minus_min_I * mult;
    end
end

//STAGE_8
//Thresholding -> IMAGE MASK CREATION
logic [DATA_WIDTH-1:0] data_after_threshold;
logic test5;
logic test6;
logic test7;
logic test8;

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn ) begin 
  if ( ~i_sys_aresetn ) begin
    data_after_threshold <= '{default:'0};
  end else begin

    if ( thresholding_en ) begin

      if ( f_I > contrast_threshold_param ) begin
        data_after_threshold <= '{default:'1};    
      end else begin
        data_after_threshold <= '{default:'0};
      end  

    end else begin
      if ( f_I > MAXIMUM_BRIGHTNESS ) begin
        data_after_threshold <= '1;
      end else begin
        data_after_threshold <= f_I;
      end
    end
  end     
end
//
//

//OUTPUT 
// [23:16] - saturation channel, [15:8] - image mask, [7:0] - original image
// if thresholding_en == 0,      [15:8] - contrasted image

always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin 
    if ( ~i_sys_aresetn ) begin
      m_axis_tdata  <= '{default:'0};
      m_axis_tvalid <= 1'b0;
      m_axis_tuser  <= 1'b0;
      m_axis_tlast  <= 1'b0;
    end else begin

      m_axis_tdata[2*DATA_WIDTH-1:0] <= {data_after_threshold, tdata[PIPELINE_LENGTH-1]};
      m_axis_tvalid                  <= tvalid[PIPELINE_LENGTH-1];
      m_axis_tuser                   <= tuser[PIPELINE_LENGTH-1];
      m_axis_tlast                   <= tlast[PIPELINE_LENGTH-1];

    end
end

//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
endmodule
