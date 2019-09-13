library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity store_st_unit_controller is
generic (
    VIRTUAL_PORT_CNT_LOG2 : natural := 4;
	MEMORY_DEPTH_LOG2_INPUT : natural := 7
);
Port (

	ap_clk : in std_logic;
	rst_n : in std_logic;

    credits_list_out_input_buffer : in std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
	
    chan_req : out slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	chan_req_valid : out std_logic;
	chan_req_ready : in std_logic;
	chan_clear_outstanding : out std_logic;
	
    stream_s_tuples  : in tuple_vec(4-1 downto 0);
    stream_s_status  : in stream_status;
	stream_s_ready   : out std_logic;

    stream_m_tuples  : out tuple_vec(4-1 downto 0);
    stream_m_status  : out stream_status;
	stream_m_ready   : in std_logic;
	
    ap_start : out STD_LOGIC;
    ap_done : in STD_LOGIC;
    ap_idle : in STD_LOGIC;
    ap_ready : in STD_LOGIC;
    
    regentry_active : out STD_LOGIC_VECTOR(0 DOWNTO 0);
    regentry_buffer_base : out STD_LOGIC_VECTOR(63 DOWNTO 0);
    regentry_buffer_iterator : out STD_LOGIC_VECTOR(31 DOWNTO 0);
    regentry_buffer_length : out STD_LOGIC_VECTOR(31 DOWNTO 0);
    regentry_return_addr : out STD_LOGIC_VECTOR(13 DOWNTO 0);
    regentry_return_value : out STD_LOGIC_VECTOR(7 DOWNTO 0);
    free_credits_in_buffer : out STD_LOGIC_VECTOR(11 DOWNTO 0);
    agg_result : in STD_LOGIC_VECTOR(31 DOWNTO 0)
);
end store_st_unit_controller;

