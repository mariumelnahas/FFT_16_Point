function T = fft_16pt_types(dt)

switch dt
    case 'double'
        % Inputs & Outputs
        T.in_r = double([]); T.in_i = double([]);
        T.out_r = double([]); T.out_i = double([]);
        
        % Shift Registers
        T.sr1_r = double([]); T.sr1_i = double([]);
        T.sr2_r = double([]); T.sr2_i = double([]);
        T.sr3_r = double([]); T.sr3_i = double([]);
        T.sr4_r = double([]); T.sr4_i = double([]);
        
        % Twiddles
        T.W16 = double([]); T.W8 = double([]); T.W4 = double([]);
        T.tw1_r = double([]); T.tw1_i = double([]);
        T.tw2_r = double([]); T.tw2_i = double([]);
        T.tw3_r = double([]); T.tw3_i = double([]);
        T.tw4_r = double([]); T.tw4_i = double([]);
        
        % Stage 1
        T.stage1_add_out_r = double([]); T.stage1_add_out_i = double([]);
        T.stage1_sub_out_r = double([]); T.stage1_sub_out_i = double([]);
        T.stage1_mult_out_rxr = double([]); T.stage1_mult_out_rxi = double([]);
        T.stage1_mult_out_ixi = double([]); T.stage1_mult_out_ixr = double([]);
        T.stage1_mult_add_out_r = double([]); T.stage1_mult_add_out_i = double([]);

        % Stage 2
        T.stage2_add_out_r = double([]); T.stage2_add_out_i = double([]);
        T.stage2_sub_out_r = double([]); T.stage2_sub_out_i = double([]);
        T.stage2_mult_out_rxr = double([]); T.stage2_mult_out_rxi = double([]);
        T.stage2_mult_out_ixi = double([]); T.stage2_mult_out_ixr = double([]);
        T.stage2_mult_add_out_r = double([]); T.stage2_mult_add_out_i = double([]);

        % Stage 3
        T.stage3_add_out_r = double([]); T.stage3_add_out_i = double([]);
        T.stage3_sub_out_r = double([]); T.stage3_sub_out_i = double([]);
        T.stage3_mult_out_rxr = double([]); T.stage3_mult_out_rxi = double([]);
        T.stage3_mult_out_ixi = double([]); T.stage3_mult_out_ixr = double([]);
        T.stage3_mult_add_out_r = double([]); T.stage3_mult_add_out_i = double([]);

        % Stage 4
        T.stage4_add_out_r = double([]); T.stage4_add_out_i = double([]);
        T.stage4_sub_out_r = double([]); T.stage4_sub_out_i = double([]);
        T.stage4_mult_out_rxr = double([]); T.stage4_mult_out_rxi = double([]);
        T.stage4_mult_out_ixi = double([]); T.stage4_mult_out_ixr = double([]);
        T.stage4_mult_add_out_r = double([]); T.stage4_mult_add_out_i = double([]);
        
    case 'single'
        % Inputs & Outputs
        T.in_r = single([]); T.in_i = single([]);
        T.out_r = single([]); T.out_i = single([]);
        
        % Shift Registers
        T.sr1_r = single([]); T.sr1_i = single([]);
        T.sr2_r = single([]); T.sr2_i = single([]);
        T.sr3_r = single([]); T.sr3_i = single([]);
        T.sr4_r = single([]); T.sr4_i = single([]);
        
        % Twiddles
        T.W16 = single([]); T.W8 = single([]); T.W4 = single([]);
        T.tw1_r = single([]); T.tw1_i = single([]);
        T.tw2_r = single([]); T.tw2_i = single([]);
        T.tw3_r = single([]); T.tw3_i = single([]);
        T.tw4_r = single([]); T.tw4_i = single([]);
        
        % Stage 1
        T.stage1_add_out_r = single([]); T.stage1_add_out_i = single([]);
        T.stage1_sub_out_r = single([]); T.stage1_sub_out_i = single([]);
        T.stage1_mult_out_rxr = single([]); T.stage1_mult_out_rxi = single([]);
        T.stage1_mult_out_ixi = single([]); T.stage1_mult_out_ixr = single([]);
        T.stage1_mult_add_out_r = single([]); T.stage1_mult_add_out_i = single([]);

        % Stage 2
        T.stage2_add_out_r = single([]); T.stage2_add_out_i = single([]);
        T.stage2_sub_out_r = single([]); T.stage2_sub_out_i = single([]);
        T.stage2_mult_out_rxr = single([]); T.stage2_mult_out_rxi = single([]);
        T.stage2_mult_out_ixi = single([]); T.stage2_mult_out_ixr = single([]);
        T.stage2_mult_add_out_r = single([]); T.stage2_mult_add_out_i = single([]);

        % Stage 3
        T.stage3_add_out_r = single([]); T.stage3_add_out_i = single([]);
        T.stage3_sub_out_r = single([]); T.stage3_sub_out_i = single([]);
        T.stage3_mult_out_rxr = single([]); T.stage3_mult_out_rxi = single([]);
        T.stage3_mult_out_ixi = single([]); T.stage3_mult_out_ixr = single([]);
        T.stage3_mult_add_out_r = single([]); T.stage3_mult_add_out_i = single([]);

        % Stage 4
        T.stage4_add_out_r = single([]); T.stage4_add_out_i = single([]);
        T.stage4_sub_out_r = single([]); T.stage4_sub_out_i = single([]);
        T.stage4_mult_out_rxr = single([]); T.stage4_mult_out_rxi = single([]);
        T.stage4_mult_out_ixi = single([]); T.stage4_mult_out_ixr = single([]);
        T.stage4_mult_add_out_r = single([]); T.stage4_mult_add_out_i = single([]);

    case 'FxPt'
        % Format: fi([], signed, WordLength, FractionLength)
        
