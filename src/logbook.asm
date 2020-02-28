;=============================================================================
;
;   File logbook.asm                          combined next generation V3.08.8
;
;   Logbook
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-11-12 : [mH] moving from OSTC code
;
;=============================================================================


#include "hwos.inc"						; mandatory header
#include "tft.inc"
#include "external_flash.inc"
#include "math.inc"
#include "strings.inc"
#include "convert.inc"
#include "tft_outputs.inc"
#include "eeprom_rs232.inc"
#include "menu_processor.inc"
#include "start.inc"
#include "surfmode.inc"
#include "divemode.inc"
#include "ghostwriter.inc"
#include "rtc.inc"

#DEFINE inside_loogbook
#include "logbook.inc"


	extern	do_main_menu2
	extern	gaslist_show_mix


;---- Private local variables ------------------------------------------------

	CBLOCK	local1						; max size is 16 byte !!!
		count_temperature				; current sample count for temperature divisor
		count_deco						; current sample count for deco (ceiling) divisor
		logbook_cur_depth:2				; current depth, for drawing profile
		logbook_cur_tp:2				; current temperature, for drawing profile
		logbook_last_tp					; Y of the last item in Tp° curve
		logbook_min_tp:2				; min temperature, for drawing profile
		logbook_max_tp:2				; maximum temperature, for drawing profile
		logbook_ceiling					; current ceiling, for drawing profile
		logbook_flags					; flags only used in logbook.asm
		logbook_page_number				; page# in logbook
		logbook_divenumber				; # of dive in list during search
		logbook_max_dive_counter		; counts dive# to zero
	ENDC								; used: 16 byte, remaining: 0 byte => FULL

	CBLOCK	local2						; max size is 16 byte !!!
		profile_temp1:2					; temp for profile display
		profile_temp2:2					; temp for profile display
		logbook_sample_counter:2		; amount of read samples
		y_scale:2						; y-scale (the horizontal lines)
		x_scale:2						; x-scale (the vertical lines)
		logbook_pixel_x_pos				; x2 position of current pixel in X-direction
		logbook_min_temp_pos			; lowest row in the temp graph
		logbook_max_temp_pos			; lowest row in the temp graph
		logbook_menupos_temp			; last position of cursor
		logbook_divenumber_temp			; used to back-up dive number
		logbook_max_dive_counter_temp	; used to back-up max_dive_counter
	ENDC								; used: 16 byte, remaining: 0 byte => FULL

	CBLOCK	local3						; max size is 16 byte !!!
		divenumber						; used for accessing dives
		vertical_interval:2				; holds interval of samples for vertical 10min line
		backup_color1					; used for restoring drawing color
		backup_color2					; used for restoring drawing color
		fill_between_rows				; used for fill between rows
		logbook_temp					; used as temp
		logbook_temp_backup				; used as backup for temp
		divisor_temperature				; divisor used while sampling of the dive data
		divisor_deco					; divisor used while sampling of the dive data
		divisor_gf						; divisor used while sampling of the dive data
		divisor_ppo2_sensors			; divisor used while sampling of the dive data
		divisor_decoplan				; divisor used while sampling of the dive data
		divisor_cns						; divisor used while sampling of the dive data
		divisor_tank					; divisor used while sampling of the dive data
		total_num_dives					; total number of dives (low byte on)
	ENDC								; used: 16 byte, remaining: 0 byte => full


	; Remarks: The variable gaslist_gas is "misused" here as a local variable,
	;          because the storage space for local variables is fully used up.
	;
	;          This code includes decoding and displaying of log data for Trimix
	;          and CCR/pSCR dives to make sure that if such dives are in the
	;          logbook they will be displayed correctly.

;---- Defines ----------------------------------------------------------------

; Flags
#DEFINE return_from_profileview		logbook_flags,0
#DEFINE all_dives_shown				logbook_flags,1
#DEFINE logbook_page_not_empty		logbook_flags,2
#DEFINE end_of_profile				logbook_flags,3
#DEFINE keep_cursor_new_page		logbook_flags,4
#DEFINE log_marker_found			logbook_flags,5
#DEFINE log_show_gas_short			logbook_flags,6
;									logbook_flags,7	; unused


; Logbook Coordinates
#DEFINE logbook_list_left			.10				; column of dive# in list
#DEFINE logbook_row_offset			.27				; distance between rows of list
#DEFINE logbook_row_number			.7				; number of dive entry rows per list

; Profile display
#DEFINE profile_height_pixels		.157			; amount of pixels height for profile display
#DEFINE profile_width_pixels		.156			; amount of pixels width for profile display
#DEFINE profile_left				.1				; left border
#DEFINE profile_top					.65				; top border

; "Bailout"
#DEFINE logbook_bailout_column		.124
#DEFINE logbook_bailout_row			.207

; Dive number
#DEFINE logbook_divenumer_column	.1
#DEFINE logbook_divenumer_row		.1

; Date and Time
#DEFINE logbook_date_column			.100
#DEFINE logbook_date_row			.7
#DEFINE logbook_time_column			.120
#DEFINE logbook_time_row			.38

; Max. Depth
#DEFINE log_max_value_row			.38
#DEFINE log_max_value_column		.1

; Divetime
#DEFINE log_divetime_mins_value_row		.38
#DEFINE log_divetime_mins_value_column	.60

; Gaslist below profile
#DEFINE log_gas_row					.225
#DEFINE log_gas_column1				.0
#DEFINE log_gas_column2				log_gas_column1+(.1*.32)
#DEFINE log_gas_column3				log_gas_column1+(.2*.32)
#DEFINE log_gas_column4				log_gas_column1+(.3*.32)
#DEFINE log_gas_column5				log_gas_column1+(.4*.32)

; Logbook Page2
; Gaslist
#DEFINE log2_title_row1				.20
#DEFINE log2_title_column			.90
#DEFINE log2_gas_column				log2_title_column
#DEFINE log2_gas_row1				.36
#DEFINE log2_gas_row2				1*.16+log2_gas_row1
#DEFINE log2_gas_row3				2*.16+log2_gas_row1
#DEFINE log2_gas_row4				3*.16+log2_gas_row1
#DEFINE log2_gas_row5				4*.16+log2_gas_row1

; Setpoint List
#DEFINE log2_title_sp_row			.130
#DEFINE log2_sp_row1				.146
#DEFINE log2_sp_row2				1*.16+log2_sp_row1
#DEFINE log2_sp_row3				2*.16+log2_sp_row1
#DEFINE log2_sp_row4				3*.16+log2_sp_row1
#DEFINE log2_sp_row5				4*.16+log2_sp_row1

; Details list
#DEFINE log2_salinity_row			.55
#DEFINE log2_salinity_column		.2
#DEFINE log2_cns_row				.1*.16+log2_salinity_row
#DEFINE log2_cns_column				log2_salinity_column
#DEFINE log2_avr_row				.2*.16+log2_salinity_row
#DEFINE log2_avr_column				log2_salinity_column
#DEFINE log2_decomodel2_row			.3*.16+log2_salinity_row
#DEFINE log2_decomodel2_column		log2_salinity_column
#DEFINE log2_decomodel3_row			.4*.16+log2_salinity_row
#DEFINE log2_decomodel3_column		log2_salinity_column
#DEFINE log2_decomodel_row			.5*.16+log2_salinity_row
#DEFINE log2_decomodel_column		log2_salinity_column
#DEFINE log2_firmware_row			.6*.16+log2_salinity_row
#DEFINE log2_firmware_column		log2_salinity_column
#DEFINE log2_battery_row			.7*.16+log2_salinity_row
#DEFINE log2_battery_column			log2_salinity_column
#DEFINE log2_divemode_row			.8*.16+log2_salinity_row
#DEFINE log2_divemode_column		log2_salinity_column
#DEFINE log2_lastdeco_row			.9*.16+log2_salinity_row
#DEFINE log2_lastdeco_column		log2_salinity_column

; Air pressure
#DEFINE MBAR_row					.10*.16+log2_salinity_row
#DEFINE MBAR_column					log2_salinity_column


logbook		CODE

;=============================================================================

TFT_logbook_cursor:
	WIN_BOX_BLACK .0, .239, logbook_list_left-.8, logbook_list_left-.1    ; top, bottom, left, right

	WIN_LEFT logbook_list_left-.8					; set horizontal position
	WIN_FONT FT_SMALL								; select small font
	call	TFT_standard_color						; print in white color
	decf	menu_pos_cur,W							; get row number -1 into WREG
	mullw	logbook_row_offset						; multiply with vertical offset between rows
	movff	PRODL,win_top							; set vertical position
	STRCPY_PRINT "\xB7"								; print cursor
	return											; done


	global	logbook									; entry point coming from menu_tree.asm
logbook:
	call	TFT_boot
;	call	TFT_standard_color

	clrf	logbook_flags							; clear all flags
	clrf	menu_pos_max							; clear number of used rows on current page
	clrf	logbook_page_number						; here: # of current displayed page
	clrf	logbook_divenumber						; # of dive in list during search
	clrf	logbook_temp
	clrf	logbook_temp_backup

	movlw	logbook_row_number						; get number of dive entry rows per list
	movwf	menu_pos_cur							; initialize cursor position to last entry

	call	eeprom_total_dives_read					; read total number of dives
	movf	mpr+0,W									; extract low byte
	movwf	logbook_max_dive_counter				; copy to logbook_max_dive_counter
	movwf	total_num_dives							; copy to total_num_dives, too


;-----------------------------------------------------------------------------
; display dive headers backwards from latest dive to first dive, stop when
; - no dive is stored                (no valid header found)
; - current dive has no valid header (past last dive, < 256 dives)
; - when 255 dives are reached       (logbook display limit)

logbook2:
	incf	logbook_temp,F							; increase dive counter
	incf	logbook_temp,W							; = 0x..FF ?
	bz		logbook_reset							; YES - loop

	; compute index for dive to show / goto previous dive
	decf	logbook_max_dive_counter,F

	; compute the start address of the header of the dive to show
	movf	logbook_max_dive_counter,W				; hand over index in WREG
	call	log_header_addr_by_index				; compute address of header start

	; copy the first 22 byte of the header from FLASH to memory
	FLASH_RR_READ mpr,header_buffer,.22

	; check if there is a header
	MOVCC	header_buffer+index_header_start,WREG	; read first byte of header
	xorlw	0xFA									; header start code found?
	bnz		logbook3b								; NO  - abort
	incf	logbook_divenumber,F					; YES - new header found, increase logbook_divenumber
	bra		logbook4								;     - done with searching, display the header

