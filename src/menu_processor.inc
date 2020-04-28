;=============================================================================
;
;   File menu_processor.inc                 * combined next generation V3.09.5
;
;   Routines to handle all OSTC graphic/text menus.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-05-30 : [jDG] Creation.



; Menu Parameters
; NOTE: needs to be identical in .inc and .asm files!
;
#define MENU_LINES_MAX_SURF	.7			; max number of lines per screen
#define MENU_LINES_MAX_DIVE	.6			; max number of lines per dive mode menu
#define MENU_HEIGHT_SURF	.27			; spacing between menu items in surface mode (pixel)
#define MENU_VCENTER		.125		; vertical center position of menu items


; Menu Processor Functions
;
	extern	menu_processor_reset		; push current  menu item (cursor position) to   the stack
	extern	menu_processor_pop			; pull current  menu item (cursor position) from the stack
	extern	menu_processor_double_pop	; pull previous menu item (cursor position) from the stack


; Encoding Format for Menu Item Types
;
; 1st word with code1  2nd word with code2  item_type  Type           Functionality
; ------------------------------------------------------------------------------------------------------------------------
; tttt tttt tttt ttt0  cccc cccc cccc ccc0      0      MENU_DYNAMIC   Call Item with dynamic Title
; ~--~ tttt tttt ttt1  cccc cccc cccc ccc0      1      MENU_CALL      Call Item with fixed   Title (multi-lingual)
; ~--~ tttt tttt ttt1  ~000 cccc cccc ccc1      2      MENU_OPT_INC   Option Increment with fixed multi-lingual Title
; ~--~ tttt tttt ttt1  ~001 cccc cccc ccc1      2      MENU_OPT_INCS  as before, but stops at max value
; ~--~ tttt tttt ttt1  ~011 cccc cccc ccc1      2      MENU_OPT_DECS  as before, but decrement (only stop at min avail)
; ~--~ tttt tttt ttt1  ~100 cccc cccc ccc1      2      MENU_GRP_INC   Option Increment for an Option out of an Option Group
; ~--~ tttt tttt ttt1  ~101 cccc cccc ccc1      2      MENU_GRP_INCS  as before, but stops at max value
; ~--~ tttt tttt ttt1  ~111 cccc cccc ccc1      2      MENU_GRP_DECS  as before, but decrement (only stop at min avail)
;
;  t : Address Bits: title_func_addr or title_text_addr   |     Attention: title_func_addr and
;  c : Address Bits: item_func_addr  or option_addr       | item_func_addr must be within 0x0xxxx
;  - : unused, reads as zero
;  ~ : unused, reads as one (part of the real program memory address shining through)
; 0/1: fixed Bit Values making up Menu Item Type Encoding



;-----------------------------------------------------------------------------
; Open a Dive Mode Menu Block
;
; nb_items         number of menu items that will follow
;
MENU_BEGIN_DIVE	MACRO nb_items

items_target set nb_items
items_count  set 0

	; check number of menu items
	IF nb_items <= 0
		Error "Zero items in menu ", x
	ENDIF
	IF nb_items > MENU_LINES_MAX_DIVE
			Error "too many items in menu", x
	ENDIF

	; store code for menu execution
	extern	menu_processor
	call	menu_processor

	; store menu header data
	db	nb_items,				0x00					; number of items, encoding for no menu titel

	ENDM


;-----------------------------------------------------------------------------
; Open a Surface Mode Menu Block with leading empty Item Lines
;
; title_text_addr  address of multi-lingual menu title text
; offset           number of empty  menu items to  start with
; nb_items         number of active menu items that will follow
;
MENU_BEGIN_OFFSET	MACRO title_text_addr, nb_items, offset

items_target set nb_items
items_count  set 0

	; check number of menu items
	IF nb_items <= 0
		Error "Zero items in menu ", x
	ENDIF
	IFNDEF scrolling_menu_enabled
		IF (nb_items + offset) > MENU_LINES_MAX_SURF
			Error "too many items in menu", x
		ENDIF
	ENDIF

	; compute vertical start position of 1st menu item
	IF nb_items > MENU_LINES_MAX_SURF
		local	vertical_start_pos = ( MENU_VCENTER - (MENU_HEIGHT_SURF/2) * MENU_LINES_MAX_SURF )
	ELSE
		local	vertical_start_pos = ( MENU_VCENTER - (MENU_HEIGHT_SURF/2) * nb_items ) + (MENU_HEIGHT_SURF/2 * offset)
	ENDIF

	; store code for menu execution
	extern	title_text_addr			; 2 byte address of multi-lingual title text
	extern	menu_processor
	call	menu_processor

	; store menu header data
	db	nb_items,				vertical_start_pos		; number  of items, vertical start position 1st item
	db	low(title_text_addr),	high(title_text_addr)	; address of multi-lingual title text

	ENDM



;-----------------------------------------------------------------------------
; Open a Surface Mode Menu Block
;
; title_text_addr  address of multi-lingual menu title text
; nb_items         number of active   menu items that will follow
;
MENU_BEGIN		MACRO title_text_addr, nb_items
	MENU_BEGIN_OFFSET	title_text_addr, nb_items,0
	endm


;-----------------------------------------------------------------------------
; Call Item with dynamic Title
;
; title_func_addr  address of the function to generate   the line title
; item_func_addr   address of the function to be executed on line selection
;
MENU_DYNAMIC	MACRO title_func_addr, item_func_addr

