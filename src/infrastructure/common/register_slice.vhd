library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;

entity stream_register_slice is
generic (
	TUPPLE_COUNT : natural := 1;
	LDEST_LENGTH : natural := 1
);
Port (
    clk : in std_logic;
    rstn : in std_logic;
    
    clear : in std_logic;
    is_empty : out std_logic;

    stream_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_s_status : in stream_status;
    stream_s_ready : out std_logic;
    stream_s_ldest : in std_logic_vector(LDEST_LENGTH downto 0);
	
    stream_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_m_status : out stream_status;
    stream_m_ready : in std_logic;
    stream_m_ldest : out std_logic_vector(LDEST_LENGTH downto 0)
);
end stream_register_slice;

architecture Behavioral of stream_register_slice is
    signal stream_reg_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_reg_status : stream_status := (cdest => (others => '-'), ptype => (others => '-'), yield => '-', valid => '0');
    signal stream_reg_ldest : std_logic_vector(LDEST_LENGTH downto 0);
    
    signal stream_m_ready_delayed : std_logic := '0';
    signal new_data_in : std_logic;
begin

    new_data_in <= stream_s_status.valid AND stream_s_ready; 
    is_empty <= '1' when is0(stream_m_status.valid) AND is0(stream_reg_status.valid) else '0';
    stream_s_ready <= stream_m_ready_delayed OR NOT(stream_m_status.valid);
    
    
    main: process (clk)
    begin
        if rising_edge(clk) then
            if is0(rstn) OR is1(clear) then
                stream_reg_status.valid <= '0';
                stream_m_status.valid <= '0';
            else
                
                stream_m_ready_delayed <= stream_m_ready;
                
                if is1(stream_m_ready) OR is0(stream_m_status.valid) then
                    if is1(stream_reg_status.valid) then
                        stream_m_tuples <= stream_reg_tuples;
                        stream_m_ldest  <= stream_reg_ldest;
                        stream_m_status <= stream_reg_status;
                        stream_reg_status.valid <= '0';
                    elsif is1(new_data_in) then
                        stream_m_tuples <= stream_s_tuples;
                        stream_m_ldest  <= stream_s_ldest;
                        stream_m_status <= stream_s_status;
                    else
                        stream_m_status.valid <= '0';
                    end if;
                elsif is1(new_data_in) then
                    stream_reg_tuples <= stream_s_tuples;
                    stream_reg_status <= stream_s_status;
                    stream_reg_ldest <= stream_s_ldest;
                end if;
                
            end if;
        end if;
    end process;
    
end Behavioral;