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


module hist_eq_module #(
  parameter DATA_WIDTH = 8
)(  

  input  logic                    i_sys_clk,
  input  logic                    i_sys_aresetn,
  
  input  logic [DATA_WIDTH-1:0]   s_axis_tdata,
  input  logic                    s_axis_tvalid,
  input  logic                    s_axis_tuser,
  input  logic                    s_axis_tlast,
  output logic                    s_axis_tready,

  output logic [3*DATA_WIDTH-1:0] m_axis_tdata,
  output logic                    m_axis_tvalid,
  output logic                    m_axis_tuser,
  output logic                    m_axis_tlast

);


//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
endmodule
