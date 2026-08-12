module compare_files;

  string line_m, line_g;
  int fd_m, fd_g;
  int line_num = 0;
  int mismatch_count = 0;

  initial begin

    fd_m = $fopen("rtl_outputs_m.txt", "r");
    fd_g = $fopen("fft_outputs.txt", "r");

    if (fd_m == 0) begin
      $display("ERROR: Cannot open rtl_outputs_m.txt");
      $finish;
    end

    if (fd_g == 0) begin
      $display("ERROR: Cannot open fft_outputs.txt");
      $finish;
    end

    while (!$feof(fd_m) && !$feof(fd_g)) begin
      line_num++;

      void'($fgets(line_m, fd_m));
      void'($fgets(line_g, fd_g));

      // Remove trailing newline if needed
      if (line_m != line_g) begin
        mismatch_count++;

        $display("\nMismatch at line %0d", line_num);
        $display("M: %s", line_m);
        $display("G: %s", line_g);
      end
    end

    // Check if file lengths differ
    if (!$feof(fd_m) || !$feof(fd_g)) begin
      $display("\nERROR: Files have different numbers of lines");
    end

    $display("\n=================================");
    $display("Total lines compared : %0d", line_num);
    $display("Total mismatches     : %0d", mismatch_count);
    $display("=================================");

    $fclose(fd_m);
    $fclose(fd_g);

    $finish;
  end

endmodule