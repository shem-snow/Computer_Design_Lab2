/*
 * FPGA demonstration for the DualPortMemory module: read-modify-write-read on the dual-port Block-RAM.
 *
 * Inputs:
 * 	KEY[0] (rst) = reset, active-low. Resets the FSM only. The RAM keeps its contents
 * 	               (reprogram the FPGA to get the initial memory image back).
 * 	KEY[1] (go)  = run the read-modify-write-verify sequence once, active-low.
 * 	SW[9:0]      = address to view on port B while the FSM is idle.
 *
 * Outputs:
 * 	HEX3:HEX0 = memory word at the address on SW[9:0] (read through port B)
 * 	HEX5:HEX4 = low byte of that address (SW[9:8] are the upper two address bits)
 * 	LEDR[0]   = at least one run has completed
 * 	LEDR[1]   = last run: all 7 locations verified
 * 	LEDR[8:2] = last run: per-location pass bits (LEDR[2] = test 0 ... LEDR[8] = test 6)
 * 	LEDR[9]   = last run: at least one location FAILED
 *
 * What the demo does:
 * 	0.	When you first flash the board, RAM is holding a small memory of 1,024 numbers filled from lab3_memory_init.txt.
 * 		Almost every address holds its own address as its value (address 3 holds 0003, address 1023 holds 03FF), so you can check the addressing is right.
 * 		Seven "test" addresses hold values that start with A: 0, 1, 2, 510, 511, 512 and 513. 510–513 are included because they sit where we expect the split between the two memory blocks.
 * 
 * 	1.	The slide switches allow you specify addresses whose values will be displayed at Hex[3:0].
 * 		The low byte of the address is displayed at Hex[5:4].
 * 
 * 	2. Each press of the KEY[1] button adds 0x1000 to the values at the seven test addresses then writes it back,
 * 		then reads it again through the memory's other port to check it. The LEDs all light up to indicate success.
 * 		That's the "read, modify, write, read again" the lab asks for.
 * 		The test only rewrites seven addresses: 0, 1, 2, 510, 511, 512 and 513. Every other address keeps its starting value forever 
 */
module demo_Memory
(
	input clk,
	input rst,
	input go,
	input [9:0] slide_switches,
	output [9:0] leds,

	output [6:0] seg0,
	output [6:0] seg1,
	output [6:0] seg2,
	output [6:0] seg3,
	output [6:0] seg4,
	output [6:0] seg5
);

	localparam DATA_WIDTH = 16;
	localparam ADDR_WIDTH = 10;

	// Internal connecting wires
	wire en_a, we_a, en_b, we_b;
	wire [ADDR_WIDTH-1:0] addr_a, addr_b;
	wire [DATA_WIDTH-1:0] din_a, din_b, q_a, q_b;

	wire [6:0] pass_bits;
	wire run_done, all_passed, any_failed;

	// KEY[1] is asynchronous to the clock: synchronize it, then turn a press into a one-cycle pulse.
	reg [2:0] go_sync;
	always @(posedge clk)
		go_sync <= {go_sync[1:0], ~go}; // ~go because the KEYs are active-low
	wire go_pulse = go_sync[1] & ~go_sync[2];

	// Memory
	DualPortMemory #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) mem (
		.clock(clk),
		.en_a(en_a), .we_a(we_a), .addr_a(addr_a), .din_a(din_a), .q_a(q_a),
		.en_b(en_b), .we_b(we_b), .addr_b(addr_b), .din_b(din_b), .q_b(q_b)
	);

	// Moore FSM
	memory_test_fsm fsm (
		.clk(clk), .rst(~rst), .go(go_pulse), .view_address(slide_switches),
		.q_a(q_a), .q_b(q_b),
		.en_a(en_a), .we_a(we_a), .addr_a(addr_a), .din_a(din_a),
		.en_b(en_b), .we_b(we_b), .addr_b(addr_b), .din_b(din_b),
		.pass_bits(pass_bits), .run_done(run_done), .all_passed(all_passed), .any_failed(any_failed)
	);

	assign leds = {any_failed, pass_bits, all_passed, run_done};

	// HexTo7Seg (module lives in demos/demo_Regfile.v)
	hex_to_seven_segment htss0(.hex_value(q_b[3:0]),   .segments(seg0));
	hex_to_seven_segment htss1(.hex_value(q_b[7:4]),   .segments(seg1));
	hex_to_seven_segment htss2(.hex_value(q_b[11:8]),  .segments(seg2));
	hex_to_seven_segment htss3(.hex_value(q_b[15:12]), .segments(seg3));
	hex_to_seven_segment htss4(.hex_value(addr_b[3:0]), .segments(seg4));
	hex_to_seven_segment htss5(.hex_value(addr_b[7:4]), .segments(seg5));

endmodule


