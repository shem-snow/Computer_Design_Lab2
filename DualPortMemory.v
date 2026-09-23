/*
 * Synchronous, true dual-port Block-RAM (single clock).
 *
 * Written in the style of Quartus' "True Dual-Port RAM (single clock)" template so that
 * synthesis infers M10K blocks instead of building the memory out of logic registers.
 *
 * 	- Both ports can independently read OR write every clock edge.
 * 	- Everything happens on the posedge of the one shared clock.
 * 	- DOUT (q_a / q_b) is registered: an address presented before edge N produces data
 * 	  that is valid right AFTER edge N. In other words, reads have a 1-cycle latency.
 * 	- en_x = 0 freezes that port (no write, q_x holds its last value).
 *
 * Sizing (M10K on the Cyclone V SE A5):
 * 	1 block  = 512 words x 16 bits (internally 512 x 20, top 4 bits unused)
 * 	2 blocks = 1024 words -> ADDR_WIDTH = 10  (this lab)
 * 	Later in the project ADDR_WIDTH can grow toward 18. Note 2^18 = 262,144 words, but the
 * 	chip only has 397 * 512 = 203,264 words, so a full 18-bit memory will NOT fit.
 *
 * Read-during-write behavior (what q_x shows when you read the address being written):
 * 	WRITE_FIRST = 1 ("new data"): q_x shows the value being written this cycle.
 * 	WRITE_FIRST = 0 ("old data"): q_x shows the value that was there before the write.
 *
 * 	The lab handout frames this as blocking vs. non-blocking at the output. These are equivalent:
 * 		ram[addr] = din;  q <= ram[addr];   // blocking write   -> q sees the new value (write-first)
 * 		ram[addr] <= din; q <= ram[addr];   // nonblocking write -> q sees the old value (read-first)
 * 	Using "q <= din" for write-first is the form Quartus' template uses, and it avoids mixing
 * 	blocking and non-blocking assignments to the same array.
 *
 * 	Mixed-port (port A writes addr X while port B reads addr X in the SAME cycle): in RTL
 * 	simulation port B gets the OLD value. Two ports WRITING the same address in the same
 * 	cycle is a hardware conflict with an undefined result; the control logic must never do it.
 *
 * INIT_FILE is loaded with $readmemh. Quartus resolves the relative path from the project folder.
 * Initial contents only come from the FPGA bitstream: pressing reset does NOT restore them.
 */
module Memory #(
	parameter DATA_WIDTH  = 16,
	parameter ADDR_WIDTH  = 10,
	parameter WRITE_FIRST = 1,
	parameter INIT_FILE   = "memory_files/lab3_memory_init.txt"
)	(
		input clock,

		// Port A
		input en_a,
		input we_a,
		input [ADDR_WIDTH-1:0] addr_a,
		input [DATA_WIDTH-1:0] din_a,
		output reg [DATA_WIDTH-1:0] q_a,

		// Port B
		input en_b,
		input we_b,
		input [ADDR_WIDTH-1:0] addr_b,
		input [DATA_WIDTH-1:0] din_b,
		output reg [DATA_WIDTH-1:0] q_b
	);

		reg [DATA_WIDTH-1:0] ram [0:2**ADDR_WIDTH-1];

		initial begin
			if (INIT_FILE != "")
				$readmemh(INIT_FILE, ram);
		end

		generate
			if (WRITE_FIRST) begin : g_write_first

				// Port A
				always @(posedge clock) begin
					if (en_a) begin
						if (we_a) begin
							ram[addr_a] <= din_a;
							q_a <= din_a;
						end
						else
							q_a <= ram[addr_a];
					end
				end

				// Port B
				always @(posedge clock) begin
					if (en_b) begin
						if (we_b) begin
							ram[addr_b] <= din_b;
							q_b <= din_b;
						end
						else
							q_b <= ram[addr_b];
					end
				end

			end
			else begin : g_read_first

				// Port A
				always @(posedge clock) begin
					if (en_a) begin
						if (we_a)
							ram[addr_a] <= din_a;
						q_a <= ram[addr_a];
					end
				end

				// Port B
				always @(posedge clock) begin
					if (en_b) begin
						if (we_b)
							ram[addr_b] <= din_b;
						q_b <= ram[addr_b];
					end
				end

			end
		endgenerate

endmodule
