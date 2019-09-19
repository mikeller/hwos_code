;=============================================================================
;
;   File logbook.asm                          combined next generation V3.03.5
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

	extern	do_main_menu2
	extern	gaslist_show_mix


	;---- Private local variables -------------------------------------------------

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
		y_scale:2						; y-scale (The horizontal lines)
		x_scale:2						; x-scale (The vertical lines)
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
		backup_divedata					; used to backup depth and salinity
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
	ENDC								; used: 16 byte, remaining: 0 byte => FULL


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
#DEFINE logbook_row_number			.7				; amount of rows in the list

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
#DEFINE log_divetime_value_row		.38
#DEFINE log_divetime_value_column	.60

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


; Header coordinates
#DEFINE log_profile_version			.8
#DEFINE log_date					.12
#DEFINE log_time					.15
#DEFINE log_max_depth				.17
#DEFINE log_divetime				.19
#DEFINE log_min_temp				.22
#DEFINE log_surface_press			.24
#DEFINE log_desattime				.26
#DEFINE log_gas1					.28
#DEFINE log_gas2					.32
#DEFINE log_gas3					.36
#DEFINE log_gas4					.40
#DEFINE log_gas5					.44
#DEFINE log_firmware				.48
#DEFINE log_battery					.50
#DEFINE log_samplingrate			.52
#DEFINE log_cns_start				.53
#DEFINE log_gf_start				.55
#DEFINE log_gf_end					.56
#DEFINE log_batt_info				.59
#DEFINE log_sp1						.60
#DEFINE log_sp2						.62
#DEFINE log_sp3						.64
#DEFINE log_sp4						.66
#DEFINE log_sp5						.68
#DEFINE log_salinity				.70
#DEFINE log_cns_end					.71
#DEFINE log_avr_depth				.73
#DEFINE log_total_seconds			.75
#DEFINE log_gf_lo					.77
#DEFINE log_sat_mult				.77
#DEFINE log_gf_hi					.78
#DEFINE log_desat_mult				.78
#DEFINE log_decomodel				.79
#DEFINE log_total_dives				.80
#DEFINE log_divemode				.82
#DEFINE log_last_stop				.243


LOG_POINT_TO	macro	address
	movlw	address
	movwf	ext_flash_address+0
	endm

logbook		CODE

;=============================================================================

TFT_logbook_cursor:
	WIN_BOX_BLACK .0, .239, logbook_list_left-.8, logbook_list_left-.1    ; top, bottom, left, right

	WIN_LEFT logbook_list_left-.8					; set horizontal position
	WIN_FONT FT_SMALL								; select small font
;	bcf		win_invert								; reset invert flag
	call	TFT_standard_color						; print in white color
	decf	menu_pos_cur,W							; get row number -1 into WREG
	mullw	logbook_row_offset						; multiply with vertical offset between rows
	movff	PRODL,win_top							; set vertical position
	STRCPY_PRINT "\xB7"								; print cursor
	return											; done


	global	logbook									; entry point coming from menu_tree.asm
logbook:
	clrf	logbook_flags
	call	TFT_boot
;	call	TFT_standard_color
	clrf	menu_pos_max							; number of used rows on current logbook-page
	clrf	logbook_page_number						; here: # of current displayed page
	clrf	logbook_divenumber						; # of dive in list during search
	clrf	logbook_temp
	clrf	logbook_temp_backup
	movlw	logbook_row_number
	movwf	menu_pos_cur							; number of current position on display (logbook_row_number-x)
	read_int_eeprom .2								; get low-byte of total dives
	movff	EEDATA,logbook_max_dive_counter

;-----------------------------------------------------------------------------	
; display dive headers backwards from read_int_eeprom .2 = lo-1
; 1st: 200000h-200FFFh -> lo=0
; 2nd: 201000h-201FFFh -> lo=1
; 3rd: 202000h-202FFFh -> lo=2
; 256: 2FF000h-2FFFFFh -> lo=255 (And hi>0...)
; Stop when
; a) no dive is stored (no valid header found)
; b) current dive has no valid header (Number of stored dives < 256)
; c) when 255 dives are reached logbook_temp = 255

logbook2:
	incf	logbook_temp,F							; increase dive counter
	incf	logbook_temp,W							; = 0x..FF ?
	bz		logbook_reset							; YES - ..FF --> loop

	; Set ext_flash_address:3 to TOC entry of this dive
	; 1st: 200000h-200FFFh -> logbook_max_dive_counter=0
	; 2nd: 201000h-201FFFh -> logbook_max_dive_counter=1
	; 3rd: 202000h-202FFFh -> logbook_max_dive_counter=2
	; 256: 2FF000h-2FFFFFh -> logbook_max_dive_counter=255 (and hi>0...)

	decf	logbook_max_dive_counter,F				; -1

	clrf	ext_flash_address+0
	clrf	ext_flash_address+1
	movlw	0x20
	movwf	ext_flash_address+2
	movlw	.16
	mulwf	logbook_max_dive_counter				; logbook_max_dive_counter*16 = offset to 0x2000 (up:hi)
	movf	PRODL,W
	addwf	ext_flash_address+1,F
	movf	PRODH,W
	addwfc	ext_flash_address+2,F
	; pointer at the first 0xFA of header

	call	ext_flash_byte_read						; reads one byte@ext_flash_address:3 into WREG and ext_flash_rw
	movwf	ext_flash_rw
	movlw	0xFA
	cpfseq	ext_flash_rw							; 0xFA found?
	bra		logbook3b								; NO - abort
	incf	logbook_divenumber,F					; YES - new header found, increase logbook_divenumber
	bra		logbook4								;     - done with searching, display the header

logbook3b:
	btfss	logbook_page_not_empty					; was there at least one dive?
	bra		exit_logbook							; not a single header was found, leave logbook
	bra		logbook_display_loop2

logbook_reset:
	tstfsz	logbook_divenumber						; was there at least one dive?
	bra		logbook_reset2
	bra		logbook3b								; NO - nothing to do

logbook_reset2:
	bsf		all_dives_shown							; YES
	bra		logbook_display_loop2					; continue

logbook4:
	btfsc	all_dives_shown							; all dives displayed?
	bra		logbook_display_loop2					; YES - display first page again
	call	display_listdive						; NO  - display short header for list on current list position
	movlw	logbook_row_number						;     - 
	cpfseq	menu_pos_cur							;     - first dive on list (top row)?
	bra		logbook_display_loop1					;       NO - skip saving of address

	; store all registers required to rebuilt the current logbook page after the detail/profile view
	movff	logbook_divenumber,logbook_divenumber_temp				; # of dive in list of the current page
	movff	logbook_max_dive_counter,logbook_max_dive_counter_temp	; backup counter
	movff	logbook_temp,logbook_temp_backup						; amount of dives drawn until now

logbook_display_loop1:
	decfsz	menu_pos_cur,F							; list full?
	bra		logbook2								; NO - search another dive for our current logbook page

logbook_display_loop2:
	btfss	logbook_page_not_empty					; was there one dive at all?
	bra		logbook									; YES - so reload the first page

	; TFT_mask...

	WIN_LEFT	logbook_list_left
	WIN_TOP		logbook_row_offset*(logbook_row_number+.0)
	STRCPY_TEXT_PRINT tNextLog						; "Next Page"

	WIN_LEFT	logbook_list_left
	WIN_TOP		logbook_row_offset*(logbook_row_number+.1)
	STRCPY_TEXT_PRINT tExit							; "Exit"

	movlw	d'1'									; set cursor to position 1...
	btfsc	return_from_profileview					; .. unless we are returning from a detail/profile view
	movf	logbook_menupos_temp,W					; load last cursor position again
	movwf	menu_pos_cur							; and set menu_pos_cur byte
	bcf		return_from_profileview					; do this only once while the page is loaded again

	bcf		logbook_page_not_empty					; obviously the current page is NOT empty

	movlw	d'8'									; set cursor to position 7...
	btfsc	keep_cursor_new_page					; ... if we came from the "new page" line
	movwf	menu_pos_cur							; and set menu_pos_cur byte
	bcf		keep_cursor_new_page

	call	TFT_logbook_cursor						; show the cursor

