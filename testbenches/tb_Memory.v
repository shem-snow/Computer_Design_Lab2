`timescale 1ns/1ps

/*
	Unit testbench for Memory.v.

	Two copies of the memory are driven with the exact same inputs:
		dut_wf : WRITE_FIRST = 1 (same-port read-during-write returns NEW data)
		dut_rf : WRITE_FIRST = 0 (same-port read-during-write returns OLD data)

	Inputs change on the falling edge so they are stable at every rising edge.

	Tests:
		1. $readmemh initialization (test words + background words, read on both ports)
		2. Read latency: q only updates on the rising edge
		3. Write on port A, read back on port B (and vice versa)
		4. Both ports writing different addresses in the same cycle
		5. Same-port read-during-write (write-first vs read-first)
		6. Mixed-port read-during-write (A writes X while B reads X in the same cycle)
		7. Enable = 0 blocks writes and holds q

	Run from the repository root (so the init-file path resolves), e.g.:
		iverilog -o tb_mem testbenches/tb_Memory.v Memory.v && vvp tb_mem
*/
module tb_Memory;

	localparam DATA_WIDTH = 16;
	localparam ADDR_WIDTH = 10;

	/*
		Inputs to the memory.
	*/
	reg clock;
	reg en_a, we_a, en_b, we_b;
	reg [ADDR_WIDTH-1:0] addr_a, addr_b;
	reg [DATA_WIDTH-1:0] din_a, din_b;

	/*
		Outputs from the memory.
	*/
	wire [DATA_WIDTH-1:0] q_a_wf, q_b_wf, q_a_rf, q_b_rf;

	integer number_of_tests;
	integer number_of_errors;

	DualPortMemory #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .WRITE_FIRST(1)) dut_wf (
		.clock(clock),
		.en_a(en_a), .we_a(we_a), .addr_a(addr_a), .din_a(din_a), .q_a(q_a_wf),
		.en_b(en_b), .we_b(we_b), .addr_b(addr_b), .din_b(din_b), .q_b(q_b_wf)
	);

	DualPortMemory #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .WRITE_FIRST(0)) dut_rf (
		.clock(clock),
		.en_a(en_a), .we_a(we_a), .addr_a(addr_a), .din_a(din_a), .q_a(q_a_rf),
		.en_b(en_b), .we_b(we_b), .addr_b(addr_b), .din_b(din_b), .q_b(q_b_rf)
	);

	// 50 MHz clock like CLOCK_50 on the board
	initial clock = 1'b0;
	always #10 clock = ~clock;

	/*
		Helpers
	*/

	// Wait for the next rising edge, then settle a little before checking outputs.
	task tick;
		begin
			@(posedge clock);
			#1;
		end
	endtask

	// Move to the falling edge before changing inputs.
	task to_negedge;
		begin
			@(negedge clock);
		end
	endtask

	task idle_ports;
		begin
			en_a = 1'b1; we_a = 1'b0; din_a = 16'h0000;
			en_b = 1'b1; we_b = 1'b0; din_b = 16'h0000;
		end
	endtask

	task check;
		input [8*48-1:0] name;
		input [DATA_WIDTH-1:0] actual;
		input [DATA_WIDTH-1:0] expected;
		begin
			number_of_tests = number_of_tests + 1;
			if (actual !== expected) begin
				number_of_errors = number_of_errors + 1;
				$display("ERROR: %0s  expected %h  got %h  (t=%0t)", name, expected, actual, $time);
			end
		end
	endtask

	// Read one address on both ports of both memories and compare to the expected word.
	task read_and_check;
		input [ADDR_WIDTH-1:0] address;
		input [DATA_WIDTH-1:0] expected;
		begin
			to_negedge;
			idle_ports;
			addr_a = address;
			addr_b = address;
			tick;
			check("read port A (write-first)", q_a_wf, expected);
			check("read port B (write-first)", q_b_wf, expected);
			check("read port A (read-first)",  q_a_rf, expected);
			check("read port B (read-first)",  q_b_rf, expected);
		end
	endtask

	initial begin
		number_of_tests  = 0;
		number_of_errors = 0;

		idle_ports;
		addr_a = 0;
		addr_b = 0;

		/*
			1. Initialization from memory_files/lab3_memory_init.txt
		*/
		$display("1. Initial contents");
		read_and_check(10'd0,    16'hA000);
		read_and_check(10'd1,    16'hA001);
		read_and_check(10'd2,    16'hA002);
		read_and_check(10'd510,  16'hA1FE);
		read_and_check(10'd511,  16'hA1FF);
		read_and_check(10'd512,  16'hA200);
		read_and_check(10'd513,  16'hA201);
		read_and_check(10'd3,    16'h0003); // background: word = its own address
		read_and_check(10'd1023, 16'h03FF);

		/*
			2. Read latency: change the address between edges, q must not move until the edge.
		*/
		$display("2. Registered output / 1-cycle read latency");
		to_negedge;
		addr_a = 10'd1;           // q_a currently holds word 1023 from the last read
		#5;
		check("q_a holds before edge", q_a_wf, 16'h03FF);
		tick;
		check("q_a updates at edge",   q_a_wf, 16'hA001);

		/*
			3. Write on one port, read on the other.
		*/
		$display("3. Cross-port write then read");
		to_negedge;
		idle_ports;
		addr_a = 10'd100; din_a = 16'hBEEF; we_a = 1'b1;
		tick;
		read_and_check(10'd100, 16'hBEEF);

		to_negedge;
		idle_ports;
		addr_b = 10'd600; din_b = 16'hCAFE; we_b = 1'b1;
		tick;
		read_and_check(10'd600, 16'hCAFE);

		/*
			4. Both ports write (different addresses) in the same cycle.
		*/
		$display("4. Simultaneous writes to different addresses");
		to_negedge;
		idle_ports;
		addr_a = 10'd200; din_a = 16'h1234; we_a = 1'b1;
		addr_b = 10'd800; din_b = 16'h5678; we_b = 1'b1;
		tick;
		read_and_check(10'd200, 16'h1234);
		read_and_check(10'd800, 16'h5678);

		/*
			5. Same-port read-during-write: port A writes 0x0BAD over 0x1234 at address 200.
			   write-first -> q_a shows the NEW value; read-first -> q_a shows the OLD value.
		*/
		$display("5. Same-port read-during-write");
		to_negedge;
		idle_ports;
		addr_a = 10'd200; din_a = 16'h0BAD; we_a = 1'b1;
		addr_b = 10'd0;
		tick;
		check("same-port RDW, write-first", q_a_wf, 16'h0BAD);
		check("same-port RDW, read-first",  q_a_rf, 16'h1234);
		read_and_check(10'd200, 16'h0BAD); // both versions stored the new value

		/*
			6. Mixed-port read-during-write: A writes address 300 while B reads address 300.
			   In RTL both versions return the OLD value on port B.
			   (On the FPGA this case is "old data" or "don't care" depending on how Quartus
			   configures the M10K. Check the RAM summary in the Fitter report.)
		*/
		$display("6. Mixed-port read-during-write");
		to_negedge;
		idle_ports;
		addr_a = 10'd300; din_a = 16'h7777; we_a = 1'b1;
		addr_b = 10'd300;
		tick;
		check("mixed-port RDW, port B (write-first)", q_b_wf, 16'h012C); // 300 = 0x12C
		check("mixed-port RDW, port B (read-first)",  q_b_rf, 16'h012C);
		read_and_check(10'd300, 16'h7777);

		/*
			7. Enable low: no write happens and q holds.
		*/
		$display("7. Enable");
		read_and_check(10'd400, 16'h0190);
		to_negedge;
		idle_ports;
		en_a = 1'b0;
		addr_a = 10'd400; din_a = 16'hFFFF; we_a = 1'b1;
		addr_b = 10'd1;
		tick;
		check("en_a=0 holds q_a", q_a_wf, 16'h0190);
		read_and_check(10'd400, 16'h0190); // write was blocked

		$display("");
		$display("========================================");
		$display("MEMORY TESTBENCH COMPLETE");
		$display("Tests performed: %0d", number_of_tests);
		$display("Errors found:    %0d", number_of_errors);

		if (number_of_errors == 0)
			$display("RESULT: PASS");
		else
			$display("RESULT: FAIL");

		$display("========================================");
		//$finish;
	end

endmodule
