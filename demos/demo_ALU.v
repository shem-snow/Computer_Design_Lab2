/*
 * FPGA demonstration for the 16-bit ALU.
 *
 * Switch assignments:
 *     SW[4:0] = ALU configuration
 *     SW[8:5] = four-bit data value
 *				This four-bit value will be given to "immediate".
 *     SW[9]   = signed/unsigned selection
 *
 * Entered byte:
 *     SW[9] = 0: {4'b0000, SW[8:5]}
 *     SW[9] = 1: sign-extended SW[8:5]
 *
 * Button assignments, active-low:
 *     KEY[3] = save entered byte into lhs[15:8]
 *     KEY[2] = save entered byte into lhs[7:0]
 *     KEY[1] = save entered byte into regfile_rhs[15:8]
 *     KEY[0] = save entered byte into regfile_rhs[7:0]
 *
 * LED assignments:
 *     LEDR[0]   = complete test passed
 *     LEDR[1]   = result matches
 *     LEDR[2]   = all flags match
 *     LEDR[3]   = valid ALU configuration
 *     LEDR[8:4] = actual ALU flags
 *     LEDR[9]   = selected test failed
 *
 * Seven-segment assignments:
 *     HEX3:HEX0 = actual ALU result
 *     HEX5:HEX4 = currently entered 8-bit value
 *
 * This design assumes the ALU port is named:
 *
 *     sign_extend_immediate
 * 
 */

