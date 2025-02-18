library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity test_seq_gen is
generic (
    CDEST_VAL : natural := 0;
    RANDOMIZE_CDEST : boolean := true;
    SEED : natural := 0;
    TEST_PAYLOAD : natural := 0;
    RANDOM_YIELDS : boolean := true
);
Port (
    clk : in std_logic;
    rstn : in std_logic;
    
    active : in std_logic;
    
    stream_m_tuples : out tuple_vec(0 downto 0);
    stream_m_status : out stream_status;
    stream_m_ready  : in std_logic
);
end test_seq_gen;

architecture Behavioral of test_seq_gen is
    constant rand_spec  : lfsr_spec := new_lfsr_iterator(64, true);
    
    signal rand_vec : std_logic_vector(64-1 downto 0) := init_lfsr(rand_spec, SEED);

    signal iterator_m : natural := 0;
    signal terminate_circuit : std_logic := '0';
    
    signal next_cdest : unsigned(CDEST_SIZE_IN_BIT-1 downto 0) := to_unsigned(CDEST_VAL, CDEST_SIZE_IN_BIT);
    
    signal idle_cycle : std_logic;
    
    signal stream_running : std_logic;
begin

    idle_cycle <= and_reduce(rand_vec(12 downto 7));

    stream_m_tuples(0).value <= std_logic_vector(to_unsigned(iterator_m, VALUE_SIZE_IN_BITS));
    stream_m_tuples(0).tag  <= std_logic_vector(to_unsigned(TEST_PAYLOAD, TAG_SIZE_IN_BITS)) when iterator_m /= 0 else (others => '0');
    stream_m_status.cdest <= std_logic_vector(next_cdest) when RANDOMIZE_CDEST else std_logic_vector(to_unsigned(CDEST_VAL, CDEST_SIZE_IN_BIT));
    stream_m_status.yield <= '1' when is1(terminate_circuit) OR (is1(rand_vec(23 downto 20)) AND RANDOM_YIELDS) else '0';
    stream_m_status.valid <= '1' when is1((active OR stream_running) AND NOT(idle_cycle)) else '0';
    stream_m_status.ptype <= TLAST_MASK_HARDEND_0INVALID when is1(terminate_circuit) else
           TLAST_MASK_HARDEND_3INVALID when iterator_m = 0 else
           TLAST_MASK_SOFTEND;
    
    main: process (clk)
    begin
        if rising_edge(clk) then
            rand_vec <= step(rand_spec, rand_vec);
            
            if is1(rstn AND (active OR stream_running) AND NOT(idle_cycle)) then
                
                stream_running <= '1';
                
                if is1(stream_m_ready) then
                    iterator_m <= iterator_m + 1;
                    
                    if is0(rand_vec(20 downto 16)) then
                        
                    end if;
                    
                    if is1(rand_vec(9 downto 0)) then
                        terminate_circuit <= '1';
                    end if;
                    
                    if is1(terminate_circuit) then
                        iterator_m <= 0;
                        terminate_circuit <= '0';
                        next_cdest <= unsigned(rand_vec(CDEST_SIZE_IN_BIT+40 downto 41));
                        stream_running <= '0';
                    end if;
                end if;

            end if;
        end if;
    end process;

end Behavioral;
