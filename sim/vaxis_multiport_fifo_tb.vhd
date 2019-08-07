library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library vaxis;

entity vaxis_multiport_fifo_tb is
end vaxis_multiport_fifo_tb;

architecture Behavioral of vaxis_multiport_fifo_tb is
    type INT_ARRAY is array (integer range <>) of integer;
    type chan_change_modes is (RANDOM, INCREMENTAL);


    --UUT DECL
    constant clk_period : time := 2ns;
    constant chan_change_mode : chan_change_modes := RANDOM;
    constant TDATA_WIDTH : natural := 48;
	constant TDEST_WIDTH : natural := 14;
	constant TUSER_WIDTH : natural := 3;
	constant VIRTUAL_PORT_CNT_LOG2 : natural := 4;
	constant MEMORY_DEPTH_LOG2 : natural := 9;
	constant ALMOST_FULL_LEVEL : natural := 16;

	signal clk : std_logic := '0';
	signal rst_n : std_logic := '0';

	signal almost_full : std_logic;
	signal backoff : std_logic := '0';
	
	signal TDATA_s  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	signal TVALID_s : std_logic;
	signal TREADY_s : std_logic;
	signal TDEST_s  : std_logic_vector(TDEST_WIDTH-1 downto 0);
	signal TUSER_s  : std_logic_vector(TUSER_WIDTH-1 downto 0);
	signal TLAST_s  : std_logic;
	
	signal TDATA_m  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	signal TVALID_m : std_logic;
	signal TREADY_m : std_logic;
	signal TDEST_m  : std_logic_vector(TDEST_WIDTH-1 downto 0);
	signal TUSER_m  : std_logic_vector(TUSER_WIDTH-1 downto 0);
	signal TLAST_m  : std_logic;
	
	--TEST RAND DECL
	constant rand_source_size : natural := 64;
	constant rand_source_spec : lfsr_spec := new_lfsr_iterator(rand_source_size);
	signal rand_source : std_logic_vector(rand_source_size-1 downto 0) := init_lfsr(rand_source_spec);
	signal counters_write : INT_ARRAY(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => 0);
	signal counters_read : INT_ARRAY(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => 0);
	signal random_chan : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	signal selected_chan : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
	
	signal change_output_channel : std_logic;
	signal next_output_channel : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
	
    signal read_enable : std_logic := '0';
    signal next_output_skip_prftchd_data : std_logic := '0';
begin

    clk <= NOT clk after clk_period/2;
    rst_n <= '1' after  clk_period*100;

    --lol
    random_chan <= unsigned(rand_source(VIRTUAL_PORT_CNT_LOG2-1 downto 0));
    TDATA_s(31 downto 0) <= std_logic_vector(to_unsigned(counters_write(to_integer(selected_chan)), 32));
    TDATA_s((TDATA_WIDTH*8)-1 downto 32) <= (others => '0');
    TDEST_s(VIRTUAL_PORT_CNT_LOG2-1 downto 0) <= std_logic_vector(selected_chan);
    TDEST_s(TDEST_WIDTH-1 downto VIRTUAL_PORT_CNT_LOG2) <= (others => '0');
    TUSER_s <= (others => '0');
    TLAST_s <= and_reduce(rand_source(VIRTUAL_PORT_CNT_LOG2+4 downto VIRTUAL_PORT_CNT_LOG2));
    TREADY_m <= or_reduce(rand_source(VIRTUAL_PORT_CNT_LOG2+6 downto VIRTUAL_PORT_CNT_LOG2+5));
    read_enable <= or_reduce(rand_source(VIRTUAL_PORT_CNT_LOG2 downto 0));
    
    randgen: process (clk)
        variable read_chan : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0); 
    begin
        if rising_edge(clk) and is1(rst_n) then
            rand_source <= step(rand_source_spec, rand_source);
            
            backoff <= and_reduce(rand_source(63 downto 53)) AND NOT(backoff);
            
            TVALID_s  <= '1';
            if is1(TVALID_s AND TREADY_s) then
                if is1(rand_source(VIRTUAL_PORT_CNT_LOG2+10 downto VIRTUAL_PORT_CNT_LOG2+9)) then
                    TVALID_s <= '0';
                end if;
                counters_write(to_integer(selected_chan)) <= counters_write(to_integer(selected_chan)) + 1;
            end if;
            
            if is1(almost_full) then
                if chan_change_mode = RANDOM then
                    selected_chan <= random_chan;
                else
                    selected_chan <= selected_chan + 1;
                end if;
            end if;
            
            if is1(TVALID_m AND TREADY_m) then
                read_chan := unsigned(TDEST_m(VIRTUAL_PORT_CNT_LOG2-1 downto 0));
                if counters_read(to_integer(read_chan)) = to_integer(unsigned(TDATA_m(31 downto 0))) then
                    counters_read(to_integer(read_chan)) <= counters_read(to_integer(read_chan)) + 1;
                else
                    report "Mismatch! expected " & integer'image(counters_read(to_integer(read_chan))) & " but recieved " & integer'image(to_integer(unsigned(TDATA_m(31 downto 0)))) severity warning;
                end if;
            end if;
        end if;
    end process;
    
    output_chan_select: process (clk)
    begin
        if rising_edge(clk) then
            next_output_skip_prftchd_data <= '0';
        
            if is1(change_output_channel) then
                if chan_change_mode = RANDOM then
                    next_output_channel <= random_chan;
                else
                    next_output_channel <= next_output_channel + 1;
                end if;
                next_output_skip_prftchd_data <= and_reduce(rand_source(50 downto 47));
            elsif is1(and_reduce(rand_source(53 downto 44))) then
                if chan_change_mode = RANDOM then
                    next_output_channel <= random_chan;
                else
                    next_output_channel <= next_output_channel + 1;
                end if;
            end if;
        end if;
    end process;

    uut: entity vaxis.vaxis_multiport_fifo
    generic map (
        TDATA_WIDTH => TDATA_WIDTH,
        TDEST_WIDTH => TDEST_WIDTH,
        TUSER_WIDTH => TUSER_WIDTH,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2 => MEMORY_DEPTH_LOG2,
        ALMOST_FULL_LEVEL => ALMOST_FULL_LEVEL,
        MEMORY_TYPE => "block",
        RAM_PIPELINE_DEPTH => 2
    ) port map (
        ap_clk => clk,
        rst_n => rst_n,
        
        almost_full => almost_full,
        
        credits_list_out => OPEN,
        change_output_chan => change_output_channel,
        next_output_chan => std_logic_vector(next_output_channel),
        read_enable => read_enable,
        next_output_skip_prftchd_data => next_output_skip_prftchd_data,
	
        TDATA_s  => TDATA_s ,
        TVALID_s => TVALID_s,
        TREADY_s => TREADY_s,
        TDEST_s  => TDEST_s ,
        TUSER_s  => TUSER_s ,
        TLAST_s  => TLAST_s ,
        fifo_port_dest => std_logic_vector(selected_chan),
        TDATA_m  => TDATA_m ,
        TVALID_m => TVALID_m,
        TREADY_m => TREADY_m,
        TDEST_m  => TDEST_m ,
        TUSER_m  => TUSER_m ,
        TLAST_m  => TLAST_m 
    );

end Behavioral;
