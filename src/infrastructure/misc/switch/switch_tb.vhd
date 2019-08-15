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
    constant port_cnt_input : natural := 5;
    constant port_cnt_output : natural := 4;
    signal clk : std_logic := '1';
    signal rstn : std_logic := '0';
        
    signal stream_s_tuples : tuple_vec(port_cnt_input-1 downto 0);
    signal stream_s_status : stream_status_vec(port_cnt_input-1 downto 0);
    signal stream_s_ready  : std_logic_vector(port_cnt_input-1 downto 0);
    
    signal stream_m_tuples : tuple_vec(port_cnt_output-1 downto 0);
    signal stream_m_status : stream_status_vec(port_cnt_output-1 downto 0);
    signal stream_m_ready  : std_logic_vector(port_cnt_output-1 downto 0);
begin

    clk <= NOT clk after clk_freq/2;
    rstn <= '1' after clk_freq*50;

    generators: for i in 0 to port_cnt_input-1 generate
        gen_instance: entity libramen.test_seq_gen
        generic map (
            CDEST_VAL => i MOD 4,
            RANDOMIZE_CDEST => false,
            SEED => i,
            TEST_PAYLOAD => 0,
            RANDOM_YIELDS => false
        ) port map (
            clk => clk,
            rstn => rstn,
            
            active => '1',
            
            stream_m_tuples(0) => stream_s_tuples(i),
            stream_m_status => stream_s_status(i),
            stream_m_ready => stream_s_ready(i)
        );
    end generate;
    
    consumers: for i in 0 to port_cnt_output-1 generate
        cons_instance: entity libramen.test_seq_chk
        generic map (
            TEST_PAYLOAD => 0
        ) port map (
            clk => clk,
            rstn => rstn,
            
            slave_error_interrupt => OPEN,
            
            stream_s_tuples(0) => stream_m_tuples(i),
            stream_s_status => stream_m_status(i),
            stream_s_ready => stream_m_ready(i)
        );
    end generate;

    uut: entity libramen.switch
    generic map (
        TUPPLE_COUNT => 1,
        INPORT_CNT   => port_cnt_input,
        OUTPORT_CNT  => port_cnt_output,
        CDEST_PARSE_OFFSET => 0,
        CONNECTION_MATRIX => (others => '1')
    ) port map (
        clk => clk,
        rstn => rstn,
        
        stream_s_tuples => stream_s_tuples,
        stream_s_status => stream_s_status,
        stream_s_ready => stream_s_ready,
        
        stream_m_tuples => stream_m_tuples,
        stream_m_status => stream_m_status,
        stream_m_ready => stream_m_ready
    );
    
end architecture; --Behavioral
