library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
	use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;

entity vaxis_round_robin_st_shell_tb is
end vaxis_round_robin_st_shell_tb;

architecture Behavioral of vaxis_round_robin_st_shell_tb is

	constant TUPPLE_COUNT : natural := 4;
    constant OFFLOAD_DEST_REPLACEMENT : boolean := true;
	constant OFFLOAD_RETURN_HANDLING : boolean := true;
    constant VIRTUAL_PORT_CNT_LOG2 : natural := 2;
	constant MEMORY_DEPTH_LOG2_INPUT : natural := 6;
	constant MEMORY_DEPTH_LOG2_OUTPUT : natural := 6;
	constant ALMOST_FULL_LEVEL_INPUT : natural := 8;
    constant ALMOST_FULL_LEVEL_OUTPUT : natural := 8;
	constant MEMORY_TYPE_INPUT : string := "block";
    constant MEMORY_TYPE_OUTPUT : string := "block";

    constant SWITCH_PORT_CNT : natural := 6;
    constant DUMMY_PORTS : natural := 4;
    constant DUMMY_CONNECTION_VEC : int_vec(DUMMY_PORTS-1 downto 0) := (3,1,0,2); 

	constant CDEST_PARSE_OFFSET : natural := 4;
	constant CDEST_PARSE_LENGTH : natural := 4;
	constant GATEWAY_ADDR_OFFSET : natural := 8;
	constant GATEWAY_ADDR_LENGTH : natural := 4;
	constant SUBNET_IDENTITY     : natural := 0;
	constant ENABLE_INTERNETWORK_ROUTING : boolean := true;
    
    type sim_stream_group is record
        tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
        status  : stream_status;
    end record;
    type sim_stream_group_vec is array (natural range <>) of sim_stream_group; 
    
    signal ap_clk : std_logic := '1';
	signal rst_n : std_logic := '0';
	
    signal credits_list_out_input : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    signal credits_list_out_output : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
	
    signal stream_core_s_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_core_s_status  : stream_status;
	signal stream_core_s_ready   : std_logic;
	signal stream_core_s_ldest   : slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);

    signal stream_core_m_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_core_m_status  : stream_status;
	signal stream_core_m_ready   : std_logic;

    signal sw_stream_s_blob  : sim_stream_group_vec(SWITCH_PORT_CNT-1 downto 0);
    signal sw_stream_s_ready : slv(SWITCH_PORT_CNT-1 downto 0);

    signal sw_stream_m_blob  : sim_stream_group_vec(SWITCH_PORT_CNT-1 downto 0);
    signal sw_stream_m_ready : slv(SWITCH_PORT_CNT-1 downto 0);

    constant clock_period : time := 2ns;
    constant rand_spec  : lfsr_spec := new_lfsr_iterator(64, true);
    signal rand_vec : std_logic_vector(64-1 downto 0) := init_lfsr(rand_spec);
    
    signal core_busy_emulation : std_logic;
    signal activate_producers : std_logic;
    signal shutdown_producers : std_logic := '0';
    signal slave_error_vec : slv(DUMMY_PORTS-1 downto 0);
