library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;

entity multiport_fifo_out_scheduler is
generic (	
    VIRTUAL_PORT_CNT_LOG2 : natural := 3;
    MEMORY_DEPTH_LOG2_OUTPUT : natural := 3;
    MAX_CORE_PIPLINE_DEPTH   : natural := 8
);
port (
    clk : in std_logic;
    rst_n : in std_logic;

    credits_list_out_output : in std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);

    change_output_chan_req  : in std_logic;
        
    next_output_chan_out    : out std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    read_enable_out         : out std_logic;
    next_output_skip_prftchd_data_out : out std_logic
);
end multiport_fifo_out_scheduler;

architecture Behavioral of multiport_fifo_out_scheduler is
	type credit_list_output_t is array (natural range <>) of unsigned(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);

    constant spec  : lfsr_spec := new_lfsr_iterator(VIRTUAL_PORT_CNT_LOG2, true);
	
	signal next_output_chan          : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal next_output_chan_selected : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal next_output_chan_credits  : unsigned(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0) := (others => '0');
    signal ignore_output_chan        : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal ignore_output_chan_enable : std_logic := '0';
    
    signal credit_list_output : credit_list_output_t(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	
	--shorthands	
	signal trnside_input_empty : std_logic;
	signal new_out_chan_is_more_full : std_logic;
begin
    
    read_enable_out <= '1';
    trnside_input_empty        <= '1' when credit_list_output(to_integer(unsigned(next_output_chan_out))) = (2**MEMORY_DEPTH_LOG2_OUTPUT-1) else '0';
    new_out_chan_is_more_full  <= '1' when unsigned(credit_list_output(to_integer(next_output_chan))) < next_output_chan_credits else '0';
    output_chan_schedule: process (clk)
    begin
        if rising_edge(clk) then
            if is0(rst_n) then
                next_output_chan_out <= (others => '0');
                next_output_chan <= (others => '0');
                next_output_skip_prftchd_data_out <= '0';
            else
                next_output_skip_prftchd_data_out <= '0';
            
                if is1(change_output_chan_req OR trnside_input_empty) then
                    next_output_chan_out <= std_logic_vector(next_output_chan_selected);
                    ignore_output_chan <= unsigned(next_output_chan_out);
                    ignore_output_chan_enable <= change_output_chan_req;
                    if next_output_chan_out /= std_logic_vector(next_output_chan_selected) then
                        next_output_skip_prftchd_data_out <= '1';
                    end if;
                end if;
                
                next_output_chan <= next_output_chan + 1; 
                
                if is1(new_out_chan_is_more_full) OR (next_output_chan = next_output_chan_selected) then
                    if (ignore_output_chan = next_output_chan) AND is1(ignore_output_chan_enable) then
                        ignore_output_chan_enable <= '0';
                    else
                        next_output_chan_selected <= next_output_chan;
                        next_output_chan_credits <= unsigned(credit_list_output(to_integer(next_output_chan)));
                    end if;
                end if;
                
            end if;
        end if;
    end process;
    
    credit_list_remap: process (credits_list_out_output)
    begin
        for i in 0 to 2**VIRTUAL_PORT_CNT_LOG2-1 loop
            credit_list_output(i) <= unsigned(credits_list_out_output((i+1)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto i*MEMORY_DEPTH_LOG2_OUTPUT));
        end loop;
    end process;
    
    assert MAX_CORE_PIPLINE_DEPTH >= 8 report "roundrobin_scheduler: It is recommended to choose at least 8 for MAX_CORE_PIPLINE_DEPTH" severity warning;

end Behavioral;
