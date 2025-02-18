library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;

entity test_seq_chk is
generic (
    TEST_PAYLOAD : natural := 0;
    SEED : natural := 0;
    RANDOM_READY_SIG : boolean := false
);
Port (
    clk : in std_logic;
    rstn : in std_logic;
    
    slave_error_interrupt : out std_logic;
    
    stream_s_tuples : in  tuple_vec(0 downto 0);
    stream_s_status : in  stream_status;
    stream_s_ready  : out std_logic
);
end test_seq_chk;

architecture Behavioral of test_seq_chk is
    constant rand_spec  : lfsr_spec := new_lfsr_iterator(64, true);
    
    signal rand_vec : std_logic_vector(64-1 downto 0) := init_lfsr(rand_spec, SEED);

    signal iterator_s : natural := 1;
    signal ready_enable : std_logic;
begin
    
    ready_enable <= or_reduce(rand_vec(2 downto 0)) when RANDOM_READY_SIG else '1';
    stream_s_ready <= rstn AND ready_enable;
    
    slave: process (clk)
    begin
        if rising_edge(clk) then
            slave_error_interrupt <= '0';
            
            rand_vec <= step(rand_spec, rand_vec);
            
            if is1(stream_s_status.valid) AND is1(stream_s_ready) AND contains_data(stream_s_status) then
                iterator_s <= iterator_s + 1;
                
                if (to_integer(unsigned(stream_s_tuples(0).value)) /= iterator_s) AND (to_integer(unsigned(stream_s_tuples(0).tag)) /= 0) then
                    slave_error_interrupt <= '1';
                    
                    report "axis_test_seq: Slave sequence TDATA mismatch. Expected: "
                    & integer'image(iterator_s) & " but recieved "
                    & integer'image(to_integer(unsigned(stream_s_tuples(0).value))) & "!"
                    severity failure;
                end if;
                
                if (to_integer(unsigned(stream_s_tuples(0).tag)) /= TEST_PAYLOAD) AND (to_integer(unsigned(stream_s_tuples(0).tag)) /= 0) then
                    slave_error_interrupt <= '1';
                    
                    report "axis_test_seq: Slave tag TDATA mismatch. Expected: "
                    & integer'image(iterator_s) & " but recieved "
                    & integer'image(to_integer(unsigned(stream_s_tuples(0).tag))) & "!"
                    severity failure;
                end if;
                
                if is_hardend(stream_s_status) then
                    iterator_s <= 1;
                end if;
            end if;
        end if;    
    end process;

end Behavioral;