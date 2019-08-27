library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
	use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;

entity request_st_shell_tb is
end request_st_shell_tb;

architecture Behavioral of request_st_shell_tb is

	constant TUPPLE_COUNT : natural := 1;
    constant VIRTUAL_PORT_CNT_LOG2 : natural := 2;
	constant MEMORY_DEPTH_LOG2_INPUT : natural := 8;
	constant MEMORY_DEPTH_LOG2_OUTPUT : natural := 8;
	constant ALMOST_FULL_LEVEL_INPUT : natural := 12;
    constant ALMOST_FULL_LEVEL_OUTPUT : natural := 12;
	constant MEMORY_TYPE_INPUT : string := "distributed";
    constant MEMORY_TYPE_OUTPUT : string := "distributed";

    constant SWITCH_PORT_CNT : natural := 5;
    constant DUMMY_PORTS : natural := 4;

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
    signal slave_error_vec : slv(DUMMY_PORTS-1 downto 0);
    
    signal chan_req : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
	signal chan_req_valid : std_logic;
	signal chan_req_ready : std_logic;
	signal posted_chan_req : slv(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
	signal recieved_chan_rpl : slv(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
begin

    ap_clk <= NOT ap_clk after clock_period/2;
    rst_n <= '1' after clock_period*100;

    rand_vec <= step(rand_spec, rand_vec) after clock_period;

    chan_req_valid <= or_reduce(NOT posted_chan_req);
    simulated_core: process (ALL)
        variable posted_chan_req_tmp : slv(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
        variable recieved_chan_rpl_tmp : slv(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    begin
        if rising_edge(ap_clk) and is1(rst_n) then
            posted_chan_req_tmp := posted_chan_req;
            recieved_chan_rpl_tmp := recieved_chan_rpl;
            
            if is1(chan_req_valid AND chan_req_ready) then
                posted_chan_req_tmp(to_integer(unsigned(chan_req))) := '1';
                for i in 0 to 2**VIRTUAL_PORT_CNT_LOG2-1 loop
                    if is0(posted_chan_req_tmp(i)) then
                        chan_req <= to_unsigned(i, VIRTUAL_PORT_CNT_LOG2);
                        exit;
                    end if;
                end loop;
            end if;
            
            if is1(stream_core_m_ready AND stream_core_m_status.valid) then
                recieved_chan_rpl_tmp(to_integer(unsigned(stream_core_m_status.cdest(VIRTUAL_PORT_CNT_LOG2-1 downto 0)))) := '1';
                if is1(recieved_chan_rpl_tmp) then
                    recieved_chan_rpl_tmp := (others => '0');
                    posted_chan_req_tmp := (others => '0');
                end if;
            end if;
            
            posted_chan_req <= posted_chan_req_tmp;
            recieved_chan_rpl <= recieved_chan_rpl_tmp;
        end if;
        
        stream_core_m_ready  <= stream_core_s_ready;
        stream_core_s_tuples <= stream_core_m_tuples;
        stream_core_s_ldest  <= stream_core_m_status.cdest(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
        stream_core_s_status <= stream_core_m_status;
        stream_core_s_status.cdest(7 downto 4) <= stream_core_m_status.cdest(3 downto 0);
        stream_core_s_status.cdest(3 downto 0) <= (others => '0');
        stream_core_s_status.cdest(CDEST_SIZE_IN_BIT-1 downto 8) <= (others => '0');
    end process;

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
            TEST_PAYLOAD => i+1,
            RANDOM_YIELDS => true
        ) port map (
            clk => ap_clk,
            rstn => rst_n,
            
            active => '1',
            
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
            TEST_PAYLOAD => i+1
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
        CONNECTION_MATRIX => ('1', '1', '1', '1', '1',
                              '1', '0', '0', '0', '0',
                              '1', '0', '0', '0', '0',
                              '1', '0', '0', '0', '0',
                              '1', '0', '0', '0', '0')
    ) port map (
        clk => ap_clk,
        rstn => rst_n,
    
        stream_s_tuples(1*TUPPLE_COUNT-1 downto 0*TUPPLE_COUNT) => sw_stream_s_blob(0).tuples,
        stream_s_tuples(2*TUPPLE_COUNT-1 downto 1*TUPPLE_COUNT) => sw_stream_s_blob(1).tuples,
        stream_s_tuples(3*TUPPLE_COUNT-1 downto 2*TUPPLE_COUNT) => sw_stream_s_blob(2).tuples,
        stream_s_tuples(4*TUPPLE_COUNT-1 downto 3*TUPPLE_COUNT) => sw_stream_s_blob(3).tuples,
        stream_s_tuples(5*TUPPLE_COUNT-1 downto 4*TUPPLE_COUNT) => sw_stream_s_blob(4).tuples,
        stream_s_status(0) => sw_stream_s_blob(0).status,
        stream_s_status(1) => sw_stream_s_blob(1).status,
        stream_s_status(2) => sw_stream_s_blob(2).status,
        stream_s_status(3) => sw_stream_s_blob(3).status,
        stream_s_status(4) => sw_stream_s_blob(4).status,
        stream_s_ready   => sw_stream_s_ready,
        
        stream_m_tuples(1*TUPPLE_COUNT-1 downto 0*TUPPLE_COUNT) => sw_stream_m_blob(0).tuples,
        stream_m_tuples(2*TUPPLE_COUNT-1 downto 1*TUPPLE_COUNT) => sw_stream_m_blob(1).tuples,
        stream_m_tuples(3*TUPPLE_COUNT-1 downto 2*TUPPLE_COUNT) => sw_stream_m_blob(2).tuples,
        stream_m_tuples(4*TUPPLE_COUNT-1 downto 3*TUPPLE_COUNT) => sw_stream_m_blob(3).tuples,
        stream_m_tuples(5*TUPPLE_COUNT-1 downto 4*TUPPLE_COUNT) => sw_stream_m_blob(4).tuples,
        stream_m_status(0) => sw_stream_m_blob(0).status,
        stream_m_status(1) => sw_stream_m_blob(1).status,
        stream_m_status(2) => sw_stream_m_blob(2).status,
        stream_m_status(3) => sw_stream_m_blob(3).status,
        stream_m_status(4) => sw_stream_m_blob(4).status,
        stream_m_ready   => sw_stream_m_ready
    );

	uut: entity libramen.request_st_shell
	generic map (
		--IO settings
		TUPPLE_COUNT => TUPPLE_COUNT ,
		
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
		
        credits_list_out_input => credits_list_out_input,
        credits_list_out_output => credits_list_out_output,
		
		chan_req => std_logic_vector(chan_req),
		chan_req_valid => chan_req_valid,
		chan_req_ready => chan_req_ready, 
		
		stream_core_s_tuples  => stream_core_s_tuples,
		stream_core_s_status  => stream_core_s_status,
		stream_core_s_ready   => stream_core_s_ready,
		stream_core_s_ldest   => stream_core_s_ldest,

		stream_core_m_tuples  => stream_core_m_tuples,
		stream_core_m_status  => stream_core_m_status,
		stream_core_m_ready   => stream_core_m_ready,

		stream_ext_s_tuples  => sw_stream_m_blob(0).tuples,
		stream_ext_s_status  => sw_stream_m_blob(0).status,
		stream_ext_s_ready   => sw_stream_m_ready(0),
		
		stream_ext_m_tuples  => sw_stream_s_blob(0).tuples,
		stream_ext_m_status  => sw_stream_s_blob(0).status,
		stream_ext_m_ready   => sw_stream_s_ready(0)
	);

end Behavioral;