logbook3b:
	btfss	logbook_page_not_empty					; was there at least one dive?
	bra		exit_logbook							; NO  - not a single header was found, leave logbook
	bra		logbook_display_loop2					; YES - can show something

logbook_reset:
	tstfsz	logbook_divenumber						; was there at least one dive?
	bra		logbook_reset2							; YES - proceed
	bra		logbook3b								; NO  - nothing to do

logbook_reset2:
	bsf		all_dives_shown							; flag all dives are shown
	bra		logbook_display_loop2					; check number of dives on page and append navigation

logbook4:
	btfsc	all_dives_shown							; all dives shown?
	bra		logbook_display_loop2					; YES - page done
	call	display_listdive						; NO  - display short header for list on current list position
	movlw	logbook_row_number						;     - load max number of lines
	cpfseq	menu_pos_cur							;     - cursor on last line (exit)?
	bra		logbook_display_loop1					;       NO - skip saving of address

	; store all registers required to rebuilt the current logbook page after the detail/profile view
	movff	logbook_divenumber,logbook_divenumber_temp				; # of dive in list of the current page
	movff	logbook_max_dive_counter,logbook_max_dive_counter_temp	; backup counter
	movff	logbook_temp,logbook_temp_backup						; amount of dives drawn until now

logbook_display_loop1:
	decfsz	menu_pos_cur,F							; all lines used up?
	bra		logbook2								; NO  - loop to show another dive
logbook_display_loop2:
	btfss	logbook_page_not_empty					; YES - was there one dive at all?
	bra		logbook									;       NO  - restart from the first page
	;bra	logbook_display_loop3					;       YES - complete page and start HMI

logbook_display_loop3:

	; print navigation lines
	WIN_LEFT	logbook_list_left
	WIN_TOP		logbook_row_offset*(logbook_row_number+.0)
	STRCPY_TEXT_PRINT tNextLog						; "Next Page"

	WIN_LEFT	logbook_list_left
	WIN_TOP		logbook_row_offset*(logbook_row_number+.1)
	STRCPY_TEXT_PRINT tExit							; "Exit"

	movlw	d'1'									; default cursor to position 1
	btfsc	return_from_profileview					; returning from a detail/profile view?
	movf	logbook_menupos_temp,W					; YES - reload last cursor position
	movwf	menu_pos_cur							; set cursor position
	movlw	logbook_row_number+.1					; get menu line where the next page item is
	btfsc	keep_cursor_new_page					; do we come from the "next page" line?
	movwf	menu_pos_cur							; YES - set cursor to "next line" again

	bcf		return_from_profileview					; clear flag for returning from detail/profile view
	bcf		keep_cursor_new_page					; clear flag for coming from "next page"
	bcf		logbook_page_not_empty					; obviously the current page is NOT empty

	call	TFT_logbook_cursor						; show the cursor

logbook_loop_pre:
	call	logbook_preloop_tasks					; clear timeout, some flags and switch on backlight
logbook_loop:
	btfsc	switch_left								; left button pressed?
	goto	next_logbook3							; YES - move cursor
	btfsc	switch_right							; NO  - right button pressed?
	bra		display_profile_or_exit					;       YES - view details/profile
	call	housekeeping							;       NO  - handle screen dump request, timeout and entering dive mode
	bra		logbook_loop							;           - loop waiting for something to do

display_profile_or_exit:
	movlw	logbook_row_number+.2					; get menu line were the exit item is
	cpfseq	menu_pos_cur							; cursor on exit line?
	bra		display_profile_or_next					; NO  - show profile or next page
	;bra	exit_logbook							; YES - exit logbook

exit_logbook:
	bcf		switch_right							; clear pending button events
	bcf		switch_left								; ...
	goto	do_main_menu2							; jump-back to main menu (in menu_tree.asm)

display_profile_or_next:
	movlw	logbook_row_number+.1					; get menu line were the next page item is
	cpfseq	menu_pos_cur							; cursor on next page line?
	bra		display_profile							; NO  - show profile of selected dive
	goto	next_logbook2							; YES - show next page

;-----------------------------------------------------------------------------
; show graphical dive profile
;
display_profile:
	bcf		bailout_mode							; clear event flag
	bcf		event_gas_change_gas6					; clear event flag
	movff	menu_pos_cur,logbook_menupos_temp		; store current cursor position
	bsf		return_from_profileview					; tweak search routine to exit after found

	; compute the number of the dive to show
	movf	logbook_page_number,W					; get page number of page we are on
	mullw	logbook_row_number						; multiply with number of dives per page
	movf	PRODL,W									; copy low byte to WREG
	addwf	menu_pos_cur,W							; add number of selected dive on current page page
	movwf	divenumber								; result is the number of the dive to show

	; compute the header address by the dive number
	call	log_header_addr_by_divenumber

	; copy the complete header from FLASH to memory
	FLASH_RR_READ mpr,header_buffer,.256

	; read the sampling rate
	MOVCC	header_buffer+index_samplingrate,sampling_rate

	; --- start drawing the dive profile page ---

display_profile2:
	call	TFT_boot
	call	TFT_standard_color

	; show dive number
	call	logbook_show_divenumber					; show the dive number in medium font

	; show date
	WIN_SMALL logbook_date_column, logbook_date_row
	MOVTT	header_buffer+index_date,mpr			; read date
	call	TFT_convert_date						; converts into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in postinc2
	STRCAT_PRINT ""

	; show dive mode
	WIN_SMALL log_divetime_mins_value_column,logbook_date_row	; align with surrounding data
	MOVCC	header_buffer+index_divemode,lo			; read dive type (0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=pSCR)
	call	TFT_decotype_logbook					; "strcat_print"s dive mode (OC, CC, Gauge, Apnea or pSCR)
													; also sets aux_flag in case the dive was done in a deco mode

	; show time
	WIN_SMALL logbook_time_column, logbook_time_row
	MOVII	header_buffer+index_time,mpr			; get time
	output_99x										; print hour
	PUTC	':'										; print spacing ":"
	movff	hi,lo									; print minute
	output_99x										; ...
	STRCAT_PRINT ""									; display 1st row of details

	; get log format version
	MOVCC	header_buffer+index_profile_version,lo	; read profile format version
	movlw	0x24
	cpfslt	lo										; < 0x24 ?
	bra		log_skip_extra_icon						; YES -  skip end of dive icon

	; print end of dive icon
	WIN_SMALL logbook_time_column-.8, logbook_time_row
	STRCPY_PRINT 0x94

log_skip_extra_icon:
	MOVII	header_buffer+index_max_depth,mpr		; get max depth in [mbar]

	; compute vertical scale (y-axis)
	MOVII	mpr,xA
	MOVLI	profile_height_pixels,xB				; number of pixels available for plot
	call	div16x16								; xC = xA / xB with xA as remainder
	MOVII	xC,y_scale								; y-scale (mbar/pixel)
	INCI	y_scale									; increase by one to include potential remainder (round up)

	; compute number of pixels per each 10 m
	movlw	LOW   ((profile_height_pixels+1)*.1000)
	movwf	xC+0
	movlw	HIGH  (((profile_height_pixels+1)*.1000) & h'FFFF')
	movwf	xC+1
	movlw	UPPER ((profile_height_pixels+1)*.1000)
	movwf	xC+2
	clrf	xC+3
	MOVII	mpr,xB									; get max. depth in mbar
	call	div32x16								; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,x_scale								; pixels/10m (for scale, draw any xx rows a scale-line)

	; safeguard scale to become zero
	movf	x_scale+0,W								; get      low  byte
	iorwf	x_scale+1,W								; ior with high byte
	btfsc	STATUS,Z								; x_scale = zero ?
	incf	x_scale+1,F								; YES - set to 256 to make "display_profile2e" working

	; calculate vertical interval
	MOVLI	.600,xA									; a vertical line every 600 seconds (10 minutes)
	movff	sampling_rate,xB+0						; copy sampling rate to xB, low  byte
	clrf	xB+1									; clear                 xB, high byte
	call	div16x16								; xC=xA/xB with xA as remainder
	MOVII	xC,vertical_interval					; vertical_interval:2 holds number of samples between each vertical 10 min lines

	; get total sample time in seconds
	MOVII	header_buffer+index_total_seconds,xA

	; calculate x-scale value
	MOVLI	profile_width_pixels,xB					; horizontal width of plot area in pixels
	call	div16x16								; xC = xA / xB with xA as remainder: seconds per pixel
	MOVII	xC,xA									; copy seconds/pixel to xA
	movff	sampling_rate,xB+0						; divide through sampling rate
	clrf	              xB+1						; ...
	call	div16x16								; xC = xA / xB with xA as remainder: samples per pixel
	MOVII	xC,profile_temp1						; store samples/pixel
	INCI	profile_temp1							; increment result by 1 to include potential remainder (round up)

	WIN_SMALL log_max_value_column,log_max_value_row

	; get max depth in [mbar]
	MOVII	header_buffer+index_max_depth,mpr

	; print depth
	TSTOSS	opt_units								; 0=Meters, 1=Feets
	bra		display_profile_offset4_metric			; 0 - do metric
	;bra	display_profile_offset4_imperial		; 1 - do imperial

display_profile_offset4_imperial:
	call	convert_cm_to_feet						; convert value in mpr from [cm] to [feet]
	PUTC	' '
	bcf		leftbind
	output_16_3										; limit to 999 and display only (0-999)
	STRCAT_TEXT_PRINT tFeets
	bra		display_profile_offset4_common

display_profile_offset4_metric:
	bsf		ignore_digit5							; no cm...
	movlw	d'1'									; no 1000 m
	movwf	ignore_digits							; ...
	output_16dp d'3'								; xxx.y
	STRCAT_TEXT_PRINT tMeters
	;bra	display_profile_offset4_common