% Format: fi([], signed, WordLength, FractionLength)

%==========================================================================
% Inputs / Outputs
%==========================================================================
T.in_r  = fi([],1,16,13);
T.in_i  = fi([],1,16,13);

T.out_r = fi([],1,16,11);
T.out_i = fi([],1,16,11);

%==========================================================================
% Shift Registers
%==========================================================================
T.sr1_r = fi([],1,16,12);
T.sr1_i = fi([],1,16,12);

T.sr2_r = fi([],1,16,12);
T.sr2_i = fi([],1,16,12);

T.sr3_r = fi([],1,16,11);
T.sr3_i = fi([],1,16,11);

T.sr4_r = fi([],1,16,11);
T.sr4_i = fi([],1,16,11);

%==========================================================================
% Twiddle Constants
%==========================================================================
T.W16 = fi([],1,16,14);
T.W8  = fi([],1,16,14);
T.W4  = fi([],1,16,14);

T.tw1_r = fi([],1,16,14);
T.tw1_i = fi([],1,16,15);

T.tw2_r = fi([],1,16,14);
T.tw2_i = fi([],1,16,15);

T.tw3_r = fi([],1,16,0);
T.tw3_i = fi([],1,16,0);   % {-1,0}

T.tw4_r = fi([],1,16,0);   % constant 1
T.tw4_i = fi([],1,16,0);   % constant 0

%==========================================================================
% Stage 1
%==========================================================================
T.stage1_add_out_r      = fi([],1,16,12);
T.stage1_add_out_i      = fi([],1,16,12);

T.stage1_sub_out_r      = fi([],1,16,12);
T.stage1_sub_out_i      = fi([],1,16,12);

T.stage1_mult_out_rxr   = fi([],1,16,12);
T.stage1_mult_out_rxi   = fi([],1,16,12);
T.stage1_mult_out_ixi   = fi([],1,16,12);
T.stage1_mult_out_ixr   = fi([],1,16,12);

T.stage1_mult_add_out_r = fi([],1,16,12);
T.stage1_mult_add_out_i = fi([],1,16,12);

%==========================================================================
% Stage 2
%==========================================================================
T.stage2_add_out_r      = fi([],1,16,11);
T.stage2_add_out_i      = fi([],1,16,11);

T.stage2_sub_out_r      = fi([],1,16,11);
T.stage2_sub_out_i      = fi([],1,16,11);

T.stage2_mult_out_rxr   = fi([],1,16,11);
T.stage2_mult_out_rxi   = fi([],1,16,11);
T.stage2_mult_out_ixi   = fi([],1,16,11);
T.stage2_mult_out_ixr   = fi([],1,16,11);

T.stage2_mult_add_out_r = fi([],1,16,11);
T.stage2_mult_add_out_i = fi([],1,16,11);

%==========================================================================
% Stage 3
%==========================================================================
T.stage3_add_out_r      = fi([],1,16,11);
T.stage3_add_out_i      = fi([],1,16,11);

T.stage3_sub_out_r      = fi([],1,16,11);
T.stage3_sub_out_i      = fi([],1,16,11);

T.stage3_mult_out_rxr   = fi([],1,16,11);
T.stage3_mult_out_rxi   = fi([],1,16,11);
T.stage3_mult_out_ixi   = fi([],1,16,11);
T.stage3_mult_out_ixr   = fi([],1,16,11);

T.stage3_mult_add_out_r = fi([],1,16,11);
T.stage3_mult_add_out_i = fi([],1,16,11);

%==========================================================================
% Stage 4
%==========================================================================
T.stage4_add_out_r      = fi([],1,16,10);
T.stage4_add_out_i      = fi([],1,16,11);

T.stage4_sub_out_r      = fi([],1,16,10);
T.stage4_sub_out_i      = fi([],1,16,11);

T.stage4_mult_out_rxr   = fi([],1,16,11);
T.stage4_mult_out_rxi   = fi([],1,16,0);   % always zero
T.stage4_mult_out_ixi   = fi([],1,16,0);   % always zero
T.stage4_mult_out_ixr   = fi([],1,16,11);

T.stage4_mult_add_out_r = fi([],1,16,11);
T.stage4_mult_add_out_i = fi([],1,16,11);
end
end