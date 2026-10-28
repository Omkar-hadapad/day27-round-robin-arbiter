`timescale 1ns/1ps

// DAY 28 exhaustive/directed verification testbench
// Compile with day28_arbiter_all.v and select top tb_day28_all.
// Verilog-2001 compatible. EXPECTED and ACTUAL are printed as readable labels
// for mapped cases; other values are printed as hexadecimal text.

module tb_day28_all;
    parameter PRINT_EACH_CASE = 1'b1;

    reg clk, rst_n;
    integer errors;
    integer i, j, k;
    reg [8*48-1:0] scenario;

    // Basic gates
    reg ga, gb, gs;
    wire gand_y, gor_y, gnot_a, gxor_y, gmux_y;

    // Request mask
    reg [3:0] mask_req;
    reg mask_enable;
    wire [3:0] masked_req;

    // Priority comparator
    reg [3:0] pc_req;
    reg [7:0] pc_urgency;
    wire [3:0] eligible;

    // Aging logic
    reg [7:0] age_urgency, age_wait;
    wire [7:0] effective_urgency;

    // RR selector
    reg [3:0] rr_eligible;
    reg [1:0] rr_pointer;
    wire [3:0] selected_grant;

    // Wait counter
    reg [3:0] wc_req, wc_winner;
    reg wc_decision_valid;
    wire [7:0] wait_count;

    // Owner controller
    reg [3:0] oc_selected_grant;
    reg oc_resource_available, oc_fault, oc_safe_to_finish, oc_operation_done;
    wire [3:0] oc_grant;
    wire [1:0] oc_owner;
    wire oc_owner_valid;

    // Top-level arbiter
    reg [3:0] top_req;
    reg [7:0] top_urgency;
    reg top_resource_available, top_fault, top_safe_to_finish, top_operation_done;
    wire [3:0] top_grant;
    wire [1:0] top_owner, top_pointer;
    wire top_owner_valid;
    wire [7:0] top_wait_count;

    integer found;
    integer idx;
    reg [3:0] expected4;
    reg [1:0] max_urgency;
    reg [7:0] expected8;

    basic_gates u_gates (
        .a(ga), .b(gb), .select(gs),
        .and_y(gand_y), .or_y(gor_y), .not_a(gnot_a),
        .xor_y(gxor_y), .mux_y(gmux_y)
    );

    request_mask u_mask (
        .req(mask_req), .enable(mask_enable), .masked_req(masked_req)
    );

    priority_compare u_priority (
        .req(pc_req), .urgency(pc_urgency), .eligible(eligible)
    );

    aging_logic u_aging (
        .urgency(age_urgency), .wait_count(age_wait),
        .effective_urgency(effective_urgency)
    );

    rr_selector u_rr (
        .eligible(rr_eligible), .pointer(rr_pointer),
        .selected_grant(selected_grant)
    );

    wait_counter u_wait_counter (
        .clk(clk), .rst_n(rst_n), .req(wc_req),
        .decision_valid(wc_decision_valid), .winner(wc_winner),
        .wait_count(wait_count)
    );

    owner_controller u_owner (
        .clk(clk), .rst_n(rst_n), .selected_grant(oc_selected_grant),
        .resource_available(oc_resource_available), .fault(oc_fault),
        .safe_to_finish(oc_safe_to_finish), .operation_done(oc_operation_done),
        .grant(oc_grant), .owner(oc_owner), .owner_valid(oc_owner_valid)
    );

    round_robin_arbiter u_top (
        .clk(clk), .rst_n(rst_n), .req(top_req), .urgency(top_urgency),
        .resource_available(top_resource_available), .fault(top_fault),
        .safe_to_finish(top_safe_to_finish), .operation_done(top_operation_done),
        .grant(top_grant), .owner(top_owner), .owner_valid(top_owner_valid),
        .pointer(top_pointer), .wait_count(top_wait_count)
    );

    always #5 clk = ~clk;

    task step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task fail_case;
        input [8*80-1:0] test_name;
        begin
            errors = errors + 1;
            $display("FAIL | scenario=%0s | test=%0s | time=%0t", scenario, test_name, $time);
        end
    endtask

    // Convert common expected/actual values to meaningful text.
    // Unmapped values remain visible in hexadecimal, so information is not lost.
    task format_value;
        input  [8*32-1:0] test_name;
        input  [63:0] value;
        output [8*32-1:0] value_text;
        begin
            value_text = "UNMAPPED_VALUE";
            case (test_name)
                "rr_selector",
                "owner acquire R2",
                "owner safe fault",
                "owner fault hold",
                "owner acquire R0",
                "top grant R0",
                "top RR grant R2": begin
                    case (value)
                        64'd0: value_text = "NO_GRANT";
                        64'd1: value_text = "GRANT_R0";
                        64'd2: value_text = "GRANT_R1";
                        64'd4: value_text = "GRANT_R2";
                        64'd8: value_text = "GRANT_R3";
                        default: $sformat(value_text, "GRANT_VALUE=0x%h", value);
                    endcase
                end

                "owner completion",
                "owner unsafe fault",
                "owner no resource",
                "owner idle fault",
                "top no resource",
                "top fault block",
                "top no requests": begin
                    if (value == 64'd0)
                        value_text = "NO_GRANT";
                    else
                        $sformat(value_text, "VALUE=0x%h", value);
                end

                "wait_counter saturation",
                "wait_counter no-wrap",
                "wait_counter hold": begin
                    if (value == 64'd3)
                        value_text = "COUNTER_SATURATED";
                    else
                        $sformat(value_text, "COUNTER_VALUE=%h", value);
                end

                "wait_counter withdrawal": begin
                    if (value == 64'd0)
                        value_text = "COUNTER_CLEARED";
                    else
                        $sformat(value_text, "COUNTER_VALUE=%h", value);
                end

                "wait_counter R3 win": begin
                    if (value == 64'd0)
                        value_text = "WINNER_COUNTER_CLEARED";
                    else
                        $sformat(value_text, "COUNTER_VALUE=%h", value);
                end

                default: $sformat(value_text, "HEX_VALUE=0x%016h", value);
            endcase
        end
    endtask

    // Uniform result report. Existing print_result calls remain unchanged.
    task print_result;
        input [8*32-1:0] test_name;
        input [63:0] inputs_value;
        input [63:0] expected_value;
        input [63:0] actual_value;
        input case_pass;
        reg [8*32-1:0] expected_string;
        reg [8*32-1:0] actual_string;
        reg [8*8-1:0] status_string;
        begin
            format_value(test_name, expected_value, expected_string);
            format_value(test_name, actual_value, actual_string);
            if (case_pass)
                status_string = "PASS";
            else
                status_string = "FAIL";

            if (PRINT_EACH_CASE) begin
                $display("--------------------------------------------------------------------------");
                $display("TIME     : %0t", $time);
                $display("SCENARIO : %0s", scenario);
                $display("TEST     : %0s", test_name);
                $display("INPUTS   : 0x%016h", inputs_value);
                $display("EXPECTED : %0s", expected_string);
                $display("ACTUAL   : %0s", actual_string);
                $display("STATUS   : %0s", status_string);
            end
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        errors = 0;
        scenario = "INITIALIZATION";

        found = 0;
        idx = 0;
        expected4 = 4'b0000;
        expected8 = 8'b00000000;
        max_urgency = 2'b00;

        ga = 0; gb = 0; gs = 0;
        mask_req = 0; mask_enable = 0;
        pc_req = 0; pc_urgency = 0;
        age_urgency = 0; age_wait = 0;
        rr_eligible = 0; rr_pointer = 0;
        wc_req = 0; wc_winner = 0; wc_decision_valid = 0;
        oc_selected_grant = 0; oc_resource_available = 0;
        oc_fault = 0; oc_safe_to_finish = 0; oc_operation_done = 0;
        top_req = 0; top_urgency = 0; top_resource_available = 0;
        top_fault = 0; top_safe_to_finish = 0; top_operation_done = 0;

        $display("==========================================================================");
        $display("DAY 28 ROUND-ROBIN ARBITER | EXHAUSTIVE + DIRECTED VERIFICATION");
        $display("EXPECTED and ACTUAL are semantic strings where mappings are defined.");
        $display("Otherwise, values are preserved as hexadecimal text.");
        $display("TIME | SCENARIO | TEST | INPUTS | EXPECTED | ACTUAL | STATUS");
        $display("==========================================================================");

        // Establish reset for all sequential DUTs.
        step;
        if (wait_count !== 8'h00 || oc_grant !== 4'h0 || oc_owner_valid !== 1'b0 ||
            top_grant !== 4'h0 || top_owner_valid !== 1'b0 || top_pointer !== 2'd0)
            fail_case("asynchronous/sampled reset values");
        rst_n = 1;
        step;

        // 1. BASIC GATES: all 8 input combinations
        scenario = "BASIC_GATES";
        for (i = 0; i < 8; i = i + 1) begin
            {ga, gb, gs} = i[2:0];
            #1;
            print_result("basic_gates", {61'b0, ga, gb, gs},
                         {59'b0, (ga & gb), (ga | gb), (~ga), (ga ^ gb), (gs ? gb : ga)},
                         {59'b0, gand_y, gor_y, gnot_a, gxor_y, gmux_y},
                         ({gand_y, gor_y, gnot_a, gxor_y, gmux_y} ===
                          {(ga & gb), (ga | gb), (~ga), (ga ^ gb), (gs ? gb : ga)}));
            if ({gand_y, gor_y, gnot_a, gxor_y, gmux_y} !==
                {(ga & gb), (ga | gb), (~ga), (ga ^ gb), (gs ? gb : ga)})
                fail_case("basic_gates exhaustive input");
        end
        $display("GROUP COMPLETE | basic_gates | 8 input combinations checked");

        // 2. REQUEST MASK: all 16 requests x both enable values
        scenario = "REQUEST_MASK";
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                mask_req = i[3:0];
                mask_enable = j[0];
                #1;
                expected4 = j ? i[3:0] : 4'b0000;
                print_result("request_mask", {59'b0, mask_req, mask_enable},
                             {60'b0, expected4}, {60'b0, masked_req},
                             masked_req === expected4);
                if (masked_req !== expected4)
                    fail_case("request_mask exhaustive combination");
            end
        end
        $display("GROUP COMPLETE | request_mask | 32 combinations checked");

        // 3. PRIORITY COMPARATOR: all request masks x urgency vectors
        // Urgency is packed [1:0]=R0, [3:2]=R1, [5:4]=R2, [7:6]=R3.
        scenario = "PRIORITY_COMPARE";
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                pc_req = i[3:0];
                pc_urgency = j[7:0];
                #1;
                max_urgency = 2'b00;
                expected4 = 4'b0000;
                for (k = 0; k < 4; k = k + 1) begin
                    if (pc_req[k] && pc_urgency[2*k +: 2] > max_urgency)
                        max_urgency = pc_urgency[2*k +: 2];
                end
                for (k = 0; k < 4; k = k + 1) begin
                    if (pc_req[k] && pc_urgency[2*k +: 2] == max_urgency)
                        expected4[k] = 1'b1;
                end
                print_result("priority_compare", {52'b0, pc_req, pc_urgency},
                             {60'b0, expected4}, {60'b0, eligible},
                             eligible === expected4);
                if (eligible !== expected4)
                    fail_case("priority_compare exhaustive combination");
            end
        end
        $display("GROUP COMPLETE | priority_compare | 4096 request/urgency combinations checked");

        // 4. AGING LOGIC: all urgency vectors x wait vectors
        // Saturated wait (3) promotes any non-CRITICAL urgency to CRITICAL.
        scenario = "AGING_LOGIC";
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                age_urgency = i[7:0];
                age_wait = j[7:0];
                #1;
                expected8 = age_urgency;
                for (k = 0; k < 4; k = k + 1) begin
                    if ((age_wait[2*k +: 2] == 2'b11) &&
                        (age_urgency[2*k +: 2] != 2'b11))
                        expected8[2*k +: 2] = 2'b11;
                end
                print_result("aging_logic", {48'b0, age_urgency, age_wait},
                             {56'b0, expected8}, {56'b0, effective_urgency},
                             effective_urgency === expected8);
                if (effective_urgency !== expected8)
                    fail_case("aging_logic exhaustive combination");
            end
        end
        $display("GROUP COMPLETE | aging_logic | 65536 urgency/wait combinations checked");

        // 5. ROUND-ROBIN SELECTOR: all eligible masks x pointers
        scenario = "RR_SELECTOR";
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                rr_eligible = i[3:0];
                rr_pointer = j[1:0];
                #1;
                expected4 = 4'b0000;
                found = 0;
                for (k = 0; k < 4; k = k + 1) begin
                    idx = j + k;
                    if (idx >= 4) idx = idx - 4;
                    if (!found && i[idx]) begin
                        expected4[idx] = 1'b1;
                        found = 1;
                    end
                end
                print_result("rr_selector", {58'b0, rr_eligible, rr_pointer},
                             {60'b0, expected4}, {60'b0, selected_grant},
                             selected_grant === expected4);
                if (selected_grant !== expected4)
                    fail_case("rr_selector exhaustive eligible/pointer combination");
                if ((selected_grant != 0) && ((selected_grant & (selected_grant - 1'b1)) != 0))
                    fail_case("rr_selector one-hot invariant");
            end
        end
        $display("GROUP COMPLETE | rr_selector | 64 eligible/pointer combinations checked");

        // 6. WAIT COUNTER: reset, increments, saturates, clears, holds
        scenario = "WAIT_COUNTER";
        wc_req = 4'b0011;
        wc_winner = 4'b0001;
        wc_decision_valid = 1'b1;
        step;
        print_result("wait_counter increment", {52'b0, wc_req, wc_winner, wc_decision_valid},
                     {56'b0, 2'b01, 2'b00, 4'b0000}, {56'b0, wait_count},
                     (wait_count[1:0] === 2'd0 && wait_count[3:2] === 2'd1));
        if (wait_count[1:0] !== 2'd0 || wait_count[3:2] !== 2'd1)
            fail_case("wait_counter winner clear and loser increment");

        step;
        step;
        step;
        print_result("wait_counter saturation", {56'b0, wc_req}, {56'b0, 2'b11},
                     {56'b0, wait_count[3:2]}, wait_count[3:2] === 2'd3);
        if (wait_count[3:2] !== 2'd3)
            fail_case("wait_counter saturation at three");

        step;
        print_result("wait_counter no-wrap", {56'b0, wc_req}, {56'b0, 2'b11},
                     {56'b0, wait_count[3:2]}, wait_count[3:2] === 2'd3);
        if (wait_count[3:2] !== 2'd3)
            fail_case("wait_counter saturation hold/no wrap");

        wc_decision_valid = 1'b0;
        step;
        print_result("wait_counter hold", {56'b0, wc_req}, {56'b0, 2'b11},
                     {56'b0, wait_count[3:2]}, wait_count[3:2] === 2'd3);
        if (wait_count[3:2] !== 2'd3)
            fail_case("wait_counter holds when decision_valid is low");

        wc_req[1] = 1'b0;
        step;
        print_result("wait_counter withdrawal", {56'b0, wc_req}, {56'b0, 2'b00},
                     {56'b0, wait_count[3:2]}, wait_count[3:2] === 2'd0);
        if (wait_count[3:2] !== 2'd0)
            fail_case("wait_counter clears on request withdrawal");

        wc_req = 4'b1111;
        wc_winner = 4'b0010;
        wc_decision_valid = 1'b1;
        step;
        print_result("wait_counter lanes", {56'b0, wc_req},
                     {56'h0, 2'b01, 2'b01, 2'b00, 2'b01}, {56'b0, wait_count},
                     (wait_count[1:0] === 2'd1 && wait_count[3:2] === 2'd0 &&
                      wait_count[5:4] === 2'd1 && wait_count[7:6] === 2'd1));
        if (wait_count[1:0] !== 2'd1 || wait_count[3:2] !== 2'd0 ||
            wait_count[5:4] !== 2'd1 || wait_count[7:6] !== 2'd1)
            fail_case("wait_counter independent requester increments");
        wc_winner = 4'b1000;
        step;
        print_result("wait_counter R3 win", {56'b0, wc_req, wc_winner},
                     {62'b0, 2'b00}, {56'b0, wait_count[7:6]}, wait_count[7:6] === 2'd0);
        if (wait_count[7:6] !== 2'd0)
            fail_case("wait_counter R3 winner clear");
        $display("GROUP COMPLETE | wait_counter | reset, increment, independent lanes, saturation, hold and clear checked");

        // 7. OWNER CONTROLLER: acquire, done, unsafe fault, safe fault hold
        scenario = "OWNER_CTRL";
        rst_n = 0;
        step;
        rst_n = 1;
        oc_resource_available = 1;
        oc_fault = 0;
        oc_safe_to_finish = 1;
        oc_operation_done = 0;
        oc_selected_grant = 4'b0100;
        step;
        print_result("owner acquire R2", {56'b0, oc_selected_grant}, {60'b0, 4'b0100},
                     {60'b0, oc_grant}, (oc_grant === 4'b0100 && oc_owner === 2'd2 && oc_owner_valid === 1'b1));
        if (oc_grant !== 4'b0100 || oc_owner !== 2'd2 || oc_owner_valid !== 1'b1)
            fail_case("owner_controller acquires R2");

        oc_fault = 1;
        oc_safe_to_finish = 1;
        step;
        print_result("owner safe fault", {60'b0, oc_fault, oc_safe_to_finish, oc_operation_done},
                     {60'b0, 4'b0100}, {60'b0, oc_grant},
                     (oc_grant === 4'b0100 && oc_owner_valid === 1'b1));
        if (oc_grant !== 4'b0100 || oc_owner_valid !== 1'b1)
            fail_case("owner_controller safe fault retains owner");

        oc_fault = 0;
        step;
        print_result("owner fault hold", {60'b0, oc_fault, oc_operation_done},
                     {60'b0, 4'b0100}, {60'b0, oc_grant},
                     (oc_grant === 4'b0100 && oc_owner_valid === 1'b1));
        if (oc_grant !== 4'b0100 || oc_owner_valid !== 1'b1)
            fail_case("owner_controller remains in FAULT_HOLD until operation_done");
        oc_operation_done = 1;
        step;
        print_result("owner completion", {60'b0, oc_operation_done}, {60'b0, 4'b0000},
                     {60'b0, oc_grant}, (oc_grant === 4'b0000 && oc_owner_valid === 1'b0));
        if (oc_grant !== 4'b0000 || oc_owner_valid !== 1'b0)
            fail_case("owner_controller completion exits FAULT_HOLD");

        oc_operation_done = 0;
        oc_fault = 0;
        oc_safe_to_finish = 0;
        oc_selected_grant = 4'b0001;
        step;
        print_result("owner acquire R0", {60'b0, oc_selected_grant}, {60'b0, 4'b0001},
                     {60'b0, oc_grant}, (oc_grant === 4'b0001 && oc_owner_valid === 1'b1));
        if (oc_grant !== 4'b0001 || !oc_owner_valid)
            fail_case("owner_controller reacquires R0");
        oc_fault = 1;
        oc_safe_to_finish = 0;
        step;
        print_result("owner unsafe fault", {60'b0, oc_fault, oc_safe_to_finish},
                     {60'b0, 4'b0000}, {60'b0, oc_grant},
                     (oc_grant === 4'b0000 && oc_owner_valid === 1'b0));
        if (oc_grant !== 4'b0000 || oc_owner_valid !== 1'b0)
            fail_case("owner_controller unsafe fault clears ownership");

        oc_fault = 0;
        oc_resource_available = 0;
        oc_selected_grant = 4'b1000;
        step;
        print_result("owner no resource", {60'b0, oc_resource_available, oc_fault},
                     {60'b0, 4'b0000}, {60'b0, oc_grant},
                     (!oc_owner_valid && oc_grant === 4'b0000));
        if (oc_owner_valid || oc_grant != 0)
            fail_case("owner_controller blocks grant when resource unavailable");
        oc_resource_available = 1;
        oc_fault = 1;
        step;
        print_result("owner idle fault", {60'b0, oc_resource_available, oc_fault},
                     {60'b0, 4'b0000}, {60'b0, oc_grant},
                     (!oc_owner_valid && oc_grant === 4'b0000));
        if (oc_owner_valid || oc_grant != 0)
            fail_case("owner_controller blocks grant during idle fault");
        oc_fault = 0;
        oc_selected_grant = 0;
        $display("GROUP COMPLETE | owner_controller | acquire, completion, safe/unsafe fault and IDLE blocking checked");

        // 8. TOP-LEVEL INTEGRATION
        scenario = "TOP_INTEGRATION";
        rst_n = 0;
        top_req = 0;
        top_urgency = 8'b10_10_01_10; // R0=HIGH,R1=MEDIUM,R2=HIGH,R3=HIGH
        top_resource_available = 1;
        top_fault = 0;
        top_safe_to_finish = 1;
        top_operation_done = 0;
        step;
        rst_n = 1;
        top_req = 4'b1111;
        step;
        print_result("top grant R0", {52'b0, top_req, top_urgency}, {60'b0, 4'b0001},
                     {60'b0, top_grant},
                     (top_grant === 4'b0001 && top_owner === 2'd0 && top_owner_valid === 1'b1));
        if (top_grant !== 4'b0001 || top_owner !== 2'd0 || !top_owner_valid)
            fail_case("top arbiter first grant R0 at pointer zero");
        if ((top_grant != 0) && ((top_grant & (top_grant - 1'b1)) != 0))
            fail_case("top arbiter one-hot grant on first transaction");

        // Finish R0; next equal-high request encountered from pointer 1 is R2.
        top_operation_done = 1;
        step;
        top_operation_done = 0;
        step;
        print_result("top RR grant R2", {52'b0, top_req, top_pointer}, {60'b0, 4'b0100},
                     {60'b0, top_grant},
                     (top_grant === 4'b0100 && top_owner === 2'd2 && top_owner_valid === 1'b1));
        if (top_grant !== 4'b0100 || top_owner !== 2'd2 || !top_owner_valid)
            fail_case("top arbiter round-robin selects R2 after R0");

        top_operation_done = 1;
        step;
        top_operation_done = 0;
        top_resource_available = 0;
        step;
        print_result("top no resource", {60'b0, top_resource_available, top_fault},
                     {60'b0, 4'b0000}, {60'b0, top_grant},
                     (!top_owner_valid && top_grant === 4'b0000));
        if (top_owner_valid || top_grant != 0)
            fail_case("top arbiter blocks grant when resource unavailable");

        top_resource_available = 1;
        top_fault = 1;
        step;
        print_result("top fault block", {60'b0, top_resource_available, top_fault},
                     {60'b0, 4'b0000}, {60'b0, top_grant},
                     (!top_owner_valid && top_grant === 4'b0000));
        if (top_owner_valid || top_grant != 0)
            fail_case("top arbiter blocks new grant during fault");

        top_fault = 0;
        top_req = 0;
        step;
        print_result("top no requests", {60'b0, top_req}, {60'b0, 4'b0000},
                     {60'b0, top_grant}, (!top_owner_valid && top_grant === 4'b0000));
        if (top_owner_valid || top_grant != 0)
            fail_case("top arbiter no grant when no requests are active");

        $display("GROUP COMPLETE | top-level | priority, owner/grant consistency, RR progression, resource and fault blocking checked");
        $display("==========================================================================");
        if (errors == 0) begin
            $display("OVERALL RESULT: PASS | errors=0");
        end else begin
            $display("OVERALL RESULT: FAIL | errors=%0d", errors);
            $display(1, "Day 28 verification failed");
        end
        $display("NOTE: RTL simulation still must be run with your installed simulator.");
        $display("NOTE: This is not a formal proof or safety certification.");
        $display("==========================================================================");
        $finish;
    end
endmodule
