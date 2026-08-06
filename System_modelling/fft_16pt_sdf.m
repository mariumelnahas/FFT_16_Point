function [out_r, out_i] = fft_16pt_sdf(test_in_r, test_in_i, num_cycles, T) %#codegen
% T: Types table structure containing specific fixed-point variable definitions

% Floating-point twiddle factors (cast to target type)
W16 = cast(exp(-1i * 2*pi * (0:7) / 16), 'like', T.W16);
W8  = cast(exp(-1i * 2*pi * (0:3) / 8),  'like', T.W8);
W4  = cast(exp(-1i * 2*pi * (0:1) / 4),  'like', T.W4);

% Initialize shift registers using the types table
sr1_r = zeros(1, 8, 'like', T.sr1_r); sr1_i = zeros(1, 8, 'like', T.sr1_i);
sr2_r = zeros(1, 4, 'like', T.sr2_r); sr2_i = zeros(1, 4, 'like', T.sr2_i);
sr3_r = zeros(1, 2, 'like', T.sr3_r); sr3_i = zeros(1, 2, 'like', T.sr3_i);
sr4_r = zeros(1, 1, 'like', T.sr4_r); sr4_i = zeros(1, 1, 'like', T.sr4_i);

out_r = zeros(num_cycles, 1, 'like', T.out_r);
out_i = zeros(num_cycles, 1, 'like', T.out_i);