display_profile_offset4_common:
	WIN_SMALL log_divetime_mins_value_column,log_divetime_mins_value_row
	bsf		leftbind

	; show dive time minutes : seconds
	MOVTT	header_buffer+index_divetime,mpr		; get   dive time
	output_16										; print dive time minutes
	PUTC	'm'										; print "m" (minutes)
	movff	up,lo									; print dive time seconds
	output_99x										; dive time seconds
	STRCAT_PRINT "s"								; print "s" (seconds)

	; get minimum temperature (for later use)
	MOVII	header_buffer+index_min_temp,logbook_min_tp

	; print gases
	btfss	aux_flag								; dive done in a deco mode?
	bra		logbook_set_gas_color					; NO - always use gas 1 color (white) then

	; set pointer to gas 1 type
	MOVCC	header_buffer+index_gas1+.3,WREG		; read gas type
	decfsz	WREG,W									; = 1 (= "First") ?
	bra		logbook_find_first_gas2					; NO
logbook_set_gas_color:
	movlw	.1										; YES - select white color
	bra		logbook_find_first_gas_done

logbook_find_first_gas2:
	; set pointer to gas 2 type
	MOVCC	header_buffer+index_gas2+.3,WREG		; read gas type
	decfsz	WREG,W									; = 1 (= "First") ?
	bra		logbook_find_first_gas3					; NO
	movlw	.2										; YES - select green color
	bra		logbook_find_first_gas_done

logbook_find_first_gas3:
	; set pointer to gas 3 type
	MOVCC	header_buffer+index_gas3+.3,WREG		; read gas type
	decfsz	WREG,W									; = 1 (= "First") ?
	bra		logbook_find_first_gas4					; NO
	movlw	.3										; YES - select red color
	bra		logbook_find_first_gas_done

logbook_find_first_gas4:
	; set pointer to gas 4 type
	MOVCC	header_buffer+index_gas4+.3,WREG		; read gas type
	decfsz	WREG,W									; = 1 (= "First") ?
	bra		logbook_find_first_gas5					; NO
	movlw	.4										; YES - select yellow color
	bra		logbook_find_first_gas_done

logbook_find_first_gas5:
	; must be gas 5 then
	movlw	.5										; select cyan color
	;bra	logbook_find_first_gas_done

logbook_find_first_gas_done:
	movwf	backup_color1							; keep copy of color for later restore
	call	TFT_color_code_gas						; set color

	; set ext_flash_address to the begin of the profile data
	MOVTT	header_buffer+index_profile_start_address,ext_flash_address

	; skip the 0xFA 0xFA header of the profile data
	ext_flash_inc_address_0x20 d'2'

	; initialize flag for signaling when last sample set was read
	bcf		end_of_profile

	; check if the profile actually belongs to this dive (check done with low bytes only)
	FLASH_CC_READ_0x20 lo								; read dive  number in profile
	incf	total_num_dives,W						; WREG = total number of dives + 1
	bsf		STATUS,C								; set borrow
	subfwb	divenumber,W							; WREG = total number of dives - number of dive to show - 1
	cpfseq	lo										; number of dive in profile = number of dive to show?
	bra		display_profile_no_profile				; NO  - no profile data for this dive available
	;bra	display_profile_show_profile			; YES - show profile

display_profile_show_profile:

	; skip high byte of dive number          1 byte
	; skip second header code                2 byte
	; skip length of profile data            3 byte
	; skip sampling rate in profile section  1 byte
	; skip number of divisors                1 byte
	;                                        ======
	;        total number of bytes to skip = 8 byte
	ext_flash_inc_address_0x20 d'8'

	; read divisor temp
	ext_flash_inc_address_0x20 d'2'					; skip information type and length
	FLASH_CW_READ_0x20								; read  temperature divisor
	movwf	divisor_temperature						; store temperature divisor
	movwf	count_temperature						; store to temperature counter, too

	; read divisor deco
	ext_flash_inc_address_0x20 d'2'					; skip information type and length
	FLASH_CW_READ_0x20								; read  deco divisor
	movwf	divisor_deco							; store deco divisor
	movwf	count_deco								; store to deco status counter, too

	; read divisor GF
	ext_flash_inc_address_0x20 d'2'					; skip information type and length
	FLASH_CC_READ_0x20 divisor_gf						; store saturation divisor

	; read divisor ppO2 sensors
	ext_flash_inc_address_0x20 d'2'					; skip information type and length
	FLASH_CC_READ_0x20 divisor_ppo2_sensors			; store ppO2 divisor

	; read divisor deco plan
	ext_flash_inc_address_0x20 d'2'					; skip information type and length
	FLASH_CC_READ_0x20 divisor_decoplan				; store deco plan divisor

	; read divisor CNS
	ext_flash_inc_address_0x20 d'2'					; skip information type and length
	FLASH_CC_READ_0x20 divisor_cns						; store CNS divisor

	; read divisor tank data
	ext_flash_inc_address_0x20 d'2'					; skip information type and length
	FLASH_CC_READ_0x20 divisor_tank					; store tank pressure divisor


	; start drawing the profile

	; set color
	movlw	color_deepblue
	call	TFT_set_color

	; draw a frame around profile area
	WIN_FRAME_COLOR16 profile_top-1,profile_top+profile_height_pixels+1,profile_left-1,profile_left+profile_width_pixels+1

	; draw depth grid
	movlw	profile_top								; set top  position of plot area
	movwf	win_top									; ...
	movlw	profile_left							; set left position of plot area
	movwf	win_leftx2								; ...
	movlw	d'1'									; draw lines of 1 pixel width
	movwf	win_height								; ...
	movlw	profile_width_pixels+.1					; set right position of plot area
	movwf	win_width+0								; ...
	clrf	win_width+1								; ...
	bra		display_profile2_loline					; do not draw the 0 m line
display_profile2_loop:
	call	TFT_box									; draw the line
display_profile2_loline:
	movf	win_top,W								; get last row drawn
	addwf	x_scale+0,W								; add line interval distance, low byte
	tstfsz	x_scale+1								; interval distance > 255 ?
	movlw	d'255'									; YES - would make win_top > 239 -> prepare abort
	btfsc	STATUS,C								; did the add produce a carry?
	movlw	d'255'									; YES - would make win_top > 239 -> prepare abort
	movwf	win_top									; write position of next line back to win_top
	movlw	profile_top+profile_height_pixels+.1	; get limit for last line
	cpfsgt	win_top									; line to draw beyond limit?
	bra		display_profile2_loop					; NO - draw the line

	; do various initializations for drawing the curves
	clrf	gaslist_gas								; here: used as counter for depth readings
	movlw	profile_width_pixels+profile_left-.1
	movwf	ignore_digits							; here: used as counter for x-pixels

	movlw	profile_left+.1
	movwf	logbook_pixel_x_pos						; here: used as column x2 (start at column 5)

	movlw	profile_top+.1							; zero-m row
	movwf	fill_between_rows
	movwf	logbook_last_tp							; initialize for temperature curve, too

	movlw	LOW(-.100)								; initialize max temperature to -10.0 °C
	movwf	logbook_max_tp+0
	movlw	HIGH 0xFFFF & (-.100)
	movwf	logbook_max_tp+1

	setf	logbook_cur_tp+0						; initialize temperature to 0xFFFF = 'no data'
	setf	logbook_cur_tp+1						; ...
	clrf	logbook_last_tp							; also reset previous Y for temperature
	clrf	logbook_ceiling							; ceiling = 0, correct value for no ceiling
	movlw	profile_top+.1
	movwf	logbook_min_temp_pos					; initialize for displaying the lowest  temperature
	movlw	profile_top+profile_height_pixels
	movwf	logbook_max_temp_pos					; initialize for displaying the highest temperature

	movlw	profile_left
	movwf	win_leftx2
	movlw	profile_top
	movwf	win_top
	movlw	profile_height_pixels
	movwf	win_height
	movlw	LOW (profile_width_pixels*.2)
	movwf	win_width+0
	movlw	HIGH (profile_width_pixels*.2)
	movwf	win_width+1
	call	TFT_box_write							; open box for d1

;	INIT_PIXEL_WRITE logbook_pixel_x_pos			; pixel x2 (also sets standard color!)

	; start profile plotting loop
	CLRI	logbook_sample_counter					; clear counter for amount of samples read so far

profile_display_loop:
	; initialize pixel write
	movf	logbook_pixel_x_pos,W
	mullw	2
	call	pixel_write_col320

	MOVII	profile_temp1,profile_temp2				; 16 bit x-scaler

	incf	profile_temp2+1,F
	tstfsz	profile_temp2+0							; must not be zero, is zero?
	bra		profile_display_loop2					; NO  - ok
	incf	profile_temp2+0,F						; YES - increase by 1

profile_display_loop2:
	rcall	profile_view_get_depth					; read one set of depth, temp and event data
	btfsc	end_of_profile							; end of profile data reached?
	bra		profile_display_loop_done				; YES - skip all remaining pixels


	;---- draw ceiling curve, if any ---------------------------------------------

	movf	divisor_deco,W							; get divisor, deco data logged?
	bz		profile_display_skip_deco				; NO - skip

	movf	logbook_ceiling,W						; any deco ceiling?
	bz		profile_display_skip_deco				; NO  - skip

	mullw	.100									; YES - convert to mbar
	MOVII	PROD,               sub_a				;     - ceiling depth
	MOVII	logbook_cur_depth+0,sub_b				;     - current depth
	call	cmpU16									;     - compute ceiling - current depth
	movlw	color_dark_green						;     - dark green if ok
	btfss	neg_flag								;     - current depth > ceiling ?
	movlw	color_dark_red							;       NO - dark red because ceiling is violated
	call	TFT_set_color							;     - set color
	MOVII	PROD,xA									;     - divide pressure in mbar/pixel for row offset
	MOVII	y_scale,xB								;     - ...
	call	div16x16								;     - xC = xA / xB with xA as remainder
	movlw	profile_top+.1							;     - start right after the top line
	movwf	win_top									;     - ...
	movff	logbook_pixel_x_pos,win_leftx2			;     - set left border (0-159)
	movff	xC+0,win_height							;     - set hight
	call	half_vertical_line						;     - color the area

