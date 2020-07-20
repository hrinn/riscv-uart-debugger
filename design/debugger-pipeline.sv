//////////////////////////////////////////////////////////////////////////////////
// Company: Cal Poly, SLO
// Engineer: Trevor McKay
// 
// Module Name: Pipeline debugger and controller
// Project Name: Otter
// Description: Pipelined Otter debugger based on project by Keefe Johnson
// 
// 
// Revision: 0.10
// Revision 0.01 - File Created
// Revision 0.10 - Controller first rev.
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

/* TODO:
* general purpose serial module?
* serial decoder for debugger
* integration
* testing
* write documentation
*/

typedef enum logic [3:0] {
    NONE,
    PAUSE,
    RESUME,
    STEP,
    RESET,
    STATUS,
    BR_PT_ADD,
    BR_PT_RM,
    MEM_RD,
    MEM_WR,
    REG_RD,
    REG_WR
} DEBUG_FN;

module debugger(
    input clk,

    // user <-> debugger (via serial)
    input srx,
    output stx,

    // MCU -> debugger
    input [31:0] pc,
    input mcu_busy,
    input [31:0] d_rd,
    input error,

    // debugger -> MCU
    output [31:0] d_in,
    output [31:0] addr,
    output pause,
    output resume,
    output reset,
    output reg_rd,
    output reg_wr,
    output mem_rd,
    output mem_wr,
    output valid
);

    // instantiate serial module
    
    // instantiate controller

endmodule


module serial(
    input clk,
    input reset,

    // user <-> serial
        input srx,
        output stx,

    // controller -> sdec
        input ctrlr_busy,
        input [31:0] d_rd,
    // sdec -> controller
        output DEBUG_FN debug_fn,
        output [31:0] addr,
        output [31:0] d_in,
        output out_valid
);

    // decode and send serial data

endmodule


/* CURRENTLY SUPPORTS:
    * pause
    * resume
    * step
    * add break point
    * pause on break point
*/

/* NOT YET IMPLEMENTED:
    * remove breakpoint
    * status
    * read memory
    * write memory
    * read register
    * write register
*/

