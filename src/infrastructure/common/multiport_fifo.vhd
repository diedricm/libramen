library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity multiport_fifo is
generic (
	TUPPLE_COUNT : natural := 4;
	VIRTUAL_PORT_CNT_LOG2 : natural := 4;
	MEMORY_DEPTH_LOG2 : natural := 6;
	ALMOST_FULL_LEVEL : natural := 8;
	MEMORY_TYPE : string := "block";
	OVERRIDE_DELAY_LINE_LENGTH : natural := 0
);
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;
	
	credits_list_out : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2-1 downto 0);
	
    almost_full : out std_logic;
    almost_empty : out std_logic;
    
	next_output_chan : in std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	read_enable : in std_logic;
	next_output_skip_prftchd_data : in std_logic;
	
	stream_s_tuples : in tuple_vec(TUPPLE_COUNT-1 downto 0);
	stream_s_status : in stream_status;
	stream_s_ready  : out std_logic;
	stream_s_ldest  : in std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	
	stream_m_tuples : out tuple_vec(TUPPLE_COUNT-1 downto 0);
	stream_m_status : out stream_status;
	stream_m_ready  : in std_logic;
	stream_m_ldest  : out std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0)
);
end multiport_fifo;

architecture Behavioral of multiport_fifo is
	
	constant data_width_in_bits : natural := TUPPLE_COUNT*DATA_SINGLE_SIZE_IN_BYTES*8 + CDEST_SIZE_IN_BIT + PTYPE_SIZE_IN_BIT + 2;
	constant addr_width_in_bits : natural := VIRTUAL_PORT_CNT_LOG2 + MEMORY_DEPTH_LOG2;
    constant RAM_PIPELINE_DEPTH : natural := RAM_PIPELINE_DEPTH_lookup(MEMORY_TYPE, OVERRIDE_DELAY_LINE_LENGTH);
	
	subtype mem_ptr is unsigned(MEMORY_DEPTH_LOG2-1 downto 0);
	type mem_ptr_array is array (natural range <>) of mem_ptr;
	subtype chan_id is unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	type addr_delay_item is record
		req_addr : mem_ptr;
		self_chan : chan_id;
		valid : std_logic;
	end record addr_delay_item;
	type addr_delay_line is array (natural range <>) of addr_delay_item;

	--Child signals
	signal read_data_out : std_logic_vector(data_width_in_bits-1 downto 0);
	signal merged_data_write_lane : std_logic_vector(data_width_in_bits-1 downto 0);
	signal merged_addr_write_lane : std_logic_vector(addr_width_in_bits-1 downto 0);
	signal write_enable : std_logic;
	
	--State signals
	signal speculated_read_ptr_list : mem_ptr_array(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => (others => '0'));
	signal actual_read_ptr_list : mem_ptr_array(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => (others => '0'));
	signal write_ptr_list : mem_ptr_array(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0):= (others => (others => '0'));
	
	signal last_write_chan : chan_id := (others => '0');
	signal read_addr_delay_line :  addr_delay_line(RAM_PIPELINE_DEPTH-1 downto 0) := (others => (req_addr => (others => '0'), valid => '0', self_chan => (others => '0')));
	
	signal credits_list : mem_ptr_array(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0)  := (others => (others => '1'));
	signal write_credit_modified : chan_id;
	signal write_credit_modified_valid : std_logic := '0';
	signal read_credit_modified : chan_id;
	signal read_credit_modified_valid : std_logic := '0';
	signal write_credit_modified_final : chan_id;
	signal write_credit_modified_valid_final : std_logic := '0';
	signal read_credit_modified_final : chan_id;
	signal read_credit_modified_valid_final : std_logic := '0';
	
	signal advance_read_pipeline : std_logic;
	
	signal DEBUG_EXPECTED_CREDIT_LIST : mem_ptr_array(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0):= (others => (others => '0'));
