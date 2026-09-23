/*
	Uses the 7-segment display lights on the MAX10 to indicate the
	hexadecimal value supplied to the module.
*/

module hex_to_seven_segment(
	input      [3:0] hex_value,
	output reg [6:0] segments
);

	always @(*) begin
		// The seven-segment displays are active low, hence the "~".
		case (hex_value)
			4'h0: segments = ~7'b0111111; // 0
			4'h1: segments = ~7'b0000110; // 1
			4'h2: segments = ~7'b1011011; // 2
			4'h3: segments = ~7'b1001111; // 3
			4'h4: segments = ~7'b1100110; // 4
			4'h5: segments = ~7'b1101101; // 5
			4'h6: segments = ~7'b1111101; // 6
			4'h7: segments = ~7'b0000111; // 7
			4'h8: segments = ~7'b1111111; // 8
			4'h9: segments = ~7'b1101111; // 9
			4'hA: segments = ~7'b1110111; // A
			4'hB: segments = ~7'b1111100; // b
			4'hC: segments = ~7'b1011000; // c
			4'hD: segments = ~7'b1011110; // d
			4'hE: segments = ~7'b1111001; // E
			4'hF: segments = ~7'b1110001; // F
			default: segments = ~7'b0000000; // All segments off
		endcase
	end

endmodule

/*

Compatible instantiation:

	hex_to_seven_segment htss0(
		.hex_value(q_b[3:0]),
		.segments(seg0)
	);


PIN ASSIGNMENTS for the Cyclone V (ECE 3710) board:

	Inputs:
		hex_value[0]	-	PIN_AB12
		hex_value[1]	-	PIN_AC12
		hex_value[2]	-	PIN_AF9
		hex_value[3]	-	PIN_AF10

	Outputs:
		segments[0]	-	PIN_AE26
		segments[1]	-	PIN_AE27
		segments[2]	-	PIN_AE28
		segments[3]	-	PIN_AG27
		segments[4]	-	PIN_AF28
		segments[5]	-	PIN_AG28
		segments[6]	-	PIN_AH28


PIN ASSIGNMENTS for the DE-10 (ECE 3700) board:

	Inputs:
		hex_value[0]	-	PIN_C10
		hex_value[1]	-	PIN_C11
		hex_value[2]	-	PIN_D12
		hex_value[3]	-	PIN_C12

	Outputs:
		segments[0]	-	PIN_C14
		segments[1]	-	PIN_E15
		segments[2]	-	PIN_C15
		segments[3]	-	PIN_C16
		segments[4]	-	PIN_E16
		segments[5]	-	PIN_D17
		segments[6]	-	PIN_C17

*/