/*
	1. I chose the naming left-hand-side and right-hand-side for the inputs so it would be obvious what the flags mean.
		For example, the less_than_flag indicates that lhs<rhs.
		
	2. I also decided to simplify the ALU and place a decoder in the datapath to configure the ALU for each operation
	
	ADD											Covers:	ADD, ADDI, ADDU, ADDUI, ADDC, ADDCI
	-----------------------------------------------------------------------------------
	SUB											Covers:	SUB, SUBI, SUBC, SUBCI, CMP, CMPI
	-----------------------------------------------------------------------------------
	AND											Covers:	AND, ANDI
	-----------------------------------------------------------------------------------
	OR												Covers:	OR, ORI, NOP
	-----------------------------------------------------------------------------------
	XOR											Covers:	XOR, XORI
	-----------------------------------------------------------------------------------
	PASS 											Covers:	MOV, MOVI
	-----------------------------------------------------------------------------------
	MULT											Covers:	MUL, MULI
	-----------------------------------------------------------------------------------
	LSH											Covers:	LSH, LSHI
	-----------------------------------------------------------------------------------
	ASH											Covers:	ASHU, ASHUI
	-----------------------------------------------------------------------------------
	LUI											Covers:	LUI
	-----------------------------------------------------------------------------------
	SEXT											Covers:	SNXB
	-----------------------------------------------------------------------------------
	ZEXT											Covers:	ZRXB
	-----------------------------------------------------------------------------------
	NOT											Covers:	NOT
*/
module ALU #(parameter WIDTH = 16) (
	input [3:0] alu_op,
	input [WIDTH-1:0] lhs, rhs,
	input carryin,
	output reg [WIDTH-1:0] result,
	output [4:0] flags
);
	localparam ZEXT 	= 4'b0000;
	localparam SEXT 	= 4'b0001;
	localparam ADD 	= 4'b0010;
	localparam SUB		= 4'b0011;
	localparam AND		= 4'b0100;
	localparam OR		= 4'b0101;
	localparam XOR		= 4'b0110;
	localparam MULT 	= 4'b0111;
	localparam LUI		= 4'b1000;
	localparam LSH		= 4'b1001;
	localparam ASH		= 4'b1010;
	localparam PASS 	= 4'b1011;
	localparam NOT		= 4'b1100;
	// Unused			= 4'b1101;
	// Unused			= 4'b1110;
	localparam NOOP		= 4'b1111;
	
	reg carry_or_borrow_flag, unsigned_less_than_flag, signed_less_than_flag, signed_overflow_flag, equality_flag;
	assign flags = {carry_or_borrow_flag, unsigned_less_than_flag, signed_less_than_flag, signed_overflow_flag, equality_flag};
	
	
	always@(*) begin
	
		// Default outputs
		result = {WIDTH{1'b0}}; // Concatonate WIDTH number of zeros
		
		carry_or_borrow_flag = 1'b0;
      unsigned_less_than_flag = 1'b0;
      signed_less_than_flag = 1'b0;
      signed_overflow_flag = 1'b0;
      equality_flag = 1'b0;
		
		case(alu_op)
		
			ZEXT:
				// result already defaults to all zeros, so I just need to write the rhs.
				result[7:0] = rhs[7:0];
		
			SEXT: begin
				// Fill the result with the correct sign, then replace the lower bits with rhs.
				result = {WIDTH{rhs[7]}};
            result[7:0] = rhs[7:0];
			end
		
			ADD: begin
				// Pre-append the carry flag to capture carries.
				{carry_or_borrow_flag, result} = {1'b0, lhs} + {1'b0, rhs} + carryin;
				// Signed overflow occurs if the operands have the same sign that is different from the result.
				signed_overflow_flag = ~(lhs[WIDTH-1] ^ rhs[WIDTH-1]) & (lhs[WIDTH-1] ^ result[WIDTH-1]);
			end
		
			SUB: begin
				result = lhs - rhs - carryin;
				// There's a carry if the right-hand-side > left-hand-side + carryin.
				carry_or_borrow_flag = {1'b0, lhs} < ({1'b0, rhs} + carryin);
				// Signed overflow during subtraction occurs when subtracting operands with different signs results in a result sign that matches the subtrahend.
				signed_overflow_flag = (lhs[WIDTH-1] ^ rhs[WIDTH-1]) && ~(result[WIDTH-1] ^ rhs[WIDTH-1]);
				unsigned_less_than_flag = (lhs < rhs);
				signed_less_than_flag = ($signed(lhs) < $signed(rhs));
				equality_flag = (lhs == rhs);
			end
		
			AND:
				result = lhs & rhs;
		
			OR:
				result = lhs | rhs;
		
			XOR:
				result = lhs ^ rhs;
		
			MULT:
				result = lhs[7:0] * rhs[7:0];
		
			LUI:
				result[15:8] = rhs[7:0];
		
			LSH: begin
				// Check the MSB to determine left or right shift.
				if (rhs[WIDTH-1] == 1'b0)
					result = lhs << rhs;
				else
					// Allow the leading bits to be zero.
					result = lhs >> ((~rhs) + 1'b1);
			end

			ASH: begin
				// Check the MSB to determine left or right shift.
				if (rhs[WIDTH-1] == 1'b0)
					result = lhs << rhs;
				else
					// Repeat the leading bit to maintain the sign.
					result = $signed(lhs) >>> ((~rhs) + 1'b1);
			end
			
			PASS:
				result = rhs;
			
			NOT:
				result = ~lhs;
			
			default:
				result = {WIDTH{1'b0}};
		end
	end

endmodule