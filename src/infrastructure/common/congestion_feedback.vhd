library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;

entity vaxis_congestion_feedback is
generic (
	TDATA_WIDTH : natural := 12;
	TDEST_WIDTH : natural := 14;
	TUSER_WIDTH : natural := 3;
    BACKOFF_DETECTION_PERIOD : natural := 3;
    CIRCUIT_SETUP_PROBE_PERIOD : natural := 3
);
Port (
    clk : in std_logic;
    rstn : in std_logic;
    
    trigger_backoff : in std_logic;

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
end vaxis_congestion_feedback;

architecture Behavioral of vaxis_congestion_feedback is
	-- State diagram:
	--
	--   +--------------+
	--   |     Await    |
	--   |    Backoff   |<-----------------+
	--   |    Request   |                  |
	--   +--------------+                  |
	--          |                          |
	--          |-backoff=1                |
	--          |                          |
    --          v                          |
	--   +--------------+                  |
	--   |     Block    |                  |-idle counter=0
	--   |    circuit   |                  |
	--   +--------------+                  |
	--          |                          |
	--          |-backoff counter=0        |
	--          |                          |
	--          v                          |
	--   +--------------+                  |
	--   |     IDLE     |------------------+
	--   +--------------+

	type unit_state is (AWAIT_BACKOFF_REQ, BLOCK_CIRCUIT, IDLE);
	signal curr_state : unit_state := AWAIT_BACKOFF_REQ;

    signal backoff_counter : natural;
    signal idle_counter : natural;

    signal transmission_active : std_logic;
    
    signal TDATA_reg  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	signal TVALID_reg : std_logic;
	signal TREADY_reg : std_logic;
	signal TDEST_reg  : std_logic_vector(TDEST_WIDTH-1 downto 0);
	signal TUSER_reg  : std_logic_vector(TUSER_WIDTH-1 downto 0);
	signal TLAST_reg  : std_logic;
begin

    
    main: process (clk)
    begin
        if rising_edge(clk) then
        	if rstn = '1' then
        		if (trigger_backoff = '1') AND (curr_state = AWAIT_BACKOFF_REQ) then
					curr_state <= BLOCK_CIRCUIT;
					backoff_counter <= BACKOFF_DETECTION_PERIOD;
        		end if;

    			if curr_state = BLOCK_CIRCUIT then
    				if backoff_counter /= 0 then
    					backoff_counter <= backoff_counter - 1;
					else
						curr_state <= IDLE;
						idle_counter <= CIRCUIT_SETUP_PROBE_PERIOD;
    				end if;
    			end if;

    			if curr_state = IDLE then
    				if idle_counter /= 0 then
    					idle_counter <= idle_counter - 1;
					else
						curr_state <= AWAIT_BACKOFF_REQ;
    				end if;
    			end if;

            end if;
        end if;
    end process;
    
    transmission_active <= '1' when (curr_state /= BLOCK_CIRCUIT) else '0';
    TVALID_reg <= TVALID_s AND transmission_active;
    TREADY_s <= TREADY_reg AND transmission_active;
	TDATA_reg <= TDATA_s;
	TUSER_reg <= TUSER_s;
	TLAST_reg <= '0';
	TDEST_reg <= TDEST_s;
	
	regslice: entity vaxis.axis_register_slice
    generic map (
        TDATA_WIDTH => TDATA_WIDTH,
        TDEST_WIDTH => TDEST_WIDTH,
        TUSER_WIDTH => TUSER_WIDTH
    ) port map (
        clk => clk,
        rstn => rstn,
    
        TDATA_s  => TDATA_reg,
        TVALID_s => TVALID_reg,
        TREADY_s => TREADY_reg,
        TDEST_s  => TDEST_reg,
        TUSER_s  => TUSER_reg,
        TLAST_s  => TLAST_reg,
        
        TDATA_m  => TDATA_m,
        TVALID_m => TVALID_m,
        TREADY_m => TREADY_m,
        TDEST_m  => TDEST_m,
        TUSER_m  => TUSER_m,
        TLAST_m  => TLAST_m
    );
end Behavioral;