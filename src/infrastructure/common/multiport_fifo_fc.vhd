library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity vaxis_multiport_fifo_fc is
generic (
    --IO settings
	TUPPLE_COUNT : natural := 4;
	
	--IN/OUT fifo parameters
    VIRTUAL_PORT_CNT_LOG2_INPUT : natural := 3;
    VIRTUAL_PORT_CNT_LOG2_OUTPUT : natural := 3;
	MEMORY_DEPTH_LOG2_INPUT : natural := 6;
	MEMORY_DEPTH_LOG2_OUTPUT : natural := 6;
	ALMOST_FULL_LEVEL_INPUT : natural := 16;
    ALMOST_FULL_LEVEL_OUTPUT : natural := 16;
	MEMORY_TYPE_INPUT : string := "block";
    MEMORY_TYPE_OUTPUT : string := "block"
);
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;
	
    credits_list_out_input : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2_INPUT)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    credits_list_out_output : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2_OUTPUT)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
    
    next_output_chan_inp        : in std_logic_vector(VIRTUAL_PORT_CNT_LOG2_INPUT-1 downto 0);
    read_enable_inp             : in std_logic;
    
    stream_core_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_core_s_status : in stream_status;
	stream_core_s_ready : out std_logic;
	stream_core_s_ldest : in slv(VIRTUAL_PORT_CNT_LOG2_OUTPUT-1 downto 0);

    stream_core_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_core_m_status : out stream_status;
	stream_core_m_ready : in std_logic;
	stream_core_m_ldest : out slv(VIRTUAL_PORT_CNT_LOG2_INPUT-1 downto 0);

    stream_ext_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_ext_s_status : in stream_status;
	stream_ext_s_ready : out std_logic;

    stream_ext_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_ext_m_status : out stream_status;
	stream_ext_m_ready : in std_logic
);
end vaxis_multiport_fifo_fc;

architecture Behavioral of vaxis_multiport_fifo_fc is
    signal stream_fc_in_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_fc_in_status : stream_status;
    signal stream_fc_in_ready : std_logic;

    signal stream_fc_out_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_fc_out_status : stream_status;
    signal stream_fc_out_ready : std_logic;
        
    signal almost_full  : std_logic;
    
    signal change_output_chan_req      : std_logic;
    signal next_output_chan_out        : std_logic_vector(VIRTUAL_PORT_CNT_LOG2_OUTPUT-1 downto 0);
    signal read_enable_out             : std_logic;
    signal next_output_skip_prftchd_data_out : std_logic;
