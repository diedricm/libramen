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
    MAX_CORE_PIPELINE_DEPTH   : natural := 8;
    REQUEST_PIPELINE_DEPTH : natural := 3
);
port (
    clk : in std_logic;
    rst_n : in std_logic;

    credits_list_out_input  : in std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2_INPUT)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    credits_list_out_output : in std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2_OUTPUT)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);

	chan_req : in slv(VIRTUAL_PORT_CNT_LOG2_INPUT-1 downto 0);
	chan_req_valid : in std_logic;
	chan_req_ready : out std_logic;

    input_out_chan : in slv(VIRTUAL_PORT_CNT_LOG2_INPUT-1 downto 0);
    input_out_chan_valid : in std_logic;
    
    next_output_chan_inp    : out std_logic_vector(VIRTUAL_PORT_CNT_LOG2_INPUT-1 downto 0);
    read_enable_inp         : out std_logic
);
end request_scheduler;

architecture Behavioral of request_scheduler is
	constant REQUEST_PIPELINE_DEPTH_FIXED : natural := REQUEST_PIPELINE_DEPTH;
	
	type credit_list_input_t is array (natural range <>) of unsigned(MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
	type credit_list_output_t is array (natural range <>) of unsigned(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
    
    signal credit_list_input : credit_list_input_t(2**VIRTUAL_PORT_CNT_LOG2_INPUT-1 downto 0);
    signal credit_list_output : credit_list_output_t(2**VIRTUAL_PORT_CNT_LOG2_OUTPUT-1 downto 0);
    
    type request_blob is record
        chan_id : unsigned(VIRTUAL_PORT_CNT_LOG2_INPUT-1 downto 0);
        valid : std_logic;
        paused : std_logic;
    end record;
    type request_blob_vec is array (natural range <>) of request_blob;
    
    signal req_pipeline :  request_blob_vec(REQUEST_PIPELINE_DEPTH_FIXED-1 downto 0) := (others => (chan_id => (others => '0'), valid => '0', paused => '0'));
    signal req_pipeline_input : request_blob;
	
	--shorthands
	signal recside_input_empty : std_logic;
	signal recside_output_almost_full : std_logic;
	signal new_in_chan_is_more_full : std_logic;
	signal new_in_chan_output_is_full : std_logic;
	
	signal output_credits_tmp : unsigned(VIRTUAL_PORT_CNT_LOG2_OUTPUT-1 downto 0);
begin

    output_credits_tmp <= unsigned(req_pipeline_input.chan_id(VIRTUAL_PORT_CNT_LOG2_INPUT-1 downto VIRTUAL_PORT_CNT_LOG2_INPUT-VIRTUAL_PORT_CNT_LOG2_OUTPUT));
    recside_output_almost_full <= '1' when credit_list_output(to_integer(output_credits_tmp)) < MAX_CORE_PIPELINE_DEPTH else '0';

    req_pipeline_input.chan_id <= unsigned(chan_req) when is1(chan_req_ready) else req_pipeline(REQUEST_PIPELINE_DEPTH_FIXED-1).chan_id;
    req_pipeline_input.valid <= chan_req_valid  when is1(chan_req_ready) else req_pipeline(REQUEST_PIPELINE_DEPTH_FIXED-1).valid AND NOT(input_out_chan_valid);
    req_pipeline_input.paused <= '1' when is1(recside_output_almost_full) else '0'; 

    chan_req_ready <= '1' when
                    --read succesfull
                    ((req_pipeline(REQUEST_PIPELINE_DEPTH_FIXED-1).chan_id = unsigned(input_out_chan) AND is1(req_pipeline(REQUEST_PIPELINE_DEPTH_FIXED-1).valid AND input_out_chan_valid))
                    --OR no req in pipe
                    OR is0(req_pipeline(REQUEST_PIPELINE_DEPTH_FIXED-1).valid))
                    --AND NOT paused
                    AND (is0(req_pipeline(REQUEST_PIPELINE_DEPTH_FIXED-1).paused AND req_pipeline(REQUEST_PIPELINE_DEPTH_FIXED-1).valid))
                    else '0';

    next_output_chan_inp <= std_logic_vector(req_pipeline_input.chan_id);
    read_enable_inp <= req_pipeline_input.valid AND NOT(req_pipeline_input.paused);

    input_chan_schedule: process (clk)
    begin
        if rising_edge(clk) then
            if is1(rst_n) then
                req_pipeline(0) <= req_pipeline_input;
                for i in 1 to REQUEST_PIPELINE_DEPTH_FIXED-1 loop
                    req_pipeline(i) <= req_pipeline(i-1);
                end loop;
            end if;
        end if;
    end process;
    
    credit_list_remap: process (credits_list_out_input, credits_list_out_output)
    begin
        for i in 0 to 2**VIRTUAL_PORT_CNT_LOG2_INPUT-1 loop
            credit_list_input(i) <= unsigned(credits_list_out_input((i+1)*MEMORY_DEPTH_LOG2_INPUT-1 downto i*MEMORY_DEPTH_LOG2_INPUT));
        end loop;
        for i in 0 to 2**VIRTUAL_PORT_CNT_LOG2_OUTPUT-1 loop
            credit_list_output(i) <= unsigned(credits_list_out_output((i+1)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto i*MEMORY_DEPTH_LOG2_OUTPUT));
        end loop;
    end process;
     
    assert REQUEST_PIPELINE_DEPTH > 1 report "REQUEST_PIPELINE_DEPTH must be at least 1!" severity failure;
end Behavioral;
