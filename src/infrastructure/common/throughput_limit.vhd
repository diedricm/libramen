library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
library libramen;
    use libramen.core_pkg.ALL;

entity throughput_limit is
generic (
    TUPPLE_COUNT : natural := 1;
    TDATA_WIDTH : natural := 4;
    THR_DIVIDEND : natural := 5;
    THR_DIVISOR : natural := 10
);
Port (
    clk : in std_logic;
    rstn : in std_logic;
    
	stream_s  : in flit(tuples(TUPPLE_COUNT-1 downto 0));
	ready_s : out std_logic;
	
	stream_m  : out flit(tuples(TUPPLE_COUNT-1 downto 0));
	ready_m : in std_logic
);
begin
    assert THR_DIVIDEND <= THR_DIVISOR report "axis_hroughput_limit: THR_DIVIDEND must be smaller or equal to THR_DIVISOR" severity failure;
end throughput_limit;

architecture Behavioral of throughput_limit is
    signal turn_counter : natural := 0;
    signal transmission_allowed : std_logic;
begin

    process (clk)
    begin
        if rising_edge(clk) and rstn = '1' then
            turn_counter <= turn_counter + 1;
            if turn_counter = (THR_DIVISOR - 1) then
                turn_counter <= 0;
            end if;
        end if;
    end process;
    
    transmission_allowed <= '1' when (turn_counter < THR_DIVIDEND) else '0';
    
    output: process(stream_s, ready_m, transmission_allowed)
    begin
        stream_m <= stream_s;
        stream_m.valid <= stream_s.valid AND ready_m AND transmission_allowed;
        ready_s <= stream_s.valid AND ready_m AND transmission_allowed;
    end process;
    
end Behavioral;