begin


    scheduler: entity libramen.multiport_fifo_out_scheduler
    generic map (	
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2_OUTPUT,
        MEMORY_DEPTH_LOG2_OUTPUT => MEMORY_DEPTH_LOG2_OUTPUT
    ) port map (
        clk => ap_clk,
        rst_n => rst_n,
    
        credits_list_out_output => credits_list_out_output,
    
        change_output_chan_req  => change_output_chan_req,
            
        next_output_chan_out    => next_output_chan_out,
        read_enable_out         => read_enable_out,
        next_output_skip_prftchd_data_out => next_output_skip_prftchd_data_out
    );
    

    input_fc: entity libramen.vaxis_congestion_feedback
    generic map (
        TUPPLE_COUNT => TUPPLE_COUNT,
        BACKOFF_DETECTION_PERIOD => DEFAULT_BACKOFF_DETECTION_PERIOD,
        CIRCUIT_SETUP_PROBE_PERIOD => DEFAULT_CIRCUIT_SETUP_PROBE_PERIOD
    ) port map (
        clk => ap_clk,
        rstn => rst_n,
        
        trigger_backoff => almost_full,
    
        stream_s_tuples => stream_ext_s_tuples,
        stream_s_status => stream_ext_s_status,
        stream_s_ready  => stream_ext_s_ready,
        
        stream_m_tuples => stream_fc_in_tuples,
        stream_m_status => stream_fc_in_status,
        stream_m_ready  => stream_fc_in_ready
    );

    input_fifo: entity libramen.multiport_fifo
    generic map  (
        TUPPLE_COUNT => TUPPLE_COUNT,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2_INPUT,
        MEMORY_DEPTH_LOG2 => MEMORY_DEPTH_LOG2_INPUT,
        ALMOST_FULL_LEVEL => ALMOST_FULL_LEVEL_INPUT,
        MEMORY_TYPE => MEMORY_TYPE_INPUT,
        OVERRIDE_DELAY_LINE_LENGTH => 0
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        credits_list_out => credits_list_out_input,
        
        almost_full => almost_full,
        almost_empty => OPEN,
        
        next_output_chan => next_output_chan_inp,
        read_enable => read_enable_inp,
        next_output_skip_prftchd_data => '0',
        
        stream_s_tuples => stream_fc_in_tuples,
        stream_s_status => stream_fc_in_status,
        stream_s_ready  => stream_fc_in_ready,
        stream_s_ldest  => stream_fc_in_status.cdest(VIRTUAL_PORT_CNT_LOG2_INPUT-1 downto 0),
        
        stream_m_tuples => stream_core_m_tuples,
        stream_m_status => stream_core_m_status,
        stream_m_ready  => stream_core_m_ready,
        stream_m_ldest  => stream_core_m_ldest
    );
    
    output_fifo: entity libramen.multiport_fifo
    generic map  (
        TUPPLE_COUNT => TUPPLE_COUNT,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2_OUTPUT,
        MEMORY_DEPTH_LOG2 => MEMORY_DEPTH_LOG2_OUTPUT,
        ALMOST_FULL_LEVEL => ALMOST_FULL_LEVEL_OUTPUT,
        MEMORY_TYPE => MEMORY_TYPE_OUTPUT,
        OVERRIDE_DELAY_LINE_LENGTH => 0
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        credits_list_out => credits_list_out_output,
        
        almost_full => OPEN,
        almost_empty => OPEN,
        
        next_output_chan => next_output_chan_out,
        read_enable => read_enable_out,
        next_output_skip_prftchd_data => next_output_skip_prftchd_data_out,
        
        stream_s_tuples => stream_core_s_tuples,
        stream_s_status => stream_core_s_status,
        stream_s_ready  => stream_core_s_ready,
        stream_s_ldest  => stream_core_s_ldest,
        
        stream_m_tuples => stream_fc_out_tuples,
        stream_m_status => stream_fc_out_status,
        stream_m_ready  => stream_fc_out_ready,
        stream_m_ldest  => OPEN
    );
    
    output_fc: entity libramen.vaxis_congestion_backoff
    generic map (
        TUPPLE_COUNT => TUPPLE_COUNT,
        BACKOFF_DETECTION_PERIOD => DEFAULT_BACKOFF_DETECTION_PERIOD,
        CIRCUIT_SETUP_PROBE_PERIOD => DEFAULT_CIRCUIT_SETUP_PROBE_PERIOD
    ) port map (
        clk => ap_clk,
        rstn => rst_n,
    
        backoff => change_output_chan_req,
        
        stream_s_tuples => stream_fc_out_tuples,
        stream_s_status => stream_fc_out_status,
        stream_s_ready  => stream_fc_out_ready,
        
        stream_m_tuples => stream_ext_m_tuples,
        stream_m_status => stream_ext_m_status,
        stream_m_ready  => stream_ext_m_ready
    );
    
    perf_counter_section: if true generate
        constant DEBUG_PERF_COUNTER_WINSIZE : natural := 1000;
        signal stream_ext_s_debug_active_now : std_logic;
        signal stream_ext_m_debug_active_now : std_logic;
        signal stream_ext_s_debug_activation_window_1k : std_logic_vector(DEBUG_PERF_COUNTER_WINSIZE-1 downto 0) := (others => '0');
        signal stream_ext_m_debug_activation_window_1k : std_logic_vector(DEBUG_PERF_COUNTER_WINSIZE-1 downto 0) := (others => '0');
        signal stream_ext_s_debug_activation_window_num : natural range 0 to DEBUG_PERF_COUNTER_WINSIZE;
        signal stream_ext_m_debug_activation_window_num : natural range 0 to DEBUG_PERF_COUNTER_WINSIZE;
    begin
        stream_ext_s_debug_active_now <= '1' when contains_data(stream_ext_s_status) AND is1(stream_ext_s_status.valid and stream_ext_s_ready) else '0';
        stream_ext_m_debug_active_now <= '1' when contains_data(stream_ext_m_status) AND is1(stream_ext_m_status.valid and stream_ext_m_ready) else '0';
        debug_perf_counter: process(ap_clk)
            variable tmp : natural range 0 to DEBUG_PERF_COUNTER_WINSIZE;
        begin
            if rising_edge(ap_clk) and is1(rst_n) then
                stream_ext_s_debug_activation_window_1k(0) <= stream_ext_s_debug_active_now;
                tmp := to_integer(unsigned(stream_ext_s_debug_activation_window_1k(0 downto 0)));
                for i in 1 to DEBUG_PERF_COUNTER_WINSIZE-1 loop
                    stream_ext_s_debug_activation_window_1k(i) <= stream_ext_s_debug_activation_window_1k(i-1);
                    tmp := tmp + to_integer(unsigned(stream_ext_s_debug_activation_window_1k(i downto i)));
                end loop;
                stream_ext_s_debug_activation_window_num <= tmp;
                
                stream_ext_m_debug_activation_window_1k(0) <= stream_ext_m_debug_active_now;
                tmp := to_integer(unsigned(stream_ext_m_debug_activation_window_1k(0 downto 0)));
                for i in 1 to DEBUG_PERF_COUNTER_WINSIZE-1 loop
                    stream_ext_m_debug_activation_window_1k(i) <= stream_ext_m_debug_activation_window_1k(i-1);
                    tmp := tmp + to_integer(unsigned(stream_ext_m_debug_activation_window_1k(i downto i)));
                end loop;            
                stream_ext_m_debug_activation_window_num <= tmp;
            end if;
        end process;
    end generate;

end Behavioral;