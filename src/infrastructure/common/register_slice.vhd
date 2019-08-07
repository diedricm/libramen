library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;

entity axis_register_slice is
generic (
	TDATA_WIDTH : natural := 12;
	TDEST_WIDTH : natural := 14;
	TUSER_WIDTH : natural := 3
);
Port (
    clk : in std_logic;
    rstn : in std_logic;

	TDATA_s  : in std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	TVALID_s : in std_logic;
	TREADY_s : out std_logic;
	TDEST_s  : in std_logic_vector(TDEST_WIDTH-1 downto 0);
	TUSER_s  : in std_logic_vector(TUSER_WIDTH-1 downto 0);
	TLAST_s  : in std_logic;

	TDATA_m  : out std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	TVALID_m : out std_logic;
	TREADY_m : in std_logic;
	TDEST_m  : out std_logic_vector(TDEST_WIDTH-1 downto 0);
	TUSER_m  : out std_logic_vector(TUSER_WIDTH-1 downto 0);
	TLAST_m  : out std_logic
);
end axis_register_slice;

architecture Behavioral of axis_register_slice is
    signal TDATA_reg  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	signal TVALID_reg : std_logic := '0';
	signal TDEST_reg  : std_logic_vector(TDEST_WIDTH-1 downto 0);
	signal TUSER_reg  : std_logic_vector(TUSER_WIDTH-1 downto 0);
	signal TLAST_reg  : std_logic;
	
    signal TDATA_next  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	signal TVALID_next : std_logic;
	signal TDEST_next  : std_logic_vector(TDEST_WIDTH-1 downto 0);
	signal TUSER_next  : std_logic_vector(TUSER_WIDTH-1 downto 0);
	signal TLAST_next  : std_logic;
begin

    TDATA_next <= TDATA_s when is0(TVALID_reg) else TDATA_reg;
	TVALID_next <= TVALID_s when is0(TVALID_reg) else TVALID_reg; 
	TDEST_next <= TDEST_s when is0(TVALID_reg) else TDEST_reg;
	TUSER_next <= TUSER_s when is0(TVALID_reg) else TUSER_reg; 
	TLAST_next <= TLAST_s when is0(TVALID_reg) else TLAST_reg; 
    
    main: process (clk)
    begin
        if rising_edge(clk) then
            if is0(rstn) then
                TVALID_reg <= '0';
                TREADY_s <= '0';
                TVALID_m <= '0';
                TDEST_m <= (others => '0');
                TUSER_m <= (others => '0');
                TLAST_m <= '0';
                TDATA_m <= (others => '0');
            else
                
                TREADY_s <= TREADY_m;
                
                if is1(TREADY_m) then
                    TDATA_m  <= TDATA_next;
                    TVALID_m <= TVALID_next;
                    TDEST_m  <= TDEST_next;
                    TUSER_m  <= TUSER_next;
                    TLAST_m  <= TLAST_next;
                    if is1(TVALID_reg) then
                        TVALID_reg <= '0';
                    end if;
                end if;
                
                if is1(TREADY_s AND TVALID_s) AND (is0(TREADY_m) OR is1(TVALID_reg)) then
                    TDATA_reg  <= TDATA_s;
                    TVALID_reg  <= TVALID_s; 
                    TDEST_reg  <= TDEST_s;  
                    TUSER_reg  <= TUSER_s;  
                    TLAST_reg  <= TLAST_s;  
                end if;
                
            end if;
        end if;
    end process;
    
end Behavioral;