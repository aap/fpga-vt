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
	
	assign LEDG[0] = READY;
	assign LEDG[9:1] = 0;
	assign LEDR = 0;

	// control video inversion with switch
	wire invert = SW[0];


	wire [10:0] screenaddr;
	addressmap addrmap(screenX, screenY, screenaddr);

	reg [7:0] wrdata;
	wire [7:0] data_a;
	wire [7:0] data_b;
	reg wren = 0;

	/* VT52-like terminal */
	reg [6:0] curX = 0;
	reg [4:0] curY = 0;
	reg [6:0] screenX = 0;
	reg [4:0] screenY = 0;
	reg [4:0] topline = 0;
	/* states */
	reg cadX = 0;
	reg cadY = 0;
	reg esc = 0;
	reg scroll = 0;
	reg clrline = 1;
	reg clrscreen = 1;

	wire [6:0] curXINC = curX == 79 ? curX : curX+1;
	wire [4:0] curYINC = curY == 23 ? curY : curY+1;
	wire [6:0] curXDEC = curX == 0 ? curX : curX-1;
	wire [4:0] curYDEC = curY == 0 ? curY : curY-1;
	wire [6:0] curY_mem = curY+topline <= 23 ? curY+topline : curY+topline-24;
	wire [4:0] screenYINC = screenY == 23 ? 0 : screenY + 1;
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			curX <= 0;
			curY <= 0;
			screenX <= 0;
			screenY <= 0;
			topline <= 0;
			cadX <= 0;
			cadY <= 0;
			esc <= 0;
			scroll <= 0;
			clrline <= 1;
			clrscreen <= 1;
		end else begin
			if(gotchar) begin
				if(cadY) begin
					// TODO: figure out the real logic
					if(rx_data >= 'o40 && rx_data < 'o70)
						curY <= rx_data[4:0];
					cadY <= 0;
					cadX <= 1;
				end else if(cadX) begin
					// TODO: figure out the real logic
					if(rx_data >= 'o40)
						curX <= rx_data - 'o40;
					if(rx_data >= 'o160)
						curX <= 79;
					cadX <= 0;
				end else if(esc) begin
					case(rx_data)
					8'o101: curY <= curYDEC;
					8'o102: curY <= curYINC;
					8'o103: curX <= curXINC;
					8'o104: curX <= curXDEC;
					8'o110: begin
						curX <= 0;
						curY <= 0;
					end
					8'o111: begin
						curY <= curYDEC;
						if(curY == 0) begin
							scroll <= 1;
							topline <= topline == 0 ? 23 : topline-1;
						end
					end
					8'o112: begin
						screenX <= curX;
						screenY <= curY_mem;
						clrline <= 1;
						clrscreen <= 1;
					end
					8'o113: begin
						screenX <= curX;
						screenY <= curY_mem;
						clrline <= 1;
					end
					8'o131: cadY <= 1;
					endcase
					esc <= 0;
				end else if(rx_data <'o40) begin
					case(rx_data)
					8'o010: curX <= curXDEC;
					8'o011:
						if(curX < 72)
							curX <= {curX[6:3], 3'b000} + 8;
						else
							curX <= curXINC;
					8'o012: begin
						curY <= curYINC;
						// scroll down
						if(curY == 23) begin
							scroll <= 1;
							topline <= topline == 23 ? 0 : topline+1;
						end
					end
					8'o015: curX <= 0;
					8'o033: esc <= 1;
					endcase
				end else if(rx_data != 'o177) begin
					wren <= 1;
					wrdata <= rx_data;
					screenX <= curX;
					screenY <= curY_mem;
					curX <= curXINC;
				end
			end

			if(scroll) begin
				scroll <= 0;
				screenX <= 0;
				screenY <= curY_mem;
				clrline <= 1;
			end

			// clear screen by clearing successive lines
			if(clrscreen & ~clrline) begin
				screenX <= 0;
				screenY <= screenYINC;
				if(screenYINC == topline)
					clrscreen <= 0;
				else
					clrline <= 1;
			end

			// clear line
			if(clrline) begin
				if(wren) begin
					// clr done, increment or stop
					screenX <= screenX + 1;
					if(screenX == 79)
						clrline <= 0;
				end else begin
					wren <= 1;
					wrdata <= 0;
				end
			end

			if(wren)
				wren <= 0;
		end
	end
	/* TODO: this probably doesn't have to be dual ported */
	wire	[10:0]  address_b;
	mem screenmem(.address_a(screenaddr),
		.address_b(address_b),
		.clock(clk),
		.data_a(wrdata),
		.data_b(0),
		.wren_a(wren),
		.wren_b(0),
		.q_a(data_a),
		.q_b(data_b));

	/* need 80mhz clock for 800x600@60hz */
	wire clock80;
	pll80 pll80(
	  .refclk(clock50),
	  .rst(reset),

	  .outclk_0(clock80),
	  .locked(locked)
	);
	/* video signal generator */
	videogen videogen(
		.clock      (clock80),
		.reset      (~locked),

		// terminal screen
		.curX(curX),
		.curY(curY_mem),
		.topline(topline),
		.invert(invert),
		.screenmem_addr(address_b),
		.screenmem_data(data_b),

		// HDMI output
		.hsync      (HDMI_TX_HS),
		.vsync      (HDMI_TX_VS),
		.dataEnable (HDMI_TX_DE),
		.vclk       (HDMI_TX_CLK),
		.RGBchannel (HDMI_TX_D)
	);

	/* HDMI config */
	wire READY;
	I2C_HDMI_Config #(
	  .CLK_Freq (50000000), // 50MHz
	  .I2C_Freq (20000)    // 20kHz for i2c clock
	)
	I2C_HDMI_Config (
	  .iCLK        (clock50),
	  .iRST_N      (reset_n),
	  .I2C_SCLK    (I2C_SCL),
	  .I2C_SDAT    (I2C_SDA),
	  .HDMI_TX_INT (HDMI_TX_INT),
	  .READY       (READY)
	);







	/* UART */
	wire tx_send;
	wire tx_clr = 0;
	wire tx_done;
	uart_tx #(50000000, 9600, 1) tx(.clk(clock50),
		.data(kbd_ascii),
		.data_clr(tx_clr),
		.data_set(tx_send),
		.tx(UART_TX),
		.done(tx_done));
	wire [7:0] rx_data;
	wire rx_active;
	wire rx_done;
	uart_rx #(50000000, 9600) rx(.clk(clock50),
		.rx(UART_RX),
		.data(rx_data),
		.rx_active(rx_active),
		.rx_done(rx_done));

	wire gotchar;
	edgedet recv(clk, reset, rx_done, gotchar);





	/* PS/2 keyboard */
	wire ps2_clk = GPIO[28];
	wire ps2_data = GPIO[29];
	wire [7:0] kbd_data;
	wire kbd_done;
	ps2_rx ps2_rx(.clk(clk), .reset(reset),
		.ps2_clk(ps2_clk),
		.ps2_data(ps2_data),
		.data(kbd_data),
		.done(kbd_done));

	wire [6:0] kbd_ascii;
	kbdhandler kbdhandler(
		.clk(clk),
		.reset(reset),
		.newdata(kbd_done),
		.scancode(kbd_data),
		.sendchar(tx_send),
		.ascii(kbd_ascii));

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
