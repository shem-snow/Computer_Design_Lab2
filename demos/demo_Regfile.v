module demo_Regfile
(
	input	clk,
	input rst,
	input [7:0] slide_switches,
	output [4:0] alu_flags, // LEDs
	
	output [6:0] seg0,
	output [6:0] seg1,
	output [6:0] seg2,
	output [6:0] seg3
);
	
	// Internal connecting wires
	wire [3:0] rhs_selector, lhs_selector;
	wire [15:0] rhs, lhs, ALU_output, wen;
	wire [7:0] alu_config;
	
	// Register file
	Regfile rf(.clock(clk), .reset(~rst), .Rsrc_address(rhs_selector), .Rdest_address(lhs_selector),
		.write_enable(wen), .write_data(ALU_output), .Rsrc_data(rhs), .Rdest_data(lhs));

	// ALU
	ALU alu(.alu_config(alu_config[4:0]), .lhs(lhs), .regfile_rhs(rhs), .immediate_bits(slide_switches),
		.R_type(alu_config[5]), .sign_extend_immediate(alu_config[6]), .carryin(alu_config[7]),
		.result(ALU_output), .flags(alu_flags));
		
	// HexTo7Seg
	hex_to_seven_segment htss0(.hex_value(ALU_output[3:0]), .segments(seg0));
	hex_to_seven_segment htss1(.hex_value(ALU_output[7:4]), .segments(seg1));
	hex_to_seven_segment htss2(.hex_value(ALU_output[11:8]), .segments(seg2));
	hex_to_seven_segment htss3(.hex_value(ALU_output[15:12]), .segments(seg3));
		
	// Moore FSM
	regfile_alu_test_fsm fsm(
		.clk(clk), .rst(~rst), .view_select(slide_switches[3:0]),
		.rhs_selector(rhs_selector), .lhs_selector(lhs_selector),
		.wen(wen), .alu_config(alu_config)
	);

endmodule


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

