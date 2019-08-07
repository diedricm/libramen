library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;

entity roundrobin_scheduler is
generic (
	LFSR_INSTEAD_OF_SEQ_ORDER : boolean := true;
	CREDIT_SENSITIVE_SCHEDULE : boolean := true;
	
    VIRTUAL_PORT_CNT_LOG2 : natural := 3;
    MEMORY_DEPTH_LOG2_INPUT     : natural := 3;
    MEMORY_DEPTH_LOG2_OUTPUT    : natural := 3
);
port (
    clk : in std_logic;
    rst_n : in std_logic;

    credits_list_out_input  : in std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    credits_list_out_output : in std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);

    change_output_chan_req_inp : in std_logic;
    change_input_chan_req_out  : in std_logic;
    change_output_chan_req_out : in std_logic;

    next_output_chan_inp    : out std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    read_enable_inp         : out std_logic;
    next_output_chan_out    : out std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    read_enable_out         : out std_logic;
    next_output_skip_prftchd_data_out : out std_logic
);
end roundrobin_scheduler;

architecture Behavioral of roundrobin_scheduler is
	type credit_list_input_t is array (natural range <>) of unsigned(MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
	type credit_list_output_t is array (natural range <>) of unsigned(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);

    constant spec_in  : lfsr_spec := new_lfsr_iterator(VIRTUAL_PORT_CNT_LOG2, true);
	constant spec_out : lfsr_spec := new_lfsr_iterator(VIRTUAL_PORT_CNT_LOG2, true);
	
    signal next_input_chan  : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal next_input_chan_selected : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal next_input_chan_credits  : unsigned(MEMORY_DEPTH_LOG2_INPUT-1 downto 0) := (others => '0');
    
	signal next_output_chan : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal next_output_chan_selected : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal next_output_chan_credits  : unsigned(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0) := (others => '0');	
    
    signal credit_list_input : credit_list_input_t(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal credit_list_output : credit_list_output_t(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	
begin

    credit_list_remap: process (credits_list_out_input, credits_list_out_output)
    begin
        for i in 0 to 2**VIRTUAL_PORT_CNT_LOG2-1 loop
            credit_list_input(i) <= unsigned(credits_list_out_input((i+1)*MEMORY_DEPTH_LOG2_INPUT-1 downto i*MEMORY_DEPTH_LOG2_INPUT));
            credit_list_output(i) <= unsigned(credits_list_out_output((i+1)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto i*MEMORY_DEPTH_LOG2_OUTPUT));
        end loop;
    end process;

    read_enable_inp <= '1';
    read_enable_out <= '0';

    input_chan_schedule: process (clk)
        variable selected_credits : unsigned(MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
        variable index : natural;
    begin
        if rising_edge(clk) then
            if is0(rst_n) then
                next_output_chan_inp <= (others => '0');
                next_input_chan <= (others => '0');
            else
                if is1(change_output_chan_req_inp) OR is1(change_input_chan_req_out) then
                    next_output_chan_inp <= std_logic_vector(next_input_chan_selected);
                end if;
                
                if LFSR_INSTEAD_OF_SEQ_ORDER then
                    next_input_chan <= unsigned(step(spec_in, std_logic_vector(next_input_chan)));
                else
                    next_input_chan <= next_input_chan + 1; 
                end if;
                
                selected_credits := unsigned(credit_list_input(to_integer(next_input_chan)));
                if (selected_credits < next_input_chan_credits) OR (next_input_chan = next_input_chan_selected) OR NOT(CREDIT_SENSITIVE_SCHEDULE) then
                    next_input_chan_selected <= next_input_chan;
                    next_input_chan_credits <= selected_credits;
                end if;
                
            end if;
        end if;
    end process;
    
    output_chan_schedule: process (clk)
        variable selected_credits : unsigned(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
        variable index : natural;
    begin
        if rising_edge(clk) then
            if is0(rst_n) then
                next_output_chan_out <= (others => '0');
                next_output_chan <= (others => '0');
                next_output_skip_prftchd_data_out <= '0';
            else
                if is1(change_output_chan_req_out) then
                    next_output_chan_out <= std_logic_vector(next_output_chan_selected);
                end if;
                
                if LFSR_INSTEAD_OF_SEQ_ORDER then
                    next_output_chan <= unsigned(step(spec_out, std_logic_vector(next_output_chan)));
                else
                    next_output_chan <= next_output_chan + 1; 
                end if;
                
                selected_credits := unsigned(credit_list_output(to_integer(next_output_chan)));
                if (selected_credits < next_output_chan_credits) OR (next_output_chan = next_output_chan_selected) OR NOT(CREDIT_SENSITIVE_SCHEDULE) then
                    next_output_chan_selected <= next_output_chan;
                    next_output_chan_credits <= selected_credits;
                end if;
                
            end if;
        end if;
    end process;

end Behavioral;