logbook_loop_pre:
	call	logbook_preloop_tasks					; clear timeout, some flags and switch on backlight
logbook_loop:
	btfsc	switch_left								; left button pressed?
	goto	next_logbook3							; YES - adjust cursor or create new page
	btfsc	switch_right							; right button pressed?
	bra		display_profile_or_exit					; YES - view details/profile or exit logbook
	call	housekeeping							; NO to both - handle screen dump request, timeout and entering dive mode
	bra		logbook_loop							;            - loop waiting for something to do

display_profile_or_exit:
	movlw	logbook_row_number+.2					; exit?
	cpfseq	menu_pos_cur							; YES
	bra		display_profile_or_exit2				; NO  - check for "Next Page"

exit_logbook:
	bcf		switch_right							; clear pending button events
	bcf		switch_left								; ...
	goto	do_main_menu2							; jump-back to menu_tree.asm

display_profile_or_exit2:
	movlw	logbook_row_number+.1					;
	cpfseq	menu_pos_cur							; do next page?
	bra		display_profile							; NO  - show details/profile
	goto	next_logbook2							; YES - next page

display_profile:
	bcf		bailout_mode							; clear event flag
	bcf		event_gas_change_gas6					; clear event flag
	movff	menu_pos_cur,logbook_menupos_temp		; store current cursor position
	bsf		return_from_profileview					; tweak search routine to exit after found

	movf	logbook_page_number,W					; number of page
	mullw	logbook_row_number
	movf	PRODL,W
	addwf	menu_pos_cur,W							; page * logbook_row_number + menu_pos_cur =
	movwf	divenumber								; # of dive to show

display_profile2:
	call	TFT_boot

; set ext_flash pointer to "#divenumber-oldest" dive
; compute read_int_eeprom .2 - divenumber
; read required header data for profile display
; look in header for pointer to begin of dive profile (Byte 2-4)
; set pointer (ext_flash_log_pointer:3) to this address, start drawing

	decf	divenumber,F							; -1
	read_int_eeprom .2
	movf	EEDATA,W
	bcf		STATUS,C
	subfwb	divenumber,W							; max. dives (low value) - dive number
	movwf	lo										; result
	incf	divenumber,F							; +1
	; Set ext_flash_address:3 to TOC entry of this dive
	; 1st: 200000h-200FFFh -> lo=0
	; 2nd: 201000h-201FFFh -> lo=1
	; 3rd: 202000h-202FFFh -> lo=2
	; 256: 2FF000h-2FFFFFh -> lo=255 (And hi>0...)
	clrf	ext_flash_address+0
	clrf	ext_flash_address+1
	movlw	0x20
	movwf	ext_flash_address+2
	movlw	.16
	mulwf	lo										; lo*16 = offset to 0x2000 (up:hi)
	movf	PRODL,W
	addwf	ext_flash_address+1,F
	movf	PRODH,W
	addwfc	ext_flash_address+2,F
	; pointer at the first 0xFA of header

	; Now, show profile
	LOG_POINT_TO log_samplingrate
	call	ext_flash_byte_read						; read sampling rate
	movff	ext_flash_rw,sampling_rate				; store for later use

	LOG_POINT_TO .2
	call	ext_flash_byte_read_plus				; read start address of profile
	movff	ext_flash_rw,ext_flash_log_pointer+0
	call	ext_flash_byte_read_plus				; read start address of profile
	movff	ext_flash_rw,ext_flash_log_pointer+1
	call	ext_flash_byte_read_plus				; read start address of profile
	movff	ext_flash_rw,ext_flash_log_pointer+2

	CLRI	logbook_sample_counter					; holds amount of read samples

	call	TFT_standard_color
	call	logbook_show_divenumber					; show the dive number in medium font

	WIN_SMALL logbook_date_column, logbook_date_row
	LOG_POINT_TO log_date
	call	ext_flash_byte_read_plus
	movff	ext_flash_rw,up							; year
	call	ext_flash_byte_read_plus
	movff	ext_flash_rw,hi							; month
	call	ext_flash_byte_read_plus
	movff	ext_flash_rw,lo							; day
	call	TFT_convert_date						; converts into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in postinc2
	STRCAT_PRINT ""

	WIN_SMALL log_divetime_value_column,logbook_date_row	; align with surrounding data
	LOG_POINT_TO log_divemode
	call	ext_flash_byte_read_plus				; read dive mode
	movff	ext_flash_rw,lo							; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=pSCR
	call	TFT_decotype_logbook					; "strcat_print"s dive mode (OC, CC, Gauge, Apnea or pSCR)
													; also sets aux_flag in case the dive was done in a deco mode

	WIN_SMALL logbook_time_column, logbook_time_row
	LOG_POINT_TO log_time
	call	ext_flash_byte_read_plus				; hour
	movff	ext_flash_rw,lo
	call	ext_flash_byte_read_plus				; minutes
	movff	ext_flash_rw,hi
	output_99x										; hour
	PUTC	':'
	movff	hi,lo
	output_99x										; minute
	STRCAT_PRINT ""									; display 1st row of details

	LOG_POINT_TO log_profile_version
	call	ext_flash_byte_read_plus				; profile version
	movlw	0x24
	cpfslt	ext_flash_rw							; < 0x24 ?
	bra		log_skip_extra_icon						; YES -  skip

	WIN_SMALL logbook_time_column-.8, logbook_time_row
	STRCPY_PRINT 0x94								; "End of dive" icon

log_skip_extra_icon:
	LOG_POINT_TO log_max_depth
	call	ext_flash_byte_read_plus				; read max depth
	movff	ext_flash_rw,lo
	call	ext_flash_byte_read_plus				; read max depth
	movff	ext_flash_rw,hi
	MOVII	mpr,xA									; calculate y-scale for profile display
	MOVLI	profile_height_pixels,xB				; pixel height available for profile
	call	div16x16								; xC = xA / xB with xA as remainder
	MOVII	xC,y_scale								; y-scale (mbar/pixel)
	INCI	y_scale									; increase one, because there may be a remainder

	movlw	LOW   ((profile_height_pixels+1)*.1000)
	movwf	xC+0
	movlw	HIGH  (((profile_height_pixels+1)*.1000) & h'FFFF')
	movwf	xC+1
	movlw	UPPER ((profile_height_pixels+1)*.1000)
	movwf	xC+2
	clrf	xC+3

	MOVII	mpr,xB									; max. Depth in mbar
	call	div32x16								; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,x_scale								; Pixels/10m (for scale, draw any xx rows a scale-line)

	movf	x_scale+0,W
	iorwf	x_scale+1,W								; x_scale:2 = zero ?
	bnz		display_profile_offset4					; NO  - continue
	incf	x_scale+1,F								; YES - make x_scale+1>1 to make "display_profile2e" working

display_profile_offset4:
	WIN_SMALL log_max_value_column,log_max_value_row

	TSTOSS	opt_units								; 0=Meters, 1=Feets
	bra		display_profile_offset4_metric			; 0 - do metric
													; 1 - do imperial
	call	convert_mbar_to_feet					; convert value in lo:hi from mbar to feet
	PUTC	' '
	bcf		leftbind
	output_16_3										; limit to 999 and display only (0-999)
	STRCAT_TEXT_PRINT tFeets
	bra		display_profile_offset4_common

display_profile_offset4_metric:
	bsf		leftbind
	output_16dp d'3'								; max. depth
	STRCAT_TEXT_PRINT tMeters

