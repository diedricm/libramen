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
    TEST_PAYLOAD : natural := 0
);
Port (
    clk : in std_logic;
    rstn : in std_logic;
    
    slave_error_interrupt : out std_logic;
    
    stream_s : in  flit(tuples(0 downto 0));
    ready_s : out std_logic
);
end test_seq_chk;

architecture Behavioral of test_seq_chk is
    signal iterator_s : natural := 0;
begin
    
    ready_s <= rstn;
    
    slave: process (clk)
    begin
        if rising_edge(clk) then
            slave_error_interrupt <= '0';
            
            if (stream_s.valid = '1') then
                iterator_s <= iterator_s + 1;
                
                if to_integer(unsigned(stream_s.tuples(0).data)) /= iterator_s then
                    slave_error_interrupt <= '1';
                    
                    report "axis_test_seq: Slave sequence TDATA mismatch. Expected: "
                    & integer'image(iterator_s) & " but recieved "
                    & integer'image(to_integer(unsigned(stream_s.tuples(0).data))) & "!"
                    severity error;
                end if;
                
                if to_integer(unsigned(stream_s.tuples(0).tag)) /= TEST_PAYLOAD then
                    slave_error_interrupt <= '1';
                    
                    report "axis_test_seq: Slave tag TDATA mismatch. Expected: "
                    & integer'image(iterator_s) & " but recieved "
                    & integer'image(to_integer(unsigned(stream_s.tuples(0).tag))) & "!"
                    severity error;
                end if;
                
                if is_hardend(stream_s) then
                    iterator_s <= 0;
                end if;
            end if;
        end if;    
    end process;

end Behavioral;