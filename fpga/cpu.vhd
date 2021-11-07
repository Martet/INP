-- cpu.vhd: Simple 8-bit CPU (BrainLove interpreter)
-- Copyright (C) 2021 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Martin Zmitko (xzmitk01)
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- ram[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_WREN  : out std_logic;                    -- cteni z pameti (DATA_WREN='0') / zapis do pameti (DATA_WREN='1')
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA obsahuje stisknuty znak klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna pokud IN_VLD='1'
   IN_REQ    : out std_logic;                     -- pozadavek na vstup dat z klavesnice
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- pokud OUT_BUSY='1', LCD je zaneprazdnen, nelze zapisovat,  OUT_WREN musi byt '0'
   OUT_WREN : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

	type state_t is (
		s_init,
		s_load_1, s_load_2,
		s_decode,
		s_inc_ptr,
		s_dec_ptr,
		s_inc_val_1, s_inc_val_2,
		s_dec_val_1, s_dec_val_2,
		s_loop_start_0, s_loop_start_1, s_loop_start_2, s_loop_start_3, s_loop_start_wait, 
		s_loop_end_0, s_loop_end_1, s_loop_end_2, s_loop_end_3, s_loop_end_4, s_loop_end_wait, 
		s_print,
		s_input,
		s_break_0, s_break_1, s_break_2, s_break_wait,
		s_halt
	);

	signal pc_inc : std_logic;
	signal pc_dec : std_logic;
	signal pc_ptr : std_logic_vector(11 downto 0);
	
	signal cnt_rst : std_logic;
	signal cnt_inc : std_logic;
	signal cnt_dec : std_logic;
	signal cnt_cnt : std_logic_vector(7 downto 0);
	
	signal ptr_inc : std_logic;
	signal ptr_dec : std_logic;
	signal ptr_ptr : std_logic_vector(9 downto 0);
	
	signal mx_sel : std_logic_vector(1 downto 0);
	
	signal fsm_nstate : state_t;
	signal fsm_state : state_t;

begin

	pc: process(CLK, RESET)
	begin
		if (RESET = '1') then
			pc_ptr <= (others => '0');
		elsif (CLK'event) and (CLK = '1') then
			if (pc_inc = '1') then
				pc_ptr <= pc_ptr + 1;
			elsif (pc_dec = '1') then
				pc_ptr <= pc_ptr - 1;
			end if;
		end if;
	end process;
	
	CODE_ADDR <= pc_ptr;
	
	cnt: process(CLK, RESET)
	begin
		if (RESET = '1') then
			cnt_cnt <= (others => '0');
		elsif (CLK'event) and (CLK = '1') then
			if (cnt_rst = '1') then
				cnt_cnt <= "00000001";
			elsif (cnt_inc = '1') then
				cnt_cnt <= cnt_cnt + 1;
			elsif (cnt_dec = '1') then
				cnt_cnt <= cnt_cnt - 1;
			end if;
		end if;
	end process;
	
	ptr: process(CLK, RESET)
	begin
		if (RESET = '1') then
			ptr_ptr <= (others => '0');
		elsif (CLK'event) and (CLK = '1') then
			if (ptr_inc = '1') then
				ptr_ptr <= ptr_ptr + 1;
			elsif (ptr_dec = '1') then
				ptr_ptr <= ptr_ptr - 1;
			end if;
		end if;
	end process;
	
	DATA_ADDR <= ptr_ptr;
	
	DATA_WDATA <= IN_DATA when mx_sel = "00" else DATA_RDATA - 1 when mx_sel = "01" else DATA_RDATA + 1 when mx_sel = "10";
	
	OUT_DATA <= DATA_RDATA;
	
	fsm_nstate_logic: process(CLK, RESET)
	begin
		if (RESET = '1') then
			fsm_state <= s_init;
		elsif (CLK'event) and (CLK = '1') and (EN = '1') then
			fsm_state <= fsm_nstate;
		end if;
	end process;
	
	fsm: process(fsm_state, OUT_BUSY, IN_VLD)
	begin
		OUT_WREN <= '0';
		IN_REQ <= '0';
		CODE_EN <= '0';
		DATA_WREN <= '0';
		DATA_EN <= '0';
		pc_inc <= '0';
		pc_dec <= '0';
		cnt_rst <= '0';
		cnt_inc <= '0';
		cnt_dec <= '0';
		ptr_inc <= '0';
		ptr_dec <= '0';
		
		case fsm_state is
			when s_init =>
				fsm_nstate <= s_load_1;
				
			when s_load_1 =>
				CODE_EN <= '1';
				fsm_nstate <= s_load_2;
				
			when s_load_2 =>
				fsm_nstate <= s_decode;
				
			when s_decode =>
				case CODE_DATA is
					when x"3E" =>
						fsm_nstate <= s_inc_ptr;
					when x"3C" =>
						fsm_nstate <= s_dec_ptr;
					when x"2B" =>
						fsm_nstate <= s_inc_val_1;
					when x"2D" =>
						fsm_nstate <= s_dec_val_1;
					when x"5B" =>
						fsm_nstate <= s_loop_start_0;
					when x"5D" =>
						fsm_nstate <= s_loop_end_0;
					when x"2E" =>
						fsm_nstate <= s_print;
					when x"2C" =>
						fsm_nstate <= s_input;
					when x"7E" =>
						fsm_nstate <= s_break_0;
					when x"00" =>
						fsm_nstate <= s_halt;
					when others =>
						pc_inc <= '1';
						fsm_nstate <= s_load_1;
				end case;	
				
			when s_inc_ptr =>
				ptr_inc <= '1';
				pc_inc <= '1';
				fsm_nstate <= s_load_1;
				
			when s_dec_ptr =>
				ptr_dec <= '1';
				pc_inc <= '1';
				fsm_nstate <= s_load_1;
			
			when s_inc_val_1 =>
				DATA_EN <= '1';
				fsm_nstate <= s_inc_val_2;
				
			when s_inc_val_2 =>
				DATA_EN <= '1';
				DATA_WREN <= '1';
				mx_sel <= "10";
				pc_inc <= '1';
				fsm_nstate <= s_load_1;
			
			when s_dec_val_1 =>
				DATA_EN <= '1';
				fsm_nstate <= s_dec_val_2;
				
			when s_dec_val_2 =>
				DATA_EN <= '1';
				DATA_WREN <= '1';
				mx_sel <= "01";
				pc_inc <= '1';
				fsm_nstate <= s_load_1;
				
			when s_print =>
				DATA_EN <= '1';
				if (OUT_BUSY = '1') then
					fsm_nstate <= s_print;
				else
					OUT_WREN <= '1';
					pc_inc <= '1';
					fsm_nstate <= s_load_1;
				end if;
				
			when s_input =>
				mx_sel <= "00";
				IN_REQ <= '1';
				if (IN_VLD = '0') then
					fsm_nstate <= s_input;
				else
					DATA_EN <= '1';
					DATA_WREN <= '1';
					pc_inc <= '1';
					fsm_nstate <= s_load_1;
				end if;
				
			when s_loop_start_0 =>
				pc_inc <= '1';
				DATA_EN <= '1';
				fsm_nstate <= s_loop_start_1;
				
			when s_loop_start_1 =>
				if (DATA_RDATA = "00000000") then
					cnt_rst <= '1';
					fsm_nstate <= s_loop_start_2;
				else
					fsm_nstate <= s_load_1;
				end if;
				
			when s_loop_start_2 =>
				if (cnt_cnt = "00000000") then
					fsm_nstate <= s_load_1;
				else
					CODE_EN <= '1';
					fsm_nstate <= s_loop_start_wait;
				end if;
				
			when s_loop_start_wait =>
				fsm_nstate <= s_loop_start_3;
				
			when s_loop_start_3 =>
				if (CODE_DATA = x"5B") then
					cnt_inc <= '1';
				elsif (CODE_DATA = x"5D") then
					cnt_dec <= '1';
				end if;
				pc_inc <= '1';
				fsm_nstate <= s_loop_start_2;
				
			when s_loop_end_0 =>
				DATA_EN <= '1';
				fsm_nstate <= s_loop_end_1;
				
			when s_loop_end_1 =>
				if (DATA_RDATA = "00000000") then
					pc_inc <= '1';
					fsm_nstate <= s_load_1;
				else
					cnt_rst <= '1';
					pc_dec <= '1';
					fsm_nstate <= s_loop_end_2;
				end if;
			
			when s_loop_end_2 =>
				if (cnt_cnt = "00000000") then
					fsm_nstate <= s_load_1;
				else
					CODE_EN <= '1';
					fsm_nstate <= s_loop_end_wait;
				end if;
				
			when s_loop_end_wait =>
				fsm_nstate <= s_loop_end_3;
				
			when s_loop_end_3 =>
				if (CODE_DATA = x"5D") then --]
					cnt_inc <= '1';
				elsif (CODE_DATA = x"5B") then --[
					cnt_dec <= '1';
				end if;
				fsm_nstate <= s_loop_end_4;
				
			when s_loop_end_4 =>
				if (cnt_cnt = "00000000") then
					pc_inc <= '1';
				else
					pc_dec <= '1';
				end if;
				fsm_nstate <= s_loop_end_2;
				
			when s_break_0 =>
				cnt_rst <= '1';
				pc_inc <= '1';
				fsm_nstate <= s_break_1;
				
			when s_break_1 =>
				if (cnt_cnt = "00000000") then
					fsm_nstate <= s_load_1;
				else
					CODE_EN <= '1';
					fsm_nstate <= s_break_wait;
				end if;
				
			when s_break_wait =>
				fsm_nstate <= s_break_2;
				
			when s_break_2 =>
				if (CODE_DATA = x"5B") then
					cnt_inc <= '1';
				elsif (CODE_DATA = x"5D") then
					cnt_dec <= '1';
				end if;
				pc_inc <= '1';
				fsm_nstate <= s_break_1;
			
			when s_halt =>
				fsm_nstate <= s_halt;
				
		end case;
	end process;

end behavioral;
 