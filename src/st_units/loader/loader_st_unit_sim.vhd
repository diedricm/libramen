library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
  
--REGMAP  
--0x0 Start
--0x1 Reply cdest
--0x2 stream cdest
--0x3 buffer base
--0x4 requested tag range
    
entity loader_st_unit_sim is
generic (
        SIM_MEMORY_WORDS : natural := 1024;
        SIM_MEMORY_LATENCY : natural := 10
);
Port (
    
);
end loader_st_unit_sim;

architecture Behavioral of loader_st_unit_sim is

end architecture;