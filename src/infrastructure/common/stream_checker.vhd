library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity stream_checker is
generic (
	TUPPLE_COUNT : natural := 4;
	VIRTUAL_PORT_CNT_LOG2 : natural := 4;
	REPORT_FLIT_DROP : boolean := true;
	PERFCOUNTER_ENABLE : boolean := true;
	PERFCOUNTER_WINDOW : natural := 1000;
	PERFCOUNTER_REPORT_INTERVAL : natural := 10
);
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;
	
	debug_stream_tuples : in tuple_vec(TUPPLE_COUNT-1 downto 0);
	debug_stream_status : in stream_status;
	debug_stream_ready  : in std_logic;
	debug_stream_ldest  : in std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0)
);
end stream_checker;

architecture Behavioral of stream_checker is
	signal commited_data : tuple_vec(TUPPLE_COUNT-1 downto 0);
	signal commited_status : stream_status;
	signal commited_ldest  : std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal flit_commited : boolean;

	signal in_stream : boolean;
	signal in_stream_reg : boolean := false;
	signal stream_cdest : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0) := (others => '0');
	
	type data_point is record
	   cdest : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
	   valid : natural range 0 to 1;
	end record data_point;
	type data_point_vector is array (natural range <>) of data_point;
    signal stream_debug_active_now : natural range 0 to 1;
    signal stream_debug_activation_window : data_point_vector(PERFCOUNTER_WINDOW-1 downto 0) := (others => (cdest => (others => '0'), valid => 0));
    signal stream_debug_activation_window_iterator : natural range 0 to PERFCOUNTER_WINDOW := 0;
    signal stream_debug_activation_window_num : natural range 0 to PERFCOUNTER_WINDOW := 0;
    signal stream_debug_report_counter : natural range 0 to PERFCOUNTER_REPORT_INTERVAL := 0;
begin
    
    
    in_stream <= is1(debug_stream_status.valid) OR in_stream_reg;
    error_detect: process (ALL)
    begin
    
        if is0(rst_n) then
            flit_commited <= false;
        end if;
    
        if rising_edge(ap_clk) AND is1(rst_n) then
        
            if REPORT_FLIT_DROP AND flit_commited AND is0(debug_stream_ready) then
                assert commited_data = debug_stream_tuples report "Presented tuple data changed by master without being acked by slave" severity failure;
                assert commited_status = debug_stream_status report "Presented tuple status changed by master without being acked by slave" severity failure;
                assert commited_ldest = debug_stream_ldest report "Presented tuple ldest changed by master without being acked by slave" severity failure;
            end if;
        
            --check if fwd is valid [always]
            assert is_binary(debug_stream_status.valid) report "STREAM.valid is of non-binary value: " & std_logic'IMAGE(debug_stream_status.valid) severity failure;
            if is1(debug_stream_status.valid) then
                assert is_binary(debug_stream_status.yield) report "STREAM.yield is of non-binary value during valid=high: " & std_logic'IMAGE(debug_stream_status.yield) severity failure;
                assert is_binary(debug_stream_status.cdest) report "STREAM.cdest is of non-binary value during valid=high: " & slv_to_hex_string(debug_stream_status.cdest) severity failure;
                assert is_binary(debug_stream_status.ptype) report "STREAM.ptype is of non-binary value during valid=high: " & slv_to_hex_string(debug_stream_status.ptype) severity failure;
                
                if is0(debug_stream_ready) then
                    flit_commited <= true;
                    commited_data <= debug_stream_tuples;
                    commited_status <= debug_stream_status;
                    commited_ldest <= debug_stream_ldest;
                else
                    flit_commited <= false;
                    
                    in_stream_reg <= true;
                    
                    if NOT in_stream_reg then
                        stream_cdest <= debug_stream_status.cdest;
                    end if;
                    
                    if is1(debug_stream_status.yield) then
                        in_stream_reg <= false;
                    end if;
                    
                    if in_stream_reg then
                        assert stream_cdest = debug_stream_status.cdest report "CDEST changed without yield between streams" severity failure;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    stream_debug_active_now <= 1 when contains_data(debug_stream_status) AND is1(debug_stream_status.valid and debug_stream_ready) else 0;
    debug_perf_counter: process(ap_clk)
        function report_per_chan_statistics(INP : data_point_vector) return integer is
            variable INP_copy : data_point_vector(INP'range) := INP;
            variable tmp_cdest : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
            variable cdest_set : boolean := false;
            variable tmp_counter : natural range 0 to PERFCOUNTER_WINDOW := 0;
        begin
            for i in 0 to PERFCOUNTER_WINDOW-1 loop
                if INP_copy(i).valid = 1 then
                    if cdest_set AND tmp_cdest = INP_copy(i).cdest then
                        tmp_counter := tmp_counter + 1;
                    elsif NOT cdest_set then
                        tmp_counter := 1;
                        tmp_cdest := INP_copy(i).cdest;
                        cdest_set := true;
                    end if;
                    INP_copy(i).valid := 0;
                end if;
            end loop;
            
            if cdest_set then
                assert report_per_chan_statistics(INP_copy) = 0 report "WTF" severity failure;
                report "THRPUTCNTR, " & INTEGER'image(to_integer(unsigned(tmp_cdest))) & ", " & INTEGER'image(tmp_counter) severity note;
            end if;
            
            return 0;
        end function;
    begin
        if is0(rst_n) then
            stream_debug_activation_window <=  (others => (cdest => (others => '0'), valid => 0));
            stream_debug_report_counter <= 0;
            stream_debug_activation_window_num <= 0;
            stream_debug_activation_window_iterator <= 0;
        end if;
    
        if rising_edge(ap_clk) and is1(rst_n) AND PERFCOUNTER_ENABLE then
            
            stream_debug_activation_window(stream_debug_activation_window_iterator).valid <= stream_debug_active_now;
            stream_debug_activation_window(stream_debug_activation_window_iterator).cdest <= debug_stream_status.cdest;
            stream_debug_activation_window_num <= stream_debug_activation_window_num + stream_debug_active_now - stream_debug_activation_window(stream_debug_activation_window_iterator).valid;
            
            if stream_debug_activation_window_iterator = PERFCOUNTER_WINDOW-1 then
                stream_debug_activation_window_iterator <= 0;
            else
                stream_debug_activation_window_iterator <= stream_debug_activation_window_iterator + 1;
            end if;
            
            if stream_debug_report_counter = PERFCOUNTER_REPORT_INTERVAL then
                stream_debug_report_counter <= report_per_chan_statistics(stream_debug_activation_window);
            else
                stream_debug_report_counter <= stream_debug_report_counter + 1;
            end if;
            
        end if;
    end process;
    
end Behavioral;