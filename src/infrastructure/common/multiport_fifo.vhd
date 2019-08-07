library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;
    
entity vaxis_multiport_fifo is
generic (
	TDATA_WIDTH : natural := 12;
	TDEST_WIDTH : natural := 14;
	VIRTUAL_PORT_CNT_LOG2 : natural := 4;
	MEMORY_DEPTH_LOG2 : natural := 6;
	ALMOST_FULL_LEVEL : natural := 8;
	MEMORY_TYPE : string := "block"
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
	
	TDATA_s  : in std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	TVALID_s : in std_logic;
	TREADY_s : out std_logic;
	TDEST_s  : in std_logic_vector(TDEST_WIDTH-1 downto 0);
	TUSER_s  : in std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
	TLAST_s  : in std_logic;
	fifo_port_dest : in std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	
	TDATA_m  : out std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	TVALID_m : out std_logic;
	TREADY_m : in std_logic;
	TDEST_m  : out std_logic_vector(TDEST_WIDTH-1 downto 0);
	TUSER_m  : out std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
	TLAST_m  : out std_logic
);
end vaxis_multiport_fifo;

architecture Behavioral of vaxis_multiport_fifo is
	ATTRIBUTE X_INTERFACE_INFO : STRING;
	ATTRIBUTE X_INTERFACE_INFO of TDEST_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TDEST";
	ATTRIBUTE X_INTERFACE_INFO of TDATA_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TDATA";
	ATTRIBUTE X_INTERFACE_INFO of TLAST_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TLAST";
	ATTRIBUTE X_INTERFACE_INFO of TUSER_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TUSER";
	ATTRIBUTE X_INTERFACE_INFO of TVALID_s : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TVALID";
	ATTRIBUTE X_INTERFACE_INFO of TREADY_s : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TREADY";
	ATTRIBUTE X_INTERFACE_INFO of TDEST_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TDEST";
	ATTRIBUTE X_INTERFACE_INFO of TDATA_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TDATA";
	ATTRIBUTE X_INTERFACE_INFO of TLAST_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TLAST";
	ATTRIBUTE X_INTERFACE_INFO of TUSER_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TUSER";
	ATTRIBUTE X_INTERFACE_INFO of TVALID_m : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TVALID";
	ATTRIBUTE X_INTERFACE_INFO of TREADY_m : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TREADY";
	
	function RAM_PIPELINE_DEPTH_lookup(memtype : string) return natural is
	begin
        if memtype = "distributed" then
            return 2;
        elsif memtype = "register" then
            return 2;
        elsif memtype = "block" then
            return 3;
        elsif memtype = "ultra" then
            return 3;
        else
            report "Wrong MEMORY_TYPE: " & memtype & "! Use distributed, register, block or ultra." severity failure;
            return 0;
        end if;
	end;
	
	constant data_width_in_bits : natural := TDATA_WIDTH*8 + TDEST_WIDTH + TUSER_SIZE_IN_BIT + 1;
	constant addr_width_in_bits : natural := VIRTUAL_PORT_CNT_LOG2 + MEMORY_DEPTH_LOG2;
    constant RAM_PIPELINE_DEPTH : natural := RAM_PIPELINE_DEPTH_lookup(MEMORY_TYPE);
	
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
begin

    TREADY_s <= '1' when credits_list(to_integer(last_write_chan)) > 2 else '0';
	TVALID_m <= read_addr_delay_line(0).valid AND NOT(next_output_skip_prftchd_data);
	(TDATA_m, TUSER_m, TLAST_m, TDEST_m) <= read_data_out;

    advance_read_pipeline <= TREADY_m OR NOT(read_addr_delay_line(0).valid);

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
                    if is1(TVALID_m) then
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
            almost_full <= '0';
            
            if is1(TVALID_s AND TREADY_s AND rst_n) then
                flit_vaxis_dest := unsigned(fifo_port_dest);
                last_write_chan <= flit_vaxis_dest; 
                
                merged_data_write_lane <= TDATA_s & TUSER_s & TLAST_s & TDEST_s;
                merged_addr_write_lane <= std_logic_vector(flit_vaxis_dest) & std_logic_vector(write_ptr_list(to_integer(flit_vaxis_dest)));
                
                if NOT((TUSER_s = VAXIS_TLAST_MASK_SOFTEND_NO_DATA) OR (TUSER_s = VAXIS_TLAST_MASK_HARDEND_NO_DATA)) then
                    write_enable <= '1';
                    
                    write_ptr_list(to_integer(flit_vaxis_dest)) <= write_ptr_list(to_integer(flit_vaxis_dest)) + 1;
                
                    write_credit_modified <= flit_vaxis_dest;
                    write_credit_modified_valid <= '1';
                end if;
                
                if (credits_list(to_integer(flit_vaxis_dest)) < ALMOST_FULL_LEVEL) AND is0(almost_full) then
                    almost_full <= '1';
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
	
    credit_adjust_proc: process(ap_clk)
	begin
        if rising_edge(ap_clk) then
            if is1(rst_n) then
                -- adjust credit value if read chan == write chan
                write_credit_modified_valid_final <= write_credit_modified_valid;
                read_credit_modified_valid_final <= read_credit_modified_valid;
                write_credit_modified_final <= write_credit_modified;
                read_credit_modified_final <= read_credit_modified;
                if is1(read_credit_modified_valid) AND is1(write_credit_modified_valid) AND (read_credit_modified = write_credit_modified) then
                    write_credit_modified_valid_final <= '0';
                    read_credit_modified_valid_final <= '0';
                end if;
                
                --update credits
                for i in 0 to 2**VIRTUAL_PORT_CNT_LOG2-1 loop
                    if is1(write_credit_modified_valid_final) AND (write_credit_modified_final = i) then
                        credits_list(i) <= credits_list(i) - 1;
                    elsif is1(read_credit_modified_valid_final) AND (read_credit_modified_final = i) then
                        credits_list(i) <= credits_list(i) + 1;
                    else
                        credits_list(i) <= credits_list(i);
                    end if;
                end loop;
            end if;
        end if;
    end process;
	
    mem : entity vaxis.xilinx_configram_simple_dual_port 
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
    
    --assert ALMOST_FULL_LEVEL > 3 report "vaxis_multiport_fifo: ALMOST_FULL_LEVEL must be larger than 3!" severity failure;

end Behavioral;