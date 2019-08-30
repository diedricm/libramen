library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity switch is
generic (
	TUPPLE_COUNT : natural := 4;
	INPORT_CNT   : natural := 4;
	OUTPORT_CNT  : natural := 4;
	CDEST_PARSE_OFFSET : natural := 4;
	CDEST_PARSE_LENGTH : natural := 4;
	GATEWAY_ADDR_OFFSET : natural := 8;
	GATEWAY_ADDR_LENGTH : natural := 4;
	SUBNET_IDENTITY     : natural := 0;
	ENABLE_INTERNETWORK_ROUTING : boolean := true;
	CONNECTION_MATRIX : slv(0 to INPORT_CNT*OUTPORT_CNT-1) := (others => '1')
);
Port (
	clk : in std_logic;
	rstn : in std_logic;

    stream_s_tuples  : in tuple_vec(INPORT_CNT*TUPPLE_COUNT-1 downto 0);
	stream_s_status  : in stream_status_vec(INPORT_CNT-1 downto 0);
	stream_s_ready   : out std_logic_vector(INPORT_CNT-1 downto 0);
	
	stream_m_tuples  : out tuple_vec(OUTPORT_CNT*TUPPLE_COUNT-1 downto 0);
	stream_m_status  : out stream_status_vec(OUTPORT_CNT-1 downto 0);
	stream_m_ready : in std_logic_vector(OUTPORT_CNT-1 downto 0)
);
end switch;

architecture Behavioural of switch is
	constant INPORT_CNT_LOG2  : natural := log2_nat(INPORT_CNT);
	constant OUTPORT_CNT_LOG2 : natural := log2_nat(OUTPORT_CNT);
	
	subtype outport_id is unsigned(OUTPORT_CNT_LOG2-1 downto 0);
	subtype inport_id is unsigned(INPORT_CNT_LOG2-1 downto 0);
	type inport_id_vec is array (natural range <>) of inport_id;

    signal port_req_grp : slv(OUTPORT_CNT*INPORT_CNT-1 downto 0) := (others => '0');
    signal output_ready : slv(OUTPORT_CNT*INPORT_CNT-1 downto 0) := (others => '0');
    
    signal stream_forward_tuples  : tuple_vec(OUTPORT_CNT*TUPPLE_COUNT-1 downto 0);
    signal stream_forward_status : stream_status_vec(INPORT_CNT-1 downto 0);
begin

    input_controll: for i in 0 to INPORT_CNT-1 generate
        worker: entity libramen.switch_port_client
        generic map (
            TUPPLE_COUNT => TUPPLE_COUNT,
            INPORT_CNT   => INPORT_CNT,
            OUTPORT_CNT  => OUTPORT_CNT,
            CDEST_PARSE_OFFSET => CDEST_PARSE_OFFSET,
            CDEST_PARSE_LENGTH => CDEST_PARSE_LENGTH,
            GATEWAY_ADDR_OFFSET => GATEWAY_ADDR_OFFSET,
            GATEWAY_ADDR_LENGTH => GATEWAY_ADDR_LENGTH,
            SUBNET_IDENTITY     => SUBNET_IDENTITY,
            ENABLE_INTERNETWORK_ROUTING => ENABLE_INTERNETWORK_ROUTING,
            CONNECTION_VECTOR => CONNECTION_MATRIX(i*OUTPORT_CNT to (i+1)*OUTPORT_CNT-1)
        ) port map (
            clk => clk,
            rstn => rstn,
            
            port_req => port_req_grp((i+1)*OUTPORT_CNT-1 downto i*OUTPORT_CNT),
            
            stream_s_tuples  => stream_s_tuples((i+1)*TUPPLE_COUNT-1 downto i*TUPPLE_COUNT),
            stream_s_status  => stream_s_status(i),
            stream_s_ready   => stream_s_ready(i),
            
            stream_m_tuples  => stream_forward_tuples((i+1)*TUPPLE_COUNT-1 downto i*TUPPLE_COUNT),
            stream_m_status  => stream_forward_status(i),
            stream_m_ready   => output_ready((i+1)*OUTPORT_CNT-1 downto i*OUTPORT_CNT)
        );
	end generate;


    output_arbiter: for i in 0 to OUTPORT_CNT-1 generate
        signal ready_tmp : slv(INPORT_CNT-1 downto 0);
        signal req_tmp : slv(INPORT_CNT-1 downto 0);
    begin
        portctr: entity libramen.switch_port_arbiter
        generic map (
            TUPPLE_COUNT => TUPPLE_COUNT,
            INPORT_CNT   => INPORT_CNT,
            OUTPORT_CNT  => OUTPORT_CNT
        ) port map (
            clk => clk,
            rstn => rstn,
            
            port_req => req_tmp,
            
            stream_s_tuples  => stream_forward_tuples,
            stream_s_status  => stream_forward_status,
            stream_s_ready   => ready_tmp,
            
            stream_m_tuples  => stream_m_tuples((i+1)*TUPPLE_COUNT-1 downto i*TUPPLE_COUNT),
            stream_m_status  => stream_m_status(i),
            stream_m_ready => stream_m_ready(i)
        );
        
        sig_shuffle: for j in 0 to  INPORT_CNT-1 generate
            req_tmp(j) <= port_req_grp(j*OUTPORT_CNT+i);
            output_ready(j*OUTPORT_CNT+i) <= ready_tmp(j);
        end generate;
        
	end generate;
	

end architecture ; -- Behavioural