display_profile_offset4_common:
	call	ext_flash_byte_read_plus				; dive time in minutes
	movff	ext_flash_rw,lo
	call	ext_flash_byte_read_plus
	movff	ext_flash_rw,hi							; dive time in minutes

	MOVII	mpr,xA									; calculate x-scale for profile display, calculate total dive seconds first
	MOVLI	.60,xB									; 60 seconds are one minute
	call	mult16x16								; result is in xC:2

	WIN_SMALL log_divetime_value_column,log_divetime_value_row
	bsf		leftbind
	output_16										; dive time minutes
	MOVLI	.600,xA									; a vertical line every 600 seconds
	movff	sampling_rate,xB+0						; copy sampling rate to xB, low  byte
	clrf	xB+1									; clear                 xB, high byte
	call	div16x16								; xA/xB=xC with xA as remainder
	MOVII	xC,vertical_interval					; vertical_interval:2 holds interval of samples for vertical 10min line

	; Restore dive time in minutes:
	; get real sample time
	LOG_POINT_TO log_total_seconds
	call	ext_flash_byte_read_plus				; total sample time in seconds
	movff	ext_flash_rw,xC+0
	call	ext_flash_byte_read_plus				; total sample time in seconds
	movff	ext_flash_rw,xC+1

	PUTC	':'
	LOG_POINT_TO log_divetime+.2
	call	ext_flash_byte_read_plus				; read dive time seconds
	movff	ext_flash_rw,lo
	MOVII	xC,xA									; now calculate x-scale value
	MOVLI	profile_width_pixels,xB					; pix width available
	call	div16x16								; xC = xA / xB with xA as remainder
	MOVII	xC,xA
	movff	sampling_rate,xB+0						; divide through sampling rate (time interval)
	clrf	              xB+1
	call	div16x16								; xC = xA / xB with xA as remainder
	MOVII	xC,profile_temp1						; store value (use any #xC sample, skip xC-1) into temp registers
	INCI	profile_temp1							; increase by one, there might be a remainder

	bsf		leftbind
	output_99x										; dive time seconds
	call	TFT_standard_color
	STRCAT_PRINT ""

	call	ext_flash_byte_read_plus				; read min. temperature, low  byte
	movff	ext_flash_rw,logbook_min_tp+0
	call	ext_flash_byte_read_plus				; read min. temperature, high byte
	movff	ext_flash_rw,logbook_min_tp+1

	btfss	aux_flag								; dive done in a deco mode?
	bra		logbook_set_gas_color					; NO - always use gas 1 color (white) then

	; Set pointer to gas 1 type
	LOG_POINT_TO log_gas1+.3
	call	ext_flash_byte_read_plus				; read gas type
	decfsz	ext_flash_rw,W							; = 1 (= "First") ?
	bra		logbook_find_first_gas2					; NO
logbook_set_gas_color:
	movlw	.1										; YES - select white color
	movwf	ext_flash_rw
	bra		logbook_find_first_gas_done
logbook_find_first_gas2:
	; Set pointer to gas 2 type
	LOG_POINT_TO log_gas2+.3
	call	ext_flash_byte_read_plus				; read gas type
	decfsz	ext_flash_rw,W							; = 1 (= "First") ?
	bra		logbook_find_first_gas3					; NO
	movlw	.2										; YES - select green color
	movwf	ext_flash_rw
	bra		logbook_find_first_gas_done
logbook_find_first_gas3:
	; Set pointer to gas 3 type
	LOG_POINT_TO log_gas3+.3
	call	ext_flash_byte_read_plus				; read gas type
	decfsz	ext_flash_rw,W							; = 1 (= "First") ?
	bra		logbook_find_first_gas4					; NO
	movlw	.3										; YES - select red color
	movwf	ext_flash_rw
	bra		logbook_find_first_gas_done
logbook_find_first_gas4:
	; Set pointer to gas 4 type
	LOG_POINT_TO log_gas4+.3
	call	ext_flash_byte_read_plus				; read gas type
	decfsz	ext_flash_rw,W							; = 1 (= "First") ?
	bra		logbook_find_first_gas5					; NO
	movlw	.4										; YES - select yellow color
	movwf	ext_flash_rw
	bra		logbook_find_first_gas_done
logbook_find_first_gas5:
	movlw	.5										; must be gas 5, select cyan color
	movwf	ext_flash_rw
logbook_find_first_gas_done:
	movff	ext_flash_rw,backup_color1				; keep copy to restore color
	movff	ext_flash_rw,WREG						; copy gas number to WREG for color coding
	call	TFT_color_code_gas						; set color
	; Pointer is now trashed!

	; Point to profile portion of this dive
	movff	ext_flash_log_pointer+0,ext_flash_address+0
	movff	ext_flash_log_pointer+1,ext_flash_address+1
	movff	ext_flash_log_pointer+2,ext_flash_address+2

	incf_ext_flash_address_0x20 d'2'				; skip 0xFA 0xFA
	call	ext_flash_byte_read_plus_0x20			; read low byte of total dives into ext_flash_rw (at the time the dive was made)

	; Load total number of dives (low byte only)
	read_int_eeprom .2
	incf	EEDATA,W								; +1
	bsf		STATUS,C								; set borrow
	subfwb	divenumber,W							; total dives - dive# to show - 1 = low byte of total dives (at the time the dive was made)
	cpfseq	ext_flash_rw							; # of dive in logbook (Must be equal with low byte in short header)
	bra		display_profile_no_profile				; not equal, no profile for this dive available

	; Skip rest of short header: 3 Bytes
	; Skip length of profile data: 3 Bytes
	; Skip sampling rate in profile section: 1Byte
	; Skip number of divisors: 1Byte
	incf_ext_flash_address_0x20 d'8'

; divisor temp
	incf_ext_flash_address_0x20 d'2'
;	call	ext_flash_byte_read_plus_0x20			; read information type
;	call	ext_flash_byte_read_plus_0x20			; read information length
	call	ext_flash_byte_read_plus_0x20			; read information divisor
	movf	ext_flash_rw,W
	movwf	divisor_temperature						; store divisor
	movwf	count_temperature						; store to tp° counter, too
; divisor deco
	incf_ext_flash_address_0x20 d'2'
;	call	ext_flash_byte_read_plus_0x20			; read information type
;	call	ext_flash_byte_read_plus_0x20			; read information length
	call	ext_flash_byte_read_plus_0x20			; read information divisor
	movf	ext_flash_rw,W
	movwf	divisor_deco							; store divisor
	movwf	count_deco								; store as temp, too
; divisor GF
	incf_ext_flash_address_0x20 d'2'
;	call	ext_flash_byte_read_plus_0x20			; read information type
;	call	ext_flash_byte_read_plus_0x20			; read information length
	call	ext_flash_byte_read_plus_0x20			; read information divisor
	movff	ext_flash_rw,divisor_gf					; store divisor
; divisor ppO2 sensors
	incf_ext_flash_address_0x20 d'2'
;	call	ext_flash_byte_read_plus_0x20			; read information type
;	call	ext_flash_byte_read_plus_0x20			; read information length
	call	ext_flash_byte_read_plus_0x20			; read information divisor
	movff	ext_flash_rw,divisor_ppo2_sensors		; store divisor
; divisor decoplan
	incf_ext_flash_address_0x20 d'2'
;	call	ext_flash_byte_read_plus_0x20			; read information type
;	call	ext_flash_byte_read_plus_0x20			; read information length
	call	ext_flash_byte_read_plus_0x20			; read information divisor
	movff	ext_flash_rw,divisor_decoplan			; store divisor
; divisor CNS
	incf_ext_flash_address_0x20 d'2'
;	call	ext_flash_byte_read_plus_0x20			; read information type
;	call	ext_flash_byte_read_plus_0x20			; read information length
	call	ext_flash_byte_read_plus_0x20			; read information divisor
	movff	ext_flash_rw,divisor_cns				; store divisor
; divisor tank data
	incf_ext_flash_address_0x20 d'2'
;	call	ext_flash_byte_read_plus_0x20			; read information type
;	call	ext_flash_byte_read_plus_0x20			; read information length
	call	ext_flash_byte_read_plus_0x20			; read information divisor
	movff	ext_flash_rw,divisor_tank				; store divisor

	; Start profile display
	movlw	color_deepblue
	call	TFT_set_color
	; Draw a frame around profile area
	WIN_FRAME_COLOR16 profile_top-1,profile_top+profile_height_pixels+1,profile_left-1,profile_left+profile_width_pixels+1

	movlw	profile_top
	movwf	win_top
	movlw	profile_left
	movwf	win_leftx2								; left border (0-159)
	movlw	d'1'
	movwf	win_height
	movlw	profile_width_pixels+.1
	movwf	win_width+0								; right border (0-159)
	clrf	win_width+1
	bra		display_profile2f						; no 0m line
display_profile2e:
	call	TFT_box									; inputs: win_top, win_leftx2, win_height, win_width, win_color1, win_color2
display_profile2f:
	movf	win_top,W								; get row
	addwf	x_scale+0,W								; add line interval distance to win_top
	tstfsz	x_scale+1								; > 255 ?
	movlw	d'255'									; YES - make win_top>239 -> abort here
	btfsc	STATUS,C								; a carry from the addwf above?
	movlw	d'255'									; YES - make win_top>239 -> abort here
	movwf	win_top									; result in win_top again
	movlw	profile_top+profile_height_pixels+.1	; limit
	cpfsgt	win_top									; > 239 ?
	bra		display_profile2e						; NO - draw another line

	clrf	gaslist_gas								; here: used as counter for depth readings
	movlw	profile_width_pixels+profile_left-.1
	movwf	ignore_digits							; here: used as counter for x-pixels
	bcf		end_of_profile							; clear flag

	movlw	profile_left+.1
	movwf	logbook_pixel_x_pos						; here: used as column x2 (start at column 5)

	movlw	profile_top+.1							; zero-m row
	movwf	fill_between_rows
	movwf	logbook_last_tp							; initialize for Tp° curve, too

	movlw	LOW(-.100)								; initialize max tp° to -10.0 °C
	movwf	logbook_max_tp+0
	movlw	HIGH 0xFFFF & (-.100)
	movwf	logbook_max_tp+1

	setf	logbook_cur_tp+0						; initialize Tp°, before the first recorded point
	setf	logbook_cur_tp+1
	clrf	logbook_last_tp							; also reset previous Y for Tp°
	clrf	logbook_ceiling							; Ceiling = 0, correct value for no ceiling
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

profile_display_loop:
	; Init pixel write
	movf	logbook_pixel_x_pos,W
	mullw	2
	call	pixel_write_col320

	MOVII	profile_temp1,profile_temp2				; 16 bit x-scaler

	incf	profile_temp2+1,F
	tstfsz	profile_temp2+0							; must not be zero, is zero?
	bra		profile_display_loop2					; NO  - ok
	incf	profile_temp2+0,F						; YES - increase by 1

profile_display_loop2:
	rcall	profile_view_get_depth					; reads depth, temp and profile data

	btfsc	end_of_profile							; end-of profile reached?
	bra		profile_display_loop_done				; YES - skip all remaining pixels


	;---- Draw Ceiling curve, if any ---------------------------------------------
	movf	divisor_deco,W
	bz		profile_display_skip_deco

	movf	logbook_ceiling,W						; any deco ceiling?
	bz		profile_display_skip_deco

	mullw	.100									; YES - convert to mbar
	MOVII	PROD,               sub_a				; ceiling depth
	MOVII	logbook_cur_depth+0,sub_b				; current depth
	call	cmpU16									; ceiling - current depth

	movlw	color_dark_green						; dark green if ok
	btfss	neg_flag								; current depth > ceiling ?
	movlw	color_dark_red							; NO - dark red because ceiling is violated
	call	TFT_set_color

	MOVII	PROD,xA
	MOVII	y_scale,xB								; divide pressure in mbar/quant for row offset
	call	div16x16								; xC = xA / xB with xA as remainder

	movlw	profile_top+.1							; starts right after the top line
	movwf	win_top
	movff	logbook_pixel_x_pos,win_leftx2			; left border (0-159)
	movff	xC+0,win_height
	call	half_vertical_line						; inputs: win_top, win_leftx2, win_height, win_color1, win_color2

profile_display_skip_deco:
	;---- Draw Tp° curve, if any ---------------------------------------------
	movf	divisor_temperature,W
	bz		profile_display_skip_temp

	movf	logbook_cur_tp+0,W						; did we had already a valid Tp°C record?
	andwf	logbook_cur_tp+1,W
	incf	WREG
	bz		profile_display_skip_temp				; NO - just skip drawing.

	movlw	LOW  (((profile_height_pixels-.10)*.256)/.370)	; fixed tp° scale: (-2 .. +35°C * scale256 )/153pix
	movwf	xB+0
	movlw	HIGH (((profile_height_pixels-.10)*.256)/.370)
	movwf	xB+1

	movf	logbook_cur_tp+0,W						; current Tp° - (-2.0°C) == Tp° + 20
	addlw	LOW(.20)								; low byte
	movwf	xA+0
	movf	logbook_cur_tp+1,W
	btfsc	STATUS,C								; propagate carry, if any
	incf	WREG
	movwf	xA+1
	call	mult16x16								; xA*xB=xC

	; scale: divide by 256, ie. take just high byte.
	movf	xC+1,W
	sublw	profile_top+profile_height_pixels-.10	; upside-down: Y = .75 + (.153 - result)
	movwf	xC+0

	; Check limits
	movlw	profile_top+.1
	movwf	xC+1
	cpfsgt	xC+0
	movff	xC+1,xC+0

	movlw	color_orange
	call	TFT_set_color

	movf	logbook_last_tp,W						; do we have a valid previous value?
	bz		profile_display_temp_1					; NO - skip the vertical line
	movwf	xC+1
	call	profile_display_fill					; in this column between this row (xC+0) and the last row (xC+1)
profile_display_temp_1:
	movf	xC+0,W									; current row
	cpfsgt	logbook_min_temp_pos					; check limit
	movwf	logbook_min_temp_pos					; lowest row in the temp graph
	cpfslt	logbook_max_temp_pos					; check limit
	movwf	logbook_max_temp_pos					; highest row in the temp graph

	movff	xC+0,logbook_last_tp
	PIXEL_WRITE logbook_pixel_x_pos,xC+0			; set col (0..159) x row (0..239), put a current color pixel

profile_display_skip_temp:
	;---- Draw depth curve ---------------------------------------------------
	MOVII	y_scale,          xB					; divide pressure in mbar/quant for row offset
	MOVII	logbook_cur_depth,xA
	call	div16x16								; xC = xA / xB with xA as remainder
	movlw	profile_top+.1
	addwf	xC+0,F									; add 75 pixel offset to result

	btfsc	STATUS,C								; ignore potential profile errors
	movff	fill_between_rows,xC+0

	movff	backup_color1,WREG						; copy gas number to WREG for color-coding
	call	TFT_color_code_gas						; back to normal profile color

	movff	fill_between_rows,xC+1
	call	profile_display_fill					; in this column between this row (xC+0) and the last row (xC+1)
	movff	xC+0,fill_between_rows					; store last row for fill routine

	PIXEL_WRITE logbook_pixel_x_pos,xC+0			; set col (0..159) x row (0..239), put a std color pixel
	incf	logbook_pixel_x_pos,F					; next column

	;---- Draw Marker square, if any -----------------------------------------
	btfss	log_marker_found						; any marker to draw?
	bra		profile_display_skip_marker				; NO

	; tiny "m"
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

	movlw	color_orange
	call	TFT_set_color
	WIN_FONT FT_TINY
	lfsr	FSR2,buffer
	STRCPY_PRINT "m"
	bcf		log_marker_found						; clear flag

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
	;---- Draw CNS curve, if any ---------------------------------------------
	movf	divisor_cns,W
	bz		profile_display_skip_cns
	;
	; add further code here...
	;
profile_display_skip_cns:

	;---- Draw GF curve, if any ----------------------------------------------
	movf	divisor_gf,W
	bz		profile_display_skip_gf
	;
	; add further code here...
	;
profile_display_skip_gf:

	;---- All curves done

profile_display_skip_loop1:							; skips readings
	dcfsnz	profile_temp2+0,F
	bra		profile_display_loop3					; check 16bit

	rcall	profile_view_get_depth					; reads depth, temp and profile data

	btfsc	end_of_profile							; end-of profile reached?
	bra		profile_display_loop_done				; YES - skip all remaining pixels

	bra		profile_display_skip_loop1

profile_display_loop3:
	decfsz	profile_temp2+1,F						; 16 bit x-scaler test
	bra		profile_display_skip_loop1				; skips readings

	decfsz	ignore_digits,F							; counts drawn x-pixels to zero
	bra		profile_display_loop					; not ready yet
	; done

display_profile_no_profile:							; no profile available for this dive

profile_display_loop_done:
	btfss	bailout_mode							; bailout during the dive?
	bra		profile_display_loop_done_nobail		; NO
													; YES - show "Bailout"
	movlw	color_pink
	call	TFT_set_color
	WIN_TINY logbook_bailout_column,logbook_bailout_row
	STRCPY_TEXT_PRINT tDiveBailout					; bailout
profile_display_loop_done_nobail:
	btfss	event_gas_change_gas6					; did a change to gas 6 occurred?
	bra		profile_display_loop_done_nogas6		; NO
	movlw	color_pink								; YES - select color
	call	TFT_set_color							;     - set color
	WIN_TINY logbook_bailout_column,logbook_bailout_row-.15
	STRCPY_TEXT tGas								;     - print "Gas"
	STRCAT_PRINT " 6!"								;     - print " 6!"

profile_display_loop_done_nogas6:
	decf	divenumber,F							; -1
	read_int_eeprom .2
	movf	EEDATA,W
	bcf		STATUS,C
	subfwb	divenumber,W							; max. dives (low value) - dive number
	movwf	lo										; result
	incf	divenumber,F							; +1
	; set ext_flash_address:3 to TOC entry of this dive
	; 1st: 200000h-200FFFh -> lo=0
	; 2nd: 201000h-201FFFh -> lo=1
	; 3rd: 202000h-202FFFh -> lo=2
	; 256: 2FF000h-2FFFFFh -> lo=255 (And hi>0...)
	clrf	ext_flash_address+0
	clrf	ext_flash_address+1
	movlw	0x20
	movwf	ext_flash_address+2
	movlw	.16
	mulwf	lo										; lo*16 = offset to 0x2000 (up:hi)
	movf	PRODL,W
	addwf	ext_flash_address+1,F
	movf	PRODH,W
	addwfc	ext_flash_address+2,F
	; pointer at the first 0xFA of header

	movff	logbook_min_temp_pos,win_top			; Y position at lowest temperature
	movff	logbook_pixel_x_pos,win_leftx2
	movlw	.130
	cpfslt	win_leftx2								; limit left border to 130
	movwf	win_leftx2
	WIN_FONT FT_TINY
	movlw	color_orange							; use same color as tp° curve
	call	TFT_set_color

	MOVII	logbook_min_tp,mpr
	lfsr	FSR2,buffer

	TSTOSS	opt_units								; 0=°C, 1=°F
	bra		logbook_show_temp_metric				; 0 - do Celsius
													; 1 - do Fahrenheit
	call	TFT_convert_signed_16bit				; converts lo:hi into signed-short and adds '-' to POSTINC2 if required
	call	convert_celsius_to_fahrenheit			; convert value in lo:hi from Celsius to Fahrenheit
	lfsr	FSR2,buffer								; overwrite "-"
	bsf		ignore_digit5							; full degrees only
	output_16
	STRCAT_TEXT_PRINT tLogTunitF
	; Now, the max. temperature
	movlw	.15
	subwf	logbook_max_temp_pos,W
	movff	WREG,win_top							; Y position at max temperature
	MOVII	logbook_max_tp,mpr
	lfsr	FSR2,buffer
	call	TFT_convert_signed_16bit				; converts lo:hi into signed-short and adds '-' to POSTINC2 if required
	call	convert_celsius_to_fahrenheit			; convert value in lo:hi from Celsius to Fahrenheit
	output_16
	bcf		ignore_digit5
	STRCAT_TEXT_PRINT tLogTunitF

	bra		logbook_show_temp_common

logbook_show_temp_metric:
	call	TFT_convert_signed_16bit				; converts lo:hi into signed-short and adds '-' to POSTINC2 if required
	movlw	d'3'
	movwf	ignore_digits
	bsf		leftbind
	output_16dp d'2'								; temperature
	STRCAT_TEXT_PRINT tLogTunitC
	; Now, the max. temperature
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

logbook_show_temp_common:
	bcf		leftbind
	call	TFT_standard_color

	btfss	aux_flag								; dive done in a deco mode?
	bra		logbook_show_gases_done					; NO

	; show gases
	LOG_POINT_TO log_gas1							; get pointer to gaslist
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
	bra		logbook_page2							; YES - show more information
	btfsc	switch_left								; left button pressed?
	bra		exit_profileview						; YES - back to list
	call	housekeeping							; NO to both - handle screen dump request, timeout and entering dive mode
	bra		display_profile_loop					;            - loop waiting for something to do

;=============================================================================
; Draw a vertical line between xC+1 and xC+0, at current X position.
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
	call	ext_flash_byte_read_plus_0x20			; read depth first
	movff	ext_flash_rw,logbook_cur_depth+0		; low value
	call	ext_flash_byte_read_plus_0x20			; read depth first
	movff	ext_flash_rw,logbook_cur_depth+1		; high value
	call	ext_flash_byte_read_plus_0x20			; read  Profile Flag Byte
	movff	ext_flash_rw,gaslist_gas				; store Profile Flag Byte

	bcf		event_occured							; clear flag by default
	btfsc	gaslist_gas,7							; event recorded?
	bsf		event_occured							; YES - we also have an event byte
	bcf		gaslist_gas,7							; clear event byte flag (if any)
	; gaslist_gas now holds the number of additional bytes to ignore (0-127)
	movlw	0xFD									; end of profile bytes ?
	cpfseq	logbook_cur_depth+0
	bra		profile_view_get_depth_new1				; no 1st. 0xFD
	cpfseq	logbook_cur_depth+1
	bra		profile_view_get_depth_new1				; no 2nd. 0xFD
	bsf		end_of_profile							; end found - set flag, skip remaining pixels
	return

profile_view_get_depth_new1:
	btfsc	event_occured							; was there an event attached to this sample?
	rcall	profile_view_get_depth_events			; YES - get information about this event(s)

	;---- read Tp°, if any AND divisor reached AND bytes available -----------
	movf	divisor_temperature,W					; is Tp° divisor null ?
	bz		profile_view_get_depth_no_tp			; YES - no Tp° curve
	decf	count_temperature,F						; decrement tp° counter
	bnz		profile_view_get_depth_no_tp			; no temperature this time

	call	ext_flash_byte_read_plus_0x20			; Tp° low
	decf	gaslist_gas,F
	movff	ext_flash_rw,logbook_cur_tp+0
	call	ext_flash_byte_read_plus_0x20			; Tp° high
	decf	gaslist_gas,F
	movff	ext_flash_rw,logbook_cur_tp+1
	movff	divisor_temperature,count_temperature	; restart counter

	; Compute Tp° max on the fly...
	MOVII	logbook_cur_tp,sub_a					; compare cur_tp > max_tp ?
	MOVII	logbook_max_tp,sub_b
	call	sub16									; SIGNED sub_a - sub_b
	btfsc	neg_flag
	bra		profile_view_get_depth_no_tp

	; store max. temp only below dive_threshold_norm_alt_start
	tstfsz	logbook_cur_depth+1						; > 2.56 m ?
	bra		profile_view_compute_max_temp			; YES - include in max. temp measurement
	movlw	dive_threshold_norm_alt_start+0			; get start-of-dive depth in mbar / cm, low byte
	cpfsgt	logbook_cur_depth+0						; deeper that start-of-dive threshold?
	bra		profile_view_get_depth_no_tp			; NO - ignore temperature

profile_view_compute_max_temp:
	MOVII	logbook_cur_tp,logbook_max_tp

	;---- read deco, if any AND divisor=0 AND bytes available ----------------
profile_view_get_depth_no_tp:
	movf	divisor_deco,W
	bz		profile_view_get_depth_no_deco
	decf	count_deco,F
	bnz		profile_view_get_depth_no_deco

	call	ext_flash_byte_read_plus_0x20
	decf	gaslist_gas,F
	movff	ext_flash_rw,logbook_ceiling
	movff	divisor_deco,count_deco					; restart counter
	call	ext_flash_byte_read_plus_0x20			; skip stop length
	decf	gaslist_gas,F

	;---- read GF, if any AND divisor=0 AND bytes available ------------------
profile_view_get_depth_no_deco:
	; Then skip remaining bytes...
	movf	gaslist_gas,W							; number of additional bytes to ignore (0-127)
	tstfsz	gaslist_gas								; anything to skip?
	call	incf_ext_flash_address0_0x20			; YES - increases bytes in ext_flash_address:3 with 0x200000 bank switching
	return

profile_view_get_depth_events:
	clrf	event_byte2								; clear event byte 2
	call	ext_flash_byte_read_plus_0x20			; read event byte
	movff	ext_flash_rw,event_byte1				; store event byte 1
	decf	gaslist_gas,F							; reduce counter

	btfss	event_byte1,7							; another event byte?
	bra		profile_no_second_eventbyte				; NO
	call	ext_flash_byte_read_plus_0x20			; read  event byte 2
	movff	ext_flash_rw,event_byte2				; store event byte 2
	decf	gaslist_gas,F							; reduce counter
	bcf		event_byte1,7							; clear flag

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
	call	ext_flash_byte_read_plus_0x20			; read gas number
	decf	gaslist_gas,F							; reduce counter
	movff	ext_flash_rw,backup_color1
	movff	ext_flash_rw,WREG						; copy gas number to WREG for color-coding
	call	TFT_color_code_gas						; change profile color according to gas number
	return

logbook_event1:										; gas 6 used
	bsf		event_gas_change_gas6					; set event flag
	movlw	.6										; use gas 6 color
	movwf	backup_color1							; select color for gas 6
	call	TFT_color_code_gas						; set profile color
	incf_ext_flash_address_0x20 .2					; skip two bytes
	decf	gaslist_gas,F							; reduce counter
	decf	gaslist_gas,F							; reduce counter
	return

logbook_event2:										; bailout
	bsf		bailout_mode							; set flag
	movff	backup_color1,backup_color2				; backup last gas color in case we return to CCR
	movlw	.6										; use Gas6 color
	movwf	backup_color1
	call	TFT_color_code_gas						; use gas 6 color
	incf_ext_flash_address_0x20 .2					; skip two bytes
	decf	gaslist_gas,F							; reduce counter
	decf	gaslist_gas,F							; reduce counter
	return

logbook_event3:										; setpoint change
	incf_ext_flash_address_0x20 .1					; skip one byte
	decf	gaslist_gas,F							; reduce counter
	btfss	bailout_mode							; in bailout?
	return											; NO - return
	; We were in bailout before, restore profile color
	movff	backup_color2,backup_color1				; restore color
	movff	backup_color2,WREG						; copy gas number to WREG for color-coding
	call	TFT_color_code_gas						; back to normal profile color
	return

; ------------------------------------------------------------------------

exit_profileview:
	clrf	gaslist_gas								; restore all registers to build same page again
	movff	logbook_divenumber_temp,logbook_divenumber
	movff	logbook_max_dive_counter_temp,logbook_max_dive_counter
	movff	logbook_temp_backup,logbook_temp
	incf	logbook_max_dive_counter,F
	decf	logbook_divenumber,F
	bcf		all_dives_shown
	clrf	menu_pos_max							; number of used rows on current logbook-page
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
	incf	menu_pos_cur,F							; +1
	movlw	logbook_row_number+.2
	cpfsgt	menu_pos_cur							; = logbook_row_number + 3 ?
	bra		next_logbook3a							; NO
	movlw	.1
	movwf	menu_pos_cur
	bra		next_logbook3b

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

display_listdive:
	bsf		logbook_page_not_empty					; page not empty
	incf	menu_pos_max,F

	WIN_FONT FT_SMALL
	WIN_LEFT logbook_list_left

	decf	menu_pos_max,W							; -1 into WREG
	mullw	logbook_row_offset
	movff	PRODL,win_top
	lfsr	FSR2,buffer								; initialize output buffer

	movf	logbook_divenumber,W					; log_compute_divenumber needs the list number
	call	log_compute_divenumber					; compute dive number
	bsf		leftbind
	movlw	.3										; start with 3rd digit (i.e. suppress the thousands)
	movwf	ignore_digits
	output_16dp .0									; show dive number
	bcf		leftbind
	PUTC	' '
	; display_listdive2:
	LOG_POINT_TO log_date+1							; point to month
	call	ext_flash_byte_read_plus				; read month
	movff	ext_flash_rw,hi							; month
	call	ext_flash_byte_read_plus				; read day
	movff	ext_flash_rw,lo							; day
	call	TFT_convert_date_short					; converts into "DD/MM" or "MM/DD" or "MM/DD" into buffer
	PUTC	' '

	LOG_POINT_TO log_max_depth						; point to max. depth
	call	ext_flash_byte_read_plus				; max. depth
	movff	ext_flash_rw,lo
	call	ext_flash_byte_read_plus
	movff	ext_flash_rw,hi

	TSTOSS	opt_units								; 0=Meters, 1=Feets
	bra		display_listdive2_metric				; 0 - do metric
													; 1 - do imperial
	call	convert_mbar_to_feet					; convert value in lo:hi from mbar to feet
	PUTC	' '
	output_16_3										; limit to 999 and display only (0-999)
	STRCAT_TEXT tFeets1
	bra		display_listdive3

display_listdive2_metric:
	bsf		ignore_digit5							; no cm...
	movlw	d'1'									; +1
	movwf	ignore_digits							; no 1000 m
	output_16dp .3									; xxx.y
	STRCAT_TEXT tMeters
	PUTC	' '

display_listdive3:
	call	ext_flash_byte_read_plus
	movff	ext_flash_rw,lo							; read dive time minutes
	call	ext_flash_byte_read_plus
	movff	ext_flash_rw,hi
	output_16_3										; dive time minutes (0-999min)
	STRCAT_TEXT tMinutes
	clrf	WREG
	movff	WREG,buffer+.21							; limit to 21 chars
	STRCAT_PRINT ""									; display header-row in list
	return

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

; -------------------------------------------------------------------

logbook_page2:										; show more info
	rcall	log_details_header						; shows number, time/date and basic dive info

	btfss	aux_flag								; dive done in a deco mode?
	bra		logbook_page2_1							; NO

	; Deco model
	WIN_SMALL .5,.65
	LOG_POINT_TO log_decomodel
	call	ext_flash_byte_read_plus				; read deco model
	movff	ext_flash_rw,lo
	decfsz	ext_flash_rw,F
	bra		logbook_decomodel1
	; Deco model GF Version
	STRCAT_PRINT "ZHL-16+GF"
	LOG_POINT_TO log_gf_lo
	WIN_SMALL .5,.90
	STRCPY_TEXT tGF
	call	ext_flash_byte_read_plus				; read GF lo
	movff	ext_flash_rw,lo
	output_8
	STRCAT	"%/"
	bra		logbook_decomodel_common
logbook_decomodel1:
	; Deco model NON-GF Version
	STRCAT_PRINT "ZH-L16"
	LOG_POINT_TO log_sat_mult
	WIN_SMALL .5,.90
	call	ext_flash_byte_read_plus				; read sat_mult or GF low
	movff	ext_flash_rw,lo
	output_8
	STRCAT	"%/"
logbook_decomodel_common:
	call	ext_flash_byte_read_plus				; read desat_mult or GF high
	movff	ext_flash_rw,lo
	output_8
	STRCAT_PRINT "%"

	; CNS
	LOG_POINT_TO log_cns_start
	WIN_SMALL .5,.115
	STRCPY_TEXT tCNS2
	call	ext_flash_byte_read_plus				; read CNS low
	movff	ext_flash_rw,lo
	call	ext_flash_byte_read_plus				; read CNS high
	movff	ext_flash_rw,hi
	bcf		hi,int_warning_flag						; clear warning   flag (fix for cases were the flags already got stored to EEPROM)
	bcf		hi,int_attention_flag					; clear attention flag (fix for cases were the flags already got stored to EEPROM)
	output_16
	LOG_POINT_TO log_cns_end
	STRCAT	"->"
	call	ext_flash_byte_read_plus				; read CNS low
	movff	ext_flash_rw,lo
	call	ext_flash_byte_read_plus				; read CNS high
	movff	ext_flash_rw,hi
	bcf		hi,int_warning_flag						; clear warning   flag (fix for cases were the flags already got stored to EEPROM)
	bcf		hi,int_attention_flag					; clear attention flag (fix for cases were the flags already got stored to EEPROM)
	output_16
	STRCAT_PRINT "%"

logbook_page2_1:

	; Salinity
	WIN_SMALL	.5,.140
	LOG_POINT_TO log_salinity
	STRCPY_TEXT tDvSalinity
	bsf		leftbind
	call	ext_flash_byte_read_plus				; read salinity
	movff	ext_flash_rw,lo
	movff	ext_flash_rw,backup_divedata			; backup for average depth display
	output_8
	STRCAT_PRINT "%"

	; Average depth
	WIN_SMALL .5,.165
	STRCPY_TEXT tAVG
	LOG_POINT_TO log_avr_depth
	call	ext_flash_byte_read_plus				; read average low
	movff	ext_flash_rw,lo
	call	ext_flash_byte_read_plus				; read average high
	movff	ext_flash_rw,hi
	movf	backup_divedata,W						; salinity for this dive
	call	adjust_depth_with_salinity_log			; compute salinity setting (FROM WREG!) into lo:hi [mbar]
	output_16dp .3
	STRCAT_PRINT "m"

	btfss	aux_flag								; dive done in a deco mode?
	bra		logbook_page2_2							; NO

	; Last deco
	LOG_POINT_TO log_last_stop
	WIN_SMALL .5,.190
	STRCPY_TEXT tLastDecostopSurf
	call	ext_flash_byte_read_plus				; read last stop
	movff	ext_flash_rw,lo
	output_8
	STRCAT_PRINT "m"

logbook_page2_2:

	movlw	color_lightblue
	call	TFT_set_color
	WIN_FRAME_COLOR16 .63,.220,.2,.105				; top, bottom, left, right

	; Firmware
	call	TFT_standard_color
	WIN_SMALL .110,.65
	STRCAT	"V:"
	LOG_POINT_TO log_firmware
	call	ext_flash_byte_read_plus				; read firmware major number
	movf	ext_flash_rw,W							; copy to WREG
	movwf	hi										; copy from WREG to hi
	movwf	lo										; copy from WREG to lo, too
	bsf		leftbind								; print left-aligned
	output_8										; print major number
	PUTC	"."										; print "."
	call	ext_flash_byte_read_plus				; read firmware minor number
	movff	ext_flash_rw,lo							; store in lo
	output_99x										; print minor version in 2 digit format
	STRCAT_PRINT ""									; finalize output

	movf	hi,W									; get major into WREG
	xorlw	.3										; major == 3 ?
	bz		logbook_battery_percent					; YES - show battery %

	movf	hi,W									; get major into WREG (again)
	xorlw	.2										; major == 2 ?
	bnz		logbook_battery_voltage					; NO  - skip battery %
	movlw	.14										; YES - check minor version
	cpfsgt	lo										;     - minor > 14 ?
	bra		logbook_battery_voltage					;       NO  - skip battery %
	;bra	logbook_battery_percent					;       YES - show battery %

	; Battery %
logbook_battery_percent:
	WIN_SMALL .110,.140								; show battery percent
	LOG_POINT_TO log_batt_info						; address battery percent
	call	ext_flash_byte_read_plus				; read  battery percent
	movff	ext_flash_rw,lo							; copy  battery percent to lo
	output_8										; print battery percent
	STRCAT_PRINT "%"								; print "%" and finalize output

	; Battery Voltage
logbook_battery_voltage:
	WIN_SMALL .110,.90
	STRCAT_PRINT "Batt:"
	WIN_SMALL .110,.115
	LOG_POINT_TO log_battery						; address battery voltage
	call	ext_flash_byte_read_plus				; read    battery voltage, low  byte
	movff	ext_flash_rw,lo							; store in lo
	call	ext_flash_byte_read_plus				; read    battery voltage, high byte
	movff	ext_flash_rw,hi							; store in hi
	output_16dp .2									; print battery voltage
	STRCAT_PRINT "V"								; ...

	LOG_POINT_TO log_surface_press					; address surface pressure in mbar
	call	ext_flash_byte_read_plus				; read surface pressure, low  byte
	movff	ext_flash_rw,lo							; store in lo
	call	ext_flash_byte_read_plus				; read surface pressure, high byte
	movff	ext_flash_rw,hi							; store in hi
	WIN_SMALL .110,.165								; set output position
	lfsr	FSR2,buffer								; set base address of output buffer
	bsf		leftbind								; print without leading spaces
	output_16										; print air pressure before dive
	STRCAT_TEXT tMBAR								; ...
	clrf	WREG									; string terminator
	movff	WREG,buffer+7							; limit to 7 chars
	STRCAT_PRINT ""									; dump buffer to screen

	movlw	color_greenish							; select color
	call	TFT_set_color							; ...
	WIN_FRAME_COLOR16 .63,.220,.107,.159			; draw a frame around coordinates top, bottom, left, right

	rcall	logbook_preloop_tasks					; clear timeout and remaining button events
display_details_loop:
	btfss	switch_right							; right button pressed?
	bra		display_details_loop_1					; NO
	btfsc	aux_flag								; YES - dive done in a deco mode?
	bra		logbook_page3							;       YES - show more details, 2nd page
	goto	display_profile2						;       NO  - show the profile view again
display_details_loop_1:
	btfsc	switch_left								; left button pressed?
	bra		exit_profileview						; YES - back to list
	call	housekeeping							; NO to both - handle screen dump request, timeout and entering dive mode
	bra		display_details_loop					;            - loop waiting for something to do


logbook_preloop_tasks:
	movlw	CCP1CON_VALUE							; see hwos.inc
	movwf	CCP1CON									; power-on backlight
	call	TFT_standard_color						; revert to standard color
	call	reset_timeout_surfmode					; reset timeout
	bcf		switch_left								; clear left-over left  button event
	bcf		switch_right							; clear left-over right button event
	return											; done


logbook_page3:										; show even more info
	rcall	log_details_header						; shows number, time/date and basic dive info
	LOG_POINT_TO log_gas1
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

	; OC/CC Gas List
	WIN_SMALL .5,.65
	WIN_COLOR color_greenish
	LOG_POINT_TO log_divemode
	call	ext_flash_byte_read_plus				; 0=OC, 1=CC, 2=Gauge, 3=Apnea into ext_flash_rw
	decfsz	ext_flash_rw,w							; =1 (CC)?
	bra		logbook_page3a
	STRCPY_TEXT_PRINT tGaslistCC
	bra		logbook_page3b
logbook_page3a:
	STRCPY_TEXT_PRINT tGaslist
logbook_page3b:
	movlw	color_lightblue
	call	TFT_set_color
	WIN_FRAME_COLOR16 .63,.220,.2,.90+.24			; top, bottom, left, right (added .24 to the right as extra space needed for gas typ markings)

	rcall	logbook_preloop_tasks					; clear timeout, some flags and set to Speed_eco
display_details2_loop:
	btfsc	switch_right							; right button pressed?
	goto	logbook_page4							; YES - show more info
	btfsc	switch_left								; left button pressed?
	bra		exit_profileview						; YES - back to list
	call	housekeeping							; NO to both - handle screen dump request, timeout and entering dive mode
	bra		display_details2_loop					;            - loop waiting for something to do

logbook_page4:										; show even more info in CC mode
	LOG_POINT_TO log_divemode
	call	ext_flash_byte_read						; 0=OC, 1=CC, 2=Gauge, 3=Apnea into WREG and ext_flash_rw 
	decfsz	ext_flash_rw,w							; =1 (CC)? 
	goto	display_profile2						; no 

	rcall	log_details_header						; shows number, time/date and basic dive info
	; Setpoint list
	LOG_POINT_TO log_sp1
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

	rcall	logbook_preloop_tasks					; clear timeout, some flags and set to Speed_eco
display_details3_loop:
	btfsc	switch_right							; right button pressed?
	goto	display_profile2						; YES - show the profile view again
	btfsc	switch_left								; left button pressed?
	bra		exit_profileview						; YES - back to list
	call	housekeeping							; NO to both - handle screen dump request, timeout and entering dive mode
	bra		display_details3_loop					;            - loop waiting for something to do


log_details_header:
	call	TFT_boot

; Set ext_flash pointer to "#divenumber-oldest" dive
; compute read_int_eeprom .2 - divenumber
; read required header data for profile display
; look in header for pointer to begin of diveprofile (byte 2-4)
; Set pointer (ext_flash_log_pointer:3) to this address, start drawing

	decf	divenumber,F							; -1
	read_int_eeprom .2
	movf	EEDATA,W
	bcf		STATUS,C
	subfwb	divenumber,W							; max. dives (low value) - dive number
	movwf	lo										; result
	incf	divenumber,F							; +1
	; Set ext_flash_address:3 to TOC entry of this dive
	; 1st: 200000h-200FFFh -> lo=0
	; 2nd: 201000h-201FFFh -> lo=1
	; 3rd: 202000h-202FFFh -> lo=2
	; 256: 2FF000h-2FFFFFh -> lo=255 (And hi>0...)
	clrf	ext_flash_address+0
	clrf	ext_flash_address+1
	movlw	0x20
	movwf	ext_flash_address+2
	movlw	.16
	mulwf	lo										; lo*16 = offset to 0x2000 (up:hi)
	movf	PRODL,W
	addwf	ext_flash_address+1,F
	movf	PRODH,W
	addwfc	ext_flash_address+2,F
	; pointer at the first 0xFA of header
	rcall	logbook_show_divenumber					; show the dive number in medium font
	; Show date and time in first row
	WIN_SMALL .59,.10
	LOG_POINT_TO log_date
	call	ext_flash_byte_read_plus
	movff	ext_flash_rw,up							; year
	call	ext_flash_byte_read_plus
	movff	ext_flash_rw,hi							; month
	call	ext_flash_byte_read_plus
	movff	ext_flash_rw,lo							; day
	call	TFT_convert_date						; converts into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in postinc2
	PUTC	"-"
	call	ext_flash_byte_read_plus				; hour
	movff	ext_flash_rw,lo
	call	ext_flash_byte_read_plus				; minutes
	movff	ext_flash_rw,hi
	output_99x										; hour
	PUTC	':'
	movff	hi,lo
	output_99x										; minute
	STRCAT_PRINT ""									; display 1st row of details

	; Show max depth and dive time
	WIN_SMALL .5,.35
	STRCAT	"Max:"
	LOG_POINT_TO log_max_depth
	call	ext_flash_byte_read_plus				; read max depth
	movff	ext_flash_rw,lo
	call	ext_flash_byte_read_plus				; read max depth
	movff	ext_flash_rw,hi

	TSTOSS	opt_units								; 0=Meters, 1=Feets
	bra		logbook_page2_depth_metric				; 1 - do metric
													; 0 - do imperial
	call	convert_mbar_to_feet					; convert value in lo:hi from mbar to feet
	PUTC	' '
	bcf		leftbind
	output_16_3
	STRCAT_TEXT tFeets
	bra		logbook_page2_depth_common

logbook_page2_depth_metric:
	bsf		leftbind
	output_16dp d'3'								; max. depth
	STRCAT_TEXT tMeters

logbook_page2_depth_common:
	STRCAT	" - "
	call	ext_flash_byte_read_plus				; dive time in minutes
	movff	ext_flash_rw,lo
	call	ext_flash_byte_read_plus
	movff	ext_flash_rw,hi							; dive time in minutes

	bsf		leftbind
	output_16										; dive time minutes
	PUTC	"m"
	LOG_POINT_TO log_divetime+.2
	call	ext_flash_byte_read_plus				; read dive time seconds
	movff	ext_flash_rw,lo
	bsf		leftbind
	output_99x										; dive time seconds
	call	TFT_standard_color
	STRCAT_PRINT "s"
;	; Dive mode
;	LOG_POINT_TO log_divemode
;	call	ext_flash_byte_read_plus				; read dive mode
;	movff	ext_flash_rw,lo
;	call	TFT_decotype_logbook					; "strcat_print"s dive mode (OC, CC, APNEA or GAUGE)
	return

; ----------------------------------------------------------------

log_show_sp:
	lfsr	FSR2,buffer
	call	ext_flash_byte_read_plus				; read setpoint
	movff	ext_flash_rw,lo
	clrf	hi
	bsf		leftbind
	output_16dp d'3'
	bcf		leftbind
	STRCAT_TEXT tbar
	PUTC	" "
	call	ext_flash_byte_read_plus				; change depth
	movff	ext_flash_rw,lo

	TSTOSS	opt_units								; 0=Meter, 1=Feet
	bra		log_show_sp_metric						; 0 - do metric
	movf	lo,W									; 1 - do imperial
	mullw	.100									; convert meters to mbar
	MOVII	PROD,mpr
	call	convert_mbar_to_feet					; convert value in lo:hi from mbar to feet
	output_16_3
	PUTC	" "
	STRCAT_TEXT tFeets								; "ft"
	bra		log_show_sp_common
log_show_sp_metric:
	output_8
	PUTC	" "
	STRCAT_TEXT tMeters								; "m"
log_show_sp_common:
	STRCAT_PRINT ""
	return


log_show_gas:										; show gas data
	call	TFT_color_code_gas						; color the output (gas number is in WREG)
	lfsr	FSR2,buffer
	call	ext_flash_byte_read_plus				; read gas O2 fraction
	movff	ext_flash_rw,lo
	call	ext_flash_byte_read_plus				; read gas He fraction
	movff	ext_flash_rw,hi
	call	gaslist_show_mix						; put "Nxlo", "Txlo/hi", "Air" or "O2" into Postinc2
	call	ext_flash_byte_read_plus				; read change depth
	movff	ext_flash_rw,up
	call	ext_flash_byte_read_plus				; read gas type - just to increment the pointer
	movff	ext_flash_rw,ex

	btfsc	log_show_gas_short						; shall we do the short version?
	bra		log_show_gas_common						; YES
													; NO  - do the long version
	PUTC	" "										; put one space between gas composition and gas type marking
	tstfsz	ex										; gas disabled?
	bra		log_show_gas_1							; NO  - next check
	PUTC	"x"										; YES - mark with "x"
	bra		log_show_gas_4							;     - continue with change depth
log_show_gas_1:
	decfsz	ex,F									; now: -1 disabled, 0 first, 1 travel, 2 deco -> first?
	bra		log_show_gas_2							; NO  - next check
	PUTC	"*"										; YES - mark with "*"
	bra		log_show_gas_4							;     - continue with change depth
log_show_gas_2:
	decf	ex,F									; now: -2 disabled, -1 first,  0 travel, 1 deco
	decfsz	ex,F									; now: -3 disabled, -2 first, -1 travel, 0 deco -> deco?
	bra		log_show_gas_3							; NO  - nothing to mark
	PUTC	"="										; YES - mark with "="
	bra		log_show_gas_4							;     - continue with change depth
log_show_gas_3:
	PUTC	" "										; print a space in absence of any other marking
log_show_gas_4:
	PUTC	" "										; put one space between gas type marking and change depth
	TSTOSS	opt_units								; 0=Meter, 1=Feet
	bra		log_show_gas_metric						; 0 - do metric
	movf	up,W									; 1 - do imperial
	mullw	.100									; convert meters to mbar
	MOVII	PROD,mpr
	call	convert_mbar_to_feet					; convert value in lo:hi from mbar to feet
	output_16_3										; limit to 999 and display only 0-999
	STRCAT_TEXT tFeets								; "ft"
	bra		log_show_gas_common
log_show_gas_metric:
	movff	up,lo
	output_8
	STRCAT_TEXT tMeters								; "m"
log_show_gas_common:
	STRCAT_PRINT ""
	return


log_compute_divenumber:
	movwf	mpr+2									; store current dive number to mpr+2
	call	do_logoffset_common_read				; read log offset into mpr
	; check if offset = 0
	tstfsz	mpr+0									; mpr+0 (low  byte) = 0 ?
	bra		log_compute_divenumber_2				; NO - apply offset
	tstfsz	mpr+1									; mpr+1 (high byte) = 0 ?
	bra		log_compute_divenumber_2				; NO - apply offset
log_compute_divenumber_1:							; YES to both - no offset
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

; ----------------------------------------------------------------

	END