//==============================================================================
// alu32_tb.v  -  self-checking testbench for alu32
//   Works with Icarus Verilog (free) or VCS.
//   Dumps alu32_tb.vcd for GTKWave.
//==============================================================================
`timescale 1ns/1ps

module alu32_tb;

    localparam WIDTH = 32;

    reg                   clk, rst_n;
    reg  [WIDTH-1:0]      a_in, b_in;
    reg  [3:0]            opcode_in;
    wire [WIDTH-1:0]      result_out;
    wire                  zero_out, carry_out, overflow_out;

    integer errors = 0;

    // DUT
    alu32 #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .a_in(a_in), .b_in(b_in), .opcode_in(opcode_in),
        .result_out(result_out), .zero_out(zero_out),
        .carry_out(carry_out), .overflow_out(overflow_out)
    );

    // 500 MHz clock (2 ns period) - match your SDC
    initial clk = 1'b0;
    always #1 clk = ~clk;

    // Apply one operation and check after 2 clocks (input reg + output reg)
    task apply_check;
        input [WIDTH-1:0] a, b;
        input [3:0]       op;
        input [WIDTH-1:0] exp;
        begin
            @(negedge clk); a_in = a; b_in = b; opcode_in = op;
            @(negedge clk);                       // data latched into stage-1
            @(negedge clk);                       // result latched into stage-3
            if (result_out !== exp) begin
                $display("FAIL op=%b a=%h b=%h -> got %h exp %h",
                         op, a, b, result_out, exp);
                errors = errors + 1;
            end else begin
                $display("PASS op=%b a=%h b=%h -> %h", op, a, b, result_out);
            end
        end
    endtask

    initial begin
        $dumpfile("alu32_tb.vcd");
        $dumpvars(0, alu32_tb);

        // reset
        rst_n = 1'b0; a_in = 0; b_in = 0; opcode_in = 0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        apply_check(32'h0000_000A, 32'h0000_0005, 4'b0000, 32'h0000_000F); // ADD
        apply_check(32'h0000_000A, 32'h0000_0005, 4'b0001, 32'h0000_0005); // SUB
        apply_check(32'hF0F0_F0F0, 32'h0F0F_0F0F, 4'b0010, 32'h0000_0000); // AND
        apply_check(32'hF0F0_F0F0, 32'h0F0F_0F0F, 4'b0011, 32'hFFFF_FFFF); // OR
        apply_check(32'hAAAA_AAAA, 32'h5555_5555, 4'b0100, 32'hFFFF_FFFF); // XOR
        apply_check(32'hFFFF_FFFF, 32'h0000_0000, 4'b0101, 32'h0000_0000); // NOR
        apply_check(32'hFFFF_FFFE, 32'h0000_0001, 4'b0110, 32'h0000_0001); // SLT (-2 < 1)
        apply_check(32'h0000_0001, 32'h0000_0004, 4'b0111, 32'h0000_0010); // SLL by 4
        apply_check(32'h0000_0010, 32'h0000_0004, 4'b1000, 32'h0000_0001); // SRL by 4
        apply_check(32'hFFFF_FF00, 32'h0000_0004, 4'b1001, 32'hFFFF_FFF0); // SRA by 4

        repeat (2) @(negedge clk);
        if (errors == 0) $display("\n==== ALL TESTS PASSED ====\n");
        else             $display("\n==== %0d FAILURES ====\n", errors);
        $finish;
    end

endmodule
