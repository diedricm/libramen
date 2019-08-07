library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
library vaxis;
    
entity varlen_predicate_core_tb is
end varlen_predicate_core_tb;

architecture Behavioral of varlen_predicate_core_tb is

    constant clk_freq : time := 2ns;
    
    signal clk : std_logic := '0';
    signal rst_n : std_logic := '0';

    signal TDATA_memconf_s  : std_logic_vector(25*8-1 downto 0);
    signal TVALID_memconf_s : std_logic;    
    signal TDATA_s  : std_logic_vector(4*8-1 downto 0);
    signal TREADY_s : std_logic_vector(4-1 downto 0);
    signal TDATA_m  : std_logic_vector(8-1 downto 0);
    signal TVALID_m : std_logic;
    
    
begin

    clk <= NOT(clk) after clk_freq/2;
    rst_n <= '1' after clk_freq*100;
    
    uut: entity vaxis.varlen_predicate_core
    generic map (
        MATCHWIDTH => 4,
        INSTR_COUNT_LOG2 => 10,
        INSTR_BRANCHES_COUNT => 5
    ) port map (
        clk => clk,
        rstn => rst_n,
    
        TDATA_memconf_s => TDATA_memconf_s,
        TVALID_memconf_s => TVALID_memconf_s,
        
        TDATA_s => TDATA_s,
        TREADY_s => TREADY_s,
    
        TDATA_m => TDATA_m,
        TVALID_m => TVALID_m
    );

end Behavioral;
