library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity loader_st_unit_controller is
generic (
    VIRTUAL_PORT_CNT_LOG2 : natural := 4;
	MEMORY_DEPTH_LOG2_OUTPUT : natural := 7
);
Port (

	ap_clk : in std_logic;
	rst_n : in std_logic;

    credits_list_out_output_buffer : in std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
	
    stream_core_s_tuples  : in tuple_vec(0 downto 0);
    stream_core_s_status  : in stream_status;
	stream_core_s_ready   : out std_logic;
	
	active_chan : out std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	
    ap_start : out STD_LOGIC;
    ap_done : in STD_LOGIC;
    ap_idle : in STD_LOGIC;
    ap_ready : in STD_LOGIC;
    
    buffer_base : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    tuple_base  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    tuple_high  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    tuple_free  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    new_tuple_base : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    new_tuple_base_vld : IN STD_LOGIC
);
end loader_st_unit_controller;

architecture Behavioral of loader_st_unit_controller is

    constant START_REG_ADDR : natural := 0;
    constant BUFFER_BASE_REG_ADDR : natural := 3;
    constant REQ_TAG_INDEX_REG_ADDR : natural := 4;
    constant REQ_TAG_HIGH_REG_ADDR : natural := 5;
    
    constant TUPLES_PER_BLOCK : natural := 8;
    constant TUPLES_TO_BLOCK_AMOUNT_SHIFT_ADJ : natural := 3;

	type credit_list_output_t is array (natural range <>) of unsigned(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
    signal credit_list_output : credit_list_output_t(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	
	type state_t is (REC_MSG, START_LOADER, WAIT_ON_LOADER);
	signal curr_state : state_t := REC_MSG;
	signal next_state : state_t;
	
	type regslot is record
	   buffer_base : slv(64-1 downto 0);
	   tag_index   : unsigned(32-1 downto 0);
	   tag_high    : unsigned(32-1 downto 0);
	end record;
	type regvec is array(natural range <>) of regslot;
	
	signal chan_active : slv((2**VIRTUAL_PORT_CNT_LOG2)-1 downto 0) := (others => '0');
	signal regmap : regvec((2**VIRTUAL_PORT_CNT_LOG2)-1 downto 0);
	
    signal regwrite_data : slv(63 downto 0);
    signal regwrite_addr : slv(31 downto 0);
    signal regwrite_chan : slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal regwrite_valid : std_logic;
	
	signal output_stream_iterator  : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal output_stream_candidate : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	signal output_stream_candidate_vld : std_logic := '0';
    signal output_stream_candidate_free_tuples : unsigned(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
	
    signal output_stream_selected  : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	signal output_stream_selected_free_tuples : unsigned(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
	
	signal curr_input_chan : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal curr_input_active : std_logic;
begin

   
    ap_start <= '1' when curr_state = START_LOADER else '0';
    buffer_base <= regmap(to_integer(output_stream_selected)).buffer_base;
    tuple_base <= std_logic_vector(regmap(to_integer(output_stream_selected)).tag_index);
    tuple_high <= std_logic_vector(regmap(to_integer(output_stream_selected)).tag_high);
    tuple_free(MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0) <= std_logic_vector(output_stream_selected_free_tuples);
    tuple_free(31 downto MEMORY_DEPTH_LOG2_OUTPUT) <= (others => '0');
    active_chan <= std_logic_vector(output_stream_selected);
    
    stream_core_s_ready <= '1' when curr_state = REC_MSG else '0';
    
    curr_input_chan <= unsigned(stream_core_s_status.cdest(VIRTUAL_PORT_CNT_LOG2-1 downto 0));
    curr_input_active <= chan_active(to_integer(curr_input_chan));
    main: process(ap_clk)
        variable input_reg : integer := to_integer(unsigned(stream_core_s_tuples(0).tag));
    begin
         if rising_edge(ap_clk) then
            if is1(rst_n) then
            
                curr_state <= next_state;
            
                if (curr_state = REC_MSG) then
                    if is1(regwrite_valid) then
                        case (to_integer(unsigned(regwrite_addr))) is
                            when START_REG_ADDR =>          chan_active(to_integer(unsigned(regwrite_chan)))            <= '1';
                            when BUFFER_BASE_REG_ADDR =>    regmap(to_integer(unsigned(regwrite_chan))).buffer_base     <= regwrite_data(63 downto 0);
                            when REQ_TAG_INDEX_REG_ADDR =>  regmap(to_integer(unsigned(regwrite_chan))).tag_index       <= unsigned(regwrite_data(31 downto 0));
                            when REQ_TAG_HIGH_REG_ADDR =>   regmap(to_integer(unsigned(regwrite_chan))).tag_high        <= unsigned(regwrite_data(31 downto 0));
                            when others => report "ERROR in regaccess decoding" severity failure;
                        end case;
                    end if;
                    
                    if (next_state = START_LOADER) then
                        output_stream_selected <= output_stream_candidate;
                        output_stream_selected_free_tuples <= output_stream_candidate_free_tuples;
                    end if;
                    
                else
                    
                    if is1(new_tuple_base_vld) then
                        regmap(to_integer(output_stream_selected)).tag_index <= unsigned(new_tuple_base);
                        if NOT(unsigned(new_tuple_base) < regmap(to_integer(output_stream_selected)).tag_high) then
                            chan_active(to_integer(output_stream_selected)) <= '0';
                        end if;
                    end if;
                    
                end if;
            end if;
        end if;
    end process;
    
    regproc: entity libramen.regfilter
    generic map (
        TUPPLE_COUNT => 1,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        CHAN_ADDR_BY_CDEST => true,
        HIGH_REG_ADDR => REQ_TAG_HIGH_REG_ADDR,
        INPUT_CONTAINS_DATA => false
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        regwrite_data => regwrite_data,
        regwrite_addr => regwrite_addr,
        regwrite_chan => regwrite_chan,
        regwrite_valid => regwrite_valid,
        
        stream_s_tuples  => stream_core_s_tuples,
        stream_s_status  => stream_core_s_status,
        stream_s_ready   => OPEN,
        stream_s_ldest   => (others => '0'),
        
        stream_m_tuples  => OPEN,
        stream_m_status  => OPEN,
        stream_m_ready   => '1',
        stream_m_ldest   => OPEN
    );
    
    select_output_stream: process (ap_clk)
    begin
        if rising_edge(ap_clk) then
            if is1(rst_n) then
            
                if is1(chan_active(to_integer(output_stream_iterator)))
                        AND (credit_list_output(to_integer(output_stream_iterator)) < output_stream_candidate_free_tuples
                            OR is0(output_stream_candidate_vld)
                            OR (output_stream_iterator = output_stream_candidate)
                        ) then
                    output_stream_candidate <= output_stream_iterator;
                    output_stream_candidate_free_tuples <= credit_list_output(to_integer(output_stream_iterator));
                    output_stream_candidate_vld <= '1';
                end if;

                if (curr_state = REC_MSG) AND (next_state = START_LOADER) then
                    output_stream_candidate_vld <= '0';
                end if;

                output_stream_iterator <= output_stream_iterator + 1;
            end if;
        end if;
    end process;
    
    state_transition: process (ALL)
    begin
        next_state <= curr_state;
        
        case curr_state is
            when REC_MSG =>
                if is1(stream_core_s_status.valid AND stream_core_s_ready) then
                    next_state <= REC_MSG;
                elsif is1(output_stream_candidate_vld) then
                    next_state <= START_LOADER;
                end if;
            
            when START_LOADER =>
                if is0(ap_idle) then
                    next_state <= WAIT_ON_LOADER;
                end if;

            
            when WAIT_ON_LOADER =>
                if is1(ap_done) then
                    next_state <= REC_MSG;
                end if;
        
        end case;
    end process;
    
    credit_list_remap: process (credits_list_out_output_buffer)
    begin
        for i in 0 to 2**VIRTUAL_PORT_CNT_LOG2-1 loop
            credit_list_output(i) <= unsigned(credits_list_out_output_buffer((i+1)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto i*MEMORY_DEPTH_LOG2_OUTPUT));
        end loop;
    end process;

end Behavioral;