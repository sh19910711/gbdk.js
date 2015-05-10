; font.ms
;
;	Michael Hope, 1999
;	michaelh@earthling.net
;	Distrubuted under the Artistic License - see www.opensource.org
;
	.include        "global.mh"
	INCLUDE		"wait_hbl.mh"

	.globl  .copy_vram
	.globl	.cr_curs
	.globl	.adv_curs
	.globl	.cury, .curx
	.globl	.display_off

	; Structure offsets
	sfont_handle_sizeof	=	3
	sfont_handle_font	=	1
	sfont_handle_first_tile	=	0

	FONT_256ENCODING	=	0
	FONT_128ENCODING	=	1
	FONT_NOENCODING		=	2

	FONT_BCOMPRESSED	=	2
	
	FONT_BMODE_NOSCROLL	=	0
	FONT_BMODE_NOINTERP	=	1

	.M_NO_SCROLL	= 0x04	; Disables scrolling of the screen in text mode

	.CR     		= 	0x0A          ; Unix
	.MAX_FONTS		= 	6

	.module font.ms

	; Globals from drawing.s
	; FIXME: Hmmm... check the linkage of these
	.globl	.fg_colour
	.globl	.bg_colour

	.area	_BSS
font_current::
	.ds	font_handle_sizeof

font_first_free_tile::
	.ds	1
.font_temp:
	.ds	1
_font_mode::
font_mode::
	.ds	1
.font_table::
	.ds	font_handle_sizeof*.MAX_FONTS
	
	.area   _CODE

	; Copy uncompressed 16 byte tiles from (BC) to (HL), length = DE*2
	; Note: HL must be aligned on a UWORD boundry
font_copy_uncompressed::
	ld	a,d
	or	e
	ret	z

	ld	a,h
	cp	#0x98
	jr	c,4$
	sub	#0x98-0x88
	ld	h,a
4$:
	xor	a
	cp	e		; Special for when e=0 you will get another loop
	jr	nz,1$
	dec	d
1$:
	WAIT_HBL
	ld	a,(bc)
	ld	(hl+),a
	inc	bc
	
	WAIT_HBL
	ld	a,(bc)
	ld	(hl),a
	inc	bc

	inc	l
	jr	nz,2$
	inc	h
	ld	a,h		; Special wrap-around
	cp	#0x98
	jr	nz,2$
	ld	h,#0x88
2$:
	dec	e
	jr	nz,1$
	dec	d
	bit	7,d		; -1?
	jr	z,1$
	ret

	; Copy a set of compressed (8 bytes/cell) tiles to VRAM
	; Sets the foreground and background colours based on the current
	; font colours
	; Entry:
	;	From (BC) to (HL), length (DE) where DE = #cells * 8
	;	Uses the current fg_colour and bg_colour fields
font_copy_compressed::
	ld	a,d
	or	e
	ret	z		; Do nothing

	ld	a,h
	cp	#0x98		; Take care of the 97FF -> 8800 wrap around
	jr	c,font_copy_compressed_loop
	sub	#0x98-0x88
	ld	h,a
font_copy_compressed_loop:
	ld	a,(bc)
	inc	bc
	push	bc
	ld	b,a		; B and C are the two bytes that make up the colour
	ld	c,a
	ld	a,(.fg_colour)
	bit	0,a
	jr	nz,font_copy_compressed_grey1
	ld	b,#0
font_copy_compressed_grey1:
	bit	1,a
	jr	nz,font_copy_compressed_grey2
	ld	c,#0
font_copy_compressed_grey2:
	ld	a,(.bg_colour)
	bit	0,a
	jr	z,font_copy_compressed_bg_grey1
	ld	a,#0xFF		; XOR to change the BG colour only
	xor	b
	ld	b,a
	ld	a,(.bg_colour)
font_copy_compressed__bg_grey1:
	bit	1,a
	jr	z,font_copy_compressed_bg_grey2
	ld	a,#0xFF
	xor	c
	ld	c,a
font_copy_compressed__bg_grey2:
	WAIT_HBL
	ld	(hl),b
	inc	hl
	WAIT_HBL
	ld	(hl),c
	inc	hl
	ld	a,h		; Take care of the 97FFF -> 8800 wrap around
	cp	#0x98
	jr	nz,1$
	ld	h,#0x88
