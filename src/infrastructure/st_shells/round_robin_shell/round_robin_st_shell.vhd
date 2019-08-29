library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity round_robin_st_shell is
generic (
    --IO settings
	TUPPLE_COUNT : natural := 4;
    
    --Offload common vaxis tasks
    OFFLOAD_DEST_REPLACEMENT : boolean := true;
	OFFLOAD_RETURN_HANDLING : boolean := true;
	INPUT_CONTAINS_DATA : boolean := true;
	
	--IN/OUT fifo parameters  
    VIRTUAL_PORT_CNT_LOG2 : natural := 4;
	MEMORY_DEPTH_LOG2_INPUT : natural := 6;
	MEMORY_DEPTH_LOG2_OUTPUT : natural := 6;
	ALMOST_FULL_LEVEL_INPUT : natural := 8;
    ALMOST_FULL_LEVEL_OUTPUT : natural := 8;
	MEMORY_TYPE_INPUT : string := "ultra";
    MEMORY_TYPE_OUTPUT : string := "ultra"
);
Port (

	ap_clk : in std_logic;
	rst_n : in std_logic;
	
    credits_list_out_input : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    credits_list_out_output : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
	
    stream_core_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_core_s_status  : in stream_status;
	stream_core_s_ready   : out std_logic;
	stream_core_s_ldest   : in slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);

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
end round_robin_st_shell;

architecture Behavioral of round_robin_st_shell is
    signal credits_list_out_input_buffer : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    signal credits_list_out_output_buffer : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);

    signal change_output_chan_req : std_logic;
    
    signal next_output_chan_inp : std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal read_enable_inp : std_logic;
    signal next_output_chan_out : std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal read_enable_out : std_logic;
    signal next_output_skip_prftchd_data_out : std_logic;
    
    signal stream_regfilter_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_regfilter_status  : stream_status;
	signal stream_regfilter_ready   : std_logic;
	
    signal stream_destreplace_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_destreplace_status  : stream_status;
	signal stream_destreplace_ready   : std_logic;
	signal stream_destreplace_ldest  : slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
begin

    credits_list_out_input <= credits_list_out_input_buffer;
    credits_list_out_output <= credits_list_out_output_buffer;

    regoffload: entity libramen.regoffload_dest_reply
    generic map (
    	TUPPLE_COUNT => TUPPLE_COUNT,
        OFFLOAD_DEST_REPLACEMENT => OFFLOAD_DEST_REPLACEMENT,
        OFFLOAD_RETURN_HANDLING => OFFLOAD_RETURN_HANDLING,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        INPUT_CONTAINS_DATA => INPUT_CONTAINS_DATA
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        stream_core_s_tuples  => stream_core_s_tuples,
        stream_core_s_status  => stream_core_s_status,
        stream_core_s_ready   => stream_core_s_ready ,
        stream_core_s_ldest   => stream_core_s_ldest ,
        
        stream_core_m_tuples  => stream_core_m_tuples,
        stream_core_m_status  => stream_core_m_status,
        stream_core_m_ready   => stream_core_m_ready , 
        
        stream_ext_s_tuples  => stream_regfilter_tuples,
        stream_ext_s_status  => stream_regfilter_status,
        stream_ext_s_ready   => stream_regfilter_ready ,
        
        stream_ext_m_tuples  => stream_destreplace_tuples,
        stream_ext_m_status  => stream_destreplace_status,
        stream_ext_m_ready   => stream_destreplace_ready ,
        stream_ext_m_ldest   => stream_destreplace_ldest 
    );

    scheduler: entity libramen.roundrobin_scheduler
    generic map (
        VIRTUAL_PORT_CNT_LOG2_INPUT => VIRTUAL_PORT_CNT_LOG2,
        VIRTUAL_PORT_CNT_LOG2_OUTPUT => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2_INPUT => MEMORY_DEPTH_LOG2_INPUT,
        MEMORY_DEPTH_LOG2_OUTPUT => MEMORY_DEPTH_LOG2_OUTPUT,
        MAX_CORE_PIPLINE_DEPTH => ALMOST_FULL_LEVEL_OUTPUT
    ) port map (
        clk => ap_clk,
        rst_n => rst_n,
    
        credits_list_out_input  => credits_list_out_input_buffer,
        credits_list_out_output => credits_list_out_output_buffer,

        change_output_chan_req => change_output_chan_req,
        
        next_output_chan_inp    => next_output_chan_inp,
        read_enable_inp         => read_enable_inp
    );

    fifos: entity libramen.vaxis_multiport_fifo_fc
    generic map (
        --IO settings
        TUPPLE_COUNT => TUPPLE_COUNT,
        
        --IN/OUT fifo parameters
        VIRTUAL_PORT_CNT_LOG2_INPUT => VIRTUAL_PORT_CNT_LOG2,
        VIRTUAL_PORT_CNT_LOG2_OUTPUT => VIRTUAL_PORT_CNT_LOG2,
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
        
        next_output_chan_inp        => next_output_chan_inp,
        read_enable_inp             => read_enable_inp,
        
        stream_core_s_tuples => stream_destreplace_tuples,
        stream_core_s_status => stream_destreplace_status,
        stream_core_s_ready  => stream_destreplace_ready,
        stream_core_s_ldest  => stream_destreplace_ldest,        
        
        stream_core_m_tuples => stream_regfilter_tuples,
        stream_core_m_status => stream_regfilter_status,
        stream_core_m_ready  => stream_regfilter_ready,
        
        stream_ext_s_tuples => stream_ext_s_tuples,
        stream_ext_s_status => stream_ext_s_status,
        stream_ext_s_ready  => stream_ext_s_ready,
        
        stream_ext_m_tuples => stream_ext_m_tuples,
        stream_ext_m_status => stream_ext_m_status,
        stream_ext_m_ready  => stream_ext_m_ready
    );

end Behavioral;