for clk = 0 : num_cycles - 1
    
    in_r = cast(test_in_r(clk + 1), 'like', T.in_r);
    in_i = cast(test_in_i(clk + 1), 'like', T.in_i);
    
    % =====================================================================
    % STAGE 1 (Delay = 8)
    % =====================================================================
    sel1 = bitget(clk, 4);
    
    stage1_add_out_r = cast(sr1_r(end) + in_r, 'like', T.stage1_add_out_r);
    stage1_add_out_i = cast(sr1_i(end) + in_i, 'like', T.stage1_add_out_i);
    stage1_sub_out_r = cast(sr1_r(end) - in_r, 'like', T.stage1_sub_out_r);
    stage1_sub_out_i = cast(sr1_i(end) - in_i, 'like', T.stage1_sub_out_i);
    
    if sel1 == 0
        % Outputting Delayed SUB -> Must apply Twiddle Factor
        mux1_top_r = cast(in_r,       'like', T.sr1_r);
        mux1_top_i = cast(in_i,       'like', T.sr1_i);
        mux1_bot_r = cast(sr1_r(end), 'like', T.stage1_add_out_r); 
        mux1_bot_i = cast(sr1_i(end), 'like', T.stage1_add_out_i);
        
        idx = mod(clk, 8) + 1;
        tw1_r = cast(real(W16(idx)), 'like', T.tw1_r); 
        tw1_i = cast(imag(W16(idx)), 'like', T.tw1_i);
    else
        % Outputting Current ADD -> Twiddle is exactly 1
        mux1_top_r = cast(stage1_sub_out_r, 'like', T.sr1_r); 
        mux1_top_i = cast(stage1_sub_out_i, 'like', T.sr1_i);
        mux1_bot_r = cast(stage1_add_out_r, 'like', T.stage1_add_out_r); 
        mux1_bot_i = cast(stage1_add_out_i, 'like', T.stage1_add_out_i);
        
        tw1_r = cast(1, 'like', T.tw1_r); 
        tw1_i = cast(0, 'like', T.tw1_i);
    end
    
    sr1_r = [mux1_top_r, sr1_r(1:end-1)];
    sr1_i = [mux1_top_i, sr1_i(1:end-1)];
    
    stage1_mult_out_rxr = cast(mux1_bot_r * tw1_r, 'like', T.stage1_mult_out_rxr);
    stage1_mult_out_ixi = cast(mux1_bot_i * tw1_i, 'like', T.stage1_mult_out_ixi);
    stage1_mult_out_ixr = cast(mux1_bot_i * tw1_r, 'like', T.stage1_mult_out_ixr);
    stage1_mult_out_rxi = cast(mux1_bot_r * tw1_i, 'like', T.stage1_mult_out_rxi);
    
    stage1_mult_add_out_r = cast(stage1_mult_out_rxr - stage1_mult_out_ixi, 'like', T.stage1_mult_add_out_r);
    stage1_mult_add_out_i = cast(stage1_mult_out_ixr + stage1_mult_out_rxi, 'like', T.stage1_mult_add_out_i);

    % =====================================================================
    % STAGE 2 (Delay = 4)
    % =====================================================================
    sel2 = bitget(clk, 3);
    
    stage2_add_out_r = cast(sr2_r(end) + stage1_mult_add_out_r, 'like', T.stage2_add_out_r);
    stage2_add_out_i = cast(sr2_i(end) + stage1_mult_add_out_i, 'like', T.stage2_add_out_i);
    stage2_sub_out_r = cast(sr2_r(end) - stage1_mult_add_out_r, 'like', T.stage2_sub_out_r);
    stage2_sub_out_i = cast(sr2_i(end) - stage1_mult_add_out_i, 'like', T.stage2_sub_out_i);
    
    if sel2 == 0
        % Outputting Delayed SUB -> Must apply Twiddle Factor
        mux2_top_r = cast(stage1_mult_add_out_r, 'like', T.sr2_r); 
        mux2_top_i = cast(stage1_mult_add_out_i, 'like', T.sr2_i);
        mux2_bot_r = cast(sr2_r(end),            'like', T.stage2_add_out_r);
        mux2_bot_i = cast(sr2_i(end),            'like', T.stage2_add_out_i);
        
        idx = mod(clk, 4) + 1;
        tw2_r = cast(real(W8(idx)), 'like', T.tw2_r);  
        tw2_i = cast(imag(W8(idx)), 'like', T.tw2_i);
    else
        % Outputting Current ADD -> Twiddle is exactly 1
        mux2_top_r = cast(stage2_sub_out_r, 'like', T.sr2_r);      
        mux2_top_i = cast(stage2_sub_out_i, 'like', T.sr2_i);
        mux2_bot_r = cast(stage2_add_out_r, 'like', T.stage2_add_out_r);      
        mux2_bot_i = cast(stage2_add_out_i, 'like', T.stage2_add_out_i);
        
        tw2_r = cast(1, 'like', T.tw2_r);      
        tw2_i = cast(0, 'like', T.tw2_i);
    end
    
    sr2_r = [mux2_top_r, sr2_r(1:end-1)];
    sr2_i = [mux2_top_i, sr2_i(1:end-1)];
    
    stage2_mult_out_rxr = cast(mux2_bot_r * tw2_r, 'like', T.stage2_mult_out_rxr);
    stage2_mult_out_ixi = cast(mux2_bot_i * tw2_i, 'like', T.stage2_mult_out_ixi);
    stage2_mult_out_ixr = cast(mux2_bot_i * tw2_r, 'like', T.stage2_mult_out_ixr);
    stage2_mult_out_rxi = cast(mux2_bot_r * tw2_i, 'like', T.stage2_mult_out_rxi);
    
    stage2_mult_add_out_r = cast(stage2_mult_out_rxr - stage2_mult_out_ixi, 'like', T.stage2_mult_add_out_r);
    stage2_mult_add_out_i = cast(stage2_mult_out_ixr + stage2_mult_out_rxi, 'like', T.stage2_mult_add_out_i);

    % =====================================================================
    % STAGE 3 (Delay = 2)
    % =====================================================================
    sel3 = bitget(clk, 2);
    
    stage3_add_out_r = cast(sr3_r(end) + stage2_mult_add_out_r, 'like', T.stage3_add_out_r);
    stage3_add_out_i = cast(sr3_i(end) + stage2_mult_add_out_i, 'like', T.stage3_add_out_i);
    stage3_sub_out_r = cast(sr3_r(end) - stage2_mult_add_out_r, 'like', T.stage3_sub_out_r);
    stage3_sub_out_i = cast(sr3_i(end) - stage2_mult_add_out_i, 'like', T.stage3_sub_out_i);
    
    if sel3 == 0
        % Outputting Delayed SUB -> Must apply Twiddle Factor
        mux3_top_r = cast(stage2_mult_add_out_r, 'like', T.sr3_r); 
        mux3_top_i = cast(stage2_mult_add_out_i, 'like', T.sr3_i);
        mux3_bot_r = cast(sr3_r(end),            'like', T.stage3_add_out_r);            
        mux3_bot_i = cast(sr3_i(end),            'like', T.stage3_add_out_i);
        
        idx = mod(clk, 2) + 1;
        tw3_r = cast(real(W4(idx)), 'like', T.tw3_r);              
        tw3_i = cast(imag(W4(idx)), 'like', T.tw3_i);
    else
        % Outputting Current ADD -> Twiddle is exactly 1
        mux3_top_r = cast(stage3_sub_out_r, 'like', T.sr3_r);      
        mux3_top_i = cast(stage3_sub_out_i, 'like', T.sr3_i);
        mux3_bot_r = cast(stage3_add_out_r, 'like', T.stage3_add_out_r);      
        mux3_bot_i = cast(stage3_add_out_i, 'like', T.stage3_add_out_i);
        
        tw3_r = cast(1, 'like', T.tw3_r);      
        tw3_i = cast(0, 'like', T.tw3_i);
    end
    
    sr3_r = [mux3_top_r, sr3_r(1:end-1)];
    sr3_i = [mux3_top_i, sr3_i(1:end-1)];
    
    stage3_mult_out_rxr = cast(mux3_bot_r * tw3_r, 'like', T.stage3_mult_out_rxr);
    stage3_mult_out_ixi = cast(mux3_bot_i * tw3_i, 'like', T.stage3_mult_out_ixi);
    stage3_mult_out_ixr = cast(mux3_bot_i * tw3_r, 'like', T.stage3_mult_out_ixr);
    stage3_mult_out_rxi = cast(mux3_bot_r * tw3_i, 'like', T.stage3_mult_out_rxi);
    
    stage3_mult_add_out_r = cast(stage3_mult_out_rxr - stage3_mult_out_ixi, 'like', T.stage3_mult_add_out_r);
    stage3_mult_add_out_i = cast(stage3_mult_out_ixr + stage3_mult_out_rxi, 'like', T.stage3_mult_add_out_i);

    % =====================================================================
    % STAGE 4 (Delay = 1)
    % =====================================================================
    sel4 = bitget(clk, 1);
    
    stage4_add_out_r = cast(sr4_r(end) + stage3_mult_add_out_r, 'like', T.stage4_add_out_r);
    stage4_add_out_i = cast(sr4_i(end) + stage3_mult_add_out_i, 'like', T.stage4_add_out_i);
    stage4_sub_out_r = cast(sr4_r(end) - stage3_mult_add_out_r, 'like', T.stage4_sub_out_r);
    stage4_sub_out_i = cast(sr4_i(end) - stage3_mult_add_out_i, 'like', T.stage4_sub_out_i);
    
    if sel4 == 0
        mux4_top_r = cast(stage3_mult_add_out_r, 'like', T.sr4_r); 
        mux4_top_i = cast(stage3_mult_add_out_i, 'like', T.sr4_i);
        mux4_bot_r = cast(sr4_r(end),            'like', T.stage4_add_out_r);            
        mux4_bot_i = cast(sr4_i(end),            'like', T.stage4_add_out_i);
    else
        mux4_top_r = cast(stage4_sub_out_r,      'like', T.sr4_r);      
        mux4_top_i = cast(stage4_sub_out_i,      'like', T.sr4_i);
        mux4_bot_r = cast(stage4_add_out_r,      'like', T.stage4_add_out_r);      
        mux4_bot_i = cast(stage4_add_out_i,      'like', T.stage4_add_out_i);
    end
    
    % The final stage never requires a twiddle multiplier mathematically
    tw4_r = cast(1, 'like', T.tw4_r); 
    tw4_i = cast(0, 'like', T.tw4_i);
    
    sr4_r = [mux4_top_r, sr4_r(1:end-1)];
    sr4_i = [mux4_top_i, sr4_i(1:end-1)];
    
    stage4_mult_out_rxr = cast(mux4_bot_r * tw4_r, 'like', T.stage4_mult_out_rxr);
    stage4_mult_out_ixi = cast(mux4_bot_i * tw4_i, 'like', T.stage4_mult_out_ixi);
    stage4_mult_out_ixr = cast(mux4_bot_i * tw4_r, 'like', T.stage4_mult_out_ixr);
    stage4_mult_out_rxi = cast(mux4_bot_r * tw4_i, 'like', T.stage4_mult_out_rxi);
    
    stage4_mult_add_out_r = cast(stage4_mult_out_rxr - stage4_mult_out_ixi, 'like', T.stage4_mult_add_out_r);
    stage4_mult_add_out_i = cast(stage4_mult_out_ixr + stage4_mult_out_rxi, 'like', T.stage4_mult_add_out_i);
    
    % =====================================================================
    % OUTPUT CAPTURE
    % =====================================================================
    out_r(clk+1) = cast(stage4_mult_add_out_r, 'like', T.out_r);
    out_i(clk+1) = cast(stage4_mult_add_out_i, 'like', T.out_i);
end

end