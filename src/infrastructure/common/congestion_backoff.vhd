library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
library vaxis;
	use vaxis.vaxis_pkg.ALL;

entity vaxis_congestion_backoff is
generic (
	TDATA_WIDTH : natural := 12;
	TDEST_WIDTH : natural := 14;
	TUSER_WIDTH : natural := 3;
	BACKOFF_DETECTION_PERIOD : natural := 2;
	CIRCUIT_SETUP_PROBE_PERIOD : natural := 4
);
Port (
	clk : in std_logic;
	rstn : in std_logic;

	backoff : out std_logic;
	
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
end vaxis_congestion_backoff;

architecture Behavioral of vaxis_congestion_backoff is
	-- State diagram:
	--
	--   +--------------+
	--   |     Await    |      output.ready=1
	--   |   Connection | <-------------------------+
	--   |    Request   |                           |
	--   +--------------+                           |
	--          |                                   |
	--          |-input.valid=1                     |
	--          |                                   |
    --          v                                   |
	--   +--------------+                           |
	--   |              | congestion counter=0 +-----------+
	--   | Probe Ciruit |--------------------->| Terminate |
	--   |              |                      +-----------+
	--   +--------------+                           ^
	--          |                                   |
	--          |-probe counter=0                   |
	--          |                                   |
	--          v                                   |
	--   +--------------+                           |
	--   | Await backoff|  congestion counter=0     |
	--   |    signal    |---------------------------+
	--   +--------------+    OR new TDEST_s
	               
	type backoff_state_type is (AWAIT_CONN_REQ, PROBE_CIRCUIT_SETUP, AWAIT_BACKOFF_SIGNAL, TERMINATE);
	signal curr_state : backoff_state_type := AWAIT_CONN_REQ;
	signal next_state : backoff_state_type;
	
	signal circuit_destination : std_logic_vector(TDEST_WIDTH-1 downto 0) := (others => '0');

	signal detection_counter : natural range 0 to BACKOFF_DETECTION_PERIOD;
	signal probe_counter : natural range 0 to CIRCUIT_SETUP_PROBE_PERIOD;

    signal TDATA_reg  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	signal TVALID_reg : std_logic;
	signal TREADY_reg : std_logic;
	signal TDEST_reg  : std_logic_vector(TDEST_WIDTH-1 downto 0);
	signal TUSER_reg  : std_logic_vector(TUSER_WIDTH-1 downto 0);
	signal TLAST_reg  : std_logic;	
begin

	counters: process (clk)
	begin
		if rising_edge(clk) then
			backoff <= '0';

			if rstn = '1' then

				if TREADY_reg = '1' then
					detection_counter <= BACKOFF_DETECTION_PERIOD;
				else
					if detection_counter /= 0 then
						detection_counter <= detection_counter - 1;
					end if;
				end if;

				if probe_counter /= 0 then
					probe_counter <= probe_counter - 1;
				end if;

				if (curr_state = AWAIT_CONN_REQ) AND (next_state = PROBE_CIRCUIT_SETUP) then
					circuit_destination <= TDEST_s;
					probe_counter <= CIRCUIT_SETUP_PROBE_PERIOD;
				end if;

				if (curr_state /= TERMINATE) AND (next_state = TERMINATE) then
					backoff <= '1';
				end if;

			end if;

		end if;
	end process;

	state_transition: process (curr_state, detection_counter, probe_counter, TVALID_s, TREADY_reg, TDEST_s, circuit_destination)
	begin
		next_state <= curr_state;
		case curr_state is
			when AWAIT_CONN_REQ =>
				if TVALID_s = '1' then
					next_state <= PROBE_CIRCUIT_SETUP;
				end if;
				
			when PROBE_CIRCUIT_SETUP =>
				if detection_counter = 0 then
					next_state <= TERMINATE;
				end if;

				if (probe_counter = 0) AND (TREADY_reg = '1') then
					next_state <= AWAIT_BACKOFF_SIGNAL;
				end if;

			when AWAIT_BACKOFF_SIGNAL => 
				if (detection_counter = 0) OR (circuit_destination /= TDEST_s) then
					next_state <= TERMINATE;
				end if;

			when TERMINATE =>
				if TREADY_reg = '1' then
					next_state <= AWAIT_CONN_REQ;
				end if;

		end case;
	end process;

	stream_mux: process (curr_state, TREADY_reg, TVALID_s, TUSER_s, TLAST_s, TREADY_m)
	begin
		case curr_state is
			when AWAIT_CONN_REQ =>
				TREADY_s <= '0';
				TVALID_reg <= '0';
				TUSER_reg <= VAXIS_TLAST_MASK_SOFTEND_NO_DATA;
				TLAST_reg <= '0';

			when PROBE_CIRCUIT_SETUP =>
				TREADY_s <= '0';
				TVALID_reg <= '1';
				TUSER_reg <= VAXIS_TLAST_MASK_SOFTEND_NO_DATA;
				TLAST_reg <= '0';

			when AWAIT_BACKOFF_SIGNAL => 
				TREADY_s <= TREADY_m;
				TVALID_reg <= TVALID_s;
				TUSER_reg <= TUSER_s;
				TLAST_reg <= TLAST_s;

			when TERMINATE =>
				TREADY_s <= '0';
				TVALID_reg <= '1';
				TUSER_reg <= VAXIS_TLAST_MASK_SOFTEND_NO_DATA;
				TLAST_reg <= '1';

		end case;
	end process;

	TDEST_reg <= circuit_destination;
	TDATA_reg <= TDATA_s;
    
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