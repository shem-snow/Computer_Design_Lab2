`timescale 1ns/1ps

module tb_ALU;

    localparam WIDTH = 16;

    /*
        ALU configuration values must match ALU.v.
    */

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

    /*
        Inputs to the ALU.
    */

    reg [4:0] alu_config;
    reg [WIDTH-1:0] lhs;
    reg [WIDTH-1:0] regfile_rhs;
    reg [7:0] immediate_bits;
    reg R_type;
    reg sign_extend_immediate;
    reg carryin;

    /*
        Outputs from the ALU.
    */

    wire [WIDTH-1:0] result;
    wire [4:0] flags;

    /*
        Expected values calculated by the testbench.
    */

    reg [WIDTH-1:0] expected_rhs;
    reg [WIDTH-1:0] expected_result;
    reg [WIDTH:0] expected_extended_result;
    reg [4:0] expected_flags;

    reg expected_carry_flag;
    reg expected_unsigned_less_than_flag;
    reg expected_signed_less_than_flag;
    reg expected_signed_overflow_flag;
    reg expected_equality_flag;

    /*
        Directed lhs values include important signed and unsigned
        boundary cases.
    */

    reg [WIDTH-1:0] lhs_values [0:15];

    integer operation_number;
    integer lhs_number;
    integer operand_number;
    integer carry_number;

    integer number_of_tests;
    integer number_of_errors;

    /*
        Device under test.
    */

    ALU #(
        .WIDTH(WIDTH)
    ) dut (
        .alu_config(alu_config),
        .lhs(lhs),
        .regfile_rhs(regfile_rhs),
        .immediate_bits(immediate_bits),
        .R_type(R_type),
        .sign_extend_immediate(sign_extend_immediate),
        .carryin(carryin),
        .result(result),
        .flags(flags)
    );

    initial begin

        number_of_tests = 0;
        number_of_errors = 0;

        /*
            Initialize important lhs values.
        */

        lhs_values[0]  = 16'h0000;
        lhs_values[1]  = 16'h0001;
        lhs_values[2]  = 16'h0002;
        lhs_values[3]  = 16'h007F;
        lhs_values[4]  = 16'h0080;
        lhs_values[5]  = 16'h00FF;
        lhs_values[6]  = 16'h0100;
        lhs_values[7]  = 16'h7FFE;
        lhs_values[8]  = 16'h7FFF;
        lhs_values[9]  = 16'h8000;
        lhs_values[10] = 16'h8001;
        lhs_values[11] = 16'hFF00;
        lhs_values[12] = 16'hFF7F;
        lhs_values[13] = 16'hFFFE;
        lhs_values[14] = 16'hFFFF;
        lhs_values[15] = 16'h5555;

        /*
            Test all 32 ALU configurations.
        */

        for (
            operation_number = 0;
            operation_number < 32;
            operation_number = operation_number + 1
        ) begin

            alu_config = operation_number[4:0];

            /*
                Determine whether the instruction uses regfile_rhs or
                immediate_bits.
            */

            case (operation_number)

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

            /*
                Select sign extension or zero extension for immediate
                instructions.

                ADDUI and ADDCUI still use sign-extended immediates
                according to the supplied ISA.
            */

            case (operation_number)

                ADDI, ADDUI,
                ADDCI, ADDCUI,
                SUBI, CMPI,
                MULI,
                LSHI, ASHUI:
                    sign_extend_immediate = 1'b1;

                default:
                    sign_extend_immediate = 1'b0;

            endcase

            /*
                Test each important lhs value.
            */

            for (
                lhs_number = 0;
                lhs_number < 16;
                lhs_number = lhs_number + 1
            ) begin

                lhs = lhs_values[lhs_number];

                /*
                    For immediate instructions, this tests all 256 possible
                    immediate values.

                    For register instructions, it generates 256 varied
                    register operands.
                */

                for (
                    operand_number = 0;
                    operand_number < 256;
                    operand_number = operand_number + 1
                ) begin

                    immediate_bits = operand_number[7:0];

                    /*
                        Include exact arithmetic boundary values before
                        generating additional operand patterns.
                    */

                    case (operand_number)

                        0:  regfile_rhs = 16'h0000;
                        1:  regfile_rhs = 16'h0001;
                        2:  regfile_rhs = 16'h0002;
                        3:  regfile_rhs = 16'h007F;
                        4:  regfile_rhs = 16'h0080;
                        5:  regfile_rhs = 16'h00FF;
                        6:  regfile_rhs = 16'h0100;
                        7:  regfile_rhs = 16'h7FFE;
                        8:  regfile_rhs = 16'h7FFF;
                        9:  regfile_rhs = 16'h8000;
                        10: regfile_rhs = 16'h8001;
                        11: regfile_rhs = 16'hFF00;
                        12: regfile_rhs = 16'hFF7F;
                        13: regfile_rhs = 16'hFFFE;
                        14: regfile_rhs = 16'hFFFF;
                        15: regfile_rhs = 16'hAAAA;

                        default:
                            regfile_rhs = {
                                operand_number[7:0],
                                ~operand_number[7:0]
                            };

                    endcase

                    /*
                        Test both possible carryin values for every
                        instruction.

                        Operations other than ADDC, ADDCI, ADDCU, and
                        ADDCUI should ignore carryin.
                    */

                    for (
                        carry_number = 0;
                        carry_number < 2;
                        carry_number = carry_number + 1
                    ) begin

                        carryin = carry_number[0];

                        /*
                            Determine the operand that the ALU's rhs mux
                            should produce.
                        */

                        if (R_type) begin
                            expected_rhs = regfile_rhs;
                        end
                        else if (sign_extend_immediate) begin
                            expected_rhs = {
                                {8{immediate_bits[7]}},
                                immediate_bits
                            };
                        end
                        else begin
                            expected_rhs = {
                                8'h00,
                                immediate_bits
                            };
                        end

                        /*
                            Default expected outputs.

                            Flag ordering from your ALU:

                                flags[4] = carry
                                flags[3] = unsigned less-than
                                flags[2] = signed less-than
                                flags[1] = signed overflow
                                flags[0] = equality/result-zero
                        */

                        expected_result = 16'h0000;
                        expected_extended_result = 17'h00000;

                        expected_carry_flag = 1'b0;

                        expected_unsigned_less_than_flag =
                            (lhs < expected_rhs);

                        expected_signed_less_than_flag =
                            ($signed(lhs) < $signed(expected_rhs));

                        expected_signed_overflow_flag = 1'b0;
                        expected_equality_flag = 1'b0;

                        /*
                            Reference implementation for each ALU operation.
                        */

                        case (operation_number)

                            /*
                                Addition without carryin.
                            */

                            ADD, ADDI, ADDU, ADDUI: begin
                                expected_extended_result =
                                    {1'b0, lhs} +
                                    {1'b0, expected_rhs};

                                expected_result =
                                    expected_extended_result[15:0];

                                expected_carry_flag =
                                    expected_extended_result[16];

                                expected_signed_overflow_flag =
                                    ~(lhs[15] ^ expected_rhs[15]) &
                                     (lhs[15] ^
                                      expected_result[15]);
                            end

                            /*
                                Addition with carryin.
                            */

                            ADDC, ADDCI, ADDCU, ADDCUI: begin
                                expected_extended_result =
                                    {1'b0, lhs} +
                                    {1'b0, expected_rhs} +
                                    carryin;

                                expected_result =
                                    expected_extended_result[15:0];

                                expected_carry_flag =
                                    expected_extended_result[16];

                                expected_signed_overflow_flag =
                                    ~(lhs[15] ^ expected_rhs[15]) &
                                     (lhs[15] ^
                                      expected_result[15]);
                            end

                            /*
                                Subtraction and comparison.
                            */

                            SUB, SUBI, CMP, CMPI, CMPU: begin
                                expected_extended_result =
                                    {1'b0, lhs} +
                                    {1'b0, ~expected_rhs} +
                                    1'b1;

                                expected_result =
                                    expected_extended_result[15:0];

                                expected_carry_flag =
                                    expected_extended_result[16];

                                expected_signed_overflow_flag =
                                    (lhs[15] ^ expected_rhs[15]) &
                                   ~(expected_result[15] ^
                                     expected_rhs[15]);
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

                            /*
                                The product is truncated to 16 bits.
                            */

                            MUL, MULI: begin
                                expected_result =
                                    lhs * expected_rhs;
                            end

                            /*
                                Signed shift amount:

                                    Positive = shift left
                                    Negative = logical shift right
                            */

                            LSH, LSHI: begin
                                if (expected_rhs[15] == 1'b0) begin
                                    expected_result =
                                        lhs << expected_rhs;
                                end
                                else begin
                                    expected_result =
                                        lhs >>
                                        ((~expected_rhs) + 1'b1);
                                end
                            end

                            /*
                                Signed shift amount:

                                    Positive = shift left
                                    Negative = arithmetic shift right
                            */

                            ASHU, ASHUI: begin
                                if (expected_rhs[15] == 1'b0) begin
                                    expected_result =
                                        lhs << expected_rhs;
                                end
                                else begin
                                    expected_result =
                                        $signed(lhs) >>>
                                        ((~expected_rhs) + 1'b1);
                                end
                            end

                            LUI: begin
                                expected_result = {
                                    expected_rhs[7:0],
                                    8'h00
                                };
                            end

                            SNXB: begin
                                expected_result = {
                                    {8{expected_rhs[7]}},
                                    expected_rhs[7:0]
                                };
                            end

                            ZRXB: begin
                                expected_result = {
                                    8'h00,
                                    expected_rhs[7:0]
                                };
                            end

                            /*
                                This matches your implementation:
                                    result = ~lhs
                            */

                            NOT_OP: begin
                                expected_result = ~lhs;
                            end

                            NO_OP: begin
                                expected_result = 16'h0000;
                            end

                            default: begin
                                expected_result = 16'h0000;
                            end

                        endcase

                        /*
                            Your equality flag indicates result == 0.
                        */

                        expected_equality_flag =
                            (expected_result == 16'h0000);

                        expected_flags = {
                            expected_carry_flag,
                            expected_unsigned_less_than_flag,
                            expected_signed_less_than_flag,
                            expected_signed_overflow_flag,
                            expected_equality_flag
                        };

                        /*
                            Allow combinational signals to settle.
                        */

                        #1;

                        number_of_tests = number_of_tests + 1;

                        /*
                            Case inequality detects incorrect values as well
                            as X and Z outputs.
                        */

                        if (
                            (result !== expected_result) ||
                            (flags !== expected_flags)
                        ) begin

                            number_of_errors =
                                number_of_errors + 1;

                            $display(
                                "ERROR test=%0d op=%0d",
                                number_of_tests,
                                operation_number
                            );

                            $display(
                                "  R_type=%b sign_extend=%b carryin=%b",
                                R_type,
                                sign_extend_immediate,
                                carryin
                            );

                            $display(
                                "  lhs=%h regfile_rhs=%h immediate=%h",
                                lhs,
                                regfile_rhs,
                                immediate_bits
                            );

                            $display(
                                "  effective rhs=%h",
                                expected_rhs
                            );

                            $display(
                                "  expected result=%h flags=%b",
                                expected_result,
                                expected_flags
                            );

                            $display(
                                "  actual   result=%h flags=%b",
                                result,
                                flags
                            );

                            /*
                                Stop after 100 errors so one mistake does not
                                produce thousands of console messages.
                            */

                            if (number_of_errors >= 100) begin
                                $display("");
                                $display(
                                    "STOPPED AFTER 100 ERRORS"
                                );
                                $finish;
                            end
                        end
                    end
                end
            end
        end

        $display("");
        $display("========================================");
        $display("ALU TESTBENCH COMPLETE");
        $display("Tests performed: %0d", number_of_tests);
        $display("Errors found:    %0d", number_of_errors);

        if (number_of_errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $display("========================================");

        $finish;
    end

endmodule