1$:
	pop	bc
	dec	de
	ld	a,d
	or	e
	jr	nz,font_copy_compressed_loop
	ret
	
; Load the font HL
font_load::
	call	.display_off
	push	hl

	; Find the first free font entry
	ld	hl,#.font_table+font_handle_font
	ld	b,#.MAX_FONTS
font_load_find:
	ld	a,(hl)		; Check to see if this entry is free
	inc	hl		; Free is 0000 for the font pointer
	or	(hl)
	cp	#0
	jr	z,font_load_found

	inc	hl
	inc	hl
	dec	b
	jr	nz,font_load_find
	pop	hl
	ld	hl,#0
	jr	font_load_exit	; Couldn't find a free space
font_load_found:
				; HL points to the end of the free font table entry
	pop	de
	ld	(hl),d		; Copy across the font struct pointer
	dec	hl
	ld	(hl),e

	ld	a,(font_first_free_tile)
	dec	hl
	ld	(hl),a		

	push	hl
	call	font_set	; Set this new font to be the default
	
	; Only copy the tiles in if were in text mode
	ld	a,(.mode)
	and	#.T_MODE
	
	call	nz,font_copy_current

				; Increase the 'first free tile' counter
	ld	hl,#font_current+sfont_handle_font
	ld	a,(hl+)
	ld	h,(hl)
	ld	l,a

	inc	hl		; Number of tiles used
	ld	a,(font_first_free_tile)
	add	a,(hl)
	ld	(font_first_free_tile),a

	pop	hl		; Return font setup in HL
font_load_exit:
	;; Turn the screen on
	LDH     A,(.LCDC)
	OR      #0b10000001     ; LCD           = On
				; BG            = On
	AND     #0b11100111     ; BG Chr        = 0x8800
				; BG Bank       = 0x9800
	LDH     (.LCDC),A

	RET

	; Copy the tiles from the current font into VRAM
font_copy_current::	
				; Find the current font data
	ld	hl,#font_current+sfont_handle_font
	ld	a,(hl+)
	ld	h,(hl)
	ld	l,a

	inc	hl		; Points to the 'tiles required' entry
	ld	e,(hl)
	ld	d,#0
	rl	e		; Multiple DE by 8
	rl	d
	rl	e
	rl	d
	rl	e
	rl	d		; DE has the length of the tile data
	dec	hl

	ld	a,(hl)		; Get the flags
	push	af		
	and	#3			; Only lower 2 bits set encoding table size

	ld	bc,#128
	cp	#FONT_128ENCODING	; 0 for 256 char encoding table, 1 for 128 char
	jr	z,font_copy_current_copy
	ld	bc,#0
	cp	#FONT_NOENCODING
	jr	z,font_copy_current_copy
	ld	bc,#256			; Must be 256 element encoding
font_copy_current_copy:
	inc	hl
	inc	hl		; Points to the start of the encoding table
	add	hl,bc		
	ld	c,l
	ld	b,h		; BC points to the start of the tile data		

	; Find the offset in VRAM for this font
	ld	a,(font_current+sfont_handle_first_tile)	; First tile used for this font
	ld	l,a		
	ld	h,#0
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl

	ld	a,#0x90		; Tile 0 is at 9000h
	add	a,h
	ld	h,a
				; Is this font compressed?
	pop	af		; Recover flags
	bit	FONT_BCOMPRESSED,a
				; Do the jump in a mildly different way
	jr	z,font_copy_uncompressed
	jr	font_copy_compressed

font_set::
	ld	a,(hl+)
	ld	(font_current),a
	ld	a,(hl+)
	ld	(font_current+1),a
	ld	a,(hl+)
	ld	(font_current+2),a
	ret
	
	;; Print a character with interpretation
.mput_char::
;	CP      #.CR
;	JR      NZ,1$
	jr	1$
	CALL    .cr_curs
	RET
1$:
	CALL    .mset_char
	CALL    .adv_curs
	RET

	;; Print the character in A
