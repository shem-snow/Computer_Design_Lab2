`timescale 1ns/1ps

/*
 * Each test applies inputs, waits 10 ns, and checks the outputs with an if statement.
 */
module tb_ALU;

    localparam WIDTH = 16;

    localparam [3:0] ZEXT = 4'b0000;
    localparam [3:0] SEXT = 4'b0001;
    localparam [3:0] ADD  = 4'b0010;
    localparam [3:0] SUB  = 4'b0011;
    localparam [3:0] AND  = 4'b0100;
    localparam [3:0] OR   = 4'b0101;
    localparam [3:0] XOR  = 4'b0110;
    localparam [3:0] MULT = 4'b0111;
    localparam [3:0] LUI  = 4'b1000;
    localparam [3:0] LSH  = 4'b1001;
    localparam [3:0] ASH  = 4'b1010;
    localparam [3:0] PASS = 4'b1011;
    localparam [3:0] NOT  = 4'b1100;

    reg [3:0] alu_op;
    reg [WIDTH-1:0] lhs;
    reg [WIDTH-1:0] rhs;
    reg carryin;

    wire [WIDTH-1:0] result;
    wire [4:0] flags;

    integer test_number;
    integer error_count;

    ALU #(
        .WIDTH(WIDTH)
    ) dut (
        .alu_op(alu_op),
        .lhs(lhs),
        .rhs(rhs),
        .carryin(carryin),
        .result(result),
        .flags(flags)
    );

    initial begin
        test_number = 0;
        error_count = 0;
        alu_op = 4'b0000;
        lhs = 16'h0000;
        rhs = 16'h0000;
        carryin = 1'b0;
        #10;

        /* Test 1: zero-extend byte 0x80. */
        test_number = 1;
        alu_op = ZEXT;
        lhs = 16'hAAAA;
        rhs = 16'h1280;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h0080) || (flags !== 5'b00000)) begin
            $display("FAIL test 1 ZEXT: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 2: sign-extend negative byte 0x80. */
        test_number = 2;
        alu_op = SEXT;
        lhs = 16'hAAAA;
        rhs = 16'h1280;
        carryin = 1'b0;
        #10;
        if ((result !== 16'hFF80) || (flags !== 5'b00000)) begin
            $display("FAIL test 2 SEXT: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 3: ordinary addition without flags. */
        test_number = 3;
        alu_op = ADD;
        lhs = 16'h1234;
        rhs = 16'h4321;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h5555) || (flags !== 5'b00000)) begin
            $display("FAIL test 3 ADD: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 4: addition producing an unsigned carry. */
        test_number = 4;
        alu_op = ADD;
        lhs = 16'hFFFF;
        rhs = 16'h0001;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h0000) || (flags !== 5'b10000)) begin
            $display("FAIL test 4 ADD carry: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 5: positive signed-addition overflow. */
        test_number = 5;
        alu_op = ADD;
        lhs = 16'h7FFF;
        rhs = 16'h0001;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h8000) || (flags !== 5'b00010)) begin
            $display("FAIL test 5 ADD overflow: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 6: addition using carryin, as required by ADDC. */
        test_number = 6;
        alu_op = ADD;
        lhs = 16'hFFFF;
        rhs = 16'h0000;
        carryin = 1'b1;
        #10;
        if ((result !== 16'h0000) || (flags !== 5'b10000)) begin
            $display("FAIL test 6 ADDC: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 7: ordinary subtraction. */
        test_number = 7;
        alu_op = SUB;
        lhs = 16'h0005;
        rhs = 16'h0003;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h0002) || (flags !== 5'b00000)) begin
            $display("FAIL test 7 SUB: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 8: subtraction with unsigned and signed lhs < rhs. */
        test_number = 8;
        alu_op = SUB;
        lhs = 16'h0003;
        rhs = 16'h0005;
        carryin = 1'b0;
        #10;
        if ((result !== 16'hFFFE) || (flags !== 5'b11100)) begin
            $display("FAIL test 8 SUB borrow: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 9: equal operands for CMP behavior. */
        test_number = 9;
        alu_op = SUB;
        lhs = 16'hABCD;
        rhs = 16'hABCD;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h0000) || (flags !== 5'b00001)) begin
            $display("FAIL test 9 CMP equal: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 10: signed subtraction overflow: -32768 - 1. */
        test_number = 10;
        alu_op = SUB;
        lhs = 16'h8000;
        rhs = 16'h0001;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h7FFF) || (flags !== 5'b00110)) begin
            $display("FAIL test 10 SUB overflow: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 11: subtracting the carry/borrow input. */
        test_number = 11;
        alu_op = SUB;
        lhs = 16'h0000;
        rhs = 16'h0000;
        carryin = 1'b1;
        #10;
        if ((result !== 16'hFFFF) ||
            ((flags & 5'b10010) !== 5'b10000)) begin
            $display("FAIL test 11 SUBC: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 12: bitwise AND. */
        test_number = 12;
        alu_op = AND;
        lhs = 16'hA55A;
        rhs = 16'h0FF0;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h0550) || (flags !== 5'b00000)) begin
            $display("FAIL test 12 AND: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 13: bitwise OR. This operation also covers ISA NOP behavior. */
        test_number = 13;
        alu_op = OR;
        lhs = 16'hA500;
        rhs = 16'h005A;
        carryin = 1'b0;
        #10;
        if ((result !== 16'hA55A) || (flags !== 5'b00000)) begin
            $display("FAIL test 13 OR: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 14: bitwise XOR. */
        test_number = 14;
        alu_op = XOR;
        lhs = 16'hAAAA;
        rhs = 16'h0FF0;
        carryin = 1'b0;
        #10;
        if ((result !== 16'hA55A) || (flags !== 5'b00000)) begin
            $display("FAIL test 14 XOR: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 15: multiplication uses the complete 16-bit operands. */
        test_number = 15;
        alu_op = MULT;
        lhs = 16'h0100;
        rhs = 16'h0002;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h0200) || (flags !== 5'b00000)) begin
            $display("FAIL test 15 MULT: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 16: multiplication truncates the upper product bits. */
        test_number = 16;
        alu_op = MULT;
        lhs = 16'hFFFF;
        rhs = 16'h0002;
        carryin = 1'b0;
        #10;
        if ((result !== 16'hFFFE) || (flags !== 5'b00000)) begin
            $display("FAIL test 16 MULT truncation: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 17: load immediate into the upper byte. */
        test_number = 17;
        alu_op = LUI;
        lhs = 16'hAAAA;
        rhs = 16'h12CD;
        carryin = 1'b0;
        #10;
        if ((result !== 16'hCD00) || (flags !== 5'b00000)) begin
            $display("FAIL test 17 LUI: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 18: positive logical shift amount means shift left. */
        test_number = 18;
        alu_op = LSH;
        lhs = 16'h1234;
        rhs = 16'h0004;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h2340) || (flags !== 5'b00000)) begin
            $display("FAIL test 18 LSH left: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 19: -1 logical shift means shift right by one with zero fill. */
        test_number = 19;
        alu_op = LSH;
        lhs = 16'h8001;
        rhs = 16'hFFFF;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h4000) || (flags !== 5'b00000)) begin
            $display("FAIL test 19 LSH right: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 20: arithmetic right shift repeats the sign bit. */
        test_number = 20;
        alu_op = ASH;
        lhs = 16'h8001;
        rhs = 16'hFFFF;
        carryin = 1'b0;
        #10;
        if ((result !== 16'hC000) || (flags !== 5'b00000)) begin
            $display("FAIL test 20 ASH right: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 21: PASS returns rhs for MOV and MOVI. */
        test_number = 21;
        alu_op = PASS;
        lhs = 16'hAAAA;
        rhs = 16'h1234;
        carryin = 1'b0;
        #10;
        if ((result !== 16'h1234) || (flags !== 5'b00000)) begin
            $display("FAIL test 21 PASS: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        /* Test 22: custom NOT operates on lhs. */
        test_number = 22;
        alu_op = NOT;
        lhs = 16'h0F0F;
        rhs = 16'hAAAA;
        carryin = 1'b0;
        #10;
        if ((result !== 16'hF0F0) || (flags !== 5'b00000)) begin
            $display("FAIL test 22 NOT: result=%h flags=%b", result, flags);
            error_count = error_count + 1;
        end

        if (error_count == 0)
            $display("ALU_TEST_PASS: all %0d tests passed", test_number);
        else
            $display("ALU_TEST_FAIL: %0d of %0d tests failed",
                     error_count, test_number);

        // $finish;
    end

endmodule
