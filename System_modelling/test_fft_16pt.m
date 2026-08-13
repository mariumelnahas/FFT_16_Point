clear; clc; close all;

% DESIGN PARAMETERS
N = 16;
num_cycles = 32; 
nSeeds = 100;
error = zeros(1,nSeeds);
SQNR = zeros(1,nSeeds);

% OPEN FILES FOR SYSTEMVERILOG VERIFICATION
fid_in = fopen('fft_inputs.txt', 'w');
fid_out = fopen('fft_outputs.txt', 'w');

if fid_in == -1 || fid_out == -1
    error('Could not open files for writing.');
end
% bit-reversed indices
br_indices = bin2dec(fliplr(dec2bin(0:15, 4))) + 1;

for seed = 1 : nSeeds
    rng(seed);
    T = fft_16pt_types('FxPt');

    % TEST INPUTS
    x_double = randn(N, 1) + 1i * randn(N, 1);
    
    % Pad with zeros to flush the pipeline after inputting 16 points
    test_in_r_raw = [real(x_double); zeros(N, 1)];
    test_in_i_raw = [imag(x_double); zeros(N, 1)];
    
    % Cast to Fixed-Point based on Types Table
    test_in_r = cast(test_in_r_raw, 'like', T.in_r);
    test_in_i = cast(test_in_i_raw, 'like', T.in_i);
    
    % Extract the entire array of binary strings at once
    str_in_r = test_in_r.bin;
    str_in_i = test_in_i.bin;
    
    % ---------------------------------------------------------------------
    % WRITE ONLY VALID INPUTS (Cycles 1 to 16)
    % Skips the 16 zero-padded flush cycles
    % ---------------------------------------------------------------------
    for k = 1 : N
        fprintf(fid_in, '%s%s\n', str_in_r(k,:), str_in_i(k,:));
    end
    
    % FFT ALGORITHM
    [out_r, out_i] = fft_16pt_sdf_mex(test_in_r, test_in_i, num_cycles, T);
    
    % Extract output binary strings at once
    str_out_r = out_r.bin;
    str_out_i = out_i.bin;
    
    % ---------------------------------------------------------------------
    % WRITE ONLY VALID OUTPUTS (Cycles 16 to 31)
    % Accounts for the 15-cycle hardware latency
    % ---------------------------------------------------------------------
    for k = 1 : N
        hw_idx = 15 + br_indices(k);
        fprintf(fid_out, '%s%s\n', str_out_r(hw_idx,:), str_out_i(hw_idx,:));
    end
    
    % VERIFY RESULTS
    y_raw_hw = out_r(16:31) + 1i * out_i(16:31);
    
    % Generate bit-reversed indices for 0 to 15
    br_indices = bin2dec(fliplr(dec2bin(0:15, 4))) + 1;
    y = y_raw_hw(br_indices);
    
    yExpected = fft(x_double);
    
    % Cast fixed-point object back to double before evaluating math
    y_double = double(y);
    
    error(seed) = mean(abs(y_double - yExpected));
    SQNR(seed) = mean(abs(yExpected).^2) / mean(abs(y_double - yExpected).^2);
end

fclose(fid_in);
fclose(fid_out);

disp('Generated fft_inputs.txt and fft_outputs.txt successfully!');

SQNR_dB = 10*log10(SQNR);

% PLOT
figure; plot(1 : nSeeds, error, 'LineWidth', 2); grid on;
xlabel('Seed', 'FontSize', 14); ylabel('Error', 'FontSize', 14);
title('Quantization Error over 100 Seeds');

figure; plot(1 : nSeeds, SQNR_dB, 'LineWidth', 2); grid on;
xlabel('Seed', 'FontSize', 14); ylabel('SQNR (dB)', 'FontSize', 14);
title('16-Point FFT Fixed-Point SQNR');