/*
	This FSM runs the Lab 3 test on 7 locations: 0, 1, 2 (block 0) and 510, 511, 512, 513
	(straddling the 512-word boundary between the two blocks).

	For each location:
		S_READ    port A: present the address (read)
		S_MODIFY  q_a is now valid (1-cycle read latency). Save it and compute q_a + INCREMENT.
		S_WRITE   port A: write the modified value back to the same address
		S_REREAD  port B: present the same address (read through the OTHER port)
		S_VERIFY  q_b is now valid. Compare it to what was written and record pass/fail.

	Verification compares against the value that was actually read + INCREMENT, not against
	constants from the init file, so the test still passes on the 2nd, 3rd, ... run.

	S_DISPLAY: between runs, port B follows view_address so the 7-seg can show any word.
*/
module memory_test_fsm #(
	parameter DATA_WIDTH = 16,
	parameter ADDR_WIDTH = 10,
	parameter [DATA_WIDTH-1:0] INCREMENT = 16'h1000
) (
	input clk,
	input rst,
	input go,                                 // one-cycle start pulse
	input [ADDR_WIDTH-1:0] view_address,      // slide switches

	input [DATA_WIDTH-1:0] q_a,
	input [DATA_WIDTH-1:0] q_b,

	output reg en_a,
	output reg we_a,
	output reg [ADDR_WIDTH-1:0] addr_a,
	output reg [DATA_WIDTH-1:0] din_a,

	output reg en_b,
	output reg we_b,
	output reg [ADDR_WIDTH-1:0] addr_b,
	output reg [DATA_WIDTH-1:0] din_b,

	output reg [6:0] pass_bits,
	output reg run_done,
	output all_passed,
	output any_failed
);

	localparam NUM_TESTS = 7;

	localparam S_DISPLAY = 3'd0,
	           S_READ    = 3'd1,
	           S_MODIFY  = 3'd2,
	           S_WRITE   = 3'd3,
	           S_REREAD  = 3'd4,
	           S_VERIFY  = 3'd5;

	reg [2:0] state;
	reg [2:0] test_index;
	reg [DATA_WIDTH-1:0] modified_data;

	wire [ADDR_WIDTH-1:0] test_addr = test_address(test_index);

	assign all_passed = run_done & (pass_bits == {NUM_TESTS{1'b1}});
	assign any_failed = run_done & ~all_passed;

	// Next state logic
	always @(posedge clk) begin
		if (rst) begin
			state         <= S_DISPLAY;
			test_index    <= 3'd0;
			modified_data <= {DATA_WIDTH{1'b0}};
			pass_bits     <= {NUM_TESTS{1'b0}};
			run_done      <= 1'b0;
		end else begin
			case (state)
				S_DISPLAY: begin
					if (go) begin
						state      <= S_READ;
						test_index <= 3'd0;
						pass_bits  <= {NUM_TESTS{1'b0}};
						run_done   <= 1'b0;
					end
				end

				S_READ:
					state <= S_MODIFY;

				S_MODIFY: begin
					modified_data <= q_a + INCREMENT;
					state         <= S_WRITE;
				end

				S_WRITE:
					state <= S_REREAD;

				S_REREAD:
					state <= S_VERIFY;

				S_VERIFY: begin
					pass_bits[test_index] <= (q_b == modified_data);
					if (test_index == NUM_TESTS - 1) begin
						run_done <= 1'b1;
						state    <= S_DISPLAY;
					end else begin
						test_index <= test_index + 3'd1;
						state      <= S_READ;
					end
				end

				default:
					state <= S_DISPLAY;
			endcase
		end
	end

	// Output logic
	always @(*) begin

		// default values: both ports idle, port B pointed at the switches
		en_a   = 1'b0;
		we_a   = 1'b0;
		addr_a = test_addr;
		din_a  = modified_data;

		en_b   = 1'b1;
		we_b   = 1'b0;
		addr_b = view_address;
		din_b  = {DATA_WIDTH{1'b0}};

		case (state)
			S_READ: begin
				en_a = 1'b1;
			end

			S_WRITE: begin
				en_a = 1'b1;
				we_a = 1'b1;
			end

			S_REREAD: begin
				addr_b = test_addr;
			end

			default: ; // S_DISPLAY, S_MODIFY, S_VERIFY use the defaults
		endcase
	end

	// The 7 locations under test
	function [ADDR_WIDTH-1:0] test_address;
		input [2:0] index;
		begin
			case (index)
				3'd0:    test_address = 10'd0;
				3'd1:    test_address = 10'd1;
				3'd2:    test_address = 10'd2;
				3'd3:    test_address = 10'd510;
				3'd4:    test_address = 10'd511;
				3'd5:    test_address = 10'd512;
				3'd6:    test_address = 10'd513;
				default: test_address = 10'd0;
			endcase
		end
	endfunction

endmodule
