/*
	Control FSM for the CPU. Drives every control wire in the datapath.

	Every instruction goes through:
		FETCH    memory[PC] is read on port A (q_a is valid after this edge)
		DECODE   instruction_register <= q_a
		EXECUTE  everything else happens on this edge: ALU result written back, flags updated,
		         STORE written, PC updated. LOAD only presents its address here.
		LOAD_WB  (LOAD only) the loaded word is written into Rdest and the PC is updated.

	The PC is only updated at the end of an instruction, so during EXECUTE it still holds the
	address of the current instruction:
		branch target = PC + disp   (relative to the branch itself)
		link_pc       = PC + 1      (JAL's return address)

	Register fields are always IR[11:8] (Rdest / STOR data / Rlink / condition) and
	IR[3:0] (Rsrc / Raddr / Rtarget), so the register write enable is always 1 << IR[11:8].

	Jcond and JAL take their target from the Common Data Bus, so the ALU is set to MOV (R-type)
	for them, which puts R[IR[3:0]] on the bus.

	Condition codes (IR[11:8] of Bcond/Jcond). For CMP Rsrc, Rdest the ALU computes Rdest - Rsrc:
		Z = Rdest == Rsrc   L = Rdest < Rsrc (unsigned)   N = Rdest < Rsrc (signed)
		so GT means "Rsrc > Rdest", the same as the CR16 convention.
*/
module FSM_Controller (
	input clock,
	input reset,
	input [15:0] instruction, // instruction_register
	input [4:0] flags, // status_register: {C, L, N, F, Z}

	output reg [15:0] reg_wen,
	output reg [4:0] alu_config,
	output reg R_type, Sext_imm, carry,
	output reg branch, jump, link, load, store,
	output reg PC_Enable, update_instruction, flag_write,
	output reg en_a, wen_a, en_b, wen_b
);

	// States
	localparam FETCH   = 2'd0;
	localparam DECODE  = 2'd1;
	localparam EXECUTE = 2'd2;
	localparam LOAD_WB = 2'd3;

	// ALU configurations (must match Dumb_ALU.v)
	localparam ADD=5'd0,  ADDI=5'd1,  ADDU=5'd2,  ADDUI=5'd3,  ADDC=5'd4,  ADDCI=5'd5,
	           ADDCU=5'd6,ADDCUI=5'd7,SUB=5'd8,   SUBI=5'd9,  CMP=5'd10,  CMPI=5'd11,
	           CMPU=5'd12,AND=5'd13,  ANDI=5'd14, OR=5'd15,   ORI=5'd16,  XOR=5'd17,
	           XORI=5'd18,MOV=5'd19,  MOVI=5'd20, MUL=5'd21,  MULI=5'd22, LSH=5'd23,
	           LSHI=5'd24,ASHU=5'd25, ASHUI=5'd26,LUI=5'd27,  SNXB=5'd28, ZRXB=5'd29,
	           NOT=5'd30, NO_OP=5'd31;

	// Instruction fields
	wire [3:0] opcode = instruction[15:12];
	wire [3:0] rdest  = instruction[11:8];
	wire [3:0] ext    = instruction[7:4];
	wire [3:0] cond   = instruction[11:8];

	// Instruction classes
	wire is_special = (opcode == 4'b0100);
	wire is_load    = is_special && (ext == 4'b0000);
	wire is_store   = is_special && (ext == 4'b0100);
	wire is_jal     = is_special && (ext == 4'b1000);
	wire is_jcond   = is_special && (ext == 4'b1100);
	wire is_bcond   = (opcode == 4'b1100);

	// Condition checker
	wire C = flags[4], L = flags[3], N = flags[2], F = flags[1], Z = flags[0];
	reg condition_true;
	always @(*) begin
		case (cond)
			4'b0000: condition_true = Z;           // EQ
			4'b0001: condition_true = ~Z;          // NE
			4'b0010: condition_true = C;           // CS
			4'b0011: condition_true = ~C;          // CC
			4'b0100: condition_true = L;           // HI
			4'b0101: condition_true = ~L;          // LS
			4'b0110: condition_true = N;           // GT
			4'b0111: condition_true = ~N;          // LE
			4'b1000: condition_true = F;           // FS
			4'b1001: condition_true = ~F;          // FC
			4'b1010: condition_true = ~L & ~Z;     // LO
			4'b1011: condition_true = L | Z;       // HS
			4'b1100: condition_true = ~N & ~Z;     // LT
			4'b1101: condition_true = N | Z;       // GE
			4'b1110: condition_true = 1'b1;        // UC (unconditional)
			default: condition_true = 1'b0;        // never
		endcase
	end

	// ALU decoder: which ALU operation, and whether it writes a register and/or the flags.
	reg [4:0] decoded_config;
	reg decoded_R_type, decoded_Sext_imm, decoded_carry, decoded_reg_write, decoded_flag_write;
	always @(*) begin
		// default: not an ALU instruction
		decoded_config     = NO_OP;
		decoded_R_type     = 1'b0;
		decoded_Sext_imm   = 1'b0;
		decoded_carry      = 1'b0;
		decoded_reg_write  = 1'b0;
		decoded_flag_write = 1'b0;

		case (opcode)
			4'b0000: begin // R-type
				decoded_R_type    = 1'b1;
				decoded_reg_write = 1'b1;
				case (ext)
					4'b0001: decoded_config = AND;
					4'b0010: decoded_config = OR;
					4'b0011: decoded_config = XOR;
					4'b0101: begin decoded_config = ADD;  decoded_flag_write = 1'b1; end
					4'b0110: decoded_config = ADDU;
					4'b0111: begin decoded_config = ADDC; decoded_flag_write = 1'b1; decoded_carry = 1'b1; end
					4'b1001: begin decoded_config = SUB;  decoded_flag_write = 1'b1; end
					4'b1011: begin decoded_config = CMP;  decoded_flag_write = 1'b1; decoded_reg_write = 1'b0; end
					4'b1101: decoded_config = MOV;
					4'b1110: decoded_config = MUL;
					default: decoded_reg_write = 1'b0; // WAIT, SUBC and unused: do nothing
				endcase
			end

			4'b0001: begin decoded_config = ANDI;  decoded_reg_write = 1'b1; end
			4'b0010: begin decoded_config = ORI;   decoded_reg_write = 1'b1; end
			4'b0011: begin decoded_config = XORI;  decoded_reg_write = 1'b1; end
			4'b0101: begin decoded_config = ADDI;  decoded_reg_write = 1'b1; decoded_Sext_imm = 1'b1; decoded_flag_write = 1'b1; end
			4'b0110: begin decoded_config = ADDUI; decoded_reg_write = 1'b1; decoded_Sext_imm = 1'b1; end
			4'b0111: begin decoded_config = ADDCI; decoded_reg_write = 1'b1; decoded_Sext_imm = 1'b1; decoded_flag_write = 1'b1; decoded_carry = 1'b1; end
			4'b1001: begin decoded_config = SUBI;  decoded_reg_write = 1'b1; decoded_Sext_imm = 1'b1; decoded_flag_write = 1'b1; end
			4'b1011: begin decoded_config = CMPI;  decoded_Sext_imm = 1'b1; decoded_flag_write = 1'b1; end
			4'b1101: begin decoded_config = MOVI;  decoded_reg_write = 1'b1; end
			4'b1110: begin decoded_config = MULI;  decoded_reg_write = 1'b1; decoded_Sext_imm = 1'b1; end
			4'b1111: begin decoded_config = LUI;   decoded_reg_write = 1'b1; end

			4'b1000: begin // shifts
				decoded_reg_write = 1'b1;
				case (ext)
					4'b0100: begin decoded_config = LSH;  decoded_R_type = 1'b1; end
					4'b0110: begin decoded_config = ASHU; decoded_R_type = 1'b1; end
					// TODO: LSHI/ASHUI. Their 5-bit signed amount is IR[4:0], but the ALU
					// sign-extends from IR[7], so negative (right) shifts come out wrong.
					default: decoded_reg_write = 1'b0;
				endcase
			end

			4'b0100: begin // special: only SNXB and ZRXB use the ALU here
				case (ext)
					4'b0010: begin decoded_config = SNXB; decoded_R_type = 1'b1; decoded_reg_write = 1'b1; end
					4'b0110: begin decoded_config = ZRXB; decoded_R_type = 1'b1; decoded_reg_write = 1'b1; end
					default: ;
				endcase
			end

			default: ; // Bcond (1100) and unused opcodes
		endcase
	end

	reg [1:0] state;

	// Next state logic
	always @(posedge clock) begin
		if (reset)
			state <= FETCH;
		else begin
			case (state)
				FETCH:   state <= DECODE;
				DECODE:  state <= EXECUTE;
				EXECUTE: state <= is_load? LOAD_WB : FETCH;
				LOAD_WB: state <= FETCH;
				default: state <= FETCH;
			endcase
		end
	end

	// Output logic
	always @(*) begin

		// default values: nothing is written anywhere
		reg_wen            = 16'b0;
		alu_config         = NO_OP;
		R_type             = 1'b0;
		Sext_imm           = 1'b0;
		carry              = 1'b0;
		branch             = 1'b0;
		jump               = 1'b0;
		link               = 1'b0;
		load               = 1'b0;
		store              = 1'b0;
		PC_Enable          = 1'b0;
		update_instruction = 1'b0;
		flag_write         = 1'b0;
		en_a               = 1'b0;
		wen_a              = 1'b0;
		en_b               = 1'b0; // port B is reserved for the VGA
		wen_b              = 1'b0;

		case (state)
			FETCH: begin
				en_a = 1'b1; // read memory[PC]
			end

			DECODE: begin
				update_instruction = 1'b1; // IR <= q_a
			end

			EXECUTE: begin
				if (is_load) begin
					load = 1'b1; // address = R[Raddr]
					en_a = 1'b1;
					alu_config = MOV; // Common_Data_BUS = R[IR[3:0]]
					R_type     = 1'b1;
				end
				else if (is_store) begin
					store     = 1'b1; // address = IR[11:8], data = IR[3:0]
					en_a      = 1'b1;
					wen_a     = 1'b1;
					PC_Enable = 1'b1;
					alu_config = MOV; // Common_Data_BUS = R[IR[3:0]]
					R_type     = 1'b1;
				end
				else if (is_bcond) begin
					branch    = condition_true;
					PC_Enable = 1'b1;
				end
				else if (is_jcond || is_jal) begin
					alu_config = MOV; // put R[Rtarget] on the Common Data Bus
					R_type     = 1'b1;
					jump       = is_jal | condition_true;
					link       = is_jal;
					reg_wen    = is_jal? (16'b1 << rdest) : 16'b0;
					PC_Enable  = 1'b1;
				end
				else begin // ALU instructions (and anything unrecognized, which acts as a NOP)
					alu_config = decoded_config;
					R_type     = decoded_R_type;
					Sext_imm   = decoded_Sext_imm;
					carry      = decoded_carry;
					flag_write = decoded_flag_write;
					reg_wen    = decoded_reg_write? (16'b1 << rdest) : 16'b0;
					PC_Enable  = 1'b1;
				end
			end

			LOAD_WB: begin
				load      = 1'b1; // write_data = q_a, address still R[Raddr]
				reg_wen   = 16'b1 << rdest;
				PC_Enable = 1'b1;
			end
		endcase
	end

endmodule
