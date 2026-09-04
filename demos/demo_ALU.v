/*
 * FPGA demonstration for the 16-bit ALU.
 *
 * Switch assignments:
 *     SW[3:0] = ALU operation
 *     SW[9:7] = hard coded number for lhs
 *		 SW[6:4] = hard coded number for rhs
 *
 * LED assignments:
 *     LEDR[0]   = complete test passed
 *     LEDR[1]   = result matches
 *     LEDR[2]   = relevant flags match
 *     LEDR[3]   = selected ALU operation is valid
 *     LEDR[8:4] = actual ALU flags
 *     LEDR[9]   = selected test failed
 *
 * Seven-segment assignments:
 *     HEX3:HEX0 = actual ALU result in hexadecimal
 *     HEX5 = selected test number in hexadecimal for lhs
  *    HEX4 = selected test number in hexadecimal for rhs
 */
module demo_ALU (
    input  [9:0] SW,
    output [9:0] LEDR,
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5
);

    localparam WIDTH = 16;

    localparam [3:0] ZEXT 	= 4'b0000; // zero extend
    localparam [3:0] SEXT 	= 4'b0001; // sign extend
    localparam [3:0] ADD  	= 4'b0010; 
    localparam [3:0] SUB  	= 4'b0011;
    localparam [3:0] AND  	= 4'b0100;
    localparam [3:0] OR   	= 4'b0101;
    localparam [3:0] XOR  	= 4'b0110;
    localparam [3:0] MULT 	= 4'b0111;
    localparam [3:0] LUI  	= 4'b1000; // Load upper
    localparam [3:0] LSH  	= 4'b1001; // logical left shit
    localparam [3:0] ASH  	= 4'b1010; // arithmetic shift
    localparam [3:0] PASS 	= 4'b1011; // mov
	 // Unused			  		= 4'b1101;
	 // Unused					= 4'b1110;
    localparam [3:0] NOT  	= 4'b1100;

    wire [3:0] alu_op;

    reg [WIDTH-1:0] lhs;
    reg [WIDTH-1:0] rhs;
    reg carryin;

    wire [WIDTH-1:0] actual_result;

    reg [WIDTH-1:0] expected_result;
    reg [4:0] expected_flags;
    reg [4:0] flag_mask;
    reg valid_test;
    reg [WIDTH:0] extended_addition;

    wire result_matches;
    wire flags_match;
    wire test_passed;

    assign alu_op = SW[3:0];

    ALU #(.WIDTH(WIDTH)) alu_under_test (
        .alu_op(alu_op),
        .lhs(lhs),
        .rhs(rhs),
        .carryin(carryin),
        .result(actual_result),
        .flags(LEDR[8:4])
    );

    /*
     * Select 16-bit operands from the six-bit test number.
     *
     * switches[6:4] select rhs.
     * switches[9:7] select lhs.
     */
    always @(*) begin
        case (SW[6:4])
            3'd0: rhs = 16'h0000;
            3'd1: rhs = 16'h0001;
            3'd2: rhs = 16'h0002;
            3'd3: rhs = 16'h7FFF;
            3'd4: rhs = 16'h8000;
            3'd5: rhs = 16'hFFFF;
            3'd6: rhs = 16'hAAAA;
            3'd7: rhs = 16'h0100;
        endcase

        case (SW[9:7])
            3'd0: lhs = 16'h0000;
            3'd1: lhs = 16'h0001;
            3'd2: lhs = 16'h007F;
            3'd3: lhs = 16'h0080;
            3'd4: lhs = 16'h00FF;
            3'd5: lhs = 16'h7FFF;
            3'd6: lhs = 16'h8000;
            3'd7: lhs = 16'hFFFF;
        endcase

        carryin = SW[9];
    end

    // Golden reference model
    always @(*) begin
        expected_result = 16'h0000;
        expected_flags = 5'b00000;
        flag_mask = 5'b00000; // none
        valid_test = 1'b1;
        extended_addition = 17'h00000;

        case (alu_op)
            ZEXT: begin
                expected_result = {8'h00, rhs[7:0]};
            end

            SEXT: begin
                expected_result = {{8{rhs[7]}}, rhs[7:0]};
            end

            ADD: begin
                extended_addition = {1'b0, lhs} + {1'b0, rhs} + carryin;
                expected_result = extended_addition[15:0];
                expected_flags[4] = extended_addition[16];
                expected_flags[1] = ~(lhs[15] ^ rhs[15]) & (lhs[15] ^ expected_result[15]);
                flag_mask = 5'b10010; // ADD
            end

            SUB: begin
                expected_result = lhs - rhs - carryin;
                expected_flags[4] = ({1'b0, lhs} < ({1'b0, rhs} + carryin));
                expected_flags[3] = (lhs < rhs);
                expected_flags[2] = ($signed(lhs) < $signed(rhs));
                expected_flags[1] = (lhs[15] ^ rhs[15]) & ~(expected_result[15] ^ rhs[15]);
                expected_flags[0] = (lhs == rhs);
                flag_mask = 5'b11111; // SUB
            end

            AND: begin
                expected_result = lhs & rhs;
            end

            OR: begin
                expected_result = lhs | rhs;
            end

            XOR: begin
                expected_result = lhs ^ rhs;
            end

            MULT: begin
                expected_result = lhs * rhs;
            end

            LUI: begin
                expected_result = {rhs[7:0], 8'h00};
            end

            LSH: begin
                if (rhs[15] == 1'b0)
                    expected_result = lhs << rhs;
                else
                    expected_result = lhs >> ((~rhs) + 1'b1);
            end

            ASH: begin
                if (rhs[15] == 1'b0)
                    expected_result = lhs << rhs;
                else
                    expected_result = $signed(lhs) >>> ((~rhs) + 1'b1);
            end

            PASS: begin
                expected_result = rhs;
            end

            NOT: begin
                expected_result = ~lhs;
            end

            default: begin
                valid_test = 1'b0;
            end
        endcase
    end

    assign result_matches = (actual_result == expected_result);
    assign flags_match = ((LEDR[8:4] & flag_mask) == (expected_flags & flag_mask));
    assign test_passed = valid_test && result_matches && flags_match;

    assign LEDR[0] = test_passed;
    assign LEDR[1] = result_matches;
    assign LEDR[2] = flags_match;
    assign LEDR[3] = valid_test;
    assign LEDR[9] = valid_test && !test_passed;

    hex_to_seven_segment display_result_0 (.hex_value(actual_result[3:0]), .segments(HEX0));

    hex_to_seven_segment display_result_1 (.hex_value(actual_result[7:4]), .segments(HEX1));

    hex_to_seven_segment display_result_2 (.hex_value(actual_result[11:8]), .segments(HEX2));

    hex_to_seven_segment display_result_3 (.hex_value(actual_result[15:12]), .segments(HEX3));

    hex_to_seven_segment display_rhs (.hex_value(SW[6:4]), .segments(HEX4));

    hex_to_seven_segment display_lhs (.hex_value({2'b00, SW[9:7]}), .segments(HEX5));

endmodule


// Active-low hexadecimal seven-segment decoder
module hex_to_seven_segment (
    input [3:0] hex_value,
    output reg [6:0] segments
);

    always @(*) begin
        case (hex_value)
            4'h0: segments = 7'b1000000;
            4'h1: segments = 7'b1111001;
            4'h2: segments = 7'b0100100;
            4'h3: segments = 7'b0110000;
            4'h4: segments = 7'b0011001;
            4'h5: segments = 7'b0010010;
            4'h6: segments = 7'b0000010;
            4'h7: segments = 7'b1111000;
            4'h8: segments = 7'b0000000;
            4'h9: segments = 7'b0010000;
            4'hA: segments = 7'b0001000;
            4'hB: segments = 7'b0000011;
            4'hC: segments = 7'b1000110;
            4'hD: segments = 7'b0100001;
            4'hE: segments = 7'b0000110;
            4'hF: segments = 7'b0001110;
            default: segments = 7'b1111111;
        endcase
    end

endmodule
