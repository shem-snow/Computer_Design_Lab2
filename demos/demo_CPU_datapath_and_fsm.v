/*
	Board wrapper for the CPU so the pin names match Computer_Design_Lab.qsf.
	
	KEY[0] (rst) = reset, active-low on the board.
	HEX3:HEX0    = last value written to any register.
	
	With memory_files/test_program.txt the display should settle on 0023.
*/
module demo_CPU_datapath_and_fsm (
	input clk,
	input rst,
	output [6:0] seg0,
	output [6:0] seg1,
	output [6:0] seg2,
	output [6:0] seg3
);

	Datapath cpu(.clock(clk), .reset(~rst),
		.demo_display3(seg3), .demo_display2(seg2), .demo_display1(seg1), .demo_display0(seg0));

endmodule
