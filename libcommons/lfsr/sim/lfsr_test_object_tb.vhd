library std;
	use std.textio.all;
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.std_logic_textio.all;
library libcommons;
    use libcommons.lfsr.all;

entity lfsr_test_object_tb is
end lfsr_test_object_tb;

architecture Behavioral of lfsr_test_object_tb is
    constant clock_period : time := 10ns;
    signal clk : std_logic := '0';
    signal rst_n : std_logic := '0';
    
    signal data_out : std_logic_vector(29 downto 0);
	
	constant sample_size : natural := 2**16;
begin

    clk <= NOT clk after clock_period/2;
    rst_n <= '1' after clock_period*100;
    
	protocol: process
		type IntegerFileType is file of string;
		file datafile_out: IntegerFileType;
		variable fstatus: FILE_OPEN_STATUS;
	begin
		file_open(fstatus, datafile_out, "samples.csv", write_mode);
	
		for i in 0 to sample_size-1 loop
			wait for clock_period;
			write(datafile_out, integer'image(to_integer(unsigned(data_out))) & ",");
		end loop;
		
		report "All LFSR values written to samples.csv in current work directory.";
		
		wait;
	end process;
	
    uut: entity libcommons.lfsr_test_object
    generic map (
        LFSR_SIZE => 30,
        LFSR_CYCLE_STOP_STATE => true,
        STEP_OFFSET => 1
    ) port map (
        clk => clk,
        rst_n => rst_n,
        
        data_out => data_out,
        error => OPEN,
        passed => OPEN
    );

end Behavioral;
