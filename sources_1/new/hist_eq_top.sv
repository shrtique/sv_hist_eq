
`timescale 1 ns / 1 ps

//REGISTERS DISCRIPTION--
// reg0: W
        //[9:0]   threshold    
        //[19:10] upper_bound_param
        //[29:20] lower_bound_param
        //[30]    threshold_enable 
        //[31]    set_new_param
        
///////

//NOTES:
//For example: upper_bound = 70%  -> upper_bound_param = 717;
//             lower_bound = 20%  -> lower_bound_param = 205;
//                           100% -> 1024


	module hist_eq_top #
	(
		// Users to add parameters here
    parameter DATA_WIDTH = 8,
		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
    parameter C_S00_AXI_DATA_WIDTH	= 32,
    parameter C_S00_AXI_ADDR_WIDTH	= 4
	)
	(
		// Users to add ports here
    input  logic                      i_sys_clk,
    input  logic                      i_sys_aresetn,

    input  logic [DATA_WIDTH-1:0]     s_axis_tdata,
    input  logic                      s_axis_tvalid,
    input  logic                      s_axis_tuser,
    input  logic                      s_axis_tlast,
    output logic                      s_axis_tready,
        
    output logic [2*DATA_WIDTH-1:0]   m_axis_tdata,
    output logic                      m_axis_tvalid,
    output logic                      m_axis_tuser,
    output logic                      m_axis_tlast,

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input  logic                                s00_axi_aclk,
		input  logic                                s00_axi_aresetn,
		input  logic [C_S00_AXI_ADDR_WIDTH-1:0]     s00_axi_awaddr,
		input  logic [2:0]                          s00_axi_awprot,
		input  logic                                s00_axi_awvalid,
		output logic                                s00_axi_awready,
		input  logic [C_S00_AXI_DATA_WIDTH-1:0]     s00_axi_wdata,
		input  logic [(C_S00_AXI_DATA_WIDTH/8)-1:0] s00_axi_wstrb,
		input  logic                                s00_axi_wvalid,
		output logic                                s00_axi_wready,
		output logic [1:0]                          s00_axi_bresp,
		output logic                                s00_axi_bvalid,
		input  logic                                s00_axi_bready,
		input  logic [C_S00_AXI_ADDR_WIDTH-1:0]     s00_axi_araddr,
		input  logic [2:0]                          s00_axi_arprot,
		input  logic                                s00_axi_arvalid,
		output logic                                s00_axi_arready,
		output logic [C_S00_AXI_DATA_WIDTH-1:0]     s00_axi_rdata,
		output logic [1:0]                          s00_axi_rresp,
		output logic                                s00_axi_rvalid,
		input  logic                                s00_axi_rready
	);

//SIGNALS
logic [C_S00_AXI_DATA_WIDTH-1:0] slv_reg0;

// Instantiation of Axi Bus Interface S00_AXI
	hist_eq_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) hist_eq_S00_AXI_inst  (

	    //W REGISTERS (from processor)
        .slv_reg0_out  ( slv_reg0 ), 
        .slv_reg1_out  (  ), 
        .slv_reg2_out  (  ), 
        .slv_reg3_out  (  ),
        // 
        .S_AXI_ACLK    ( s00_axi_aclk    ),
        .S_AXI_ARESETN ( s00_axi_aresetn ),
        .S_AXI_AWADDR  ( s00_axi_awaddr  ),
        .S_AXI_AWPROT  ( s00_axi_awprot  ),
        .S_AXI_AWVALID ( s00_axi_awvalid ),
        .S_AXI_AWREADY ( s00_axi_awready ),
        .S_AXI_WDATA   ( s00_axi_wdata   ),
        .S_AXI_WSTRB   ( s00_axi_wstrb   ),
        .S_AXI_WVALID  ( s00_axi_wvalid  ),
        .S_AXI_WREADY  ( s00_axi_wready  ),
        .S_AXI_BRESP   ( s00_axi_bresp   ),
        .S_AXI_BVALID  ( s00_axi_bvalid  ),
        .S_AXI_BREADY  ( s00_axi_bready  ),
        .S_AXI_ARADDR  ( s00_axi_araddr  ),
        .S_AXI_ARPROT  ( s00_axi_arprot  ),
        .S_AXI_ARVALID ( s00_axi_arvalid ),
        .S_AXI_ARREADY ( s00_axi_arready ),
        .S_AXI_RDATA   ( s00_axi_rdata   ),
        .S_AXI_RRESP   ( s00_axi_rresp   ),
        .S_AXI_RVALID  ( s00_axi_rvalid  ),
        .S_AXI_RREADY  ( s00_axi_rready  )
	);

	// Add user logic here

	//SIGNALS
    logic [DATA_WIDTH-1:0] contrast_threshold;
    logic [9:0]            upper_bound;
    logic [9:0]            lower_bound;
    logic                  thresholding_en;
    logic [0:1]  set_new_param; 
    //
    //

    // synch stage   
    always_ff @( posedge i_sys_clk ) begin 
      if ( ~i_sys_aresetn ) begin
        set_new_param <= '0;
      end else begin
        set_new_param <= {slv_reg0[31],set_new_param[0]};
      end
    end
    ////

	//registering new parameters only when s_axis_tuser is active
    //use reg with sync reset, cause some parameters are used as inputs for DSP
	always_ff @( posedge i_sys_clk )
    begin 
      if ( ~i_sys_aresetn ) begin
        contrast_threshold <= '0;
        upper_bound        <= '0;
        lower_bound        <= '0;
        thresholding_en    <= 1'b0;
      end else begin
        if ( s_axis_tuser && set_new_param[1] ) begin
          contrast_threshold <= slv_reg0[DATA_WIDTH-1:0];
          upper_bound        <= slv_reg0[19:10];
          lower_bound        <= slv_reg0[29:20];
          thresholding_en    <= slv_reg0[30]; 
        end    
      end
    end
    //
    //
    
  //Instantiation of hist_eq_module
  hist_eq_module #(
    .DATA_WIDTH  ( DATA_WIDTH )

  ) hist_eq_module_inst ( 

    .i_sys_clk                ( i_sys_clk          ),
    .i_sys_aresetn            ( i_sys_aresetn      ),
                                
    .contrast_threshold_param ( contrast_threshold ),
    .upper_bound_param        ( upper_bound        ),
    .lower_bound_param        ( lower_bound        ),
    .thresholding_en          ( thresholding_en    ),

    .s_axis_tdata             ( s_axis_tdata       ),
    .s_axis_tvalid            ( s_axis_tvalid      ),
    .s_axis_tuser             ( s_axis_tuser       ),
    .s_axis_tlast             ( s_axis_tlast       ),
    .s_axis_tready            ( s_axis_tready      ),
     
    .m_axis_tdata             ( m_axis_tdata       ),
    .m_axis_tvalid            ( m_axis_tvalid      ),
    .m_axis_tuser             ( m_axis_tuser       ),
    .m_axis_tlast             ( m_axis_tlast       )

  );

	// User logic ends

	endmodule
