`timescale 1ns / 1ps


module mcu_stub(
    input clk,
    input logic flush,
    input logic reset,
    input logic resume,
    input logic in_valid,
    input logic rf_rd,
    input logic rf_wr,
    input logic mem_rd,
    input logic mem_wr,
    
    output reg [31:0] pc = 0,
    output wire [31:0] d_out,
    output logic mcu_busy
);

    typedef enum logic {
        IDLE,
        BUSY
    } MCU_STATE;
    
    MCU_STATE ps = IDLE, ns;
    reg [3:0] busy_cycles = 0;
    logic [3:0] busy_cycles_in = 0;
    reg paused = 0;
    logic pause_in;
    
    logic [31:0] pc_next;
    
    assign d_out = 'h28;
    
    always @(posedge clk) begin
        paused <= pause_in;
        if (!paused) pc <= pc_next;
        busy_cycles <= busy_cycles_in;
        ps <= ns;
    end
    
    always_comb begin
        busy_cycles_in = (busy_cycles > 0) ? busy_cycles - 1 : 0;
        pc_next = pc + 4;
        pause_in = paused;
        
        case(ps)
            IDLE: begin
                if (!in_valid) begin
                    mcu_busy = 0;
                    ns = IDLE;
                end
                
                else begin
                    if (flush) begin
                        busy_cycles_in = 5;
                        mcu_busy = 1;
                        pause_in = 1;
                        pc_next = pc;
                        ns = BUSY;
                    end
                    
                    if (reset) begin
                        pc_next = 0;
                        ns = IDLE;
                    end
                    
                    if (resume) begin
                        pause_in = 0;
                        pc_next = pc + 4;
                        ns = IDLE;
                    end
                    
                    if (rf_rd) begin
                        busy_cycles_in = 1;
                        mcu_busy = 1;
                        ns = BUSY;
                    end
                    
                    if (mem_rd) begin
                        busy_cycles_in = 12;
                        mcu_busy = 1;
                        ns = BUSY;
                    end
                    
                    if (rf_wr) begin
                    end
                    
                    if (mem_wr) begin
                    end
                end
                
            end
            BUSY: begin
                mcu_busy = 1;
                ns = (busy_cycles > 0) ? BUSY : IDLE;
            end
        endcase
    end

endmodule

module ctrlr_testbench();
    
    // inputs
    logic clk = 0;
    reg [31:0] pc = 0;
    logic [31:0] addr, d_in;
    DEBUG_FN debug_fn;
    logic in_valid, mcu_busy;
    logic [31:0] d_out;
    
    assign d_in = d_out;
    
    // outputs
    logic flush, reset, resume, out_valid, ctrlr_busy, rf_rd, rf_wr, mem_rd, mem_wr;
    logic [31:0] d_rd;
    
    controller CTRLR_UT(.*);
    mcu_stub MCU(.*);
    
    always begin
        # 10
        clk = ~clk;
    end
        
    initial begin
        in_valid = 0;
        debug_fn = RESUME;
        
        // issue pause
        # 40
        debug_fn = PAUSE;
        #12
        in_valid = 1;
        #25
        in_valid = 0;
        
        #200
        // issue resume
        debug_fn = RESUME;
        in_valid = 1;
        #20
        in_valid = 0;

    end

endmodule