// SPDX-License-Identifier: Apache-2.0
`timescale 1ns/1ps
module pla_tb;
    parameter int NUM_REQ=4, LOCK_MODE=0, LEN_W=8;
    localparam int MAX_LEN=(1<<LEN_W)-1;
    logic clk=0, rst_n=0;
    always #5 clk=~clk;
    logic [NUM_REQ-1:0] req='0, eop='0, grant, in_ready;
    logic ready=0, out_valid, out_last;
    logic [NUM_REQ*LEN_W-1:0] lengths='0;
    logic [NUM_REQ*32-1:0] data='0;
    logic [31:0] out_data;
    int ref_owner=-1, ref_start=0, ref_total=0, ref_accepted=0;
    int cycles=0, beats=0, packets=0, bubbles=0, stalls=0, resets=0;
    int seq[NUM_REQ], left[NUM_REQ], plen[NUM_REQ], overtakes[NUM_REQ];
    int last_fire=-1, last_done=-1;
    int seed=101;
    bit fair_check=0;
    packet_mux #(.NUM_REQ(NUM_REQ), .LOCK_MODE(LOCK_MODE), .LEN_W(LEN_W)) dut (
        .clk(clk), .rst_n(rst_n), .valid_i(req), .last_i(eop), .length_i(lengths),
        .data_i(data), .ready_i(ready), .ready_o(in_ready), .grant_o(grant),
        .valid_o(out_valid), .last_o(out_last), .data_o(out_data));

    task automatic reset_case;
        @(negedge clk); rst_n=0; req='0; ready=0; eop='0; lengths='0; fair_check=0;
        ref_owner=-1; ref_start=0; ref_total=0; ref_accepted=0;
        foreach(seq[i]) begin seq[i]=0; overtakes[i]=0; end
        repeat(3) begin @(posedge clk); #1; if(grant !== '0) $fatal(1,"RESET"); end
        @(negedge clk); rst_n=1; resets++;
    endtask
    task automatic set_lengths(input int value);
        for(int i=0;i<NUM_REQ;i++) lengths[i*LEN_W +: LEN_W]=LEN_W'(value);
    endtask
    // Drive precedes rising-edge sample. Model is scan + accepted count (not RTL mask/downcounter).
    task automatic tick;
        int chosen, idx, declared;
        bit accepted, finished;
        logic [NUM_REQ-1:0] expected;
        chosen=ref_owner; expected='0;
        if(chosen<0) begin
            for(int off=0;off<NUM_REQ;off++) begin
                idx=(ref_start+off)%NUM_REQ;
                if(chosen<0 && req[idx] && (LOCK_MODE==0 || lengths[idx*LEN_W +: LEN_W]!=0)) chosen=idx;
            end
        end
        if(chosen>=0) expected[chosen]=1;
        for(int i=0;i<NUM_REQ;i++) data[i*32 +: 32]=(i<<24)|seq[i];
        #1;
        if(grant !== expected) $fatal(1,"MODEL grant cycle=%0d N=%0d M=%0d req=%h expected=%h got=%h",cycles,NUM_REQ,LOCK_MODE,req,expected,grant);
        accepted=(chosen>=0) && ready && req[chosen];
        if(out_valid !== (|(expected & req)) || in_ready !== (expected & {NUM_REQ{ready}})) $fatal(1,"CONSUMER handshake");
        if(accepted && (out_data !== ((chosen<<24)|seq[chosen]) || out_last !== eop[chosen])) $fatal(1,"CONSUMER data/order");
        if(chosen>=0 && ref_owner<0) begin
            ref_owner=chosen; ref_total=int'(lengths[chosen*LEN_W +: LEN_W]); ref_accepted=0;
        end
        finished=0; last_fire=-1; last_done=-1;
        if(accepted) begin
            ref_accepted++; beats++; seq[chosen]++; last_fire=chosen;
            finished=(LOCK_MODE==0) ? eop[chosen] : (ref_accepted==ref_total);
        end
        if(chosen>=0 && !req[chosen]) bubbles++;
        if(chosen>=0 && req[chosen] && !ready) stalls++;
        if(finished) begin
            packets++; last_done=chosen;
            // PROP-PLA_FAIR-006: bound in other completed packets, not cycles.
            if(fair_check) for(int i=0;i<NUM_REQ;i++) begin
                if(i==chosen) overtakes[i]=0; else overtakes[i]++;
                if(overtakes[i]>=NUM_REQ) $fatal(1,"PROP-PLA_FAIR-006 requester=%0d",i);
            end
            ref_owner=-1; ref_start=(chosen+1)%NUM_REQ;
        end
        @(posedge clk); #1; cycles++;
        @(negedge clk);
    endtask

    task automatic tc_reset_mutex;
        reset_case(); set_lengths(3); req='1; eop='0; ready=0; tick();
        reset_case(); set_lengths(1); req='1; eop='1; ready=1; tick();
        if(last_fire!=0 || last_done!=0) $fatal(1,"reset priority");
    endtask
    task automatic tc_stall_bubble;
        reset_case(); set_lengths(MAX_LEN>1 ? 2 : 1); req='1; eop='0; ready=0; tick();
        req[0]=0; ready=1; eop='1; repeat(3) tick();
        req[0]=1; eop='0; ready=1; tick();
        eop='1; ready=0; repeat(3) tick(); ready=1; tick();
    endtask
    task automatic tc_eop;
        if(LOCK_MODE==0) begin
            reset_case(); req='1; eop='1; eop[0]=0; ready=1; set_lengths(0);
            repeat(4) tick();
            eop[0]=1; ready=0; tick(); ready=1; tick();
            if(last_done!=0) $fatal(1,"selected EOP completion");
        end
    endtask
    task automatic tc_single_beat;
        reset_case(); set_lengths(1); req='1; eop='1; ready=1;
        repeat(NUM_REQ*4) begin tick(); if(last_done<0) $fatal(1,"single-beat bubble"); end
    endtask
    task automatic tc_rr_order;
        reset_case(); set_lengths(1); req='1; eop='1; ready=1;
        for(int i=0;i<NUM_REQ*3;i++) begin tick(); if(last_done!=i%NUM_REQ) $fatal(1,"RR order"); end
    endtask
    task automatic tc_back_to_back; tc_single_beat(); endtask
    task automatic tc_fairness;
        reset_case(); set_lengths(1); req='1; eop='1; ready=1; fair_check=1;
        repeat(NUM_REQ*4) tick(); fair_check=0;
    endtask
    task automatic tc_length;
        if(LOCK_MODE==1) begin
            reset_case(); set_lengths(MAX_LEN); req='0; req[0]=1; eop='1; ready=1;
            for(int i=0;i<MAX_LEN;i++) begin
                tick();
                if((last_done>=0)!=(i==MAX_LEN-1)) $fatal(1,"maximum length boundary");
            end
        end
    endtask
    task automatic tc_length_stall;
        if(LOCK_MODE==1) begin
            reset_case(); set_lengths(MAX_LEN>2 ? 3 : 1); req='1; ready=0; eop='1; tick();
            set_lengths(0); repeat(3) tick(); ready=1;
            repeat(MAX_LEN>2 ? 3 : 1) tick();
            if(last_done!=0) $fatal(1,"length sampling");
        end
    endtask
    task automatic tc_zero_length;
        if(LOCK_MODE==1) begin
            reset_case(); set_lengths(0); req='1; ready=1; eop='1; repeat(3) tick();
            lengths[(NUM_REQ-1)*LEN_W +: LEN_W]=LEN_W'(1); tick();
            if(last_done!=NUM_REQ-1) $fatal(1,"zero length blocks legal contender");
        end
    endtask
    task automatic tc_random;
        reset_case(); req='0; ready=0;
        foreach(left[i]) begin plen[i]=$urandom_range(1,MAX_LEN<7 ? MAX_LEN:7); left[i]=plen[i]; end
        for(int cycle=0;cycle<2500;cycle++) begin
            for(int i=0;i<NUM_REQ;i++) begin
                if(!req[i] || last_fire==i) req[i]=($urandom_range(0,3)!=0);
                eop[i]=(left[i]==1); lengths[i*LEN_W +: LEN_W]=LEN_W'(plen[i]);
            end
            ready=($urandom_range(0,3)!=0); tick();
            if(last_fire>=0) begin
                left[last_fire]--;
                if(left[last_fire]==0) begin
                    plen[last_fire]=$urandom_range(1,MAX_LEN<7 ? MAX_LEN:7); left[last_fire]=plen[last_fire];
                end
            end
        end
        // Drain the reserved packet with valid resumed and ready high.
        ready=1;
        while(ref_owner>=0) begin
            req='0; req[ref_owner]=1; eop='0; eop[ref_owner]=(left[ref_owner]==1);
            tick(); if(last_fire>=0) left[last_fire]--;
        end
    endtask
    initial begin
        if($value$plusargs("seed=%d",seed)) begin end
        seed=$urandom(seed);
        tc_reset_mutex(); tc_stall_bubble(); tc_eop(); tc_single_beat(); tc_rr_order();
        tc_back_to_back(); tc_fairness(); tc_length(); tc_length_stall(); tc_zero_length(); tc_random();
        $display("PLA_PASS N=%0d MODE=%0d LEN_W=%0d cycles=%0d beats=%0d packets=%0d stalls=%0d bubbles=%0d resets=%0d",NUM_REQ,LOCK_MODE,LEN_W,cycles,beats,packets,stalls,bubbles,resets);
        $finish;
    end
    initial begin #10000000; $fatal(1,"TIMEOUT"); end
endmodule
