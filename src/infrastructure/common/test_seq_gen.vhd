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
    TDEST_VAL : natural := 0;
    SEED : natural := 0;
    TEST_PAYLOAD : natural := 0
);
Port (
    clk : in std_logic;
    rstn : in std_logic;
    
    active : in std_logic;
    
    stream_m : out flit(tuples(0 downto 0));
    ready_m : in std_logic
);
end test_seq_gen;

architecture Behavioral of test_seq_gen is
    constant rand_spec  : lfsr_spec := new_lfsr_iterator(64, true);
    
    signal rand_vec : std_logic_vector(64-1 downto 0) := init_lfsr(rand_spec, SEED);

    signal iterator_m : natural := 0;
    signal terminate_circuit : std_logic := '0';
begin

    stream_m.tuples(0).data <= std_logic_vector(to_unsigned(iterator_m, VALUE_SIZE_IN_BITS));
    stream_m.tuples(0).tag  <= std_logic_vector(to_unsigned(TEST_PAYLOAD, TAG_SIZE_IN_BITS)) when iterator_m /= 0 else (others => '0');
    stream_m.cdest <= std_logic_vector(to_unsigned(TDEST_VAL, CDEST_SIZE_IN_BIT));
    stream_m.yield <= '1' when is1(terminate_circuit) OR is1(rand_vec(23 downto 20)) else '0';
    stream_m.valid <= '1' when is1(active) else '0';
    stream_m.ptype <= TLAST_MASK_HARDEND_0INVALID when is1(terminate_circuit) else
           TLAST_MASK_HARDEND_3INVALID when iterator_m = 0 else
           TLAST_MASK_SOFTEND;
    
    main: process (clk)
    begin
        if rising_edge(clk) then
            if is1(rstn AND active) then
                rand_vec <= step(rand_spec, rand_vec);
                
                if is1(ready_m) then
                    iterator_m <= iterator_m + 1;
                    
                    if is0(rand_vec(20 downto 16)) then
                        
                    end if;
                    
                    if is1(terminate_circuit) then
                        iterator_m <= 0;
                        terminate_circuit <= '0';
                    end if;
                    
                    if is1(rand_vec(6 downto 0)) then
                        terminate_circuit <= '1';
                    end if;
                end if;

            end if;
        end if;
    end process;

end Behavioral;