architecture Behavioral of store_st_unit_controller is

    constant START_REG_ADDR : natural := 0;
    constant RETURN_DEST_REG_ADDR : natural := 1;
    constant BUFFER_BASE_REG_ADDR : natural := 3;
    constant REQ_TAG_INDEX_REG_ADDR : natural := 4;
    constant REQ_TAG_HIGH_REG_ADDR : natural := 5;
    
    constant TUPLES_PER_BLOCK : natural := 8;
    constant TUPLES_TO_BLOCK_AMOUNT_SHIFT_ADJ : natural := 3;

	type credit_list_input_t is array (natural range <>) of unsigned(MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    signal credit_list_input : credit_list_input_t(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	
	type state_t is (REC_MSG, START_LOADER, WAIT_ON_LOADER);
	signal curr_state : state_t := REC_MSG;
	signal next_state : state_t;
	
	type regslot is record
	   buffer_base : slv(64-1 downto 0);
	   tag_index   : unsigned(32-1 downto 0);
	   tag_high    : unsigned(32-1 downto 0);
	   return_dest : slv(14-1 downto 0);
	   return_value: slv(8-1 downto 0);
	end record;
	type regvec is array(natural range <>) of regslot;
	
	signal chan_active : slv((2**VIRTUAL_PORT_CNT_LOG2)-1 downto 0) := (others => '0');
	signal regmap : regvec((2**VIRTUAL_PORT_CNT_LOG2)-1 downto 0);
	
    signal regwrite_data : slv(63 downto 0);
    signal regwrite_addr : slv(31 downto 0);
    signal regwrite_chan : slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal regwrite_valid : std_logic;
	
	signal input_stream_iterator  : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    signal input_stream_candidate : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	signal input_stream_candidate_vld : std_logic := '0';
    signal input_stream_candidate_avail_quples : unsigned(MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
	
    signal input_stream_selected  : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	signal input_stream_selected_avail_quples : unsigned(MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
	
	signal char_req_counter : unsigned(MEMORY_DEPTH_LOG2_INPUT-1 downto 0) := (others => '0');
	
	signal curr_input_chan : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal curr_input_active : std_logic;
begin
   
    ap_start <= '1' when curr_state = START_LOADER else '0';
    
    regentry_active(0) <= chan_active(to_integer(input_stream_selected));
    regentry_buffer_base <= regmap(to_integer(input_stream_selected)).buffer_base;
    regentry_buffer_iterator <= std_logic_vector(regmap(to_integer(input_stream_selected)).tag_index);
    regentry_buffer_length <= std_logic_vector(regmap(to_integer(input_stream_selected)).tag_high);
    regentry_return_addr <= regmap(to_integer(input_stream_selected)).return_dest;
    regentry_return_value <= regmap(to_integer(input_stream_selected)).return_value;
    
    free_credits_in_buffer <= std_logic_vector(to_unsigned(to_integer(input_stream_selected_avail_quples), 12));
    
    curr_input_chan <= unsigned(stream_s_status.cdest(VIRTUAL_PORT_CNT_LOG2-1 downto 0));
    curr_input_active <= chan_active(to_integer(curr_input_chan));
    main: process(ap_clk)
        variable tmp_branch : boolean;
    begin
         if rising_edge(ap_clk) then
            if is0(rst_n) then
                chan_req_valid <= '0';
            else
                chan_clear_outstanding <= '0';
                chan_req_valid <= '0';
            
                curr_state <= next_state;
           
                if is1(regwrite_valid) then
                    case (to_integer(unsigned(regwrite_addr))) is
                        when START_REG_ADDR =>          chan_active(to_integer(unsigned(regwrite_chan)))            <= '1';
                                                        regmap(to_integer(unsigned(regwrite_chan))).return_value     <= regwrite_data(7 downto 0);
                        when RETURN_DEST_REG_ADDR =>    regmap(to_integer(unsigned(regwrite_chan))).return_dest     <= regwrite_data(13 downto 0);
                        when BUFFER_BASE_REG_ADDR =>    regmap(to_integer(unsigned(regwrite_chan))).buffer_base     <= std_logic_vector(shift_right(unsigned(regwrite_data(63 downto 0)), 6));
                        when REQ_TAG_INDEX_REG_ADDR =>  regmap(to_integer(unsigned(regwrite_chan))).tag_index       <= unsigned(regwrite_data(31 downto 0));
                        when REQ_TAG_HIGH_REG_ADDR =>   regmap(to_integer(unsigned(regwrite_chan))).tag_high        <= unsigned(regwrite_data(31 downto 0));
                        when others => report "ERROR in regaccess decoding" severity failure;
                    end case;
                end if;
                
                tmp_branch := false;
                for i in 0 to 2**VIRTUAL_PORT_CNT_LOG2-1 loop
                    if (credit_list_input(i) < 2**MEMORY_DEPTH_LOG2_INPUT-1) AND is0(chan_active(i)) then
                        chan_req <= std_logic_vector(to_unsigned(i, VIRTUAL_PORT_CNT_LOG2));
                        chan_req_valid <= '1';
                        tmp_branch := true;
                    end if;
                end loop;
                
                if (curr_state = WAIT_ON_LOADER) AND NOT(tmp_branch) then
                    chan_req <= std_logic_vector(input_stream_selected);
                    chan_req_valid <= '1';
                    
                    if is1(chan_req_valid AND chan_req_ready) then
                        if NOT is0(char_req_counter) then
                            char_req_counter <= char_req_counter - 1;
                        else
                            chan_req_valid <= '0';
                        end if;
                    end if;
                    
                    if (is1(stream_s_status.valid AND stream_s_ready) AND is_hardend(stream_s_status)) then
                        char_req_counter <= (others => '0');
                        chan_clear_outstanding <= '1';
                    end if;
                end if;
                
                if (curr_state = REC_MSG) AND (next_state = START_LOADER) then
                    input_stream_selected <= input_stream_candidate;
                    input_stream_selected_avail_quples <= input_stream_candidate_avail_quples;
                end if;
                    
                if (curr_state = START_LOADER) AND (next_state = WAIT_ON_LOADER) then
                    char_req_counter <= to_unsigned(to_integer(2**MEMORY_DEPTH_LOG2_INPUT - 1 - input_stream_selected_avail_quples), MEMORY_DEPTH_LOG2_INPUT);
                end if;
                    
                if (curr_state = WAIT_ON_LOADER) AND (next_state = REC_MSG) then
                    regmap(to_integer(input_stream_selected)).tag_index <= unsigned(agg_result);
                    if NOT(unsigned(agg_result) < regmap(to_integer(input_stream_selected)).tag_high) then
                        chan_active(to_integer(input_stream_selected)) <= '0';
                    end if;
                end if;
                    
            end if;
        end if;
    end process;
    
    select_input_stream: process (ap_clk)
    begin
        if rising_edge(ap_clk) then
            if is1(rst_n) then
                if is1(chan_active(to_integer(input_stream_iterator)))
                        AND (credit_list_input(to_integer(input_stream_iterator)) /= (2**MEMORY_DEPTH_LOG2_INPUT - 1))
                        AND (credit_list_input(to_integer(input_stream_iterator)) < input_stream_candidate_avail_quples
                            OR is0(input_stream_candidate_vld)
                            OR (input_stream_iterator = input_stream_candidate)
                        ) then
                    input_stream_candidate <= input_stream_iterator;
                    input_stream_candidate_avail_quples <= credit_list_input(to_integer(input_stream_iterator));
                    input_stream_candidate_vld <= '1';
                end if;

                if (curr_state = REC_MSG) AND (next_state = START_LOADER) then
                    input_stream_candidate_vld <= '0';
                end if;

                input_stream_iterator <= input_stream_iterator + 1;
            end if;
        end if;
    end process;
    
    regproc: entity libramen.regfilter
    generic map (
        TUPPLE_COUNT => 4,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        CHAN_ADDR_BY_CDEST => false,
        HIGH_REG_ADDR => REQ_TAG_HIGH_REG_ADDR,
        INPUT_CONTAINS_DATA => true
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        regwrite_data => regwrite_data,
        regwrite_addr => regwrite_addr,
        regwrite_chan => regwrite_chan,
        regwrite_valid => regwrite_valid,
        
        stream_s_tuples  => stream_s_tuples,
        stream_s_status  => stream_s_status,
        stream_s_ready   => stream_s_ready,
        stream_s_ldest   => (others => '0'),
        
        stream_m_tuples  => stream_m_tuples,
        stream_m_status  => stream_m_status,
        stream_m_ready   => stream_m_ready,
        stream_m_ldest   => OPEN
    );
    
    state_transition: process (ALL)
    begin
        next_state <= curr_state;
        
        case curr_state is
            when REC_MSG =>
                if is1(stream_s_status.valid AND stream_s_ready) then
                    next_state <= REC_MSG;
                elsif is1(input_stream_candidate_vld) then
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
    
    credit_list_remap: process (credits_list_out_input_buffer)
    begin
        for i in 0 to 2**VIRTUAL_PORT_CNT_LOG2-1 loop
            credit_list_input(i) <= unsigned(credits_list_out_input_buffer((i+1)*MEMORY_DEPTH_LOG2_INPUT-1 downto i*MEMORY_DEPTH_LOG2_INPUT));
        end loop;
    end process;

end Behavioral;