items_count set items_count+1

	;extern	title_func_addr		; 2 byte address of dynamic title function
	;extern	item_func_addr		; 2 byte address of item function

	local	code1 = 0x0000		; dynamic title
	local	code2 = 0x0000		; call function

	db	low(title_func_addr + code1), high(title_func_addr + code1)
	db	low(item_func_addr  + code2), high(item_func_addr  + code2)

	ENDM


;-----------------------------------------------------------------------------
; Call Item with fixed multi-lingual Title
;
; title_text_addr  address of multi-lingual item text
; item_func_addr   address of the function to be executed on line selection
;
MENU_CALL		MACRO title_text_addr, item_func_addr

items_count set items_count+1

	extern	title_text_addr		; 2 byte address of multi-lingual title text
	;extern	item_func_addr		; 2 byte address of item function

	local	code1 = 0x0001		; static multi-lingual title
	local	code2 = 0x0000		; call function

	db	low(title_text_addr + code1), high(title_text_addr + code1)
	db	low(item_func_addr  + code2), high(item_func_addr  + code2)

	ENDM


;-----------------------------------------------------------------------------
; Option Increment Item with fixed multi-lingual Title, wrap-around after max
;
; title_text_addr  address of multi-lingual item text
; option_addr      address of option to be incremented on line selection
;
MENU_OPT_INC	MACRO title_text_addr, option_addr

items_count set items_count+1

	extern	title_text_addr		; 2 byte address of multi-lingual title text
	extern	option_addr			; 2 byte address of option definition data

	local	code1 = 0x0001		; static multi-lingual title
	local	code2 = 0x0001		; option increment with wrap-around after max

	db	low(title_text_addr + code1), high(title_text_addr + code1)
	db	low(option_addr     + code2), high(option_addr     + code2)

	ENDM


;-----------------------------------------------------------------------------
; Option Increment Item with fixed multi-lingual Title, stop at max value
;
; title_text_addr  address of multi-lingual item text
; option_addr      address of option to be incremented on line selection
;
MENU_OPT_INCS	MACRO title_text_addr, option_addr

items_count set items_count+1

	extern	title_text_addr		; 2 byte address of multi-lingual title text
	extern	option_addr			; 2 byte address of option definition data

	local	code1 = 0x0001		; static multi-lingual title
	local	code2 = 0x1001		; option increment with stop at max value

	db	low(title_text_addr + code1), high(title_text_addr + code1)
	db	low(option_addr     + code2), high(option_addr     + code2)

	ENDM


;-----------------------------------------------------------------------------
; Option Increment Item for an Option out of an Option Group, with fixed multi-lingual Title
;
; title_text_addr  address of multi-lingual item text
; option_addr      base address of the option group
; gaslist_gas      offset of the selected option to be incremented within the group (normal variable)
;
MENU_GRP_INC	MACRO title_text_addr, option_addr

items_count set items_count+1

	extern	title_text_addr		; 2 byte address of multi-lingual title text
	extern	option_addr			; 2 byte address of option definition data

	local	code1 = 0x0001		; static multi-lingual title
	local	code2 = 0x4001		; option increment, group member, wrap-around after max value

	db	low(title_text_addr + code1), high(title_text_addr + code1)
	db	low(option_addr     + code2), high(option_addr     + code2)

	ENDM


;-----------------------------------------------------------------------------
; Option Increment Item for an Option out of an Option Group, with fixed multi-lingual Title
;
; title_text_addr  address of multi-lingual item text
; option_addr      base address of the option group
; gaslist_gas      offset of the selected option to be incremented within the group (normal variable)
;
MENU_GRP_INCS	MACRO title_text_addr, option_addr

items_count set items_count+1

	extern	title_text_addr		; 2 byte address of multi-lingual title text
	extern	option_addr			; 2 byte address of option definition data

	local	code1 = 0x0001		; static multi-lingual title
	local	code2 = 0x5001		; option increment, group member, stop at max value

	db	low(title_text_addr + code1), high(title_text_addr + code1)
	db	low(option_addr     + code2), high(option_addr     + code2)

	ENDM


;-----------------------------------------------------------------------------
; Option Decrement Item with fixed multi-lingual Title, stop at min value
;
; title_text_addr  address of multi-lingual item text
; option_addr      address of option to be incremented on line selection
;
MENU_OPT_DECS	MACRO title_text_addr, option_addr

items_count set items_count+1

	extern	title_text_addr		; 2 byte address of multi-lingual title text
	extern	option_addr			; 2 byte address of option definition data

	local	code1 = 0x0001		; static multi-lingual title
	local	code2 = 0x3001		; option decrement, stop at min value

	db	low(title_text_addr + code1), high(title_text_addr + code1)
	db	low(option_addr     + code2), high(option_addr     + code2)

	ENDM


;-----------------------------------------------------------------------------
; Option Decrement Item for an Option out of an Option Group, with fixed multi-lingual Title
;
; title_text_addr  address of multi-lingual item text
; option_addr      base address of the option group
; gaslist_gas      offset of the selected option to be decremented within the group (normal variable)
;
MENU_GRP_DECS	MACRO title_text_addr, option_addr

items_count set items_count+1

	extern	title_text_addr		; 2 byte address of multi-lingual title text
	extern	option_addr			; 2 byte address of option definition data

	local	code1 = 0x0001		; static multi-lingual title
	local	code2 = 0x7001		; option decrement, group member, stop at min value

	db	low(title_text_addr + code1), high(title_text_addr + code1)
	db	low(option_addr     + code2), high(option_addr     + code2)

	ENDM


;-----------------------------------------------------------------------------
; Close a Menu Block
;
MENU_END	MACRO

	IF items_count != items_target
		Error "menu items count mismatch", x
	ENDIF

	ENDM


;-----------------------------------------------------------------------------