begin
    
    --TODO the plus 3 is used to mitigate credit propagation delays. Dont judge me!
    almost_full <= '1' when (credits_list(to_integer(unsigned(stream_s_ldest))) < (ALMOST_FULL_LEVEL + 3)) AND is1(stream_s_status.valid AND stream_s_ready) else '0';            
                
    stream_s_ready <= '1' when credits_list(to_integer(last_write_chan)) > 3 else '0';
    
	stream_m_status.valid <= read_addr_delay_line(0).valid AND NOT(next_output_skip_prftchd_data);
    stream_m_status.ptype <= get_stream_status(read_data_out).ptype;
	stream_m_status.cdest <= get_stream_status(read_data_out).cdest;
	stream_m_status.yield <= get_stream_status(read_data_out).yield;
	stream_m_ldest  <= std_logic_vector(read_addr_delay_line(0).self_chan);
	stream_m_tuples <= get_tuples(read_data_out);
	

    advance_read_pipeline <= stream_m_ready OR NOT(read_addr_delay_line(0).valid);

	read_port_proc: process(ap_clk)
	   variable curr_read_chan : chan_id;
	begin
	
		if rising_edge(ap_clk) then
		  if is1(rst_n) then
                almost_empty <= '0';
                read_credit_modified_valid <= '0';
                
                if is1(advance_read_pipeline) then
                
                    -- delay line forward
                    for i in RAM_PIPELINE_DEPTH-1 downto 1 loop
                        read_addr_delay_line(i-1) <= read_addr_delay_line(i);
                    end loop;
                    read_addr_delay_line(RAM_PIPELINE_DEPTH-1).valid <= '0';
                    
                    -- ack succesful read
                    if is1(stream_m_status.valid) then
                        actual_read_ptr_list(to_integer(read_addr_delay_line(0).self_chan)) <= read_addr_delay_line(0).req_addr + 1;
                        read_credit_modified <= read_addr_delay_line(0).self_chan;
                        read_credit_modified_valid <= '1';
                    end if;
                    
                    --read req
                    if is1(read_enable) then
                        curr_read_chan := unsigned(next_output_chan);
                    
                        read_addr_delay_line(RAM_PIPELINE_DEPTH-1).req_addr <= speculated_read_ptr_list(to_integer(curr_read_chan));
                        read_addr_delay_line(RAM_PIPELINE_DEPTH-1).self_chan <= unsigned(next_output_chan);
                        
                        if (speculated_read_ptr_list(to_integer(curr_read_chan)) /= write_ptr_list(to_integer(curr_read_chan))) then
                            read_addr_delay_line(RAM_PIPELINE_DEPTH-1).valid <= '1';
                            speculated_read_ptr_list(to_integer(curr_read_chan)) <= speculated_read_ptr_list(to_integer(curr_read_chan)) + 1;
                        else
                            almost_empty <= '1';
                        end if;
                    end if;
                end if;
                
                --process skip command                
                if is1(next_output_skip_prftchd_data) then
                    for i in 0 to RAM_PIPELINE_DEPTH-1 loop
                        read_addr_delay_line(i).valid <= '0';
                    end loop;
                    
                    speculated_read_ptr_list <= actual_read_ptr_list;
                end if;
                
            end if;
		end if;
	end process;

    write_port_proc: process (ap_clk)
        variable flit_vaxis_dest : chan_id;
    begin
        if rising_edge(ap_clk) then
            write_credit_modified_valid <= '0';
            write_enable <= '0';
            
            if is1(stream_s_status.valid AND stream_s_ready AND rst_n) then
                flit_vaxis_dest := unsigned(stream_s_ldest);
                last_write_chan <= flit_vaxis_dest; 
                
                merged_data_write_lane <= to_slv(stream_s_tuples, stream_s_status);
                merged_addr_write_lane <= std_logic_vector(flit_vaxis_dest) & std_logic_vector(write_ptr_list(to_integer(flit_vaxis_dest)));
                
                if NOT(stream_s_status.ptype = TLAST_MASK_SOFTEND_NO_DATA) then
                    write_enable <= '1';
                    
                    write_ptr_list(to_integer(flit_vaxis_dest)) <= write_ptr_list(to_integer(flit_vaxis_dest)) + 1;
                
                    write_credit_modified <= flit_vaxis_dest;
                    write_credit_modified_valid <= '1';
                end if;
                            
                if (write_ptr_list(to_integer(flit_vaxis_dest)) + 1) = actual_read_ptr_list(to_integer(flit_vaxis_dest)) then
                    report "Write pointer passed read pointer!" severity warning;
                end if;
            end if;
        end if;
    end process;
	
    credit_out: process (credits_list)
    begin
        for i in 0 to 2**VIRTUAL_PORT_CNT_LOG2-1 loop
            credits_list_out((i+1)*MEMORY_DEPTH_LOG2-1 downto i*MEMORY_DEPTH_LOG2) <= std_logic_vector(credits_list(i));
        end loop;
    end process;
	
    credit_adjust_proc: process(ALL)
	begin
        if rising_edge(ap_clk) then
            if is1(rst_n) then
                if NOT(is1(read_credit_modified_valid) AND is1(write_credit_modified_valid) AND (read_credit_modified = write_credit_modified)) then
                    
                    if is1(write_credit_modified_valid)  then
                        credits_list(to_integer(write_credit_modified)) <= credits_list(to_integer(write_credit_modified)) - 1;
                    end if;
                    
                    if is1(read_credit_modified_valid) then 
                        credits_list(to_integer(read_credit_modified)) <= credits_list(to_integer(read_credit_modified)) + 1;
                    end if;
                    
                end if;
            end if;
        end if;
    end process;
	
    mem : entity libramen.xilinx_dual_port_ram 
    generic map (
        AWIDTH => addr_width_in_bits, 
        DWIDTH => data_width_in_bits,
        MEMORY_TYPE => MEMORY_TYPE,
        DELAY_PIPELINE_DEPTH => RAM_PIPELINE_DEPTH - 1
    ) port map (
        clk => ap_clk,  
        wea => write_enable,
        mem_en => advance_read_pipeline,
        dina => merged_data_write_lane, 
        addra => merged_addr_write_lane, 
        addrb => std_logic_vector(read_addr_delay_line(RAM_PIPELINE_DEPTH-1).self_chan) & std_logic_vector(read_addr_delay_line(RAM_PIPELINE_DEPTH-1).req_addr), 
        doutb => read_data_out
    );

end Behavioral;