begin

    ap_clk <= NOT ap_clk after clock_period/2;
    rst_n <= '1' after clock_period*100;

    rand_vec <= step(rand_spec, rand_vec) after clock_period;

    shutdown_producers <= '1' after 10us;

    stream_core_s_tuples <= stream_core_m_tuples;
    stream_core_s_status <= stream_core_m_status;
    stream_core_m_ready  <= stream_core_s_ready;
    stream_core_s_ldest  <= stream_core_m_status.cdest(VIRTUAL_PORT_CNT_LOG2-1 downto 0);

    system_setup: entity libramen.fixed_configuration_controller
    generic map (
        INSTR_LIST => (256+0, 2, DUMMY_CONNECTION_VEC(0)*16,
                       256+1, 2, DUMMY_CONNECTION_VEC(1)*16,
                       256+2, 2, DUMMY_CONNECTION_VEC(2)*16,
                       256+3, 2, DUMMY_CONNECTION_VEC(3)*16,
                       256+0, 1, 4*16,
                       256+1, 1, 4*16,
                       256+2, 1, 4*16,
                       256+3, 1, 4*16)   
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        finished => activate_producers,
        
        stream_m_tuples(0) => sw_stream_s_blob(5).tuples(0),
        stream_m_status => sw_stream_s_blob(5).status,
        stream_m_ready  => sw_stream_s_ready(5)
    );
    sw_stream_s_blob(5).tuples(TUPPLE_COUNT-1 downto 1) <= (others => (others => (others => '0')));
    sw_stream_m_ready(5) <= '1';

    producers: for i in 0 to DUMMY_PORTS-1 generate
        signal stream_tmp_tuples  : tuple_vec(0 downto 0);
        signal stream_tmp_status : stream_status;
        signal stream_tmp_ready : std_logic;
    begin
        producer_instance: entity libramen.test_seq_gen
        generic map (
            CDEST_VAL => 256+i,
            RANDOMIZE_CDEST => false,
            SEED => i,
            TEST_PAYLOAD => DUMMY_CONNECTION_VEC(i),
            RANDOM_YIELDS => true
        ) port map (
            clk => ap_clk,
            rstn => rst_n,
            
            active => activate_producers AND NOT(shutdown_producers),
            
            stream_m_tuples(0) => stream_tmp_tuples(0),
            stream_m_status => stream_tmp_status,
            stream_m_ready  => stream_tmp_ready
        );
        
        producer_fc: entity libramen.vaxis_congestion_backoff
        generic map (
            TUPPLE_COUNT => 1,
            BACKOFF_DETECTION_PERIOD => DEFAULT_BACKOFF_DETECTION_PERIOD,
            CIRCUIT_SETUP_PROBE_PERIOD => DEFAULT_CIRCUIT_SETUP_PROBE_PERIOD
        ) port map (
            clk => ap_clk,
            rstn => rst_n,
            
            backoff => OPEN,
            
            stream_s_tuples(0)  => stream_tmp_tuples(0),
            stream_s_status => stream_tmp_status,
            stream_s_ready => stream_tmp_ready,
            
            stream_m_tuples(0) => sw_stream_s_blob(i+1).tuples(0),
            stream_m_status => sw_stream_s_blob(i+1).status,
            stream_m_ready  => sw_stream_s_ready(i+1)
        );
        sw_stream_s_blob(i+1).tuples(TUPPLE_COUNT-1 downto 1) <= (others => (others => (others => '0')));
    end generate;

    recievers:  for i in 0 to DUMMY_PORTS-1 generate
        reciever_instance: entity libramen.test_seq_chk
        generic map (
            TEST_PAYLOAD => i,
            RANDOM_READY_SIG => false
        ) port map (
            clk => ap_clk,
            rstn => rst_n,
            
            slave_error_interrupt => slave_error_vec(i),
            
            stream_s_tuples(0) => sw_stream_m_blob(i+1).tuples(0),
            stream_s_status    => sw_stream_m_blob(i+1).status,
            stream_s_ready  => sw_stream_m_ready(i+1)
        );
    end generate;

    switch: entity libramen.switch
    generic map (
        TUPPLE_COUNT => TUPPLE_COUNT, 
        INPORT_CNT   => SWITCH_PORT_CNT,
        OUTPORT_CNT  => SWITCH_PORT_CNT,
        CDEST_PARSE_OFFSET => CDEST_PARSE_OFFSET,
        CDEST_PARSE_LENGTH => CDEST_PARSE_LENGTH,
        GATEWAY_ADDR_OFFSET => GATEWAY_ADDR_OFFSET,
        GATEWAY_ADDR_LENGTH => GATEWAY_ADDR_LENGTH,
        SUBNET_IDENTITY     => SUBNET_IDENTITY,
        ENABLE_INTERNETWORK_ROUTING => ENABLE_INTERNETWORK_ROUTING,
        CONNECTION_MATRIX => ('1', '1', '1', '1', '1', '1',
                              '1', '0', '0', '0', '0', '0',
                              '1', '0', '0', '0', '0', '0',
                              '1', '0', '0', '0', '0', '0',
                              '1', '0', '0', '0', '0', '0',
                              '1', '0', '0', '0', '0', '0')
    ) port map (
        clk => ap_clk,
        rstn => rst_n,
    
        stream_s_tuples(1*TUPPLE_COUNT-1 downto 0*TUPPLE_COUNT) => sw_stream_s_blob(0).tuples,
        stream_s_tuples(2*TUPPLE_COUNT-1 downto 1*TUPPLE_COUNT) => sw_stream_s_blob(1).tuples,
        stream_s_tuples(3*TUPPLE_COUNT-1 downto 2*TUPPLE_COUNT) => sw_stream_s_blob(2).tuples,
        stream_s_tuples(4*TUPPLE_COUNT-1 downto 3*TUPPLE_COUNT) => sw_stream_s_blob(3).tuples,
        stream_s_tuples(5*TUPPLE_COUNT-1 downto 4*TUPPLE_COUNT) => sw_stream_s_blob(4).tuples,
        stream_s_tuples(6*TUPPLE_COUNT-1 downto 5*TUPPLE_COUNT) => sw_stream_s_blob(5).tuples,
        stream_s_status(0) => sw_stream_s_blob(0).status,
        stream_s_status(1) => sw_stream_s_blob(1).status,
        stream_s_status(2) => sw_stream_s_blob(2).status,
        stream_s_status(3) => sw_stream_s_blob(3).status,
        stream_s_status(4) => sw_stream_s_blob(4).status,
        stream_s_status(5) => sw_stream_s_blob(5).status,
        stream_s_ready   => sw_stream_s_ready,
        
        stream_m_tuples(1*TUPPLE_COUNT-1 downto 0*TUPPLE_COUNT) => sw_stream_m_blob(0).tuples,
        stream_m_tuples(2*TUPPLE_COUNT-1 downto 1*TUPPLE_COUNT) => sw_stream_m_blob(1).tuples,
        stream_m_tuples(3*TUPPLE_COUNT-1 downto 2*TUPPLE_COUNT) => sw_stream_m_blob(2).tuples,
        stream_m_tuples(4*TUPPLE_COUNT-1 downto 3*TUPPLE_COUNT) => sw_stream_m_blob(3).tuples,
        stream_m_tuples(5*TUPPLE_COUNT-1 downto 4*TUPPLE_COUNT) => sw_stream_m_blob(4).tuples,
        stream_m_tuples(6*TUPPLE_COUNT-1 downto 5*TUPPLE_COUNT) => sw_stream_m_blob(5).tuples,
        stream_m_status(0) => sw_stream_m_blob(0).status,
        stream_m_status(1) => sw_stream_m_blob(1).status,
        stream_m_status(2) => sw_stream_m_blob(2).status,
        stream_m_status(3) => sw_stream_m_blob(3).status,
        stream_m_status(4) => sw_stream_m_blob(4).status,
        stream_m_status(5) => sw_stream_m_blob(5).status,
        stream_m_ready   => sw_stream_m_ready
    );

    uut: entity libramen.round_robin_st_shell
    generic map (
        --IO settings
        TUPPLE_COUNT => TUPPLE_COUNT,
        
        --Offload common vaxis tasks
        OFFLOAD_DEST_REPLACEMENT => OFFLOAD_DEST_REPLACEMENT,
        OFFLOAD_RETURN_HANDLING => OFFLOAD_RETURN_HANDLING,
        
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
        
        credits_list_out_input => credits_list_out_input,
        credits_list_out_output => credits_list_out_output,
        
        stream_core_s_tuples  => stream_core_s_tuples,
        stream_core_s_status  => stream_core_s_status,
        stream_core_s_ready   => stream_core_s_ready,
        stream_core_s_ldest   => stream_core_s_ldest,
        
        stream_core_m_tuples => stream_core_m_tuples ,
        stream_core_m_status => stream_core_m_status ,
        stream_core_m_ready  => stream_core_m_ready  ,
        
        stream_ext_s_tuples  => sw_stream_m_blob(0).tuples  ,
        stream_ext_s_status  => sw_stream_m_blob(0).status  ,
        stream_ext_s_ready   => sw_stream_m_ready(0),
        
        stream_ext_m_tuples  => sw_stream_s_blob(0).tuples  ,
        stream_ext_m_status  => sw_stream_s_blob(0).status  ,
        stream_ext_m_ready   => sw_stream_s_ready(0)   
    );

end Behavioral;
