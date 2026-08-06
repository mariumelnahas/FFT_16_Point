clear; clc; close all;

% DESIGN PARAMETERS
N = 16;
num_cycles = 32; 
nSeeds = 100;
error = zeros(1,nSeeds);
SQNR = zeros(1,nSeeds);
for seed = 1 : nSeeds
    rng(seed);

    T = fft_16pt_types('FxPt');
    
    % TEST INPUTS
    x_double = randn(N, 1) + 1i * randn(N, 1);
    
    % Pad with zeros to flush the pipeline after inputting 16 points
    test_in_r = [real(x_double); zeros(N, 1)];
    test_in_i = [imag(x_double); zeros(N, 1)];
    
    % FFT ALGORITHM
    [out_r, out_i] = fft_16pt_sdf_mex(test_in_r, test_in_i, num_cycles, T);
    
    % VERIFY RESULTS
    y_raw_hw = out_r(16:31) + 1i * out_i(16:31);
    
    % Generate bit-reversed indices for 0 to 15
    br_indices = bin2dec(fliplr(dec2bin(0:15, 4))) + 1;
    y = y_raw_hw(br_indices);
    y_double = double(y);
    
    yExpected = fft(x_double);
    error(seed) = mean(abs(y_double - yExpected));
    SQNR(seed) = mean(abs(yExpected).^2) / mean(abs(y_double - yExpected).^2);
end

SQNR_dB = 10*log10(SQNR);

% PLOT
figure; plot(1 : nSeeds, error, 'LineWidth', 2); grid on;
xlabel('Seed', 'FontSize', 14); ylabel('Error', 'FontSize', 14);
%figure; plot(1 : nSeeds, SQNR_dB, 'LineWidth', 2); grid on;
figure; plot(1:nSeeds, SQNR_dB, 'LineWidth', 2); grid on; ylim('auto');