profile_display_skip_deco:

	;---- draw temperature curve, if any ---------------------------------------------

	movf	divisor_temperature,W					; get divisor, deco data logged?
	bz		profile_display_skip_temp				; NO - skip

	movf	logbook_cur_tp+0,W						; did we had a valid temperature record already (0xFF = 'no data')?
	andwf	logbook_cur_tp+1,W						; ...
	incf	WREG									; ...
	bz		profile_display_skip_temp				; NO - skip drawing

	; fixed temperature scale: (-2 .. +35°C * scale256 ) / 153 pixel
	movlw	LOW  (((profile_height_pixels-.10)*.256)/.370)
	movwf	xB+0
	movlw	HIGH (((profile_height_pixels-.10)*.256)/.370)
	movwf	xB+1

	movf	logbook_cur_tp+0,W						; current temperature - (-2.0°C) == temperature + 20
	addlw	LOW(.20)								; low byte
	movwf	xA+0
	movf	logbook_cur_tp+1,W
	btfsc	STATUS,C								; propagate carry, if any
	incf	WREG
	movwf	xA+1
	call	mult16x16								; xA*xB=xC

	; scale: divide by 256 -> just take the high byte
	movf	xC+1,W
	sublw	profile_top+profile_height_pixels-.10	; upside-down: Y = .75 + (.153 - result)
	movwf	xC+0

	; check limits
	movlw	profile_top+.1
	movwf	xC+1
	cpfsgt	xC+0
	movff	xC+1,xC+0

	movlw	color_orange							; select color for temperature curve
	call	TFT_set_color							; set color

	movf	logbook_last_tp,W						; do we have a valid previous value?
	bz		profile_display_temp_1					; NO  - skip the vertical line
	movwf	xC+1									; YES - set end position
	call	profile_display_fill					;     - draw in this column between this row (xC+0) and the last row (xC+1)

profile_display_temp_1:
	movf	xC+0,W									; get position
	cpfsgt	logbook_min_temp_pos					; > min limit?
	movwf	logbook_min_temp_pos					; NO - set to lowest  position for the temp graph
	cpfslt	logbook_max_temp_pos					; < max limit?
	movwf	logbook_max_temp_pos					; NO - set to highest position for the temp graph

	movff	xC+0,logbook_last_tp					; set col (0..159) x row (0..239)
	PIXEL_WRITE logbook_pixel_x_pos,xC+0			; draw a pixel

profile_display_skip_temp:

	;---- draw depth curve ---------------------------------------------------

	MOVII	y_scale,          xB					; divide pressure in mbar/pixel for row offset
	MOVII	logbook_cur_depth,xA					; get current depth
	call	div16x16								; xC = xA / xB with xA as remainder
	movlw	profile_top+.1							; get offset
	addwf	xC+0,F									; add offset
	btfsc	STATUS,C								; profile error?
	movff	fill_between_rows,xC+0					; YES - ignore

	movf	backup_color1,W							; copy gas number to WREG for color-coding
	call	TFT_color_code_gas						; set color

	movff	fill_between_rows,xC+1					; set position
	call	profile_display_fill					; in this column between this row (xC+0) and the last row (xC+1)
	movff	xC+0,fill_between_rows					; store last row for fill routine

	PIXEL_WRITE logbook_pixel_x_pos,xC+0			; draw a pixel
	incf	logbook_pixel_x_pos,F					; advance to next column

	;---- draw marker square, if any -----------------------------------------

	btfss	log_marker_found						; any marker to draw?
	bra		profile_display_skip_marker				; NO  - skip
	bcf		log_marker_found						; YES - clear flag

	; set position
	incf	fill_between_rows,W						; increase row (Y)
	movwf	win_top

	; limit win_top to 220
	movlw	.220
	cpfslt	win_top
	movwf	win_top
	decf	logbook_pixel_x_pos,W					; decrease column (X)
	movwf	win_leftx2

	; limit win_leftx2 to 151
	movlw	.151
	cpfslt	win_leftx2
	movwf	win_leftx2

	; print marker
	movlw	color_orange
	call	TFT_set_color
	WIN_FONT FT_TINY
	lfsr	FSR2,buffer
	STRCPY_PRINT "m"

	movlw	profile_left
	movwf	win_leftx2
	movlw	profile_top
	movwf	win_top
	movlw	profile_height_pixels
	movwf	win_height
	movlw	LOW (profile_width_pixels*.2)
	movwf	win_width+0
	movlw	HIGH (profile_width_pixels*.2)
	movwf	win_width+1
	call	TFT_box_write							; re-open box for d1

profile_display_skip_marker:

	;---- draw CNS curve, if any ---------------------------------------------

	movf	divisor_cns,W							; get divisor, CNS logged?
	bz		profile_display_skip_cns				; NO - skip
	;
	; add further code here...
	;

profile_display_skip_cns:

	;---- draw saturation curve, if any --------------------------------------

	movf	divisor_gf,W							; get divisor, saturation logged?
	bz		profile_display_skip_gf					; NO - skip
	;
	; add further code here...
	;

profile_display_skip_gf:

	; all curves done
	bra		profile_display_skip_loop1


profile_display_skip_loop1:
	dcfsnz	profile_temp2+0,F						; decrement low byte of x-scaler, became zero?
	bra		profile_display_loop3					; YES - decrement high byte
	rcall	profile_view_get_depth					; NO  - read next depth, temp and profile data set
	btfsc	end_of_profile							;     - end-of profile reached?
	bra		profile_display_loop_done				;       YES - skip all remaining pixels
	bra		profile_display_skip_loop1				;       NO  - continue

profile_display_loop3:
	decfsz	profile_temp2+1,F						; decrement high byte of x-scaler, became zero?
	bra		profile_display_skip_loop1				; NO  - continue
	decfsz	ignore_digits,F							; YES - count drown x-pixels to zero, became zero?
	bra		profile_display_loop					;       NO  - draw next sample
	bra		profile_display_loop_done				;       YES - done

profile_display_loop_done:
	btfss	bailout_mode							; bailout during the dive?
	bra		profile_display_gas6					; NO  - skip next
	movlw	color_pink								; YES - show "Bailout" in pink color
	call	TFT_set_color							;     - ...
	WIN_TINY logbook_bailout_column,logbook_bailout_row;  - ...
	STRCPY_TEXT_PRINT tDiveBailout					;     - print text

profile_display_gas6:
	btfss	event_gas_change_gas6					; did a change to gas 6 occurred?
	bra		profile_display_temperatures			; NO  - skip next
	movlw	color_pink								; YES - select color
	call	TFT_set_color							;     - set color
	WIN_TINY logbook_bailout_column,logbook_bailout_row-.15
	STRCPY_TEXT tGas								;     - print "Gas"
	STRCAT_PRINT " 6!"								;     - print " 6!"

profile_display_temperatures:
	movff	logbook_min_temp_pos,win_top			; get Y position at lowest temperature
	movff	logbook_pixel_x_pos,win_leftx2			; get X ...
	movlw	.130									; left border limit
	cpfslt	win_leftx2								; too far to the left?
	movwf	win_leftx2								; YES - set to limit
	WIN_FONT FT_TINY								; select font
	movlw	color_yellow							; select color
	call	TFT_set_color							; set    color

	MOVII	logbook_min_tp,mpr						; get min temperature
	lfsr	FSR2,buffer								; initialize string buffer

	TSTOSS	opt_units								; 0=°C, 1=°F
	bra		logbook_show_temp_metric				; 0 - do Celsius
	;bra	logbook_show_temp_imperial				; 1 - do Fahrenheit

logbook_show_temp_imperial:
	; min temperature
	call	TFT_convert_signed_16bit				; convert lo:hi into signed-short and add '-' to POSTINC2 if required
	call	convert_celsius_to_fahrenheit			; convert value in lo:hi from Celsius to Fahrenheit
	lfsr	FSR2,buffer								; overwrite "-"
	bsf		ignore_digit5							; full degrees only
	output_16
	STRCAT_TEXT_PRINT tLogTunitF
	; max temperature
	movlw	.15
	subwf	logbook_max_temp_pos,W
	movwf	win_top									; Y position at max temperature
	MOVII	logbook_max_tp,mpr
	lfsr	FSR2,buffer
	call	TFT_convert_signed_16bit				; converts lo:hi into signed-short and adds '-' to POSTINC2 if required
	call	convert_celsius_to_fahrenheit			; convert value in lo:hi from Celsius to Fahrenheit
	output_16
	bcf		ignore_digit5
	STRCAT_TEXT_PRINT tLogTunitF
	bra		logbook_show_gases

logbook_show_temp_metric:
	; min temperature
	call	TFT_convert_signed_16bit				; convert lo:hi into signed-short and add '-' to POSTINC2 if required
	movlw	d'3'
	movwf	ignore_digits
	bsf		leftbind
	output_16dp d'2'								; temperature
	STRCAT_TEXT_PRINT tLogTunitC
	; max temperature
	movlw	.15
	subwf	logbook_max_temp_pos,W
	movwf	win_top									; Y position at max temperature
	MOVII	logbook_max_tp,mpr
	lfsr	FSR2,buffer
	call	TFT_convert_signed_16bit				; converts lo:hi into signed-short and adds '-' to POSTINC2 if required
	movlw	d'3'
	movwf	ignore_digits
	bsf		leftbind
	output_16dp d'2'								; temperature
	STRCAT_TEXT_PRINT tLogTunitC
	bra		logbook_show_gases


display_profile_no_profile:
	; print message "No Data anymore..."
	WIN_SMALL .4,.110								; set text size and position
	call	TFT_disabled_color						; use the color for disabled things
	STRCPY_TEXT_PRINT tNoProfileData				; print message


