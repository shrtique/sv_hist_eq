`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.10.2018 09:43:08
// Design Name: 
// Module Name: tb_video_stream
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


module tb_video_stream #(
  parameter N      = 8,
  parameter width  = 10,
  parameter height = 10
  )(
  output logic         sys_clk,
  output logic         sys_aresetn,

  output logic [N-1:0] reg_video_tdata,
  output logic         reg_video_tvalid,
  output logic         reg_video_tlast,
  output logic         reg_video_tuser
  );


//signals//

  logic         clk;
  logic         aresetn;
  logic         en;


  //localparam    N = 8;
  
  logic [N-1:0] video_img;
  logic [N-1:0] video_mask;



  logic         video_tvalid;
  logic         video_tlast;
  logic         video_tuser;
  logic         video_tready;

 // logic [N-1:0] reg_video_tdata;
 // logic         reg_video_tvalid;
 // logic         reg_video_tlast;
 // logic         reg_video_tuser;
  logic         reg_video_tready;

  //localparam    width  = 10;
  //localparam    height = 10;


  logic [N-1:0] loaded_image [0:width*height-1];
  logic [N-1:0] loaded_mask  [0:width*height-1];
  logic [3:0]   testvectors  [10:0];

  logic         stream_on;
  logic         end_of_frame;
  logic         en_counters;
  logic [31:0]  pixel_address, pixel_address_current;
  logic [12:0]  pixel_counter;
  logic [12:0]  line_counter;
  logic [3:0]   frame_counter;

  logic [3:0]   pause_counter;
  logic [3:0]   pause_counter_reg;

  logic         en_drop, reg_en_drop;
///////////



//read image from file
integer fileId;

initial
  begin
    // Read
    fileId = $fopen("img_1280_1024_3.bin", "rb");
    $fread(loaded_image, fileId);
    $fclose(fileId);

  

    en_drop = 0;
    aresetn = 0; #15; aresetn = 1;
    en = 0; #33.2; en = 1;

    //LINE DROP
    wait ( (pixel_counter == 2) && ( line_counter == 0 ) );
    #0.5;
    en_drop = 1;
    #1;
    en_drop = 0;
    //

    //TLAST DROP
    wait ( (pixel_counter == 7) && ( line_counter == 0 ) );
    #0.5;
    en_drop = 1;
    #1;
    en_drop = 0;
    //
    
    //TUSER DROP
    wait ( state == IDLE );
    #0.5;
    en_drop = 1;
    #1;
    en_drop = 0;


  end	
//////////////////////

//reg_en_drop
always_ff @( posedge clk, negedge aresetn )
  begin
    if ( ~aresetn ) begin
      reg_en_drop <= 1'b0;
    end else begin
      reg_en_drop <= en_drop;
    end  
  end  

//generate clk
always
  begin
    clk = 1; #0.5;
    clk = 0; #0.5;
  end	
//////////////
assign sys_clk = clk;
assign sys_aresetn = aresetn;



//assign stream_on = ( en ) ? 1'b1 : 1'b0;

//AXIS FSM
typedef enum logic [3:0] {IDLE, TUSER, LINETRANSFER, TLAST, WAITING, PAUSE_BTW_FRAMES, DROP} statetype;
statetype state, nextstate;

//state reg
always_ff @( posedge clk, negedge aresetn )
 begin
   if   ( ~aresetn ) state <= IDLE;
   else              state <= nextstate;	
 end

//output reg
always_ff @( posedge clk, negedge aresetn )
 begin
   if   ( ~aresetn ) begin
     reg_video_tdata   <= 8'h00;
     reg_video_tvalid  <= 1'b0;
     reg_video_tlast   <= 1'b0;
     reg_video_tuser   <= 1'b0;
     reg_video_tready  <= 1'b0;

     pause_counter_reg <= 4'h0;
   end else begin
   	 reg_video_tdata   <= video_img;
     reg_video_tvalid  <= video_tvalid;
     reg_video_tlast   <= video_tlast;
     reg_video_tuser   <= video_tuser;
     reg_video_tready  <= video_tready;

     pause_counter_reg <= pause_counter;
   end             	
 end

//nextstage logic and output logic
always_comb
 begin

   video_img      = reg_video_tdata;
   video_tvalid   = 1'b0;  
   video_tlast    = 1'b0;
   video_tuser    = 1'b0;

   case ( state )

   	 IDLE : begin
   	   video_img      = 8'h00;
       video_tvalid   = 1'b0;  
       video_tlast    = 1'b0;
       video_tuser    = 1'b0;
       video_tready   = 1'b0;

       en_counters    = 1'b0;

       pause_counter  = 4'h0;

   	   if ( ( en ) && ( ~end_of_frame ) ) begin 
         
         video_tvalid = 1'b1;
         video_tuser  = 1'b1;
         video_img    = loaded_image[pixel_address]; 
   	     nextstate    = TUSER;
   	   end
   	 end //IDLE 

   	 TUSER : begin

   	 	video_img    = loaded_image[pixel_address];
      video_tuser  = 1'b0;
   	 	en_counters  = 1'b1;
      video_tvalid = 1'b1;
   	  nextstate    = LINETRANSFER;
      
      if ( reg_en_drop ) begin

        video_tvalid = 1'b0;
        video_img    = 8'b0;
        en_counters  = 1'b1;

        nextstate = DROP;
      end  

   	 end //TUSER      

   	 LINETRANSFER : begin
   	   video_tvalid = 1'b1;
   	   video_tuser  = 1'b0;	
   	   video_img    = loaded_image[pixel_address];

       

       en_counters  = 1'b1;

   	   if ( pixel_counter == width - 2 ) begin	
         video_tlast = 1'b1;
   	     nextstate   = TLAST;
   	   end

       if ( reg_en_drop ) begin

         video_tvalid = 1'b0;
         video_img    = 8'b0;
         en_counters  = 1'b1;
         video_tlast  = 1'b0;

         nextstate = DROP;
       end  
   	 end //LINETRANSFER  
     
     DROP : begin
       video_tvalid   = 1'b1;
       //en_counters    = 1'b1;
       video_img      = loaded_image[pixel_address];
       nextstate      = LINETRANSFER;

       if ( pixel_counter == width - 1 ) begin  
         video_tlast = 1'b1;
         nextstate   = TLAST;
       end

     end 

   	 TLAST : begin

       pause_counter = 4'h4;
   	   nextstate     = WAITING;
   	 end //TLAST

   	 WAITING : begin
   	   video_tvalid = 1'b0; 
   	   video_tlast  = 1'b0;
       video_img    = 8'h00;
       video_mask   = 8'h00;

       en_counters  = 1'b0;

   	   if ( end_of_frame ) begin
   	   	 nextstate = PAUSE_BTW_FRAMES;
         pause_counter = 4'ha;
   	   end else begin
         if ( pause_counter_reg != 0 ) begin
           pause_counter = pause_counter_reg - 1; 
         end else begin

            en_counters   = 1'b1;
            video_img     = loaded_image[pixel_address];
            video_tvalid  = 1'b1;
            nextstate     = LINETRANSFER;
          end 
   	   end

   	 end //WAITING 

     PAUSE_BTW_FRAMES : begin
       if ( pause_counter_reg != 0 ) begin
         pause_counter = pause_counter_reg - 1; 
       end else begin
         nextstate = IDLE;
       end 
     end //PAUSE_BTW_FRAMES

   	 default : nextstate = IDLE;
   endcase
 end


always @( posedge clk, negedge aresetn )
  begin
    if ( ~aresetn ) begin
      //pixel_address <= 0;
      pixel_counter <= 0;
      line_counter  <= 0;
      frame_counter <= 4'd5;
      end_of_frame  <= 1'b0;
    end else begin

      if (frame_counter != 0) begin
        end_of_frame <= 1'b0;    
      end
        
      if ( ( en_counters ) && ( reg_video_tvalid ) ) begin
        //pixel_address <= pixel_address + 1;
        pixel_counter <= pixel_counter + 1;

        if ( pixel_counter == width - 1 ) begin
          line_counter <= line_counter + 1;
          pixel_counter <= 0;

          if ( line_counter == height - 1 ) begin
            line_counter  <= 0;
            //pixel_address <= 0;
            end_of_frame  <= 1'b1;
            frame_counter <= frame_counter - 1;
          end	
        end
       end	

     end
  end


  //adress counter
  always_ff @( posedge clk, negedge aresetn )
    begin
      if ( ~aresetn ) begin
        pixel_address_current = 0;
      end else begin
        pixel_address_current = pixel_address;
      end  
    end  

  always_comb
    begin
      if ( ~aresetn ) begin
        pixel_address = 0;
      end else begin

        if ( ( en_counters ) && ( reg_video_tvalid ) ) begin
          pixel_address = pixel_address + 1;

          if ( ( pixel_counter == width - 1 ) && ( line_counter == height - 1 ) ) begin
            pixel_address = 0;
          end  
        end  
      end  
    end  


endmodule


