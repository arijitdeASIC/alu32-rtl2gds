//==============================================================================
// alu32.v  -  32-bit ALU with registered inputs and outputs
//
// Why registered I/O?
//   A purely combinational ALU has no clock, so CTS is meaningless and there
//   are no reg-to-reg timing paths to optimize. By registering the operands on
//   the way in and the result on the way out, every operation becomes a real
//   FF -> combinational-logic -> FF path. That is what gives you genuine
//   WNS / TNS / skew numbers downstream in PrimeTime.
//==============================================================================
module alu32 #(
    parameter WIDTH = 32
)(
    input                   clk,
    input                   rst_n,        // active-low async reset
    input      [WIDTH-1:0]  a_in,
    input      [WIDTH-1:0]  b_in,
    input      [3:0]        opcode_in,
    output reg [WIDTH-1:0]  result_out,
    output reg              zero_out,
    output reg              carry_out,
    output reg              overflow_out
);

    //--------------------------------------------------------------------------
    // Opcode encoding
    //--------------------------------------------------------------------------
    localparam OP_ADD = 4'b0000;
    localparam OP_SUB = 4'b0001;
    localparam OP_AND = 4'b0010;
    localparam OP_OR  = 4'b0011;
    localparam OP_XOR = 4'b0100;
    localparam OP_NOR = 4'b0101;
    localparam OP_SLT = 4'b0110;  // set-less-than (signed)
    localparam OP_SLL = 4'b0111;  // shift left logical
    localparam OP_SRL = 4'b1000;  // shift right logical
    localparam OP_SRA = 4'b1001;  // shift right arithmetic

    //--------------------------------------------------------------------------
    // Stage 1: input registers
    //--------------------------------------------------------------------------
    reg [WIDTH-1:0] a_q, b_q;
    reg [3:0]       op_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_q  <= {WIDTH{1'b0}};
            b_q  <= {WIDTH{1'b0}};
            op_q <= 4'b0000;
        end else begin
            a_q  <= a_in;
            b_q  <= b_in;
            op_q <= opcode_in;
        end
    end

    //--------------------------------------------------------------------------
    // Stage 2: combinational ALU core (the timing-critical logic)
    //--------------------------------------------------------------------------
    reg  [WIDTH:0]   sum_ext;     // 1 extra bit to capture carry-out
    reg  [WIDTH-1:0] alu_res;
    reg              carry_c, ovf_c;

    always @(*) begin
        // defaults
        sum_ext = {1'b0, a_q} + {1'b0, b_q};
        alu_res = {WIDTH{1'b0}};
        carry_c = 1'b0;
        ovf_c   = 1'b0;

        case (op_q)
            OP_ADD: begin
                sum_ext = {1'b0, a_q} + {1'b0, b_q};
                alu_res = sum_ext[WIDTH-1:0];
                carry_c = sum_ext[WIDTH];
                ovf_c   = (a_q[WIDTH-1] == b_q[WIDTH-1]) &&
                          (alu_res[WIDTH-1] != a_q[WIDTH-1]);
            end
            OP_SUB: begin
                sum_ext = {1'b0, a_q} - {1'b0, b_q};
                alu_res = sum_ext[WIDTH-1:0];
                carry_c = sum_ext[WIDTH];   // borrow
                ovf_c   = (a_q[WIDTH-1] != b_q[WIDTH-1]) &&
                          (alu_res[WIDTH-1] != a_q[WIDTH-1]);
            end
            OP_AND: alu_res = a_q & b_q;
            OP_OR : alu_res = a_q | b_q;
            OP_XOR: alu_res = a_q ^ b_q;
            OP_NOR: alu_res = ~(a_q | b_q);
            OP_SLT: alu_res = ($signed(a_q) < $signed(b_q)) ?
                              {{(WIDTH-1){1'b0}}, 1'b1} : {WIDTH{1'b0}};
            OP_SLL: alu_res = a_q << b_q[4:0];
            OP_SRL: alu_res = a_q >> b_q[4:0];
            OP_SRA: alu_res = $signed(a_q) >>> b_q[4:0];
            default: alu_res = {WIDTH{1'b0}};
        endcase
    end

    //--------------------------------------------------------------------------
    // Stage 3: output registers
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_out   <= {WIDTH{1'b0}};
            zero_out     <= 1'b0;
            carry_out    <= 1'b0;
            overflow_out <= 1'b0;
        end else begin
            result_out   <= alu_res;
            zero_out     <= (alu_res == {WIDTH{1'b0}});
            carry_out    <= carry_c;
            overflow_out <= ovf_c;
        end
    end

endmodule