logbook_show_gases:
	bcf		leftbind
	call	TFT_standard_color

	btfss	aux_flag								; dive done in a deco mode?
	bra		logbook_show_gases_done					; NO - don't show gases

	; show gases
	lfsr	FSR0,header_buffer+index_gas1			; load base address of gases
	bsf		log_show_gas_short						; do the short version of log_show_gas
	bsf		leftbind

	WIN_TINY log_gas_column1, log_gas_row
	movlw	.1										; color for gas 1
	call	log_show_gas

	WIN_TINY log_gas_column2, log_gas_row
	movlw	.2										; color for gas 2
	call	log_show_gas

	WIN_TINY log_gas_column3, log_gas_row
	movlw	.3										; color for gas 3
	call	log_show_gas

	WIN_TINY log_gas_column4, log_gas_row
	movlw	.4										; color for gas 4
	call	log_show_gas

	WIN_TINY log_gas_column5, log_gas_row
	movlw	.5										; color for gas 5
	call	log_show_gas

	bcf		leftbind

logbook_show_gases_done:

	rcall	logbook_preloop_tasks					; clear timeout, some flags and set to Speed_eco
display_profile_loop:
	btfsc	switch_right							; right button pressed?
	bra		logbook_page1							; YES - show more information
	btfsc	switch_left								; NO  - left button pressed?
	bra		exit_profileview						;       YES - back to list
	call	housekeeping							;       NO  - handle screen dump request, timeout and entering dive mode
	bra		display_profile_loop					;           - loop waiting for something to do


;=============================================================================
; Draw a vertical line between xC+1 and xC+0, at current X position
;
; Note: should keep xC+0
; Note: ascending or descending !
;
profile_display_fill:
	; First, check if xC+0 > fill_between_rows or xC+0 < aponoe_mins
	movf	xC+0,W
	cpfseq	xC+1									; xC+0 = apnoe_mins ?
	bra		profile_display_fill2					; NO
	return

profile_display_fill2:
	; Make sure to init X position
	movf	logbook_pixel_x_pos,W
	mullw	2
	decf	PRODL,F
	movlw	0
	subwfb	PRODH,F
	call	pixel_write_col320

	movf	xC+0,W
	cpfsgt	xC+1									; fill_between_rows > xC+0 ?
	bra		profile_display_fill_up					; YES

profile_display_fill_down2:							; loop
	decf	xC+1,F

	HALF_PIXEL_WRITE xC+1							; updates just row (0..239)

	movf	xC+0,W
	cpfseq	xC+1									; loop until xC+1 = xC+0
	bra		profile_display_fill_down2
	return											; fill_between_rows and xC+0 are untouched

profile_display_fill_up:							; fill upwards from xC+0 to apone_mins!
	incf	xC+1,F

	HALF_PIXEL_WRITE xC+1							; updates just row (0..239)

	movf	xC+0,W
	cpfseq	xC+1									; loop until xC+1 = fill_between_rows
	bra		profile_display_fill_up
	return											; fill_between_rows and xC+0 are untouched

;=============================================================================


profile_view_get_depth:
	INCI	logbook_sample_counter					; count read pixels

	movf	logbook_sample_counter+0,W
	cpfseq	vertical_interval+0
	bra		profile_view_get_depth_no_line			; no need to draw a 10min line, continue
	movf	logbook_sample_counter+1,W
	cpfseq	vertical_interval+1
	bra		profile_view_get_depth_no_line			; no need to draw a 10min line, continue
	; draw a new 10min line here...
	CLRI	logbook_sample_counter					; clear counting registers for next line

	; Vertical lines...
	movlw	color_deepblue
	call	TFT_set_color
	movlw	profile_top+.1
	movwf	win_top
	incf	logbook_pixel_x_pos,W					; draw one line to right to make sure it's the background of the profile
	movwf	win_leftx2								; left border (0-159)
	movlw	profile_height_pixels
	movwf	win_height
	movlw	profile_height_pixels
	movwf	win_width								; "window" height
	call	half_horizontal_line					; inputs: win_top, win_leftx2, win_width, win_color1, win_color2

profile_view_get_depth_no_line:
	FLASH_II_READ_0x20 logbook_cur_depth				; read depth (2 bytes)
	FLASH_CC_READ_0x20 gaslist_gas						; read Profile Flag Byte

	bcf		event_occured							; clear flag by default
	btfsc	gaslist_gas,7							; event recorded?
	bsf		event_occured							; YES - we also have an event byte
	bcf		gaslist_gas,7							; clear event byte flag (if any)

	; gaslist_gas now holds the number of additional bytes to ignore (0-127)

	; check for end of profile
	movlw	0xFD									; load token for end of profile data
	cpfseq	logbook_cur_depth+0						; end of profile token in 1st depth byte?
	bra		profile_view_get_depth_new1				; NO  - profile continues
	cpfseq	logbook_cur_depth+1						; YES - end of profile token in 2nd depth byte?
	bra		profile_view_get_depth_new1				;       NO  - profile continues
	bsf		end_of_profile							;       YES - end of profile, set flag to skip remaining pixels
	return											;           - done

profile_view_get_depth_new1:
	btfsc	event_occured							; was there an event attached to this sample?
	rcall	profile_view_get_depth_events			; YES - get information about this event(s)

	; read temperature if available AND divisor reached AND bytes available
	movf	divisor_temperature,W					; is temperature divisor null ?
	bz		profile_view_get_depth_no_tp			; YES - no temperature curve
	decf	count_temperature,F						; NO  - decrement temperature counter, counter zero now?
	bnz		profile_view_get_depth_no_tp			;       NO  - no temperature this time
	FLASH_II_READ_0x20 logbook_cur_tp					;       YES - read temperature (2 bytes)
	decf	gaslist_gas,F							;           - reduce counter twice
	decf	gaslist_gas,F							;           - ...
	movff	divisor_temperature,count_temperature	;           - restart counter

	; compute max temperature on the fly...
	MOVII	logbook_cur_tp,sub_a					; copy current temperature to sub_a
	MOVII	logbook_max_tp,sub_b					; copy maximum temperature to sub_b
	call	sub16									; SIGNED sub_a - sub_b
	btfsc	neg_flag								; current temperature > maximum temperature ?
	bra		profile_view_get_depth_no_tp			; NO  - no new max temperature

	; store new max. temperature, but only if below dive_threshold_norm_alt_start
	tstfsz	logbook_cur_depth+1						; deeper than 2.55 m ?
	bra		profile_view_compute_max_temp			; YES - include in max. temp measurement
	movlw	dive_threshold_norm_alt_start+0			; get start-of-dive depth in mbar / cm, low byte
	cpfsgt	logbook_cur_depth+0						; deeper that start-of-dive threshold?
	bra		profile_view_get_depth_no_tp			; NO - ignore current temperature

profile_view_compute_max_temp:
	MOVII	logbook_cur_tp,logbook_max_tp			; store new max temperature

	;---- read deco, if any AND divisor=0 AND bytes available ----------------
profile_view_get_depth_no_tp:
	movf	divisor_deco,W
	bz		profile_view_get_depth_no_deco
	decf	count_deco,F
	bnz		profile_view_get_depth_no_deco

	FLASH_CC_READ_0x20 logbook_ceiling					; read the ceiling
	decf	gaslist_gas,F							; reduce the counter
	movff	divisor_deco,count_deco					; restart counter
	ext_flash_inc_address_0x40 d'1'					; skip the stop duration
	decf	gaslist_gas,F							; reduce the counter

	;---- read GF, if any AND divisor=0 AND bytes available ------------------

profile_view_get_depth_no_deco:
	; then skip remaining bytes...
	movf	gaslist_gas,W							; get number of additional bytes to ignore (0-127)
	tstfsz	WREG									; anything to skip?
	call	incf_ext_flash_address0_0x20			; YES - skip #WREG bytes
	return

profile_view_get_depth_events:
	clrf	event_byte2								; clear event byte 2
	FLASH_CC_READ_0x20 event_byte1						; read  event byte 1
	decf	gaslist_gas,F							; reduce counter

	btfss	event_byte1,7							; another event byte?
	bra		profile_no_second_eventbyte				; NO  - skip next
	FLASH_CC_READ_0x20 event_byte2						; YES - read event byte 2
	decf	gaslist_gas,F							;     - reduce counter
	bcf		event_byte1,7							;     - clear flag

profile_no_second_eventbyte:
	; Check event flags in the EventBytes
	btfsc	event_byte1,4							; manual gas changed?
	rcall	logbook_event1							; YES
	btfsc	event_byte1,5							; stored gas changed?
	rcall	logbook_event4							; YES
	btfsc	event_byte1,6							; setpoint change?
	rcall	logbook_event3							; YES
	btfsc	event_byte2,0							; bailout?
	rcall	logbook_event2							; YES
	; any alarm?
	bcf		event_byte1,4							; clear bits already tested
	bcf		event_byte1,5
	bcf		event_byte1,6
	movlw	.6										; coding for manual marker
	cpfseq	event_byte1								; manual marker set?
	return											; NO  - done
	bsf		log_marker_found						; YES - draw small yellow rectangle here
	return											;     - done

logbook_event4:										; stored gas changed
	FLASH_CC_READ_0x20 backup_color1					; read gas number, to be used as color index
	decf	gaslist_gas,F							; reduce counter
	call	TFT_color_code_gas						; change profile color according to gas number (still in WREG)
	return

logbook_event1:										; gas 6 used
	bsf		event_gas_change_gas6					; set event flag
	movlw	.6										; use gas 6 color
	movwf	backup_color1							; select color for gas 6
	call	TFT_color_code_gas						; set profile color
	ext_flash_inc_address_0x20 d'2'					; skip two bytes
	decf	gaslist_gas,F							; reduce counter
	decf	gaslist_gas,F							; reduce counter
	return

logbook_event2:										; bailout
	bsf		bailout_mode							; set flag
	movff	backup_color1,backup_color2				; backup last gas color in case we return to CCR
	movlw	.6										; use Gas6 color
	movwf	backup_color1
	call	TFT_color_code_gas						; use gas 6 color
	ext_flash_inc_address_0x20 d'2'					; skip two bytes
	decf	gaslist_gas,F							; reduce counter
	decf	gaslist_gas,F							; reduce counter
	return

logbook_event3:										; setpoint change
	ext_flash_inc_address_0x20 d'1'					; skip one byte
	decf	gaslist_gas,F							; reduce counter
	btfss	bailout_mode							; in bailout?
	return											; NO  - done
	movff	backup_color2,backup_color1				; YES - restore color
	movf	backup_color2,W							;     - copy gas number to WREG for color-coding
	call	TFT_color_code_gas						;     - back to normal profile color
	return											;     - done

