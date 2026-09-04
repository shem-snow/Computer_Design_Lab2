/*
 * The decoder translates the instruction in the instruction register to controls for the datapath at the execution stage.
 * 	- The register file receives a write/no-write flag.
 *		- The current instruction is determined to be R-type or I-type.
 *		- An 8-bit immediate value is extracted from the instruction.
 *		- The ALU needs operation selection inputs.
 * 	- A jump or no jump flag will be set.
 *
 * Flag ordering matches the current ALU interface:
 *		flag_write_enable[4] = carry or borrow
 *		flag_write_enable[3] = unsigned lhs < rhs
 *		flag_write_enable[2] = signed lhs < rhs
 *		flag_write_enable[1] = signed overflow
 *		flag_write_enable[0] = equality
 */
module ALU_decoder #(
    parameter WIDTH = 16
) (
    input [15:0] instruction,

    output reg [3:0] alu_op,

    output reg [3:0] lhs_register_address,
    output reg [3:0] rhs_register_address,
    output reg [3:0] destination_register_address,

    output reg [WIDTH-1:0] immediate_value,
    output reg rhs_uses_immediate,
    output reg carryin_uses_psr,

    output reg register_write_enable,
    output reg [4:0] flag_write_enable,

    output reg instruction_uses_alu,
    output reg illegal_instruction
);

	// These are the same parameters in the ALU
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

   localparam [4:0] WRITE_ADD_SUB_FLAGS = 5'b10010;
   localparam [4:0] WRITE_COMPARE_FLAGS = 5'b01101;

   always @(*) begin
		/* Safe defaults for instructions that do not use the ALU. */
      alu_op = NOOP;

      lhs_register_address = instruction[11:8];
      rhs_register_address = instruction[3:0];
      destination_register_address = instruction[11:8];

      immediate_value = {WIDTH{1'b0}};
      rhs_uses_immediate = 1'b0;
      carryin_uses_psr = 1'b0;

      register_write_enable = 1'b0;
      flag_write_enable = 5'b00000; // write no flags

      instruction_uses_alu = 1'b0;
      illegal_instruction = 1'b0;

      case (instruction[15:12])

          /* Register-to-register ALU instructions. */
          4'b0000: begin
				case (instruction[7:4])
					4'b0000: begin
						/* WAIT is valid only when the entire word is zero. */
							if (instruction != 16'h0000)
								illegal_instruction = 1'b1;
               end
					
					4'b0001: begin                     // AND
                        alu_op = AND;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                    end

                    4'b0010: begin                     // OR / NOP
                        alu_op = OR;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                    end

                    4'b0011: begin                     // XOR
                        alu_op = XOR;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                    end

                    4'b0101: begin                     // ADD
                        alu_op = ADD;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                        flag_write_enable = WRITE_ADD_SUB_FLAGS;
                    end

                    4'b0110: begin                     // ADDU
                        alu_op = ADD;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                    end

                    4'b0111: begin                     // ADDC
                        alu_op = ADD;
                        instruction_uses_alu = 1'b1;
                        carryin_uses_psr = 1'b1;
                        register_write_enable = 1'b1;
                        flag_write_enable = WRITE_ADD_SUB_FLAGS;
                    end

                    4'b1001: begin                     // SUB
                        alu_op = SUB;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                        flag_write_enable = WRITE_ADD_SUB_FLAGS;
                    end

                    4'b1010: begin                     // SUBC
                        alu_op = SUB;
                        instruction_uses_alu = 1'b1;
                        carryin_uses_psr = 1'b1;
                        register_write_enable = 1'b1;
                        flag_write_enable = WRITE_ADD_SUB_FLAGS;
                    end

                    4'b1011: begin                     // CMP
                        alu_op = SUB;
                        instruction_uses_alu = 1'b1;
                        flag_write_enable = WRITE_COMPARE_FLAGS;
                    end

                    4'b1101: begin                     // MOV
                        alu_op = PASS;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                    end

                    4'b1110: begin                     // MUL
                        alu_op = MULT;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                    end

                    default: begin
                        illegal_instruction = 1'b1;
                    end
                endcase
            end

            4'b0001: begin                             // ANDI
                alu_op = AND;
                immediate_value = {{(WIDTH-8){1'b0}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                instruction_uses_alu = 1'b1;
                register_write_enable = 1'b1;
            end

            4'b0010: begin                             // ORI
                alu_op = OR;
                immediate_value = {{(WIDTH-8){1'b0}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                instruction_uses_alu = 1'b1;
                register_write_enable = 1'b1;
            end

            4'b0011: begin                             // XORI
                alu_op = XOR;
                immediate_value = {{(WIDTH-8){1'b0}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                instruction_uses_alu = 1'b1;
                register_write_enable = 1'b1;
            end

            4'b0100: begin
                /* Only SNXB and ZRXB use this ALU. Other special opcodes do not. */
                case (instruction[7:4])
                    4'b0000: begin                     // LOAD
                    end

                    4'b0001: begin                     // LPR
                    end

                    4'b0010: begin                     // SNXB
                        alu_op = SEXT;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                    end

                    4'b0011: begin                     // DI = 16'h4030
                        if (instruction != 16'h4030)
                            illegal_instruction = 1'b1;
                    end

                    4'b0100: begin                     // STOR
                    end

                    4'b0101: begin                     // SPR
                    end

                    4'b0110: begin                     // ZRXB
                        alu_op = ZEXT;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                    end

                    4'b0111: begin                     // EI = 16'h4070
                        if (instruction != 16'h4070)
                            illegal_instruction = 1'b1;
                    end

                    4'b1000: begin                     // JAL
                    end

                    4'b1001: begin                     // RETX = 16'h4090
                        if (instruction != 16'h4090)
                            illegal_instruction = 1'b1;
                    end

                    4'b1010: begin                     // TBIT
                    end

                    4'b1011: begin                     // EXCP
                        if (instruction[11:8] != 4'b0000)
                            illegal_instruction = 1'b1;
                    end

                    4'b1100: begin                     // Jcond
                    end

                    4'b1101: begin                     // Scond
                    end

                    4'b1110: begin                     // TBITI
                    end

                    4'b1111: begin
                        illegal_instruction = 1'b1;
                    end
                endcase
            end

            4'b0101: begin                             // ADDI
                alu_op = ADD;
                immediate_value = {{(WIDTH-8){instruction[7]}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                instruction_uses_alu = 1'b1;
                register_write_enable = 1'b1;
                flag_write_enable = WRITE_ADD_SUB_FLAGS;
            end

            4'b0110: begin                             // ADDUI
                alu_op = ADD;
                immediate_value = {{(WIDTH-8){instruction[7]}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                instruction_uses_alu = 1'b1;
                register_write_enable = 1'b1;
            end

            4'b0111: begin                             // ADDCI
                alu_op = ADD;
                immediate_value = {{(WIDTH-8){instruction[7]}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                carryin_uses_psr = 1'b1;
                instruction_uses_alu = 1'b1;
                register_write_enable = 1'b1;
                flag_write_enable = WRITE_ADD_SUB_FLAGS;
            end

            4'b1000: begin                             // Shift group
                case (instruction[7:5])
                    3'b000: begin                     // LSHI: extension 000s
                        alu_op = LSH;
                        immediate_value = {{(WIDTH-5){instruction[4]}}, instruction[4:0]};
                        rhs_uses_immediate = 1'b1;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                    end

                    3'b001: begin                     // ASHUI: extension 001s
                        alu_op = ASH;
                        immediate_value = {{(WIDTH-5){instruction[4]}}, instruction[4:0]};
                        rhs_uses_immediate = 1'b1;
                        instruction_uses_alu = 1'b1;
                        register_write_enable = 1'b1;
                    end

                    3'b010: begin
                        if (instruction[4] == 1'b0) begin // LSH
                            alu_op = LSH;
                            instruction_uses_alu = 1'b1;
                            register_write_enable = 1'b1;
                        end
                        else begin                    // Unused extension 0101
                            illegal_instruction = 1'b1;
                        end
                    end

                    3'b011: begin
                        if (instruction[4] == 1'b0) begin // ASHU
                            alu_op = ASH;
                            instruction_uses_alu = 1'b1;
                            register_write_enable = 1'b1;
                        end
                        else begin                    // Unused extension 0111
                            illegal_instruction = 1'b1;
                        end
                    end

                    default: begin                    // Extensions 1xxx are unused
                        illegal_instruction = 1'b1;
                    end
                endcase
            end

            4'b1001: begin                             // SUBI
                alu_op = SUB;
                immediate_value = {{(WIDTH-8){instruction[7]}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                instruction_uses_alu = 1'b1;
                register_write_enable = 1'b1;
                flag_write_enable = WRITE_ADD_SUB_FLAGS;
            end

            4'b1010: begin                             // SUBCI
                alu_op = SUB;
                immediate_value = {{(WIDTH-8){instruction[7]}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                carryin_uses_psr = 1'b1;
                instruction_uses_alu = 1'b1;
                register_write_enable = 1'b1;
                flag_write_enable = WRITE_ADD_SUB_FLAGS;
            end

            4'b1011: begin                             // CMPI
                alu_op = SUB;
                immediate_value = {{(WIDTH-8){instruction[7]}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                instruction_uses_alu = 1'b1;
                flag_write_enable = WRITE_COMPARE_FLAGS;
            end

            4'b1100: begin
                /* Bcond is valid but handled by PC control, not this ALU decoder. */
            end

            4'b1101: begin                             // MOVI
                alu_op = PASS;
                immediate_value = {{(WIDTH-8){1'b0}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                instruction_uses_alu = 1'b1;
                register_write_enable = 1'b1;
            end

            4'b1110: begin                             // MULI
                alu_op = MULT;
                immediate_value = {{(WIDTH-8){instruction[7]}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                instruction_uses_alu = 1'b1;
                register_write_enable = 1'b1;
            end

            4'b1111: begin                             // LUI
                alu_op = LUI;
                immediate_value = {{(WIDTH-8){1'b0}}, instruction[7:0]};
                rhs_uses_immediate = 1'b1;
                instruction_uses_alu = 1'b1;
                register_write_enable = 1'b1;
            end

            default: begin
                illegal_instruction = 1'b1;
            end
        endcase
    end

endmodule
