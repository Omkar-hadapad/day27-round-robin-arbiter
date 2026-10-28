`timescale 1ns/1ps

// DAY 28: Round-Robin Arbiter with Priority, Aging, and Fault Handling
// File: day28_arbiter_all.v
//
// Urgency encoding:
//   2'b00 = LOW
//   2'b01 = MEDIUM
//   2'b10 = HIGH
//   2'b11 = CRITICAL
//
// Packing:
//   urgency[1:0] = R0
//   urgency[3:2] = R1
//   urgency[5:4] = R2
//   urgency[7:6] = R3
//
// Aging policy:
//   When a request's 2-bit wait counter saturates at 2'b11,
//   its effective urgency is promoted to CRITICAL.
//
// Safety note:
//   This RTL is not a physical emergency-stop circuit. Hardware requiring
//   immediate shutdown must use an independent, validated safety interlock.

// ============================================================
// 1. BASIC GATES
// ============================================================

module basic_gates(
    input  wire a,
    input  wire b,
    input  wire select,
    output wire and_y,
    output wire or_y,
    output wire not_a,
    output wire xor_y,
    output wire mux_y
);
    assign and_y = a & b;
    assign or_y  = a | b;
    assign not_a = ~a;
    assign xor_y = a ^ b;
    assign mux_y = select ? b : a;
endmodule


// ============================================================
// 2. REQUEST MASK
// ============================================================

module request_mask(
    input  wire [3:0] req,
    input  wire       enable,
    output wire [3:0] masked_req
);
    assign masked_req = req & {4{enable}};
endmodule


// ============================================================
// 3. PRIORITY COMPARATOR
// Finds all requesting inputs with maximum urgency.
// Round-robin selection later resolves ties.
// ============================================================

module priority_compare(
    input  wire [3:0] req,
    input  wire [7:0] urgency,
    output reg  [3:0] eligible
);
    reg [1:0] max_urgency;
    integer i;

    always @* begin
        max_urgency = 2'b00;
        eligible    = 4'b0000;

        // Find the highest urgency among active requests.
        for (i = 0; i < 4; i = i + 1) begin
            if (req[i] && (urgency[2*i +: 2] > max_urgency))
                max_urgency = urgency[2*i +: 2];
        end

        // Mark every request tied at the maximum urgency.
        for (i = 0; i < 4; i = i + 1) begin
            if (req[i] && (urgency[2*i +: 2] == max_urgency))
                eligible[i] = 1'b1;
        end
    end
endmodule


// ============================================================
// 4. WAIT COUNTER
// Each request has a 2-bit saturating wait counter.
// Counter advances on a valid arbitration opportunity.
// Counter clears when request is removed or selected.
// ============================================================

module wait_counter(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] req,
    input  wire       decision_valid,
    input  wire [3:0] winner,
    output reg  [7:0] wait_count
);
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wait_count <= 8'b0;
        end else begin
            for (i = 0; i < 4; i = i + 1) begin
                if (!req[i] || winner[i]) begin
                    wait_count[2*i +: 2] <= 2'b00;
                end else if (decision_valid &&
                             (wait_count[2*i +: 2] != 2'b11)) begin
                    wait_count[2*i +: 2] <=
                        wait_count[2*i +: 2] + 2'b01;
                end
            end
        end
    end
endmodule


// ============================================================
// 5. AGING LOGIC
// A request at the aging threshold is promoted to CRITICAL.
// The original urgency input is not modified.
// ============================================================

module aging_logic(
    input  wire [7:0] urgency,
    input  wire [7:0] wait_count,
    output reg  [7:0] effective_urgency
);
    integer i;

    always @* begin
        effective_urgency = urgency;

        for (i = 0; i < 4; i = i + 1) begin
            if ((wait_count[2*i +: 2] == 2'b11) &&
                (urgency[2*i +: 2] != 2'b11)) begin
                effective_urgency[2*i +: 2] = 2'b11;
            end
        end
    end
endmodule


// ============================================================
// 6. ROUND-ROBIN SELECTOR
// Selects exactly one eligible request, starting at pointer.
// Pointer encoding: 0 -> R0, 1 -> R1, 2 -> R2, 3 -> R3.
// ============================================================

module rr_selector(
    input  wire [3:0] eligible,
    input  wire [1:0] pointer,
    output reg  [3:0] selected_grant
);
    integer offset;
    integer idx;
    reg found;

    always @* begin
        selected_grant = 4'b0000;
        found           = 1'b0;
        idx             = 0;

        for (offset = 0; offset < 4; offset = offset + 1) begin
            idx = pointer + offset;

            if (idx >= 4)
                idx = idx - 4;

            if (!found && eligible[idx]) begin
                selected_grant[idx] = 1'b1;
                found                = 1'b1;
            end
        end
    end
endmodule


// ============================================================
// 7. OWNER CONTROLLER
//
// IDLE:
//   Accept a candidate if the resource is available and no fault exists.
//
// ACTIVE:
//   Hold current ownership until operation_done, or handle a fault.
//
// FAULT_HOLD:
//   Preserve the current grant/owner while a safe operation finishes.
//   No new owner is granted in this state.
// ============================================================

module owner_controller(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] selected_grant,
    input  wire       resource_available,
    input  wire       fault,
    input  wire       safe_to_finish,
    input  wire       operation_done,
    output reg  [3:0] grant,
    output reg  [1:0] owner,
    output reg        owner_valid
);
    localparam IDLE      = 2'b00;
    localparam ACTIVE    = 2'b01;
    localparam FAULT_HOLD = 2'b10;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            grant       <= 4'b0000;
            owner       <= 2'b00;
            owner_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    grant       <= 4'b0000;
                    owner_valid <= 1'b0;

                    if (resource_available &&
                        !fault &&
                        (selected_grant != 4'b0000)) begin
                        grant       <= selected_grant;
                        owner_valid <= 1'b1;

                        if      (selected_grant[0]) owner <= 2'd0;
                        else if (selected_grant[1]) owner <= 2'd1;
                        else if (selected_grant[2]) owner <= 2'd2;
                        else                        owner <= 2'd3;

                        state <= ACTIVE;
                    end
                end

                ACTIVE: begin
                    if (operation_done) begin
                        grant       <= 4'b0000;
                        owner_valid <= 1'b0;
                        state       <= IDLE;
                    end else if (fault && !safe_to_finish) begin
                        // RTL ownership is revoked on this clock edge.
                        // This is not a physical emergency-stop mechanism.
                        grant       <= 4'b0000;
                        owner_valid <= 1'b0;
                        state       <= IDLE;
                    end else if (fault && safe_to_finish) begin
                        // Retain the current owner until safe completion.
                        state <= FAULT_HOLD;
                    end
                end

                FAULT_HOLD: begin
                    // Hold grant and owner; do not accept a new requester.
                    if (operation_done) begin
                        grant       <= 4'b0000;
                        owner_valid <= 1'b0;
                        state       <= IDLE;
                    end
                end

                default: begin
                    state       <= IDLE;
                    grant       <= 4'b0000;
                    owner       <= 2'b00;
                    owner_valid <= 1'b0;
                end
            endcase
        end
    end
endmodule


// ============================================================
// 8. TOP-LEVEL ROUND-ROBIN ARBITER
// ============================================================

module round_robin_arbiter(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] req,
    input  wire [7:0] urgency,
    input  wire       resource_available,
    input  wire       fault,
    input  wire       safe_to_finish,
    input  wire       operation_done,
    output wire [3:0] grant,
    output wire [1:0] owner,
    output wire       owner_valid,
    output reg  [1:0] pointer,
    output wire [7:0] wait_count
);
    wire [3:0] masked_req;
    wire [3:0] eligible;
    wire [3:0] selected_grant;
    wire [7:0] effective_urgency;
    wire       decision_valid;

    // Do not make a new arbitration decision when the resource is
    // unavailable, a fault is active, or a current owner is valid.
    request_mask u_mask (
        .req        (req),
        .enable     (resource_available && !fault && !owner_valid),
        .masked_req (masked_req)
    );

    aging_logic u_aging (
        .urgency           (urgency),
        .wait_count        (wait_count),
        .effective_urgency (effective_urgency)
    );

    priority_compare u_priority (
        .req      (masked_req),
        .urgency  (effective_urgency),
        .eligible (eligible)
    );

    rr_selector u_selector (
        .eligible       (eligible),
        .pointer        (pointer),
        .selected_grant (selected_grant)
    );

    assign decision_valid =
        (selected_grant != 4'b0000) &&
        resource_available &&
        !fault &&
        !owner_valid;

    wait_counter u_wait_counter (
        .clk            (clk),
        .rst_n          (rst_n),
        .req            (req),
        .decision_valid (decision_valid),
        .winner          (selected_grant),
        .wait_count      (wait_count)
    );

    owner_controller u_owner (
        .clk               (clk),
        .rst_n             (rst_n),
        .selected_grant    (selected_grant),
        .resource_available(resource_available),
        .fault             (fault),
        .safe_to_finish    (safe_to_finish),
        .operation_done    (operation_done),
        .grant             (grant),
        .owner             (owner),
        .owner_valid       (owner_valid)
    );

    // Advance the pointer after a valid candidate decision.
    // This design reserves the next pointer when the candidate is chosen,
    // not when the operation completes.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pointer <= 2'd0;
        end else if (decision_valid) begin
            if      (selected_grant[0]) pointer <= 2'd1;
            else if (selected_grant[1]) pointer <= 2'd2;
            else if (selected_grant[2]) pointer <= 2'd3;
            else if (selected_grant[3]) pointer <= 2'd0;
        end
    end
endmodule