; ------------------------------------------------------------------------

exit_profileview:
	clrf	gaslist_gas								; restore all registers to build same page again
	movff	logbook_divenumber_temp,logbook_divenumber
	movff	logbook_max_dive_counter_temp,logbook_max_dive_counter
	movff	logbook_temp_backup,logbook_temp
	incf	logbook_max_dive_counter,F
	decf	logbook_divenumber,F
	bcf		all_dives_shown
	clrf	menu_pos_max							; number of rows used on current logbook-page
	movlw	logbook_row_number
	movwf	menu_pos_cur							; here: active row on current page
	call	TFT_boot
	goto	logbook2								; start search

next_logbook2:
	btfsc	all_dives_shown							; all shown?
	goto	logbook									; YES
	clrf	menu_pos_max							; number of used rows on current logbook-page
	movlw	logbook_row_number
	movwf	menu_pos_cur
	incf	logbook_page_number,F					; start new screen
	bsf		keep_cursor_new_page					; keep cursor on "next page"
	call	TFT_boot
	goto	logbook2								; start search

next_logbook3:
	incf	menu_pos_cur,F							; set cursor to next line
	movlw	logbook_row_number+.2					; get maximum number of lines
	cpfsgt	menu_pos_cur							; cursor position beyond last line?
	bra		next_logbook3a							; NO - ok, done
	movlw	.1										; YES - reset to first line
	movwf	menu_pos_cur							;     - ...
	bra		next_logbook3b							;     - done

next_logbook3a:
	incf	menu_pos_max,W							; last entry on current page +1
	cpfseq	menu_pos_cur							; same as cursor position?
	bra		next_logbook3b							; NO
	movlw	logbook_row_number+.1					; YES - ...
	movwf	menu_pos_cur							;     - ... jump directly to "next page" if page is not full

	movlw	logbook_row_number
	cpfseq	menu_pos_max							; last dive was row logbook_row_number?
	bsf		all_dives_shown							; NO - set flag to load first page again (full reset)

next_logbook3b:
	call	TFT_logbook_cursor
	goto	logbook_loop_pre

; ------------------------------------------------------------------
; list one dive
;
display_listdive:
	bsf		logbook_page_not_empty					; flag page will not be empty
	incf	menu_pos_max,F							; increment number of lines shown

	lfsr	FSR2,buffer								; initialize output buffer
	WIN_FONT FT_SMALL								; select font
	WIN_LEFT logbook_list_left						; set horizontal output position
	decf	menu_pos_max,W							; get current line -1 into WREG
	mullw	logbook_row_offset						; multiply with row spacing
	movff	PRODL,win_top							; set vertical output position

	; print dive number
	movf	logbook_divenumber,W					; get running number of the dive
	call	log_compute_divenumber					; compute dive number to show (incorporate dive number offset)
	bsf		leftbind								; start left-aligned
	movlw	.3										; start with 3rd digit (i.e. suppress the thousands)
	movwf	ignore_digits							; ...
	output_16dp .0									; print dive number
	bcf		leftbind								; end left-alignment

	PUTC	' '										; print a space char

	; print dive date
	MOVTT	header_buffer+index_date,mpr			; get date
	call	TFT_convert_date_short					; convert and print date

	PUTC	' '										; print a space char

	; print dive depth
	MOVII	header_buffer+index_max_depth,mpr		; get max depth

	TSTOSS	opt_units								; switch by configured units
	bra		display_listdive2_metric				; 0 - do metric
	;bra	display_listdive2_imperial				; 1 - do imperial

display_listdive2_imperial:
	call	convert_cm_to_feet						; convert value in mpr from [cm] to [feet]
	PUTC	' '										; print one space char
	output_16_3										; print depth, limited to 999
	STRCAT_TEXT tFeets1								; print unit label
	bra		display_listdive3						; continue with common part

display_listdive2_metric:
	bsf		ignore_digit5							; do not print the cm
	movlw	d'1'									; do not print the first digit (no 1000 m)
	movwf	ignore_digits							; ...
	output_16dp .3									; print depth in format xxx.y
	STRCAT_TEXT tMeters								; print unit label
	PUTC	' '										; print one space char
	;bra	display_listdive3						; continue with common part

	; print dive time
display_listdive3:
	MOVII	header_buffer+index_divetime,mpr		; get dive time (minutes only)
	output_16_3										; print minutes (0-999 min)
	STRCAT_TEXT tMinutes							; print minutes mark ("'")
	clrf	WREG									; create string terminator
	movff	WREG,buffer+.21							; hard limit the output to 21 chars
	STRCAT_PRINT ""									; finalize output

	return											; done

; ------------------------------------------------------------------

logbook_show_divenumber:
	WIN_MEDIUM	logbook_divenumer_column, logbook_divenumer_row
	movf	divenumber,W							; log_compute_divenumber needs the list number
	call	log_compute_divenumber					; compute dive number
	bsf		leftbind
	output_16										; show dive number
	bcf		leftbind
	STRCAT_PRINT ""									; finalize output
	return											; done


;-----------------------------------------------------------------------------
;  1st Details Page after Profile: Dive Statistics

logbook_page1:										; show more info
	rcall	log_details_header						; shows number, time/date and basic dive info

	btfss	aux_flag								; dive done in a deco mode?
	bra		logbook_page1_1							; NO

	; deco model
	WIN_SMALL .5,.65
	MOVCC	header_buffer+index_decomodel,WREG		; get deco model (0= ZH-L16, 1=ZH-L16+GF)
	decfsz	WREG,W									; GF model?
	bra		logbook_decomodel_1						; NO  - ZH-L16
	;bra	logbook_decomodel_2						; YES - ZH-L16+GF

logbook_decomodel_2:
	; deco model GF version
	STRCAT_PRINT "ZHL-16+GF"
	WIN_SMALL .5,.90
	STRCPY_TEXT tGF2
	MOVII	header_buffer+index_gf_lo_hi,mpr		; get  GF factors
	output_8										; print GF lo
	STRCAT	"%/"
	movff	hi,lo									; print GF hi
	output_8										; ...
	STRCAT_PRINT "%"
	bra		logbook_cns

logbook_decomodel_1:
	; deco model none-GF version
	STRCAT_PRINT "ZH-L16"
	WIN_SMALL .5,.90
	MOVII	header_buffer+index_factor_sat_desat,mpr; get both factors
	output_8										; print saturation factor
	STRCAT	"%/"
	movff	hi,lo									; print desaturation factor
	output_8										; ...
	STRCAT_PRINT "%"
	;bra	logbook_cns

logbook_cns:
	WIN_SMALL .5,.115
	STRCPY_TEXT tCNS2
	MOVII	header_buffer+index_cns_start,mpr		; get CNS at start of dive
	bcf		mpr+1,int_warning_flag					; clear warning   flag (fix for cases were the flags already got stored to EEPROM)
	bcf		mpr+1,int_attention_flag				; clear attention flag (fix for cases were the flags already got stored to EEPROM)
	output_16
	STRCAT	"->"
	MOVII	header_buffer+index_cns_end,mpr			; get CNS at end of dive
	bcf		hi,int_warning_flag						; clear warning   flag (fix for cases were the flags already got stored to EEPROM)
	bcf		hi,int_attention_flag					; clear attention flag (fix for cases were the flags already got stored to EEPROM)
	output_16
	STRCAT_PRINT "%"

logbook_page1_1:
	WIN_SMALL .5,.140
	STRCPY_TEXT tAVG
	MOVII	header_buffer+index_avr_depth,mpr		; get average depth

	TSTOSS	opt_units								; 0=Meters, 1=Feets
	bra		logbook_page1_1_metric					; do metric
	;bra	logbook_page1_1_imperial				; do imperial

logbook_page1_1_imperial:
	call	convert_cm_to_feet						; convert value in lo:hi from [cm] to [feet]
	PUTC	' '
	output_16_3										; limit to 999 and display only (0-999)
	STRCAT_PRINT "ft"
	bra		logbook_page1_1_common

logbook_page1_1_metric:
	bsf		ignore_digit5							; no cm (flag will be cleared by output_16)
	movlw	.1										; no 1000 meters
	movwf	ignore_digits							; ...
	output_16dp .3									; xxx.y
	STRCAT_PRINT "m"
	;bra	logbook_page1_1_common

logbook_page1_1_common:
	btfss	aux_flag								; dive done in a deco mode?
	bra		logbook_page1_2							; NO

	; Salinity
	WIN_SMALL .5,.165								; ex WIN_SMALL .5,.140
	STRCPY_TEXT tDvSalinity2
	bsf		leftbind
	MOVCC	header_buffer+index_salinity,lo			; read salinity
	output_8
	STRCAT_PRINT "%"

	; Last deco
	WIN_SMALL .5,.190
	STRCPY_TEXT tLastDeco
	MOVCC	header_buffer+index_last_stop,lo		; read last stop depth
	output_8
	STRCAT_PRINT "m"

logbook_page1_2:
	movlw	color_lightblue
	call	TFT_set_color
	WIN_FRAME_COLOR16 .63,.220,.2,.105				; top, bottom, left, right

	; Firmware
	call	TFT_standard_color
	WIN_SMALL .110,.65
	STRCAT	"V:"
	MOVII	header_buffer+index_firmware,mpr		; get firmware version
	movff	lo,up									; keep a backup of major in up
	bsf		leftbind								; print left-aligned
	output_8										; print major version (in 1 digit due to leftbind)
	PUTC	"."										; print "."
	movff	hi,lo									; print minor version...
	output_99x										; ... in 2 digit format
	STRCAT_PRINT ""									; finalize output

	movf	up,W									; get major into WREG
	xorlw	.3										; major == 3 ?
	bz		logbook_battery_percent					; YES - show battery %
	movf	up,W									; NO  - get major into WREG (again)
	xorlw	.2										;       major == 2 ?
	bnz		logbook_battery_voltage					;       NO  - skip battery %
	movlw	.14										;       YES - check minor version
	cpfsgt	lo										;           - minor > 14 ?
	bra		logbook_battery_voltage					;             NO  - skip battery %
	;bra	logbook_battery_percent					;             YES - show battery %

	; Battery %
