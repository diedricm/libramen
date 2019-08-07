library ieee;
    use ieee.std_logic_1164.ALL;
    use ieee.numeric_std.ALL;
library libcommons;
    use libcommons.misc.all;

entity regbuffer is
generic (
    BUFFERWIDTH : natural;
	BUFFERDEPTH : natural
);
port (
    clk : in std_logic;
	
	input : in std_logic_vector(BUFFERWIDTH-1 downto 0);
	output : out std_logic_vector(BUFFERWIDTH-1 downto 0)
);
end regbuffer;

architecture Behavioral of regbuffer is
	type buffertype is array (BUFFERDEPTH downto 0) of std_logic_vector(BUFFERWIDTH-1 downto 0);
	signal bufferstages : buffertype := (others => (others => '0'));
begin

    bufferblock: if BUFFERDEPTH /= 0 generate
        mainproc: process(clk)
        begin
            if rising_edge(clk) then
                bufferstages(0) <= input;
            
                for i in 0 to BUFFERDEPTH-1 loop
                    bufferstages(i+1) <= bufferstages(i);
                end loop;
            end if;
        end process;
        
        output <= bufferstages(BUFFERDEPTH-1);
	end generate;
	
	passthroughblock: if BUFFERDEPTH = 0 generate
	   output <= input;
	end generate;

end Behavioral;