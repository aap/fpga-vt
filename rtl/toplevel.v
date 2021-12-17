`default_nettype none

module toplevel(

	//////////// CLOCK //////////
	input 		          		CLOCK_125_p,
	input 		          		CLOCK_50_B5B,
	input 		          		CLOCK_50_B6A,
	input 		          		CLOCK_50_B7A,
	input 		          		CLOCK_50_B8A,

	//////////// LED //////////
	output		     [7:0]		LEDG,
	output		     [9:0]		LEDR,

	//////////// KEY //////////
	input 		          		CPU_RESET_n,
	input 		     [3:0]		KEY,
	
	//////////// SW //////////
	input 		     [9:0]		SW,

	//////////// HDMI-TX //////////
	output		          		HDMI_TX_CLK,
	output		    [23:0]		HDMI_TX_D,
	output		          		HDMI_TX_DE,
	output		          		HDMI_TX_HS,
	input 		          		HDMI_TX_INT,
	output		          		HDMI_TX_VS,

	//////////// I2C for Audio/HDMI-TX/Si5338/HSMC //////////
	output		          		I2C_SCL,
	inout 		          		I2C_SDA,

	//////////// Uart to USB //////////
	input 		          		UART_RX,
	output		          		UART_TX,

	//////////// GPIO, GPIO connect to GPIO Default //////////
	inout 		    [35:0]		GPIO
);
	wire reset_n = CPU_RESET_n;
	wire reset = ~reset_n;
	wire clock50 = CLOCK_50_B5B;
	wire clock25, locked;
	wire clk = clock50;
	
	assign LEDG[0] = hdmi_ready;
	assign LEDG[9:1] = 0;
	assign LEDR = 0;

	// control video inversion with switch
	wire invert = SW[0];
	wire bell_inverts = SW[1];

	wire hdmi_ready;
	pseudo_vt52 vt(.clk(clk), .reset(reset),
		.invert_video(invert),
		.bell_inverts(bell_inverts),

		.HDMI_TX_CLK(HDMI_TX_CLK),
		.HDMI_TX_D(HDMI_TX_D),
		.HDMI_TX_DE(HDMI_TX_DE),
		.HDMI_TX_HS(HDMI_TX_HS),
		.HDMI_TX_INT(HDMI_TX_INT),
		.HDMI_TX_VS(HDMI_TX_VS),
		.hdmi_ready(hdmi_ready),

		.I2C_SCL(I2C_SCL),
		.I2C_SDA(I2C_SDA),

		.UART_RX(UART_RX),
		.UART_TX(UART_TX),

		.ps2_clk(GPIO[28]),
		.ps2_data(GPIO[29])
	);
endmodule









module edgedet(input wire clk, input wire reset, input wire in, output wire p);
	reg [1:0] x;
	reg [1:0] init = 0;
	always @(posedge clk or posedge reset)
		if(reset)
			init <= 0;
		else begin
			x <= { x[0], in };
			init <= { init[0], 1'b1 };
		end
	assign p = (&init) & x[0] & !x[1];
endmodule
