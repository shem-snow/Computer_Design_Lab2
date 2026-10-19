module Datapath (
input clock,
input reset,

output [6:0] demo_display3,
output [6:0] demo_display2,
output [6:0] demo_display1,
output [6:0] demo_display0
);
	
	// FSM controls
	wire [15:0] reg_wen;
	wire [4:0] alu_config;
	wire R_type, Sext_imm, carry, branch, jump, link, load, store, PC_Enable, update_instruction, en_a, wen_a, en_b, wen_b, flag_write;
	
	// Connecting/structural wiring
	wire [15:0] write_data, Rsrc_data, Rdest_data, Common_Data_BUS, new_PC, linked_PC, memory_in_a, memory_address_a, memory_out_a, memory_in_b, memory_address_b, memory_out_b;
	assign write_data = link? linked_PC : (load? memory_out_a : Common_Data_BUS);
	assign memory_in_a = Common_Data_BUS;
	assign memory_address_a = store ? Rdest_data : (load ? Common_Data_BUS : program_counter);
	wire [4:0] alu_flags;
	wire shift_immediate = (instruction_register[15:12] == 4'b1000) && (instruction_register[7:6] == 2'b00); // LSHI, ASHUI
	
	// Datapath registers
	reg [15:0] instruction_register, program_counter;
	reg [4:0] status_register;
	always@(posedge clock)
		if(reset)
			program_counter <= 16'b0;
		else if(PC_Enable)
			program_counter <= new_PC;
		else
			program_counter <= program_counter;
	always@(posedge clock)
		if(flag_write)
			status_register <= alu_flags;
		else
			status_register <= status_register;
	always@(posedge clock)
		instruction_register <= update_instruction? memory_out_a : instruction_register;
	
	// For the demo
	reg [15:0] last_write;
		always@(posedge clock)
		if(reset)
			last_write <= 16'b0;
		else if(|reg_wen)
			last_write <= write_data;
	
	// Modules
	Regfile regs(.clock(clock), .reset(reset), .Rsrc_address(store? instruction_register[11:8] : instruction_register[3:0]), .Rdest_address(store? instruction_register[3:0] : instruction_register[11:8]), .write_data(write_data), .write_enable(reg_wen), .Rsrc_data(Rsrc_data), .Rdest_data(Rdest_data));
	Dumb_ALU alu(.alu_config(alu_config), .lhs(Rdest_data), .regfile_rhs(Rsrc_data), .immediate_bits(shift_immediate? {{3{instruction_register[4]}}, instruction_register[4:0]} : instruction_register[7:0]), .R_type(R_type), .sign_extend_immediate(Sext_imm), .carryin((carry? status_register[4]: 0)), .result(Common_Data_BUS), .flags(alu_flags));
	PC_Logic pc_logic(.CDB(Common_Data_BUS), .PC(program_counter), .imm({{8{instruction_register[7]}}, instruction_register[7:0]}), .branch(branch), .jump(jump), .new_pc(new_PC), .link_pc(linked_PC));
	DualPortMemory #(.INIT_FILE("memory_files/datapath_test_program.txt")) memory(.clock(clock), .en_a(en_a), .we_a(wen_a), .addr_a(memory_address_a), .din_a(memory_in_a), .q_a(memory_out_a), .en_b(en_b), .we_b(wen_b), .addr_b(16'b0), .din_b(16'b0), .q_b(memory_out_b) ); // TODO: add VGA
	FSM_Controller fsm(.clock(clock), .reset(reset), .instruction(instruction_register), .flags(status_register),
		.reg_wen(reg_wen), .alu_config(alu_config), .R_type(R_type), .Sext_imm(Sext_imm), .carry(carry),
		.branch(branch), .jump(jump), .link(link), .load(load), .store(store),
		.PC_Enable(PC_Enable), .update_instruction(update_instruction), .flag_write(flag_write),
		.en_a(en_a), .wen_a(wen_a), .en_b(en_b), .wen_b(wen_b));
	
	// Demo seven segment display
	hex_to_seven_segment display3(.hex_value(last_write[15:12]), .segments(demo_display3));
	hex_to_seven_segment display2(.hex_value(last_write[11:8]),  .segments(demo_display2));
	hex_to_seven_segment display1(.hex_value(last_write[7:4]),   .segments(demo_display1));
	hex_to_seven_segment display0(.hex_value(last_write[3:0]),   .segments(demo_display0));


endmodule
