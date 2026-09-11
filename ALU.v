/*
	1. I chose the naming left-hand-side and right-hand-side for the inputs so it would be obvious what the flags mean.
		For example, the less_than_flag indicates that lhs<rhs.
		
	2. I also decided to simplify the ALU and place a decoder in the datapath to configure the ALU for each operation
	
		localparam ZEXT 	= 4'b0000;
		localparam SEXT 	= 4'b0001;
		localparam ADD 	= 4'b0010; // ADD, ADDI, ADDU, ADDUI, ADDC, ADDCU, ADDCUI, ADDCI
		localparam SUB		= 4'b0011; // SUB, SUBI, CMP, CMPI, CMPU, CMPUI
		localparam AND		= 4'b0100; // AND
		localparam OR		= 4'b0101; // OR
		localparam XOR		= 4'b0110; // XOR
		localparam MULT 	= 4'b0111;
		localparam LUI		= 4'b1000;
		localparam LSH		= 4'b1001; // LSH, LSHI
		localparam ASH		= 4'b1010; // ALSH
		localparam MOV 	= 4'b1011;
		localparam NOT		= 4'b1100; // NOT
		// Unused			= 4'b1101; // 
		// Unused			= 4'b1110; // 
		localparam NOOP	= 4'b1111; // NOP/WAIT
		
			ADD											Covers:	ADD, ADDI, ADDU, ADDUI, ADDC, ADDCI
	-----------------------------------------------------------------------------------
	SUB											Covers:	SUB, SUBI, SUBC, SUBCI, CMP, CMPI
	-----------------------------------------------------------------------------------
	AND											Covers:	AND, ANDI
	-----------------------------------------------------------------------------------
	OR												Covers:	OR, ORI
	-----------------------------------------------------------------------------------
	XOR											Covers:	XOR, XORI
	-----------------------------------------------------------------------------------
	MOV 											Covers:	MOV, MOVI
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
	-----------------------------------------------------------------------------------
	---											Covers:	
	-----------------------------------------------------------------------------------
	---											Covers:	
	-----------------------------------------------------------------------------------
	NOOP											Covers: NOOP/WAIT
	-----------------------------------------------------------------------------------
	
	But the course required the following instructions be implemented inside the ALU:
		ADD, ADDI, ADDU, ADDUI, ADDC, ADDCU, ADDCUI, ADDCI, SUB, SUBI,
		CMP, CMPI, CMPU, CMPUI, AND, ANDI, OR, ORI, XOR, XORI,
		MUL, MULI, MOVI, LSH, LSHI, ASHU, ASHUI, LUI, SNXB, ZRXB,
		NOT, NOOP
	

*/
module ALU #(parameter WIDTH = 16) (
	input [4:0] alu_config,
	input [WIDTH-1:0] lhs, regfile_rhs,
	input [7:0] immediate_bits,
	input R_type,
	input sign_extend_immediate,
	input carryin,
	output reg [WIDTH-1:0] result,
	output [4:0] flags
);
	

	localparam ADD			= 5'b00000;
	localparam ADDI		= 5'b00001;
	localparam ADDU		= 5'b00010;
	localparam ADDUI		= 5'b00011;
	localparam ADDC		= 5'b00100;
	localparam ADDCI		= 5'b00101;
	localparam ADDCU		= 5'b00110;
	localparam ADDCUI		= 5'b00111;
	
	localparam SUB			= 5'b01000;
	localparam SUBI		= 5'b01001;
	localparam CMP			= 5'b01010;
	localparam CMPI		= 5'b01011;
	localparam CMPU		= 5'b01100;
	
	localparam AND			= 5'b01101;
	localparam ANDI		= 5'b01110;
	localparam OR			= 5'b01111;
	localparam ORI			= 5'b10000;
	localparam XOR			= 5'b10001;
	localparam XORI		= 5'b10010;
	
	localparam MOV			= 5'b10011;
	localparam MOVI		= 5'b10100;
	localparam MUL			= 5'b10101;
	localparam MULI		= 5'b10110;
	
	localparam LSH			= 5'b10111;
	localparam LSHI		= 5'b11000;
	localparam ASHU		= 5'b11001;
	localparam ASHUI		= 5'b11010;
	
	localparam LUI			= 5'b11011;
	localparam SNXB		= 5'b11100;
	localparam ZRXB		= 5'b11101;
	localparam NOT			= 5'b11110;
	localparam NO_OP		= 5'b11111;

	reg carry_flag, unsigned_less_than_flag, signed_less_than_flag, signed_overflow_flag, equality_flag;
	assign flags = {	carry_flag, 						// 4
							unsigned_less_than_flag, 		// 3
							signed_less_than_flag, 			// 2
							signed_overflow_flag,			// 1
							equality_flag 						// 0
						};
	
	// MUX for selecting R-type and I-type instructions
	wire [WIDTH-1:0] rhs;
	assign rhs = (R_type)? regfile_rhs : (sign_extend_immediate)? {{(WIDTH-8){immediate_bits[7]}}, immediate_bits} : {{(WIDTH-8){1'b0}}, immediate_bits};

	
	always@(*) begin
	
		// Default outputs
		result = {WIDTH{1'b0}}; // Concatonate WIDTH number of zeros
		
		carry_flag = 1'b0;
		unsigned_less_than_flag = lhs < rhs;
		signed_less_than_flag = ($signed(lhs) < $signed(rhs));
		signed_overflow_flag = 1'b0;
		equality_flag = 1'b0;
		
		case(alu_config)
		
			ADD, ADDI, ADDU, ADDUI: begin
				// Pre-append the carry flag to capture carries.
				{carry_flag, result} = {1'b0, lhs} + {1'b0, rhs};
				// Signed overflow occurs if the operands have the same sign that is different from the result.
				signed_overflow_flag = ~(lhs[WIDTH-1] ^ rhs[WIDTH-1]) & (lhs[WIDTH-1] ^ result[WIDTH-1]);
			end
			
			ADDC, ADDCI, ADDCU, ADDCUI: begin
				// Pre-append the carry flag to capture carries.
				{carry_flag, result} = {1'b0, lhs} + {1'b0, rhs} + carryin;
				// Signed overflow occurs if the operands have the same sign that is different from the result.
				signed_overflow_flag = ~(lhs[WIDTH-1] ^ rhs[WIDTH-1]) & (lhs[WIDTH-1] ^ result[WIDTH-1]);
			end
			
			SUB, SUBI, CMP, CMPI, CMPU: begin
				{carry_flag, result} = {1'b0, lhs} + {1'b0, ~rhs} + 1'b1;
				// Signed overflow during subtraction occurs when subtracting operands with different signs results in a result sign that matches the subtrahend.
				signed_overflow_flag = (lhs[WIDTH-1] ^ rhs[WIDTH-1]) & ~(result[WIDTH-1] ^ rhs[WIDTH-1]);
				equality_flag = (lhs == rhs);
			end
			
			AND, ANDI:
				result = lhs & rhs;
		
			OR, ORI:
				result = lhs | rhs;
		
			XOR, XORI:
				result = lhs ^ rhs;
				
			MOV, MOVI:
				result = rhs;
				
			MUL, MULI:
				// Performs multiplication of the whole 16-bit value then truncates the result
				result = lhs * rhs;
				
			LSH, LSHI: begin
				// Check the MSB to determine left or right shift.
				if (rhs[WIDTH-1] == 1'b0)
					result = lhs << rhs;
				else
					// Allow the leading bits to be zero.
					result = lhs >> ((~rhs) + 1'b1);
			end
			
			ASHU, ASHUI: begin
				// Check the MSB to determine left or right shift.
				if (rhs[WIDTH-1] == 1'b0)
					result = lhs << rhs;
				else
					// Repeat the leading bit to maintain the sign.
					result = $signed(lhs) >>> ((~rhs) + 1'b1);
			end
			
			LUI:
				result = {rhs[7:0], {(WIDTH-8){1'b0}}};
				
			SNXB:
				// Fill the result with the correct sign, then replace the lower bits with rhs.
				result = {{(WIDTH-8){rhs[7]}}, rhs[7:0]};
		
			ZRXB:
				// result already defaults to all zeros, so I just need to write the rhs.
				result = { {(WIDTH-8){1'b0}}, rhs[7:0]};
			
			
			NOT:
				result = ~lhs;
			
			NO_OP:
				result = {WIDTH{1'b0}};
				
			default:
				result = {WIDTH{1'b0}};
		endcase
		
		// The zero/equality flag must be calculated AFTER the result
		equality_flag = (result == {WIDTH{1'b0}});
	end

endmodule