module controller(
    // INPUTS
        input clk,

        // sdec -> controller
            input DEBUG_FN debug_fn,
            input logic [31:0] addr,
            input logic in_valid,
            
        // MCU -> controller
            input logic [31:0] pc,
            input logic mcu_busy,
    
    // OUTPUTS
        // controller -> MCU
            output logic pause,
            output logic reset,
            output logic resume,
            output logic out_valid,
            output logic rf_rd,
            output logic mem_rd,
            output logic rf_wr,
            output logic mem_wr,

        // controller -> sdec
            output logic ctrlr_busy
    );
    
    // keep track of mcu state
    reg mcu_paused = 0;
    logic mcu_paused_in;

    // breakpoints
    logic [31:0] break_pts[8];
    initial
        for (int i = 0; i < 8; i++)
            break_pts[i] = 'Z;
    reg [2:0] num_break_pts = 0;
    logic bp_add, hit;

    // states for controller
    typedef enum logic [3:0] {
        IDLE,
        WAIT_PAUSE,
        WAIT_RESUME,
        WAIT_MEM_RD,
        WAIT_MEM_WR,
        WAIT_REG_RD,
        WAIT_REG_WR,
        WAIT_STEP,
        BREAK_HIT,
        REPLY
    } STATE;
    
    STATE ps = IDLE, ns; 
    
    always_ff @(posedge clk) begin
        // update paused state
        mcu_paused <= mcu_paused_in; 

        // compare pc to all breakpoints
        hit = 0;
        if (!mcu_paused) begin
            for (int i = 0; i < 8; i++) begin
                if ((pc + 4) == break_pts[i]) begin
                    ps <= BREAK_HIT;
                    hit = 1;
                end
            end
        end
        if (!hit) ps <= ns;
        
        // load in new breakpoints
        if (bp_add) begin
            break_pts[num_break_pts] <= addr;
            num_break_pts <= num_break_pts + 1;
        end
    end
    
    always_comb begin
        pause = 0;
        reset = 0;
        resume = 0;
        bp_add= 0;
        rf_rd = 0;
        rf_wr = 0;
        mem_rd = 0;
        mem_wr = 0;
        ns  = IDLE;

        /* controller will output no commands and
        * accept no input in its default state */
        
        // output is invalid unless specified
        out_valid = 0;
        // busy unless specified
        ctrlr_busy = 1;

        // keep these values by default
        mcu_paused_in = mcu_paused;

        case(ps)

            IDLE: begin
                // check for valid from sdec high
                if (in_valid) begin
                    case(debug_fn)
                        PAUSE: begin
                            pause = 1;
                            out_valid = 1;
                            ns = WAIT_PAUSE;
                        end
                        RESUME: begin
                            resume = 1;
                            out_valid = 1;
                            ns = WAIT_RESUME;
                        end
                        STEP: begin
                            // step only supported if MCU is paused
                            if (mcu_paused) begin
                                resume = 1;
                                out_valid = 1;
                                ns = WAIT_STEP;
                               end
                            else begin
                                ctrlr_busy = 0;
                                ns = IDLE;
                            end
                        end
                        BR_PT_ADD: begin
                            ctrlr_busy = 0;
                            bp_add = 1;
                            ns = IDLE;
                        end
                        MEM_RD: begin
                            mem_rd = 1;
                            ns = WAIT_MEM_RD;
                        end
                        MEM_WR: begin
                            mem_wr = 1;
                            ns = WAIT_MEM_WR;
                        end
                    endcase
                end            
                // no command given, stay idle
                else begin
                    ctrlr_busy = 0;
                    ns = IDLE;
                end
            end
            
            WAIT_PAUSE: begin
                if (mcu_busy) begin
                    out_valid = 1;
                    pause = 1;
                    ns = WAIT_PAUSE;
                end
                else begin
                    mcu_paused_in = 1;
                    ctrlr_busy = 0;
                    ns = IDLE;
                end
            end

            WAIT_RESUME: begin
                if (mcu_busy) begin
                    resume = 1;
                    out_valid = 1;
                    ns = WAIT_RESUME;
                end
                else begin
                    mcu_paused_in = 0;
                    ctrlr_busy = 0;
                    ns = IDLE;
                end
            end

            WAIT_STEP: begin
                out_valid = 1;
                // wait for resume
                if (mcu_busy) begin
                    resume = 1;
                    ns = WAIT_STEP;
                end
                // pause on next cycle
                else begin
                    pause = 1;
                    ns = WAIT_PAUSE;
                end
            end

            WAIT_MEM_RD: begin
                if (mcu_busy) begin
                    out_valid = 1;
                    mem_rd = 1;
                    ns = WAIT_MEM_RD;
                end
                else begin
                    ctrlr_busy = 0;
                    ns = IDLE;
                end
            end

            WAIT_MEM_WR: begin
                if (mcu_busy) begin
                    out_valid = 1;
                    mem_wr = 1;
                    ns = WAIT_MEM_RD;
                end
                else begin
                    ctrlr_busy = 0;
                    ns = IDLE;
                end
            end

            WAIT_REG_RD: begin
                if (mcu_busy) begin
                    out_valid = 1;
                    rf_rd = 1;
                    ns = WAIT_REG_RD;
                end
                else begin
                    ctrlr_busy = 0;
                    ns = IDLE;
                end
            end

            WAIT_REG_WR: begin
                if (mcu_busy) begin
                    out_valid = 1;
                    rf_wr = 1;
                    ns = WAIT_REG_WR;
                end
                else begin
                    ctrlr_busy = 0;
                    ns = IDLE;
                end
            end

            BREAK_HIT: begin
                pause = 1;
                out_valid = 1;
                ns = WAIT_PAUSE;
            end

            REPLY: begin
            end
            
            default: ns = IDLE;
        endcase
    end

endmodule
