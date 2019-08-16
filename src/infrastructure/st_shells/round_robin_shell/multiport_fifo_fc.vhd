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
    VIRTUAL_PORT_CNT_LOG2 : natural := 3;
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
	
    credits_list_out_input : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    credits_list_out_output : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
	
    change_output_chan_req_inp  : out std_logic;
    change_input_chan_req_out   : out std_logic;
    change_output_chan_req_out  : out std_logic;
    
    next_output_chan_inp        : in std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    read_enable_inp             : in std_logic;
    next_output_chan_out        : in std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    read_enable_out             : in std_logic;
    next_output_skip_prftchd_data_out : in std_logic;
	
    stream_core_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_core_s_status : in stream_status;
	stream_core_s_ready : out std_logic;
	stream_core_s_ldest : in slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);

    stream_core_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_core_m_status : out stream_status;
	stream_core_m_ready : in std_logic;

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
    signal change_output_chan_req_out_1, change_output_chan_req_out_2 : std_logic;
begin

    change_output_chan_req_out <= change_output_chan_req_out_1 OR change_output_chan_req_out_2;

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
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2 => MEMORY_DEPTH_LOG2_INPUT,
        ALMOST_FULL_LEVEL => ALMOST_FULL_LEVEL_INPUT,
        MEMORY_TYPE => MEMORY_TYPE_INPUT
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        credits_list_out => credits_list_out_input,
        
        almost_full => almost_full,
        almost_empty => change_output_chan_req_inp,
        
        next_output_chan => next_output_chan_inp,
        read_enable => read_enable_inp,
        next_output_skip_prftchd_data => '0',
        
        stream_s_tuples => stream_fc_in_tuples,
        stream_s_status => stream_fc_in_status,
        stream_s_ready  => stream_fc_in_ready,
        stream_s_ldest  => stream_fc_in_status.cdest(VIRTUAL_PORT_CNT_LOG2-1 downto 0),
        
        stream_m_tuples => stream_core_m_tuples,
        stream_m_status => stream_core_m_status,
        stream_m_ready  => stream_core_m_ready,
        stream_m_ldest  => OPEN
    );
    
    output_fifo: entity libramen.multiport_fifo
    generic map  (
        TUPPLE_COUNT => TUPPLE_COUNT,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2 => MEMORY_DEPTH_LOG2_OUTPUT,
        ALMOST_FULL_LEVEL => ALMOST_FULL_LEVEL_OUTPUT,
        MEMORY_TYPE => MEMORY_TYPE_OUTPUT
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        credits_list_out => credits_list_out_output,
        
        almost_full => change_input_chan_req_out,
        almost_empty => change_output_chan_req_out_1,
        
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
    
        backoff => change_output_chan_req_out_2,
        
        stream_s_tuples => stream_fc_out_tuples,
        stream_s_status => stream_fc_out_status,
        stream_s_ready  => stream_fc_out_ready,
        
        stream_m_tuples => stream_ext_m_tuples,
        stream_m_status => stream_ext_m_status,
        stream_m_ready  => stream_ext_m_ready
    );

end Behavioral;