logbook_battery_percent:
	WIN_SMALL .110,.140
	MOVCC	header_buffer+index_batt_percent,lo		; get   battery percent
	output_8										; print battery percent
	STRCAT_PRINT "%"								; print "%" and finalize output

	; Battery Voltage
logbook_battery_voltage:
	WIN_SMALL .110,.90
	STRCAT_PRINT "Batt:"
	WIN_SMALL .110,.115
	MOVII	header_buffer+index_battery_voltage,mpr	; get   battery voltage
	output_16dp .2									; print battery voltage
	STRCAT_PRINT "V"								; print unit (Volt)

	; Surface Pressure
	MOVII	header_buffer+index_surface_press,mpr	; get surface pressure
	WIN_SMALL .110,.165								; set output position
	bsf		leftbind								; print without leading spaces
	output_16										; print surface pressure before dive
	STRCAT_TEXT tMBAR								; print unit
	clrf	WREG									; string terminator
	movff	WREG,buffer+7							; limit to 7 chars
	STRCAT_PRINT ""									; dump buffer to screen

	movlw	color_greenish							; select color
	call	TFT_set_color							; ...
	WIN_FRAME_COLOR16 .63,.220,.107,.159			; draw a frame with coordinates top, bottom, left, right

	; handle HMI
	rcall	logbook_preloop_tasks					; clear timeout and remaining button events
display_details1_loop:
	btfsc	switch_right							; right button pressed?
	bra		display_details1_more					; YES - more info or back to profile
	btfsc	switch_left								; left button pressed?
	bra		exit_profileview						; YES - back to list
	call	housekeeping							; NO  - handle screen dump request, timeout and entering dive mode
	bra		display_details1_loop					;     - loop waiting for something to do

display_details1_more:
	btfss	aux_flag								; YES - dive done in a deco mode?
	goto	display_profile2						;       NO  - show the profile view again
	;bra	logbook_page2							;       YES - show more details


;-----------------------------------------------------------------------------
;  2nd Details Page after Profile: Tissue and Decompression Status

logbook_page2:

; ################# to be removed later ##################################
;	movlw	fw_version_beta				; get beta status
;	tstfsz	WREG						; beta?
;	bra		display_page2_betajump		; YES - omit firmware version check
; ########################################################################

	; skip this page for dives recorded with firmwares < 3.09
	MOVII	header_buffer+index_firmware,mpr		; get firmware version major and minor

	movlw	.2										; minimum required major is 3, -1 for cpfsgt
	cpfsgt	lo										; major >= requirement?
	bra		logbook_page3							; NO  - skip this page
	movlw	.8										; YES - minimum required minor is 9, -1 for cpfsgt
	cpfsgt	hi										;     - minor >= requirement?
	bra		logbook_page3							;       NO  - skip this page

; ################# to be removed later ##################################
display_page2_betajump:
; ########################################################################

	rcall	log_details_header						; shows number, time/date and basic dive info

	; basic configuration of tissue graphics
	bsf		tissue_graphic_mode						; select logbook mode
	bcf		tissue_graphic_layout					; select press+sat
	bcf		tissue_graphic_cns						; do not show CNS value
	bcf		tissue_graphic_gf						; do not show GF lines by default

	; GF configuration
	MOVCC	header_buffer+index_decomodel,WREG		; get deco model (0= ZH-L16, 1=ZH-L16+GF)
	dcfsnz	WREG									; GF model?
	bsf		tissue_graphic_gf						; YES - show GF lines

	; draw the graphics
	call	TFT_surface_tissues

	; calculate time/date of the end of the dive
	MOVTT	header_buffer+index_date,      rtc_latched_year		; get start    of the dive - year, month, day
	MOVII	header_buffer+index_time,      rtc_latched_hour		; get start    of the dive - hour, minute
	MOVCC	header_buffer+index_divetime+2,rtc_latched_secs		; get duration of the dive - seconds
	MOVII	header_buffer+index_divetime+0,mpr					; get duration of the dive - minutes
	call	rtc_add_minutes										; add minutes in mpr to time/date in rtc_latched

	; print time/date of the end of the dive
	WIN_SMALL .8,.193									; select font and output position
	MOVTT	rtc_latched_year,mpr						; get computed end-of-dive date
	call	TFT_convert_date_short						; convert and print date
	STRCAT	".-"										; print spacing ".-"
	MOVII	rtc_latched_hour,mpr						; get computed end-of-dive time
	output_99x											; print hour
	PUTC	':'											; print spacing ":"
	movff	hi,lo										; print minute
	output_99x											; ...
	STRCAT_PRINT ""										; finalize output


	; draw a white frame around the time/date
	WIN_FRAME_STD surf_tissue_diagram_bottom,.220, surf_tissue_diagram_left, surf_tissue_diagram_right

	bra		logbook_page2_rightside					; continue with right side

logbook_page2_nograph:
	WIN_SMALL .6,.118								; no tissue graphics because the
	STRCAT_PRINT "(< FW 3.08)"						; profile was recorded on a FW < 3.08

logbook_page2_rightside:

	; 1st line: supersaturation at end of dive
	WIN_SMALL .100,.68
	STRCAT_TEXT_PRINT tBeginOfDive					; print "Begin"

	; 2nd line: 
	WIN_SMALL .100+.28,.93							; +16 for centered, +28 for right-aligned
	MOVCC	header_buffer+index_supersat_start,lo	; get supersaturation at start of dive
	bcf		leftbind
	output_8										; print percent value
	STRCAT_PRINT "%"								; print "%" and finalize output

	; 3rd line: 
	WIN_SMALL .100,.118
	STRCAT_TEXT_PRINT tEndOfDive					; print "End"

	; 4th line: 
	WIN_SMALL .100+.28,.143							; +16 for centered, +28 for right-aligned
	MOVCC	header_buffer+index_supersat_end,lo		; get supersaturation at end of dive
	bcf		leftbind
	output_8										; print percent value
	STRCAT_PRINT "%"								; print "%" and finalize output

	; 5th line: desaturation time label
	WIN_SMALL .100,.168
	STRCAT_TEXT_PRINT tDesatTime					; print "Desat"

	; 6th line: desaturation time value
	WIN_SMALL .100+.14,.193							; +?? for centered, +14 for right-aligned
	MOVII	header_buffer+index_desattime,mpr		; get desaturation time
	call	convert_time							; convert hi:lo in minutes to hours (up:hi) and minutes (lo)
	movf	lo,W									; swap hi and lo
	movff	hi,lo									; ...
	movwf	hi										; ...
	output_99										; print hours in 0-99
	PUTC	'h'										; print hours mark
	movff	hi,lo									; print minutes...
	output_99x										; ... in two digits, leading zero
	STRCAT_PRINT "m"								; print minutes mark and finalize output

	; draw a colored frame around the right side
	movlw	color_orange							; select color
	call	TFT_set_color							; ...
	WIN_FRAME_COLOR16 .65,.220,.97,.159				; draw a frame with coordinates top, bottom, left, right

	; handle HMI
	rcall	logbook_preloop_tasks					; clear timeout and remaining button events
display_details1b_loop:
	btfsc	switch_right							; right button pressed?
	bra		logbook_page3							; YES - show more info
	btfsc	switch_left								; left button pressed?
	bra		exit_profileview						; YES - back to list
	call	housekeeping							; NO  - handle screen dump request, timeout and entering dive mode
	bra		display_details1b_loop					;     - loop waiting for something to do


;-----------------------------------------------------------------------------
; helper function
logbook_preloop_tasks:
	movlw	CCP1CON_VALUE							; see hwos.inc
	movwf	CCP1CON									; power-on backlight
	call	TFT_standard_color						; revert to standard color
	call	reset_timeout_surfmode					; reset timeout
	bcf		switch_left								; clear left-over left  button event
	bcf		switch_right							; clear left-over right button event
	return											; done

;-----------------------------------------------------------------------------
; 3rd Details Page after Profile: Gases / Diluents

logbook_page3:
	rcall	log_details_header						; shows number, time/date and basic dive info
	lfsr	FSR0,header_buffer+index_gas1			; load base address of the gases
	bcf		log_show_gas_short						; do the long version of log_show_gas
	bcf		leftbind

	WIN_SMALL .5,.90
	movlw	.1										; color for gas 1
	rcall	log_show_gas

	WIN_SMALL .5,.115
	movlw	.2										; color for gas 2
	rcall	log_show_gas

	WIN_SMALL .5,.140
	movlw	.3										; color for gas 3
	rcall	log_show_gas

	WIN_SMALL .5,.165
	movlw	.4										; color for gas 4
	rcall	log_show_gas

	WIN_SMALL .5,.190
	movlw	.5										; color for gas 5
	rcall	log_show_gas

	; OC/CC gas list
	WIN_SMALL .5,.65
	WIN_COLOR color_greenish

	MOVCC	header_buffer+index_divemode,WREG		; read dive mode (0=OC, 1=CC, 2=Gauge, 3=Apnea, 4= pSCR)
	decfsz	WREG,W									; dive mode = CC ?
	bra		logbook_page3a							; NO  - print OC title
	STRCPY_TEXT_PRINT tGaslistCC					; YES - print CC title
	bra		logbook_page3b							;     - continue with common part
logbook_page3a:
	STRCPY_TEXT_PRINT tGaslist						; print OC title
logbook_page3b:
	movlw	color_lightblue							; select color
	call	TFT_set_color							; set    color
	WIN_FRAME_COLOR16 .63,.220,.2,.114				; draw a frame with coordinates top, bottom, left, right

	; handle HMI
	rcall	logbook_preloop_tasks					; clear timeout, some flags and set to speed_eco
display_details2_loop:
	btfsc	switch_right							; right button pressed?
	goto	logbook_page4							; YES - show more info
	btfsc	switch_left								; NO  - left button pressed?
	bra		exit_profileview						;       YES - back to list
	call	housekeeping							;       NO  - handle screen dump request, timeout and entering dive mode
	bra		display_details2_loop					;           - loop waiting for something to do


;-----------------------------------------------------------------------------
; 4th Details Page after Profile: Setpoints

