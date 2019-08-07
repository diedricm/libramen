library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
library libcommons;
	use libcommons.misc.all;
	
entity graycode_tb is
end graycode_tb;

architecture Behavioral of graycode_tb is
	constant clock_period : time := 10 ns;
	signal clk : std_logic := '0';

	signal counter0_bin : unsigned(3 downto 0) := (others => '0');
	signal counter0_gray: unsigned(3 downto 0);
	signal counter0_check: unsigned(3 downto 0);
	
	signal counter1_bin : unsigned(6 downto 0) := (others => '0');
	signal counter1_gray: unsigned(6 downto 0);
	signal counter1_check: unsigned(6 downto 0);
begin

	clk <= not clk after clock_period/2;

	counter0_gray <= bin2gray(counter0_bin);
	counter0_check <= gray2bin(counter0_gray);

	counter1_gray <= bin2gray(counter1_bin);
	counter1_check <= gray2bin(counter1_gray);
	
	process (clk)
	begin
		if rising_edge(clk) then
			counter0_bin <= counter0_bin + 1;
			counter1_bin <= counter1_bin + 1;
		end if;
	end process;

end architecture Behavioral;