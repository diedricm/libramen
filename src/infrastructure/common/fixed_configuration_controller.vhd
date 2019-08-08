library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity fixed_configuration_controller is
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;
	
	finished : out std_logic;
	
    stream_m : out flit(tuples(0 downto 0));
    ready_m : in std_logic
);
end fixed_configuration_controller;

architecture Behavioral of fixed_configuration_controller is
    type opcode is record
        tdest : integer;
        destreg : integer;
        value :  integer;
    end record;
    type opcode_list is array (natural range <>) of opcode;

    constant opcode_count : natural := 9;
    constant opmem : opcode_list(0 to opcode_count-1) := (
        (0, 2, 48), --TDEST: 1->3
        (1, 2, 64), --TDEST: 2->4
        (2, 2, 32), --TDEST: 3->2
        (3, 2, 16), --TDEST: 4->1
        (0, 1, 80),
        (1, 1, 80),
        (2, 1, 80),
        (3, 1, 80),
        (0, 0, 0) --NEED ZERO BYTE TERMINATION
    );
    signal memindex : unsigned(7 downto 0) := (others => '0');
begin
    
    finished <= '0' when (memindex + 1) /= opcode_count else '1';
    
    stream_m.tuples(0).data <= std_logic_vector(to_unsigned(opmem(to_integer(memindex)).value, 64));
    stream_m.tuples(0).tag <= std_logic_vector(to_unsigned(opmem(to_integer(memindex)).destreg, 32));
    stream_m.valid <= '1' when (memindex + 1) /= opcode_count else '0';
    stream_m.cdest <= std_logic_vector(to_unsigned(opmem(to_integer(memindex)).tdest, 14));
    stream_m.ptype <= TLAST_MASK_HARDEND_3INVALID;
    stream_m.yield <= '1';
    
    output: process (ap_clk)
    begin
        if rising_edge(ap_clk) then
            if is1(rst_n) AND is1(ready_m) then
                if (memindex + 1) /= opcode_count then
                    memindex <= memindex + 1;
                end if;
            end if;
        end if;
        
    end process;

end Behavioral;