.mset_char:
	PUSH    BC
	PUSH    DE
	PUSH    HL
				; Compute which tile maps to this character
	ld	e,a
	ld	hl,#font_current+font_handle_font
	ld	a,(hl+)
	ld	h,(hl)
	ld	l,a
	ld	a,(hl+)
	and	#3
	cp	#FONT_NOENCODING
	jr	z,mset_char_no_encoding
	inc	hl
				; Now at the base of the encoding table
				; E is set above
	ld	d,#0
	add	hl,de
	ld	e,(hl)		; That's the tile!
mset_char_no_encoding:
	ld	a,(font_current+0)
	add	a,e
	ld	e,a

	LD      A,(.cury)       ; Y coordinate
	LD      L,A
	LD      H,#0x00
	ADD     HL,HL
	ADD     HL,HL
	ADD     HL,HL
	ADD     HL,HL
	ADD     HL,HL
	LD      A,(.curx)       ; X coordinate
	LD      C,A
	LD      B,#0x00
	ADD     HL,BC
	LD      BC,#0x9800
	ADD     HL,BC
1$:
	LDH     A,(.STAT)
	AND     #0x02
	JR      NZ,1$
	LD      (HL),E
	POP     HL
	POP     DE
	POP     BC
	RET

_mput_char::
	LDA     HL,2(SP)        ; Skip return address
	LD      A,(HL)          ; A = c
	CALL    .mput_char
	RET

_mset_char::
	push	bc
	LDA     HL,4(SP)        ; Skip return address
	LD      A,(HL)          ; A = c
	CALL    .mset_char
	pop	bc
	RET

_font_load::
	push	bc
	LDA     HL,4(SP)        ; Skip return address and bc
	LD      A,(HL)          ; A = c
	inc	hl
	ld	h,(hl)
	ld	l,a
	call    font_load
	push	hl
	pop	de		; Return in DE
	pop	bc
	RET

_mprint_string::
	push	bc
	LDA     HL,4(SP)        ; Skip return address
	LD      A,(HL)          ; A = c
	inc	hl
	ld	h,(hl)
	ld	l,a
	CALL    .mprint_string
	pop	bc
	RET

_font_set::
	push	bc
	LDA     HL,4(SP)        ; Skip return address
	LD      A,(HL)          ; A = c
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	font_set
	pop	bc
	ld	de,#0		; Always good...
	RET


_font_init::
	push	bc
	.globl	.tmode

	call	.tmode

	; Turn off scrolling
	ld	a,(.mode)
	or	#.M_NO_SCROLL
	ld	(.mode),a

	ld	a,#0		; We use the first tile as a space _always_
	ld	(font_first_free_tile),a

	ld	hl,#.font_table
	ld	b,#font_handle_sizeof*.MAX_FONTS
1$:
	ld	(hl+),a
	dec	b
	jr	nz,1$
	ld	a,#3
	ld	(font_fg_colour),a
	ld	a,#0
	ld	(font_bg_colour),a

	xor	a
	ld	(font_mode),a
	
	call	font_cls
	pop	bc
	ret
	
.mprint_string::
	ld	a,(hl)
	cp	#0
	ret	z
	push	hl
	call	.mput_char
	pop	hl
	inc	hl
	jr	.mprint_string

_print_repeat::
	push	bc
	lda	hl,4(sp)
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	xor	a
	cp	d
	jr	nz,_print_repeat_go
	pop	bc
	ret
_print_repeat_go:
	ld	a,e
	push	de
	call	.mput_char
	pop	de
	dec	d
	jr	nz,_print_repeat_go
	pop	bc
	ret

_mgotoxy::
	lda	hl,2(sp)
	ld	a,(hl+)
	ld	(.curx),a
	ld	a,(hl)
	ld	(.cury),a
	ret

font_cls::
_font_cls::	
	PUSH	DE
	PUSH	HL
	LD	HL,#0x9800
	LD	E,#0x20		; E = height
1$:
	LD	D,#0x20		; D = width
2$:
	WAIT_HBL

	LD	(HL),#0		; Always clear
	INC	HL
	DEC	D
	JR	NZ,2$
	DEC	E
	JR	NZ,1$
	POP	HL
	POP	DE
	RET
