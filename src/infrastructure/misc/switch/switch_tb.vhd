library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity switch_tb is
end switch_tb;

architecture Behavioral of switch_tb is
    constant clk_freq : time := 2ns;
    constant port_cnt : natural := 4;
    signal clk : std_logic := '0';
    signal rstn : std_logic := '0';
    
    signal stream_s  :  flit_vec(port_cnt-1 downto 0)(tuples(0 downto 0));
    signal ready_s   : std_logic_vector(port_cnt-1 downto 0);
        
    signal stream_m  : flit_vec(port_cnt-1 downto 0)(tuples(0 downto 0));
    signal ready_m   : std_logic_vector(port_cnt-1 downto 0);
begin

    generators: for i in 0 to port_cnt-1 generate
        gen_instance: entity libramen.test_seq_gen
        generic map (
            CDEST_VAL => i,
            RANDOMIZE_CDEST => true,
            SEED => i,
            TEST_PAYLOAD => 0
        ) port map (
            clk => clk,
            rstn => rstn,
            
            active => '1',
            
            stream_m => stream_s(i),
            ready_m => ready_s(i)
        );
    end generate;
    
    consumers: for i in 0 to port_cnt-1 generate
        cons_instance: entity libramen.test_seq_chk
        generic map (
            TEST_PAYLOAD => 0
        ) port map (
            clk => clk,
            rstn => rstn,
            
            slave_error_interrupt => OPEN,
            
            stream_s => stream_m(i),
            ready_s => ready_m(i)
        );
    end generate;

    uut: entity libramen.switch
    generic map (
        TUPPLE_COUNT => 1,
        INPORT_CNT   => port_cnt,
        OUTPORT_CNT  => port_cnt,
        CDEST_PARSE_LENGTH => 2,
        CDEST_PARSE_OFFSET => 0,
        CONNECTION_MATRIX => (others => (others => '1'))
    ) port map (
        clk => clk,
        rstn => rstn,
        
        stream_s  => stream_s,
        ready_s => ready_s,
        
        stream_m  => stream_m,
        ready_m => ready_m
    );

end architecture; --Behavioral
