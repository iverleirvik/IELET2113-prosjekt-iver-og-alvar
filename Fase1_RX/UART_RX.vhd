library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_RX is 
	generic (
		constant f_clk: integer := 50_000_000;
		constant BAUD_RATE: integer := 9600;
		constant o_smp_bits: integer := 8
		);
	port (
		RX_sig : in std_logic;
		clk: in std_logic;
		seg_ut: out std_logic_vector(7 downto 0);
		utgang: out std_logic
		);
end entity;		

		
architecture rtl of UART_RX is 
-------------------------------------------------------------------------------
-- Define internal signals of circuit
-------------------------------------------------------------------------------
-- clk signals
	signal BAUD_clk 		: std_logic := '0';
	signal o_smp_clk 		: std_logic := '0';
-- hold signals
	signal rx_busy: std_logic := '0';
-- data signals
	signal RX_bit 		: std_logic := '1';
	-- signal RX_bit_rdy : std_logic := '0';
	signal RX_o_smp	: std_logic_vector(6 downto 0);
	signal v_RX_data 	: std_logic_vector(7 downto 0);
	
-- iver signals
	signal o_smp_clk: std_logic := '0';
	signal BAUD_clk: std_logic := '0';
	
---------------------------------------------------------------------------------------------------------
-- Define functions of circuit
---------------------------------------------------------------------------------------------------------
	pure function majority_check(check_vector : std_logic_vector := "0000000") return std_logic is;
		variable majority_val : std_logic;
		variable count_ones : integer := 0;
	begin
		if 	check_vector(1) = '1' then count_ones := count_ones + 1;
		elsif check_vector(2) = '1' then count_ones := count_ones + 1;
		elsif check_vector(3) = '1' then count_ones := count_ones + 1;
		elsif check_vector(4) = '1' then count_ones := count_ones + 1;
		elsif check_vector(5) = '1' then count_ones := count_ones + 1;
		elsif check_vector(6) = '1' then count_ones := count_ones + 1;
		elsif check_vector(7) = '1' then count_ones := count_ones + 1;
		end if;
		if count_ones > 3 then majority_val := '1';
		else majority_val := '0';
		end if;
		return majority_val;
	end function;

-------------------------------------------------------------------------------
-- Begin architecture
-------------------------------------------------------------------------------
begin
	
	-------------------------------------------------------------------------
	-- Process to handle segment display
	-------------------------------------------------------------------------
	p_seg_handler : process ()
	begin	
	 	case show_num is
			when "00000000" =>	hex_display <= "11000000"; -- 0
			when "00000001" =>	hex_display <= "11111001"; -- 1
			when "00000011" =>	hex_display <= "10100100"; -- 3
			when "00000010" =>	hex_display <= "10110000"; -- 2
			when "00000100" =>	hex_display <= "10011001"; -- 4
			when "00000101" =>	hex_display <= "10010010"; -- 5
			when "00000110" =>	hex_display <= "10000010"; -- 6
			when "00000111" =>	hex_display <= "11111000"; -- 7
			when "00001000" =>	hex_display <= "10000000"; -- 8
			when "00001001" =>	hex_display <= "10010000"; -- 9
			when "00000000" =>	hex_display <= "10001000"; -- A
			when "00000000" =>	hex_display <= "10000011"; -- B
			when "00000000" =>	hex_display <= "11000110"; -- C
			when "00000000" =>	hex_display <= "10000000"; -- D
			when "00000000" =>	hex_display <= "10000110"; -- E
			when others	 =>	hex_display <= "10001110"; -- F
		end case;
	end process;
	
	-------------------------------------------------------------------------
	-- Use system clock to generate oversampling clock and clk for baud rate.
	-------------------------------------------------------------------------
	p_clock_division: process(clk)
		constant o_smp_factor: integer := f_clk/(baud_rate * o_smp_bits);
		variable o_smp_clk_cnt: integer := 0;
		variable BAUD_clk_cnt: integer := 0;
	begin
		if rising_edge(clk) then
			o_smp_clk_cnt := o_smp_clk_cnt + 1;
			if (o_smp_clk_cnt >= o_smp_factor) then
				o_smp_clk_cnt := 0;
				o_smp_clk <= not o_smp_clk;
				
				BAUD_clk_cnt := BAUD_clk_cnt + 1; 
				if (BAUD_clk_cnt >= o_smp_bits) then -- Baud rate clk sjekkes her for å effektivisere 
					BAUD_clk_cnt := 0; -- programmet. Man unngår å sjekke hver eneste gang.
					BAUD_clk <= not BAUD_clk;
				end if;
			end if;
		end if;	
	end process;
	
	-------------------------------------------------------------------------
	-- Seperates data bits from stop and start bits
	-------------------------------------------------------------------------
	p_data_seperation : process(clk, rx_bit)
		type t_state is (n_data, r_data);
		variable state: t_state <= n_data;
		variable cnt_data: integer := 0:
	begin
		case state is 
			when n_data =>
				rx_busy <= '0';
				if rx_data = '0' then 
					state := r_data;
				end if;
			when r_data =>
				rx_busy <= '1';
				if cnt_data < 8 then
					v_rx_data(cnt_data) <= rx_bit;
					cnt_data := cnt_data + 1;
				elsif cnt_data >= 8 then
					state := n_data;
		end case;
	end process;
	
	--------------------------------------------------------------------------
	-- Process for reading RX_sig preforming 8 times oversampling and using 
	-- the 7 rightmost readings to decide value of the recieved bit.
	--------------------------------------------------------------------------
	p_read_bit_val :process (RX_bit, RX_o_smp)
		variable o_smp_cnt : integer range 0 to 8;
	begin
		if rising_edge(o_smp_clk) then 
			if o_smp_cnt > 0 then 
				shift_left(RX_o_smp, 1);
				RX_o_smp(0) <= RX_sig;
				if o_smp_cnt = 7 then 
					RX_bit <= majority_check(RX_o_smp);
				end if;
			end if;
			o_smp_cnt := o_smp_cnt + 1;
			if o_smp_cnt >= 8 then 
				o_smp_cnt := 0;
			end if;
		end if;
	end process;
	-------------------------------------------------------------------------
	-- Set signals that go out equal to their inn system counterparts
	-------------------------------------------------------------------------
	seg_ut <= hex_display;
	utgang <= baud_rate_clk;
	
end architecture;
