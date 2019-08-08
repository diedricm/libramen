library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity xilinx_dual_port_ram is
generic (
     AWIDTH : integer := 12;  -- Address Width
     DWIDTH : integer := 72;  -- Data Width
     MEMORY_TYPE : string := "ultra";
     DELAY_PIPELINE_DEPTH : natural := 3
);
port (
     clk : in std_logic;                                  -- Clock
     wea : in std_logic;                                  -- Write Enable
     mem_en : in std_logic;                               -- Memory Enable
     dina : in std_logic_vector(DWIDTH-1 downto 0);       -- Data Input  
     addra : in std_logic_vector(AWIDTH-1 downto 0);      -- Write Address
     addrb : in std_logic_vector(AWIDTH-1 downto 0);      -- Read Address
     doutb : out std_logic_vector(DWIDTH-1 downto 0)      -- Data Output
);
end xilinx_dual_port_ram;

architecture rtl of xilinx_dual_port_ram is

    constant C_AWIDTH : integer := AWIDTH;
    constant C_DWIDTH : integer := DWIDTH;
    
    -- Internal Signals
    type mem_t is array(natural range<>) of std_logic_vector(C_DWIDTH-1 downto 0);
        
    signal mem : mem_t(2**C_AWIDTH-1 downto 0);                -- Memory Declaration
    
    signal delay_line : mem_t(DELAY_PIPELINE_DEPTH-1 downto 0);              
    
    attribute ram_style : string;
    attribute ram_style of mem : signal is MEMORY_TYPE;

begin

    doutb <= delay_line(DELAY_PIPELINE_DEPTH-1);
    
    memproc: process(clk)
    begin
        if rising_edge(clk) then
            if(wea = '1') then
                mem(to_integer(unsigned(addra))) <= dina;
            end if;
            
            if(mem_en = '1') then
                delay_line(0) <= mem(to_integer(unsigned(addrb)));
                
                for i in 1 to DELAY_PIPELINE_DEPTH-1 loop
                    delay_line(i) <= delay_line(i-1);
                end loop;
            end if;
        end if;
    end process;

end rtl;