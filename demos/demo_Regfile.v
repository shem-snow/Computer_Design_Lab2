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
	wire [15:0] rhs, lhs, ALU_output, write_BUS;
	wire [7:0] alu_config;
	
	reg load;
	reg [15:0] write_enable, mem_reg;
	wire [15:0] wen, we;
	
	assign write_BUS = (load)? mem_reg : ALU_output;
	assign we = (load)? write_enable : wen;
	
	
	// Register file including the initial loading/startup.
	Regfile rf(.clock(clk), .reset(rst), .Rsrc_address(rhs_selector), .Rdest_address(lhs_selector),
		.write_enable(we), .write_data(write_BUS), .Rsrc_data(rhs), .Rdest_data(lhs));
	reg [15:0] memdata [0:15];
	integer i;
	initial begin
		$readmemh("memory_files/16by16regfile.txt", memdata);
		@(negedge rst);
		load = 1;
		for(i = 0; i < 16; i = i + 1) begin
			@(posedge clk);
			mem_reg = memdata[i];
			write_enable = 16'b1 << i;
		end
		@(posedge clk);
		write_enable = 16'b0;
		load = 0;
	end

	// ALU
	ALU alu(.alu_config(alu_config[4:0]), .lhs(lhs), .regfile_rhs(rhs), .immediate_bits(slide_switches),
		.R_type(alu_config[5]), .sign_extend_immediate(alu_config[6]), .carryin(alu_config[7]),
		.result(ALU_output), .flags(alu_flags));
		
	// HexTo7Seg
	hex_to_seven_segment htss0(.hex_value(write_BUS[3:0]), .segments(seg0));
	hex_to_seven_segment htss1(.hex_value(write_BUS[7:4]), .segments(seg1));
	hex_to_seven_segment htss2(.hex_value(write_BUS[11:8]), .segments(seg2));
	hex_to_seven_segment htss3(.hex_value(write_BUS[15:12]), .segments(seg3));
		
	// Moore FSM
	regfile_alu_test_fsm fsm(
		.clk(clk), .rst(rst), .load(load), .view_select(slide_switches[3:0]),
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

module regfile_alu_test_fsm (
    input              clk,
    input              rst,
    input              load,         // demo_Regfile's loader reg: 1 while preloading, 0 once done
    input      [3:0]   view_select,  // slide_switches[3:0]; register to inspect once testing ends

    output reg [3:0]   rhs_selector, // Regfile Rsrc_address
    output reg [3:0]   lhs_selector, // Regfile Rdest_address
    output reg [15:0]  wen,          // Regfile write_enable
    output reg [7:0]   alu_config    // {carryin, sign_extend_immediate, R_type, opcode[4:0]}
);

    localparam ADD=5'd0,  ADDI=5'd1,  ADDU=5'd2,  ADDUI=5'd3,  ADDC=5'd4,  ADDCI=5'd5,
               ADDCU=5'd6,ADDCUI=5'd7,SUB=5'd8,   SUBI=5'd9,  CMP=5'd10,  CMPI=5'd11,
               CMPU=5'd12,AND=5'd13,  ANDI=5'd14, OR=5'd15,   ORI=5'd16,  XOR=5'd17,
               XORI=5'd18,MOV=5'd19,  MOVI=5'd20, MUL=5'd21,  MULI=5'd22, LSH=5'd23,
               LSHI=5'd24,ASHU=5'd25, ASHUI=5'd26,LUI=5'd27,  SNXB=5'd28, ZRXB=5'd29,
               NOT=5'd30, NO_OP=5'd31;

    localparam S_WAIT_LOAD = 2'd0,
               S_RUN       = 2'd1,
               S_DISPLAY   = 2'd2;

    reg [1:0] state;
    reg [4:0] op_index;
    reg       seen_load;
    reg [3:0] view_reg;

    wire [3:0] dest_reg = op_index % 5'd15; // cycles R0..R14; R15 held aside as a known operand

    // ---- state register ----
    always @(posedge clk) begin
        if (rst) begin
            state     <= S_WAIT_LOAD;
            op_index  <= 5'd0;
            seen_load <= 1'b0;
            view_reg  <= 4'd0;
        end else begin
            case (state)
                S_WAIT_LOAD: begin
                    if (load)
                        seen_load <= 1'b1;          // confirm we actually saw the loader run
                    else if (seen_load)
                        state <= S_RUN;
                end

                S_RUN: begin
                    if (op_index == 5'd31)
                        state <= S_DISPLAY;
                    else
                        op_index <= op_index + 5'd1;
                end

                S_DISPLAY: begin
                    state    <= S_DISPLAY;     // park here forever
                    view_reg <= view_select;   // registered -> keeps this Moore, not Mealy
                end
            endcase
        end
    end

    // ---- Moore outputs: function of state + registered op_index/view_reg only ----
    always @(*) begin
        rhs_selector = 4'hF;        // fixed, known operand for every R-type op
        lhs_selector = dest_reg;
        wen          = 16'b0;
        alu_config   = {3'b000, NO_OP};

        case (state)
            S_RUN: begin
                lhs_selector = dest_reg;
                wen          = (16'b1 << dest_reg);
                alu_config   = {cfg_bits(op_index), op_index};
            end
            S_DISPLAY: begin
                lhs_selector = view_reg;
                wen          = 16'b0;
            end
            default: ; // S_WAIT_LOAD: outputs stay at their safe defaults above
        endcase
    end

    // {carryin, sign_extend_immediate, R_type} per opcode, verified against ALU.v's rhs mux
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
