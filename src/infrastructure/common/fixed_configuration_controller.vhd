library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity fixed_configuration_controller is
Generic (
    INSTR_LIST : int_vec --Format (CDEST DESTREG VALUE)+
);
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;
	
	finished : out std_logic;
	
    stream_m_tuples : out tuple_vec(0 downto 0);
    stream_m_status : out stream_status;
    stream_m_ready  : in std_logic
);
end fixed_configuration_controller;

architecture Behavioral of fixed_configuration_controller is
    constant INSTR_CNT : natural := INSTR_LIST'LENGTH / 3;

    function get_nth_value(SOURCE : int_vec; ROWCNT : natural; ROWLENGTH : natural; N : natural) return int_vec is
        variable result : int_vec(ROWCNT-1 downto 0);
    begin
        for i in 0 to ROWCNT-1 loop
            result(i) := SOURCE(i*ROWLENGTH+N);
        end loop;
        return result;
    end;

    constant INSTR_CDEST_LIST : int_vec(INSTR_CNT-1 downto 0)   := get_nth_value(INSTR_LIST, INSTR_CNT, 3, 0);
    constant INSTR_DESTREG_LIST : int_vec(INSTR_CNT-1 downto 0) := get_nth_value(INSTR_LIST, INSTR_CNT, 3, 1);
    constant INSTR_TRANSMIT_VAL : int_vec(INSTR_CNT-1 downto 0) := get_nth_value(INSTR_LIST, INSTR_CNT, 3, 2);

    signal memindex : unsigned(log2_nat(INSTR_CDEST_LIST'HIGH) downto 0) := (others => '0');
    signal memindex_sanitized : natural;
begin
    
    memindex_sanitized <= to_integer(memindex) when memindex <= INSTR_TRANSMIT_VAL'HIGH else INSTR_TRANSMIT_VAL'HIGH;
    
    finished <= '0' when memindex <= INSTR_TRANSMIT_VAL'HIGH else '1';
    
    stream_m_tuples(0).value <= std_logic_vector(to_unsigned(INSTR_TRANSMIT_VAL(memindex_sanitized), 64));
    stream_m_tuples(0).tag   <= std_logic_vector(to_unsigned(INSTR_DESTREG_LIST(memindex_sanitized), 32));
    stream_m_status.valid <= '1' when memindex <= INSTR_TRANSMIT_VAL'HIGH else '0';
    stream_m_status.cdest <= std_logic_vector(to_unsigned(INSTR_CDEST_LIST(memindex_sanitized), 14));
    stream_m_status.ptype <= TLAST_MASK_HARDEND_3INVALID;
    stream_m_status.yield <= '1';
    
    output: process (ap_clk)
    begin
        if rising_edge(ap_clk) then
            if is1(rst_n) AND is1(stream_m_ready) then
                if memindex <= INSTR_TRANSMIT_VAL'HIGH then
                    memindex <= memindex + 1;
                end if;
            end if;
        end if;
        
    end process;

    assert (INSTR_CDEST_LIST'HIGH = INSTR_DESTREG_LIST'HIGH) AND (INSTR_CDEST_LIST'HIGH = INSTR_TRANSMIT_VAL'HIGH)
    report "fixed_configuration_controller: Generic mismatch!"
    severity failure;

    assert INSTR_CNT*3 = INSTR_LIST'LENGTH
    report "fixed_configuration_controller: INSTR_LIST must have multiple of 3 ints! Length is " & integer'IMAGE(INSTR_LIST'HIGH)
    severity failure;

end Behavioral;