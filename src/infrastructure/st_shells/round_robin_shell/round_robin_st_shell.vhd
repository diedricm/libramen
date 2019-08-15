library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity vaxis_round_robin_st_shell is
generic (
    --IO settings
	TUPPLE_COUNT : natural := 4;
    
    --Offload common vaxis tasks
    OFFLOAD_DEST_REPLACEMENT : boolean := true;
	OFFLOAD_RETURN_HANDLING : boolean := true;
	
	--Set scheduling parameters
	LFSR_INSTEAD_OF_SEQ_ORDER : boolean := true;
	CREDIT_SENSITIVE_SCHEDULE : boolean := true;
	
	--IN/OUT fifo parameters
    VIRTUAL_PORT_CNT_LOG2 : natural := 4;
	MEMORY_DEPTH_LOG2_INPUT : natural := 2;
	MEMORY_DEPTH_LOG2_OUTPUT : natural := 2;
	ALMOST_FULL_LEVEL_INPUT : natural := 4;
    ALMOST_FULL_LEVEL_OUTPUT : natural := 4;
	MEMORY_TYPE_INPUT : string := "distributed";
    MEMORY_TYPE_OUTPUT : string := "distributed"
);
Port (

	ap_clk : in std_logic;
	rst_n : in std_logic;
	
    credits_list_out_input : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    credits_list_out_output : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
	
    stream_core_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_core_s_status  : in stream_status;
	stream_core_s_ready   : out std_logic;
	stream_core_s_ldest   : in unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);

    stream_core_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_core_m_status  : out stream_status;
	stream_core_m_ready   : in std_logic;

    stream_ext_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_ext_s_status  : in stream_status;
	stream_ext_s_ready   : out std_logic;
	
    stream_ext_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_ext_m_status  : out stream_status;
	stream_ext_m_ready   : in std_logic
);
end vaxis_round_robin_st_shell;

architecture Behavioral of vaxis_round_robin_st_shell is
    signal credits_list_out_input_buffer : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    signal credits_list_out_output_buffer : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);

    signal change_output_chan_req_inp : std_logic;
    signal change_input_chan_req_out : std_logic;
    signal change_output_chan_req_out : std_logic;
    
    signal next_output_chan_inp : std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal read_enable_inp : std_logic;
    signal next_output_chan_out : std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal read_enable_out : std_logic;
    signal next_output_skip_prftchd_data_out : std_logic;
    
    signal stream_regfilter_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_regfilter_status  : stream_status;
	signal stream_regfilter_ready   : std_logic;
	
    signal stream_regfilter_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_regfilter_status  : stream_status;
	signal stream_regfilter_ready   : std_logic;
	signal stream_desreplace_ldest  : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
begin

    credits_list_out_input <= credits_list_out_input_buffer;
    credits_list_out_output <= credits_list_out_output_buffer;

    regoffload: entity libramen.regoffload_dest_reply
    generic map (
    	TUPPLE_COUNT => TUPPLE_COUNT,
        OFFLOAD_DEST_REPLACEMENT => OFFLOAD_DEST_REPLACEMENT,
        OFFLOAD_RETURN_HANDLING => OFFLOAD_RETURN_HANDLING,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        stream_core_s  => stream_core_s,
        ready_core_s  => ready_core_s,
        
        stream_core_m  => stream_core_m, 
        ready_core_m => ready_core_m,
        
        stream_ext_s  => stream_regfilter,
        ready_ext_s => ready_regfilter,
        
        stream_ext_m  => stream_destreplace,
        ready_ext_m => ready_destreplace
    );

    scheduler: entity libramen.roundrobin_scheduler
    generic map (
        LFSR_INSTEAD_OF_SEQ_ORDER => LFSR_INSTEAD_OF_SEQ_ORDER, 
        CREDIT_SENSITIVE_SCHEDULE => CREDIT_SENSITIVE_SCHEDULE, 
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2_INPUT => MEMORY_DEPTH_LOG2_INPUT,
        MEMORY_DEPTH_LOG2_OUTPUT => MEMORY_DEPTH_LOG2_OUTPUT
    ) port map (
        clk => ap_clk,
        rst_n => rst_n,
    
        credits_list_out_input  => credits_list_out_input_buffer,
        credits_list_out_output => credits_list_out_output_buffer,

        change_output_chan_req_inp => change_output_chan_req_inp,
        change_input_chan_req_out  => change_input_chan_req_out,
        change_output_chan_req_out => change_output_chan_req_out,
    
        next_output_chan_inp    => next_output_chan_inp,
        read_enable_inp         => read_enable_inp,
        next_output_chan_out    => next_output_chan_out,
        read_enable_out         => read_enable_out,
        next_output_skip_prftchd_data_out => next_output_skip_prftchd_data_out
    );

    fifos: entity libramen.vaxis_multiport_fifo_fc
    generic map (
        --IO settings
        TUPPLE_COUNT => TUPPLE_COUNT,
        
        --IN/OUT fifo parameters
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2_INPUT => MEMORY_DEPTH_LOG2_INPUT,
        MEMORY_DEPTH_LOG2_OUTPUT => MEMORY_DEPTH_LOG2_OUTPUT,
        ALMOST_FULL_LEVEL_INPUT => ALMOST_FULL_LEVEL_INPUT,
        ALMOST_FULL_LEVEL_OUTPUT => ALMOST_FULL_LEVEL_OUTPUT,
        MEMORY_TYPE_INPUT => MEMORY_TYPE_INPUT,
        MEMORY_TYPE_OUTPUT => MEMORY_TYPE_OUTPUT
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        credits_list_out_input => credits_list_out_input_buffer,
        credits_list_out_output => credits_list_out_output_buffer,
        
        
        change_output_chan_req_inp  => change_output_chan_req_inp,
        change_input_chan_req_out   => change_input_chan_req_out,
        change_output_chan_req_out  => change_output_chan_req_out,
        
        next_output_chan_inp        => next_output_chan_inp,
        read_enable_inp             => read_enable_inp,
        next_output_chan_out        => next_output_chan_out,
        read_enable_out             => read_enable_out,
        next_output_skip_prftchd_data_out => next_output_skip_prftchd_data_out,
        
        stream_core_s => stream_destreplace,
        ready_core_s  => ready_destreplace,
        
        stream_core_m => stream_regfilter,
        ready_core_m  => ready_regfilter,
        
        stream_ext_s => stream_ext_s,
        ready_ext_s => ready_ext_s,
        
        stream_ext_m => stream_ext_m,
        ready_ext_m => ready_ext_m
    );

end Behavioral;