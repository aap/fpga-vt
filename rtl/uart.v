module clkdiv
#(parameter INCLK=50000000, OUTCLK=(2*9600))
(
	input wire inclk,
	output wire outclk
);
	reg [31:0] cnt = 0;
	assign outclk = cnt == INCLK/OUTCLK - 1;
	always @(posedge inclk)
		if(outclk)
			cnt <= 0;
		else
			cnt <= cnt + 32'b1;
endmodule

module uart_tx
#(parameter INCLK=50000000, BAUD=9600, NSTOP=2)
(
	input wire clk,
	input wire [8:1] data,
	input wire data_clr,
	input wire data_set,
	output reg tx,
	output reg done
);
	reg [8:1] tx_buf;
	reg tx_enable = 0;
	reg tx_active = 0;
	reg tx_active0;
	reg tx_div2 = 0;
	reg tx_div20;
	wire stopdone;

	initial
		done = 0;

	// clock is twice the baudrate
	clkdiv #(INCLK,BAUD*2) clkdivtest(clk, tx_clock);
	// shift at baudrate
	wire tx_shift = tx_div20 & ~tx_div2;

	// counter for stop bits
	wire [1:0] endcount;
	assign endcount[0] = 1;
	assign endcount[1] = NSTOP-1;
	reg [1:0] cnt = 0;
	always @(posedge clk)
		if(tx_active0 & ~tx_active)
			cnt <= 0;
		else if(tx_clock && cnt != endcount)
			cnt <= cnt + 2'b1;
	assign stopdone = cnt == endcount;

	always @(posedge clk) begin
		tx_active0 <= tx_active;
		tx_div20 <= tx_div2;

		if(data_clr) begin
			done <= 0;
		end
		if(data_set) begin
			tx_buf <= data;
			tx_enable <= 1;
		end
		if(tx_clock) begin
			if(tx_active)
				tx_div2 <= ~tx_div2;
			if(stopdone & tx_enable)
				tx_active <= 1;
		end
		if(tx_shift) begin
			tx_enable <= 0;
			{ tx_buf, tx } <= { tx_enable, tx_buf };
			if(~tx_enable & tx_buf[8:2] == 0) begin
				tx_active <= 0;
				done <= 1;
			end
		end
		if(~tx_active)
			tx <= 1;
		else if(~tx_active0)
			tx <= 0;
	end
endmodule

module uart_rx
#(parameter INCLK=50000000, BAUD=9600)
(
	input wire clk,
	input wire rx,
	output reg rx_active,
	output reg rx_done,
	output reg [8:1] data
);
	initial begin
		rx_active = 0;
		rx_done = 1;
		data = 0;
	end

	// clock is 8x the baudrate
	wire rx_clock;
	clkdiv #(INCLK,BAUD*8) clkdivtest(clk, rx_clock);

	wire rx_shift = rx_4count_rise & ~rx_last_unit;
	reg rx_last_unit = 0;
	reg rx_active0;
	wire rx_4count;
	reg rx_4count0;

	wire rx_space = ~rx;
	wire rx_4count_rise = ~rx_4count0 & rx_4count;
	wire rx_set = ~rx_active0 & rx_active;

	div8 d(.clk(clk),
		.reset(rx_set),
		.cntclk(rx_clock & rx_active),
		.out(rx_4count));

	always @(posedge clk) begin
		rx_4count0 <= rx_4count;
		rx_active0 <= rx_active;

		if(rx_set) begin
			data <= 8'o377;
			rx_last_unit <= 0;
		end
		if(rx_4count_rise & rx_last_unit)
			rx_active <= 0;
		if(rx_shift) begin
			data <= { rx, data[8:2] };
			if(~data[1]) begin
				rx_last_unit <= 1;
				rx_done <= 1;
			end
			if(data[1])
				rx_done <= 0;
			if(~rx_space & (& data))
				rx_active <= 0;
		end
		if(rx_clock)
			if(~rx_active & rx_space)
				rx_active <= 1;
	end
endmodule

/*
 * This module divides the clock cntclk by 8.
 */
module div8(
	input wire clk,
	input wire reset,
	input wire cntclk,
	output wire out
);
	reg [2:0] cnt = 4;
	always @(posedge clk)
		if(reset)
			cnt <= 0;
		else if(cntclk)
			cnt <= cnt + 3'b1;
	assign out = cnt[2];
endmodule