module demo_ALU (
    input CLOCK_50,
    input [3:0] KEY,
    input [9:0] SW,

    output [9:0] LEDR,

    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5
);

    localparam WIDTH = 16;

    localparam ADD     = 5'd0;
    localparam ADDI    = 5'd1;
    localparam ADDU    = 5'd2;
    localparam ADDUI   = 5'd3;
    localparam ADDC    = 5'd4;
    localparam ADDCI   = 5'd5;
    localparam ADDCU   = 5'd6;
    localparam ADDCUI  = 5'd7;

    localparam SUB     = 5'd8;
    localparam SUBI    = 5'd9;
    localparam CMP     = 5'd10;
    localparam CMPI    = 5'd11;
    localparam CMPU    = 5'd12;

    localparam AND_OP  = 5'd13;
    localparam ANDI    = 5'd14;
    localparam OR_OP   = 5'd15;
    localparam ORI     = 5'd16;
    localparam XOR_OP  = 5'd17;
    localparam XORI    = 5'd18;

    localparam MOV     = 5'd19;
    localparam MOVI    = 5'd20;
    localparam MUL     = 5'd21;
    localparam MULI    = 5'd22;

    localparam LSH     = 5'd23;
    localparam LSHI    = 5'd24;
    localparam ASHU    = 5'd25;
    localparam ASHUI   = 5'd26;

    localparam LUI     = 5'd27;
    localparam SNXB    = 5'd28;
    localparam ZRXB    = 5'd29;
    localparam NOT_OP  = 5'd30;
    localparam NO_OP   = 5'd31;

    wire [4:0] alu_config;
    wire sign_extend_immediate;
    wire [7:0] entered_byte;

    reg R_type;

    /*
     * No unused switch remains for carryin, so it is currently zero.
     */
    wire carryin;
    assign carryin = 1'b0;

    /*
     * Stored ALU operands.
     */
    reg [WIDTH-1:0] lhs;
    reg [WIDTH-1:0] regfile_rhs;

    wire [WIDTH-1:0] actual_result;
    wire [4:0] actual_flags;

    /*
     * Golden-reference outputs.
     */
    reg [WIDTH-1:0] expected_rhs;
    reg [WIDTH-1:0] expected_result;
    reg [WIDTH:0] extended_result;
    reg [4:0] expected_flags;

    reg expected_carry_flag;
    reg expected_unsigned_less_than_flag;
    reg expected_signed_less_than_flag;
    reg expected_signed_overflow_flag;
    reg expected_equality_flag;

    wire result_matches;
    wire flags_match;
    wire valid_test;
    wire test_passed;

    /*
     * Registers used to synchronize the active-low pushbuttons.
     */
    reg [3:0] key_metastability;
    reg [3:0] key_synchronized;
    reg [3:0] key_previous;

    assign alu_config = SW[4:0];

   /*
	* Data-entry switches
	* -------------------
	*
	* SW[8:5] provides a four-bit value.
	*
	* SW[9] determines how that value is expanded into an eight-bit value:
	*
	*     SW[9] = 0:
	*         Treat SW[8:5] as unsigned and zero-extend it.
	*
	*         Example:
	*             SW[8:5] = 4'b1000
	*             entered_byte = 8'h08
	*
	*     SW[9] = 1:
	*         Treat SW[8:5] as signed and sign-extend it.
	*
	*         Example:
	*             SW[8:5] = 4'b1000
	*             entered_byte = 8'hF8, representing -8
	*
	* The resulting entered_byte has two uses:
	*
	*  1. Register operand entry
	*
	*     Pressing one of the four pushbuttons saves entered_byte into the
	*     selected half of lhs or regfile_rhs:
	*
	*         KEY[3] -> lhs[15:8]
	*         KEY[2] -> lhs[7:0]
	*         KEY[1] -> regfile_rhs[15:8]
	*         KEY[0] -> regfile_rhs[7:0]
	*
	*  2. Live immediate entry
	*
	*     For an I-type instruction, entered_byte is connected directly to
	*     the ALU's immediate_bits input. It does not need to be saved first.
	*
	*     Therefore, testing ADDI requires:
	*
	*         a. Save the desired lhs value.
	*         b. Select ADDI using SW[4:0].
	*         c. Place the desired immediate value on SW[8:5].
	*
	*     The saved regfile_rhs value is ignored by I-type instructions.
	*
	* R-type instructions use the saved regfile_rhs value and ignore the
	* live immediate value.
	*/
    assign sign_extend_immediate = SW[9];

    assign entered_byte =
        sign_extend_immediate
            ? {{4{SW[8]}}, SW[8:5]}
            : {4'b0000, SW[8:5]};

    /*
     * Infer whether the selected configuration is an R-type or I-type
     * instruction.
     */
    always @(*) begin
        case (alu_config)

            ADDI, ADDUI,
            ADDCI, ADDCUI,
            SUBI, CMPI,
            ANDI, ORI, XORI,
            MOVI, MULI,
            LSHI, ASHUI,
            LUI:
                R_type = 1'b0;

            default:
                R_type = 1'b1;

        endcase
    end

    /*
     * Initialize saved operands and button synchronization registers.
     *
     * Intel FPGA synthesis supports initial values for FPGA registers.
     */
    initial begin
        lhs = {WIDTH{1'b0}};
        regfile_rhs = {WIDTH{1'b0}};

        key_metastability = 4'b1111;
        key_synchronized = 4'b1111;
        key_previous = 4'b1111;
    end

    /*
     * Synchronize the buttons to CLOCK_50 and detect falling edges.
     *
     * A falling edge corresponds to pressing an active-low button.
     */
    always @(posedge CLOCK_50) begin
        key_metastability <= KEY;
        key_synchronized <= key_metastability;
        key_previous <= key_synchronized;

        if (key_previous[3] && !key_synchronized[3])
            lhs[15:8] <= entered_byte;

        if (key_previous[2] && !key_synchronized[2])
            lhs[7:0] <= entered_byte;

        if (key_previous[1] && !key_synchronized[1])
            regfile_rhs[15:8] <= entered_byte;

        if (key_previous[0] && !key_synchronized[0])
            regfile_rhs[7:0] <= entered_byte;
    end

 /*
 * ALU operand sources
 * -------------------
 *
 * lhs:
 *     Always comes from the value previously entered using KEY[3:2].
 *
 * regfile_rhs:
 *     Used by R-type instructions and comes from the value previously
 *     entered using KEY[1:0].
 *
 * immediate_bits:
 *     Used by I-type instructions and comes directly from the current
 *     entered_byte. No button press is required to use an immediate.
 *
 * R_type:
 *     Selects between the saved register operand and the live immediate.
 */
    ALU #(
        .WIDTH(WIDTH)
    ) alu_under_test (
        .alu_config(alu_config),
        .lhs(lhs),
        .regfile_rhs(regfile_rhs),
        .immediate_bits(entered_byte),
        .R_type(R_type),
        .sign_extend_immediate(sign_extend_immediate),
        .carryin(carryin),
        .result(actual_result),
        .flags(actual_flags)
    );

    /*
     * Construct the rhs value that the ALU should use.
     */
    always @(*) begin
        if (R_type) begin
            expected_rhs = regfile_rhs;
        end
        else if (sign_extend_immediate) begin
            expected_rhs = {
                {8{entered_byte[7]}},
                entered_byte
            };
        end
        else begin
            expected_rhs = {
                8'h00,
                entered_byte
            };
        end
    end

    /*
     * Golden-reference model.
     */
    always @(*) begin
        expected_result = {WIDTH{1'b0}};
        extended_result = {(WIDTH+1){1'b0}};

        expected_carry_flag = 1'b0;

        expected_unsigned_less_than_flag =
            (lhs < expected_rhs);

        expected_signed_less_than_flag =
            ($signed(lhs) < $signed(expected_rhs));

        expected_signed_overflow_flag = 1'b0;
        expected_equality_flag = 1'b0;

        case (alu_config)

            ADD, ADDI, ADDU, ADDUI: begin
                extended_result =
                    {1'b0, lhs} +
                    {1'b0, expected_rhs};

                expected_result =
                    extended_result[WIDTH-1:0];

                expected_carry_flag =
                    extended_result[WIDTH];

                expected_signed_overflow_flag =
                    ~(lhs[WIDTH-1] ^
                      expected_rhs[WIDTH-1]) &
                     (lhs[WIDTH-1] ^
                      expected_result[WIDTH-1]);
            end

            ADDC, ADDCI, ADDCU, ADDCUI: begin
                extended_result =
                    {1'b0, lhs} +
                    {1'b0, expected_rhs} +
                    carryin;

                expected_result =
                    extended_result[WIDTH-1:0];

                expected_carry_flag =
                    extended_result[WIDTH];

                expected_signed_overflow_flag =
                    ~(lhs[WIDTH-1] ^
                      expected_rhs[WIDTH-1]) &
                     (lhs[WIDTH-1] ^
                      expected_result[WIDTH-1]);
            end

            SUB, SUBI, CMP, CMPI, CMPU: begin
                extended_result =
                    {1'b0, lhs} +
                    {1'b0, ~expected_rhs} +
                    1'b1;

                expected_result =
                    extended_result[WIDTH-1:0];

                expected_carry_flag =
                    extended_result[WIDTH];

                expected_signed_overflow_flag =
                    (lhs[WIDTH-1] ^
                     expected_rhs[WIDTH-1]) &
                   ~(expected_result[WIDTH-1] ^
                     expected_rhs[WIDTH-1]);
            end

            AND_OP, ANDI: begin
                expected_result =
                    lhs & expected_rhs;
            end

            OR_OP, ORI: begin
                expected_result =
                    lhs | expected_rhs;
            end

            XOR_OP, XORI: begin
                expected_result =
                    lhs ^ expected_rhs;
            end

            MOV, MOVI: begin
                expected_result = expected_rhs;
            end

            MUL, MULI: begin
                expected_result =
                    lhs * expected_rhs;
            end

            LSH, LSHI: begin
                if (expected_rhs[WIDTH-1] == 1'b0)
                    expected_result =
                        lhs << expected_rhs;
                else
                    expected_result =
                        lhs >>
                        ((~expected_rhs) + 1'b1);
            end

            ASHU, ASHUI: begin
                if (expected_rhs[WIDTH-1] == 1'b0)
                    expected_result =
                        lhs << expected_rhs;
                else
                    expected_result =
                        $signed(lhs) >>>
                        ((~expected_rhs) + 1'b1);
            end

            LUI: begin
                expected_result = {
                    expected_rhs[7:0],
                    {(WIDTH-8){1'b0}}
                };
            end

            SNXB: begin
                expected_result = {
                    {(WIDTH-8){expected_rhs[7]}},
                    expected_rhs[7:0]
                };
            end

            ZRXB: begin
                expected_result = {
                    {(WIDTH-8){1'b0}},
                    expected_rhs[7:0]
                };
            end

            /*
             * This matches the current ALU implementation:
             *
             *     result = ~lhs;
             */
            NOT_OP: begin
                expected_result = ~lhs;
            end

            NO_OP: begin
                expected_result = {WIDTH{1'b0}};
            end

            default: begin
                expected_result = {WIDTH{1'b0}};
            end

        endcase

        expected_equality_flag =
            (expected_result == {WIDTH{1'b0}});

        expected_flags = {
            expected_carry_flag,
            expected_unsigned_less_than_flag,
            expected_signed_less_than_flag,
            expected_signed_overflow_flag,
            expected_equality_flag
        };
    end

    /*
     * All 32 possible alu_config values are defined.
     */
    assign valid_test = 1'b1;

    assign result_matches =
        (actual_result == expected_result);

    assign flags_match =
        (actual_flags == expected_flags);

    assign test_passed =
        valid_test &&
        result_matches &&
        flags_match;

    /*
     * LED outputs.
     */
    assign LEDR[0] = test_passed;
    assign LEDR[1] = result_matches;
    assign LEDR[2] = flags_match;
    assign LEDR[3] = valid_test;
    assign LEDR[8:4] = actual_flags;
    assign LEDR[9] = valid_test && !test_passed;

    /*
     * Display the ALU result on HEX3:HEX0.
     */
    hex_to_seven_segment display_result_0 (
        .hex_value(actual_result[3:0]),
        .segments(HEX0)
    );

    hex_to_seven_segment display_result_1 (
        .hex_value(actual_result[7:4]),
        .segments(HEX1)
    );

    hex_to_seven_segment display_result_2 (
        .hex_value(actual_result[11:8]),
        .segments(HEX2)
    );

    hex_to_seven_segment display_result_3 (
        .hex_value(actual_result[15:12]),
        .segments(HEX3)
    );

    /*
     * Display the currently entered byte on HEX5:HEX4.
     */
    hex_to_seven_segment display_entered_byte_low (
        .hex_value(entered_byte[3:0]),
        .segments(HEX4)
    );

    hex_to_seven_segment display_entered_byte_high (
        .hex_value(entered_byte[7:4]),
        .segments(HEX5)
    );

endmodule


/*
 * Active-low hexadecimal seven-segment decoder.
 */
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