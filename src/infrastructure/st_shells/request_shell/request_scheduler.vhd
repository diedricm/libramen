library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;

entity request_scheduler is
generic (
    VIRTUAL_PORT_CNT_LOG2_INPUT : natural := 3;
	VIRTUAL_PORT_CNT_LOG2_OUTPUT : natural := 3;
    MEMORY_DEPTH_LOG2_INPUT  : natural := 3;
    MEMORY_DEPTH_LOG2_OUTPUT : natural := 3;
    MAX_CORE_PIPLINE_DEPTH   : natural := 8
);
port (
    clk : in std_logic;
    rst_n : in std_logic;

    credits_list_out_input  : in std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    credits_list_out_output : in std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);

    change_output_chan_req  : in std_logic;
    
    next_output_chan_inp    : out std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    read_enable_inp         : out std_logic;
    
    next_output_chan_out    : out std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    read_enable_out         : out std_logic;
    next_output_skip_prftchd_data_out : out std_logic
);
end request_scheduler;

architecture Behavioral of request_scheduler is
	type credit_list_input_t is array (natural range <>) of unsigned(MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
	type credit_list_output_t is array (natural range <>) of unsigned(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);

    constant spec  : lfsr_spec := new_lfsr_iterator(VIRTUAL_PORT_CNT_LOG2, true);
	
    signal next_input_chan          : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal next_input_chan_selected : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal next_input_chan_credits  : unsigned(MEMORY_DEPTH_LOG2_INPUT-1 downto 0) := (others => '0');
    signal input_chan_req_enable    : std_logic := '1';
    
	signal next_output_chan          : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal next_output_chan_selected : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal next_output_chan_credits  : unsigned(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0) := (others => '0');
    signal ignore_output_chan        : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal ignore_output_chan_enable : std_logic := '0';
    
    signal credit_list_input : credit_list_input_t(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal credit_list_output : credit_list_output_t(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	
	--shorthands
	signal recside_input_empty : std_logic;
	signal recside_output_almost_full : std_logic;
	signal new_in_chan_is_more_full : std_logic;
	signal new_in_chan_output_is_full : std_logic;
	
	signal trnside_input_empty : std_logic;
	signal new_out_chan_is_more_full : std_logic;
begin

    recside_input_empty        <= '1' when credit_list_input(to_integer(unsigned(next_output_chan_inp))) = (2**MEMORY_DEPTH_LOG2_INPUT-1) else '0';
    recside_output_almost_full <= '1' when credit_list_output(to_integer(unsigned(next_output_chan_inp))) < MAX_CORE_PIPLINE_DEPTH else '0';
    new_in_chan_is_more_full   <= '1' when credit_list_input(to_integer(unsigned(next_input_chan))) < next_input_chan_credits else '0';
    new_in_chan_output_is_full <= '1' when credit_list_output(to_integer(unsigned(next_input_chan))) < MAX_CORE_PIPLINE_DEPTH else '0';
    input_chan_schedule: process (clk)
    begin
        if rising_edge(clk) then
            if is0(rst_n) then
                read_enable_inp <= '0';
                next_output_chan_inp <= (others => '0');
            else
                if is1(recside_input_empty OR recside_output_almost_full) then
                    next_output_chan_inp <= std_logic_vector(next_input_chan_selected);
                    read_enable_inp <= input_chan_req_enable;
                    input_chan_req_enable <= '0';
                end if;
                
                if is1(new_in_chan_is_more_full AND NOT(new_in_chan_output_is_full)) then
                    next_input_chan_selected <= next_input_chan;
                    next_input_chan_credits <= credit_list_input(to_integer(unsigned(next_input_chan)));
                    input_chan_req_enable <= '1';
                end if;
                
                if next_input_chan = next_input_chan_selected then
                    if is1(new_in_chan_output_is_full) then
                        next_input_chan_credits <= (others => '1');
                        read_enable_inp <= '0';
                        input_chan_req_enable <= '0';
                    else
                        next_input_chan_credits <= credit_list_input(to_integer(unsigned(next_input_chan)));
                        read_enable_inp <= '1';
                        input_chan_req_enable <= '1';
                    end if;
                end if;
                
                if LFSR_INSTEAD_OF_SEQ_ORDER then
                    next_input_chan <= unsigned(step(spec, std_logic_vector(next_input_chan)));
                else
                    next_input_chan <= next_input_chan + 1; 
                end if;
            end if;

        end if;
    end process;
    
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
                    ignore_output_chan_enable <= '1';
                    if next_output_chan_out /= std_logic_vector(next_output_chan_selected) then
                        next_output_skip_prftchd_data_out <= '1';
                    end if;
                end if;
                
                if LFSR_INSTEAD_OF_SEQ_ORDER then
                    next_output_chan <= unsigned(step(spec, std_logic_vector(next_output_chan)));
                else
                    next_output_chan <= next_output_chan + 1; 
                end if;
                
                if is1(new_out_chan_is_more_full) OR (next_output_chan = next_output_chan_selected) OR NOT(CREDIT_SENSITIVE_SCHEDULE) then
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
    
    credit_list_remap: process (credits_list_out_input, credits_list_out_output)
    begin
        for i in 0 to 2**VIRTUAL_PORT_CNT_LOG2-1 loop
            credit_list_input(i) <= unsigned(credits_list_out_input((i+1)*MEMORY_DEPTH_LOG2_INPUT-1 downto i*MEMORY_DEPTH_LOG2_INPUT));
            credit_list_output(i) <= unsigned(credits_list_out_output((i+1)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto i*MEMORY_DEPTH_LOG2_OUTPUT));
        end loop;
    end process;
    
    assert MAX_CORE_PIPLINE_DEPTH >= 8 report "roundrobin_scheduler: It is recommended to choose at least 8 for CREDIT_SENSITIVE_SCHEDULE" severity warning; 

end Behavioral;