logbook_page4:
	MOVCC	header_buffer+index_divemode,WREG		; get dive mode (0=OC, 1=CC, 2=Gauge, 3=Apnea, 4= pSCR)
	decfsz	WREG,W									; =1 (CC)?
	goto	display_profile2						; NO - skip setpoints

	rcall	log_details_header						; shows number, time/date and basic dive info

	; print setpoint list
	lfsr	FSR0,header_buffer+index_sp1			; load base address of the setpoints
	WIN_SMALL .5,.65
	WIN_COLOR color_greenish
	STRCPY_TEXT_PRINT tFixedSetpoints
	call	TFT_standard_color
	WIN_SMALL .5,.90
	rcall	  log_show_sp
	WIN_SMALL .5,.115
	rcall	  log_show_sp
	WIN_SMALL .5,.140
	rcall	  log_show_sp
	WIN_SMALL .5,.165
	rcall	  log_show_sp
	WIN_SMALL .5,.190
	rcall	  log_show_sp

	movlw	color_greenish
	call	TFT_set_color
	WIN_FRAME_COLOR16 .63,.220,.2,.112				; top, bottom, left, right

	; handle HMI
	rcall	logbook_preloop_tasks					; clear timeout, some flags and set to Speed_eco
display_details3_loop:
	btfsc	switch_right							; right button pressed?
	goto	display_profile2						; YES - show the profile view again
	btfsc	switch_left								; left button pressed?
	bra		exit_profileview						; YES - back to list
	call	housekeeping							; NO to both - handle screen dump request, timeout and entering dive mode
	bra		display_details3_loop					;            - loop waiting for something to do


;-----------------------------------------------------------------------------
; Helper Functions

log_details_header:
	call	TFT_boot
	call	TFT_standard_color

	rcall	logbook_show_divenumber					; show the dive number in medium font

	; show date and time in first row
	WIN_SMALL .59,.10
	MOVTT	header_buffer+index_date,mpr			; get date
	call	TFT_convert_date						; convert into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in buffer

	PUTC	"-"

	MOVII	header_buffer+index_time,mpr			; get time
	output_99x										; print hour
	PUTC	':'										; print spacing ":"
	movff	hi,lo									; print minute
	output_99x										; ...
	STRCAT_PRINT ""									; display 1st row of details

	; show max depth and dive time
	WIN_SMALL .5,.35
	STRCAT	"Max:"
	MOVII	header_buffer+index_max_depth,mpr		; get max depth

	TSTOSS	opt_units								; 0=Meters, 1=Feet
	bra		logbook_page2_depth_metric				; 1 - do metric
	;bra	logbook_page2_depth_imperial			; 0 - do imperial

logbook_page2_depth_imperial:
	call	convert_cm_to_feet						; convert value in lo:hi from [cm] to [feet]
	PUTC	' '
	bcf		leftbind
	output_16_3
	STRCAT_TEXT tFeets
	bra		logbook_page2_depth_common

logbook_page2_depth_metric:
	bsf		ignore_digit5							; no cm...
	movlw	d'1'									; no 1000 m
	movwf	ignore_digits							; ...
	output_16dp d'3'								; xxy.y
	STRCAT_TEXT tMeters
	;bra	logbook_page2_depth_common

logbook_page2_depth_common:
	STRCAT	" - "
	MOVTT	header_buffer+index_divetime,mpr		; get dive time
	bsf		leftbind
	output_16										; print minutes
	PUTC	"m"
	movff	up,lo									; print seconds
	output_99x										; ...
	STRCAT_PRINT "s"
	return


log_show_sp:
	; log point is set by caller
	MOVCC	POSTINC0,lo								; copy set point    into lo
	MOVCC	POSTINC0,hi								; copy change depth into hi

	movff	mpr+1,mpr+2								; save change depth
	clrf	mpr+1									; set high byte to zero for printing setpoint
	bsf		leftbind
	output_16dp d'3'								; print setpoint x.xx
	bcf		leftbind
	STRCAT_TEXT tbar
	PUTC	" "
	movff	mpr+2,mpr+0								; restore change depth to lo

	TSTOSS	opt_units								; 0=Meter, 1=Feet
	bra		log_show_sp_metric						; 0 - do metric
	;bra	log_show_sp_imperial					; 1 - do imperial

log_show_sp_imperial:
	call	convert_meter_to_feet					; convert value in lo from [m] to [feet]
	output_16_3
	PUTC	" "
	STRCAT_TEXT tFeets								; "ft"
	bra		log_show_sp_common

log_show_sp_metric:
	output_8
	PUTC	" "
	STRCAT_TEXT tMeters								; "m"
	;bra	log_show_sp_common

log_show_sp_common:
	STRCAT_PRINT ""
	return


log_show_gas:										; show gas data
	call	TFT_color_code_gas						; color the output (gas number is in WREG)
	MOVCC	POSTINC0,lo								; copy O2 fraction into lo
	MOVCC	POSTINC0,hi								; copy He fraction into hi
	call	gaslist_show_mix						; put "Nxlo", "Txlo/hi", "Air" or "O2" into buffer

	MOVCC	POSTINC0,lo								; copy change depth into lo
	MOVCC	POSTINC0,hi								; copy gas    type  into hi
	btfsc	log_show_gas_short						; shall we do the short version?
	bra		log_show_gas_common						; YES - do short version
	;bra	log_show_gas_long						; NO  - add gas types

log_show_gas_long:
	PUTC	" "										; put one space between gas composition and gas type marking
	tstfsz	hi										; gas disabled?
	bra		log_show_gas_1							; NO  - next check
	PUTC	"x"										; YES - mark with "x"
	bra		log_show_gas_4							;     - continue with change depth
log_show_gas_1:
	decfsz	hi,F									; now: -1 disabled, 0 first, 1 travel, 2 deco -> first?
	bra		log_show_gas_2							; NO  - next check
	PUTC	"*"										; YES - mark with "*"
	bra		log_show_gas_4							;     - continue with change depth
log_show_gas_2:
	decf	hi,F									; now: -2 disabled, -1 first,  0 travel, 1 deco
	decfsz	hi,F									; now: -3 disabled, -2 first, -1 travel, 0 deco -> deco?
	bra		log_show_gas_3							; NO  - nothing to mark
	PUTC	"="										; YES - mark with "="
	bra		log_show_gas_4							;     - continue with change depth
log_show_gas_3:
	PUTC	" "										; print a space in absence of any other marking
log_show_gas_4:
	PUTC	" "										; put one space between gas type marking and change depth

	TSTOSS	opt_units								; 0=Meter, 1=Feet
	bra		log_show_gas_metric						; 0 - do metric
	;bra	log_show_gas_imperial					; 1 - do imperial

log_show_gas_imperial:
	call	convert_meter_to_feet					; convert value in lo from [m] to [feet]
	output_16_3										; limit to 999 and display only 0-999
	STRCAT_TEXT tFeets								; "ft"
	bra		log_show_gas_common

log_show_gas_metric:
	output_8
	STRCAT_TEXT tMeters								; "m"
	;bra	log_show_gas_common

log_show_gas_common:
	STRCAT_PRINT ""
	return


log_compute_divenumber:
	movwf	mpr+2									; store current dive number in mpr+2
	call	eeprom_log_offset_read					; read log offset into mpr+0 & +1
	; check if offset = 0
	tstfsz	mpr+0									; low  byte = 0 ?
	bra		log_compute_divenumber_2				; NO  - apply offset
	tstfsz	mpr+1									; YES - high byte = 0 ?
	bra		log_compute_divenumber_2				;       NO  - apply offset
	;bra	log_compute_divenumber_1				;       YES - no offset

log_compute_divenumber_1:
	movff	mpr+2,mpr+0								; use plain number from dive list
	clrf	mpr+1									; set high byte to 0
	return											; done

log_compute_divenumber_2:
	; check limit (offset must be < 10000)
	MOVLI	.9999,sub_a								; sub_a = 9999
	MOVII	mpr,  sub_b								; sub_b = offset
	call	cmpU16									; 9999 - offset
	btfsc	neg_flag								; result negative, i.e. offset > 9999 ?
	bc		log_compute_divenumber_1				; YES - ignore offset
	INCI	mpr										; NO  - increment offset by 1
	MOVII	mpr,sub_a								;     - sub_a = offset + 1
	movff	mpr+2,sub_b+0							;     - sub_b = number from list (low byte)
	clrf	sub_b+1									;     -         high byte is 0
	call	subU16									;     - sub_c = offset + 1 - (number from list)
	MOVII	sub_c,mpr								;     - copy result back to mpr
	return											;     - done

;----------------------------------------------------------------------------
; Compute flash address for header data of a particular dive
;
; Memory map in flash:
;
; low(total number of dives) -> index -> start address    end address
; --------------------------------------------------------------------
;          1                      0       0x2|00|000   -   0x2|00|FFF
;          2                      1       0x2|01|000   -   0x2|01|FFF
;          3                      2       0x2|02|000   -   0x2|02|FFF
;        ...
;  256 ->  0                    255       0x2|FF|000   -   0x2|FF|FFF

log_header_addr_by_divenumber:
	; compute index of the dive with number 'divenumber'
	decf	divenumber,W							; compute number of dive to show -1...
	movwf	mpr+3									; ... and store in mpr+3
	movf	total_num_dives,W						; get number of total dives (low byte)
	bcf		STATUS,C								; clear carry/borrow bit
	subfwb	mpr+3,W									; index = number of total dives - number of dive to show + 1
	;bra	log_header_addr_by_index				; get address by index

	global	log_header_addr_by_index
log_header_addr_by_index:
	; compute the start address of the header belonging to the dive whose index is in WREG
	movwf	mpr+3									; copy index to mpr+3
	clrf	mpr+0									; set up base address 0x200000
	clrf	mpr+1									; ...
	movlw	0x20									; ...
	movwf	mpr+2									; ...
	movlw	.16										; prepare a shift left by 4 bit
	mulwf	mpr+3									; shift left index to create offset
	movf	PRODL,W									; get    low   byte of offset
	addwf	mpr+1,F									; add to high  byte of address
	movf	PRODH,W									; get    high  byte of offset
	addwfc	mpr+2,F									; add to upper byte of address

	return

; ----------------------------------------------------------------

	END