/*
	This FSM test module goes throught three states:
	1: load
		uses R[14] to count up to 27.
		on even numbers, R[14] increments
		on odd numbers, R[i] = R[14]
	2: run:
		uses "dest_reg" to select each of the 16 registers
		uses the "load_step" internal wire to count throught each ALU opertaion (0-31 for my 5-bit ALU_op)
		continues to increment R[14]
		performs Rdest <- regfile[load_step] ALU_op regfile[14]
		
	3: display
		uses the slide switches [3:0] to view each register.
*/
module regfile_alu_test_fsm (
    input              clk,
    input              rst,
    input      [3:0]   view_select,  // slide_switches[3:0] used in the final state to view register values.

    output reg [3:0]   rhs_selector, // ALU_b
    output reg [3:0]   lhs_selector, // ALU_a
    output reg [15:0]  wen,			 // write_enable
    output reg [7:0]   alu_config    // bits to select the ALU operation.
);

    localparam ADD=5'd0,  ADDI=5'd1,  ADDU=5'd2,  ADDUI=5'd3,  ADDC=5'd4,  ADDCI=5'd5,
               ADDCU=5'd6,ADDCUI=5'd7,SUB=5'd8,   SUBI=5'd9,  CMP=5'd10,  CMPI=5'd11,
               CMPU=5'd12,AND=5'd13,  ANDI=5'd14, OR=5'd15,   ORI=5'd16,  XOR=5'd17,
               XORI=5'd18,MOV=5'd19,  MOVI=5'd20, MUL=5'd21,  MULI=5'd22, LSH=5'd23,
               LSHI=5'd24,ASHU=5'd25, ASHUI=5'd26,LUI=5'd27,  SNXB=5'd28, ZRXB=5'd29,
               NOT=5'd30, NO_OP=5'd31;

    // R15 is always zero and R14 is my accumulator variable during loading until the
	 // end when it becomes the fixed "known operand" for R-type opcodes.
    localparam ZERO_REG = 4'd15;
	 localparam ACC_REG = 4'd14;
	
	 // There are 3 states in this FSM.
    localparam S_LOAD    = 2'd0, // Load known values into the regfile.
               S_RUN     = 2'd1, // Run a program that does the same operations every time.
               S_DISPLAY = 2'd2; // Use the slide switches to view the results in each register.

    reg [1:0] state;
    reg [4:0] load_step;
    reg [4:0] op_index;
    reg [3:0] view_reg;

    wire [3:0] dest_reg = op_index % 5'd14; // cycle through R0-R13 twice

    // Next state logic
    always @(posedge clk) begin
        if (rst) begin
            state     <= S_LOAD;
            load_step <= 5'd0;
            op_index  <= 5'd0;
            view_reg  <= 4'd0;
        end else begin
            case (state)
                S_LOAD: begin
                    if (load_step == 5'd27) begin // going twice the number of registers we're writing
                        state    <= S_RUN;
                        op_index <= 5'd0;
                    end else
                        load_step <= load_step + 5'd1;
                end

                S_RUN: begin
                    if (op_index == 5'd31) // opcode for NO_OP
                        state <= S_DISPLAY;
                    else
                        op_index <= op_index + 5'd1;
                end

                S_DISPLAY: begin
                    state    <= S_DISPLAY;
                    view_reg <= view_select;
                end
            endcase
        end
    end

    // Output logic
    always @(*) begin
		  
		  // default values
        rhs_selector = ACC_REG;
        lhs_selector = dest_reg;
        wen          = 16'b0;
        alu_config   = {3'b000, NO_OP};

        case (state)
            S_LOAD: begin
					 // on even steps, increment
                if (!load_step[0]) begin
                    lhs_selector = ACC_REG;
                    rhs_selector = ZERO_REG;
                    wen          = (16'b1 << ACC_REG);
                    alu_config   = {cfg_bits(ADDC), ADDC};
                end
					 // on odd steps, dump R14's current count into whichever register we're loading
					 else begin
                    lhs_selector = load_step[4:1];
                    rhs_selector = ACC_REG;
                    wen          = (16'b1 << load_step[4:1]);
                    alu_config   = {cfg_bits(MOV), MOV};
                end
            end

            S_RUN: begin
                // one opcode per register per clock, opcode number IS op_index
                lhs_selector = dest_reg;
                rhs_selector = ACC_REG; // R14 now becomes known constant operand for R-type ops
                wen          = (16'b1 << dest_reg);
                alu_config   = {cfg_bits(op_index), op_index};
            end

            S_DISPLAY: begin
                // just MOV the selected register through the ALU so the display
                // (which reads ALU_output) shows regs[view_reg] untouched
                lhs_selector = dest_reg;            // don't-care for MOV, left alone
                rhs_selector = view_reg;
                wen          = 16'b0;               // never write during display
                alu_config   = {cfg_bits(MOV), MOV};
            end
        endcase
    end

    // {carryin, sign_extend_immediate, R_type} per opcode
	 // between the localparams and this function, you can specify your ALU opcodes here.
	 // to use, append like: { cfg_bits(opcode_name), opcode_name}
    function [2:0] cfg_bits;
        input [4:0] op;
        begin
            case (op)
                ADD:     cfg_bits = 3'b0_0_1;
                ADDI:    cfg_bits = 3'b0_1_0;
                ADDU:    cfg_bits = 3'b0_0_1;
                ADDUI:   cfg_bits = 3'b0_0_0;
                ADDC:    cfg_bits = 3'b1_0_1;
                ADDCI:   cfg_bits = 3'b1_1_0;
                ADDCU:   cfg_bits = 3'b1_0_1;
                ADDCUI:  cfg_bits = 3'b1_0_0;
                SUB:     cfg_bits = 3'b0_0_1;
                SUBI:    cfg_bits = 3'b0_1_0;
                CMP:     cfg_bits = 3'b0_0_1;
                CMPI:    cfg_bits = 3'b0_1_0;
                CMPU:    cfg_bits = 3'b0_0_1;
                AND:     cfg_bits = 3'b0_0_1;
                ANDI:    cfg_bits = 3'b0_0_0;
                OR:      cfg_bits = 3'b0_0_1;
                ORI:     cfg_bits = 3'b0_0_0;
                XOR:     cfg_bits = 3'b0_0_1;
                XORI:    cfg_bits = 3'b0_0_0;
                MOV:     cfg_bits = 3'b0_0_1;
                MOVI:    cfg_bits = 3'b0_1_0;
                MUL:     cfg_bits = 3'b0_0_1;
                MULI:    cfg_bits = 3'b0_1_0;
                LSH:     cfg_bits = 3'b0_0_1;
                LSHI:    cfg_bits = 3'b0_1_0;
                ASHU:    cfg_bits = 3'b0_0_1;
                ASHUI:   cfg_bits = 3'b0_1_0;
                LUI:     cfg_bits = 3'b0_0_0;
                SNXB:    cfg_bits = 3'b0_0_0;
                ZRXB:    cfg_bits = 3'b0_0_0;
                NOT:     cfg_bits = 3'b0_0_1;
                NO_OP:   cfg_bits = 3'b0_0_0;
                default: cfg_bits = 3'b0_0_0;
            endcase
        end
    endfunction

endmodule