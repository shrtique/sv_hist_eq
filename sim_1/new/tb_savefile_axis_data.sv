`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.10.2018 16:25:02
// Design Name: 
// Module Name: tb_savefile_axis_data
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


module tb_savefile_axis_data#(
  parameter N      =  8,
  parameter height =  355,
  parameter width  =  355

  )(
  input logic         i_sys_clk,
  input logic         i_sys_aresetn,

  input logic [N-1:0] i_reg_video_tdata,
  input logic         i_reg_video_tvalid,
  input logic         i_reg_video_tlast,
  input logic         i_reg_video_tuser
  );



  //localparam    height = 355;

  //logic [207:0] data_to_save [0:(4*height-1)];
  logic [0:height-1][0:width-1][N-1:0] data_to_save;
  logic [0:height-1][0:width-1][N-1:0] image_array;
  
  logic [N-1:0]                        income_data;
  logic                                en_counters;
  logic                                end_of_frame;
  logic                                end_of_line;

  logic [10:0]                         pixel_counter;
  logic [10:0]                         line_counter;

  logic                                save_en;

  //logic                                i_sys_clk;
  //logic                                i_sys_aresetn;  



//registering data to the array of image
always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
     
    if ( ~i_sys_aresetn ) begin
      image_array <= '{default:'b0};
      //save_en      <= 1'b0;
    end else begin
      image_array[line_counter][pixel_counter] <= income_data;
    end
  end


//logic for grabbing data path
always_comb
  begin

    if ( i_reg_video_tvalid ) begin
      income_data = i_reg_video_tdata;
      en_counters = 1'b1;
    end else begin
      income_data = image_array[line_counter][pixel_counter];
      en_counters = 1'b0;   
    end	

  end	



//sync counter for pixels -> to detect that we've grabbed the whole frame
always_ff @( posedge i_sys_clk, negedge i_sys_aresetn )
  begin
     
    if ( ~i_sys_aresetn ) begin
      //pixel_address <= 0;
      pixel_counter <= 0;
      line_counter  <= 0;
      end_of_frame  <= 1'b0;
      end_of_line   <= 1'b0;
    end else begin
      if ( en_counters ) begin
        //pixel_address <= pixel_address + 1;
        pixel_counter <= pixel_counter + 1;
        end_of_line   <= 1'b0;
        if ( pixel_counter == width - 1 ) begin
          line_counter  <= line_counter + 1;
          pixel_counter <= 0;
          end_of_line   <= 1'b1;

          if ( line_counter == height - 1 ) begin
            line_counter  <= 0;
            //pixel_address <= 0;
            end_of_frame  <= 1'b1;
          end	
        end
      end
    end
  end       



 //just for test//START
/*  logic         clk;
  logic         aresetn;
  logic         save_en;
  
  always_ff @( posedge clk, negedge aresetn )
    begin
     
      if ( ~aresetn ) begin
        image_array <= '{default:'b0};
        save_en      <= 1'b0;
      end else begin
        image_array <= '{default:'hffffffffffffffffffffffffffffffffffffffffffffffffffff};
        save_en      <= 1'b1;
      end
            	
    end*/
//just for test//END 

  integer fileID;

  initial
    begin

      //i_sys_aresetn = 0; #15; i_sys_aresetn = 1;


      wait ( end_of_frame );

  	  fileID = $fopen("./test_jopa","w");
            
      for ( int i = 0; i < height; i++ ) begin

        for ( int j = 0; j < width; j++ ) begin

          $fwrite ( fileID, "%d ", image_array[i][j] ); //8bit data
        end	

        $fwrite ( fileID, "\n" );

      end	

      $fclose(fileID); 
      
      //$finish;
    

    end   



 //generate clk
/*always
  begin
    i_sys_clk = 1; #0.5;
    i_sys_clk = 0; #0.5;
  end	 
*/

endmodule