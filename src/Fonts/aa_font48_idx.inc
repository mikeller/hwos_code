;==========================================================================
; Font index exported So Nov 24 2019 by FontIO.cpp,
; v 43ff8ad28dae 2018/04/17 16:52:12 jDG   combined next generation V3.08.3
;==========================================================================
aa_font48_chars     EQU .20
aa_font48_firstChar EQU .44
aa_font48_lastChar  EQU .63
;
aa_font48_idx:
    DW    aa_font48_bits + 0x0000    ; 2C   space,         half-width, access by ,
    DW    aa_font48_bits + 0x0003    ; 2D - minus,         half-width
    DW    aa_font48_bits + 0x001C    ; 2E . dot,           half-width
    DW    aa_font48_bits + 0x002F    ; 2F | vertical line, half-width, access by |
    DW    aa_font48_bits + 0x0035    ; 30 0
    DW    aa_font48_bits + 0x00BE    ; 31 1
    DW    aa_font48_bits + 0x0108    ; 32 2
    DW    aa_font48_bits + 0x0191    ; 33 3
    DW    aa_font48_bits + 0x021F    ; 34 4
    DW    aa_font48_bits + 0x027B    ; 35 5
    DW    aa_font48_bits + 0x02ED    ; 36 6
    DW    aa_font48_bits + 0x039A    ; 37 7
    DW    aa_font48_bits + 0x0406    ; 38 8
    DW    aa_font48_bits + 0x04C6    ; 39 9
    DW    aa_font48_bits + 0x0572    ; 3A : colon,          half-width
    DW    aa_font48_bits + 0x059D    ; 3B ' inverted comma, half-width
    DW    aa_font48_bits + 0x05C0    ; 3C "
    DW    aa_font48_bits + 0x05F4    ; 3D m
    DW    aa_font48_bits + 0x0645    ; 3E ft-ligature
    DW    aa_font48_bits + 0x06E9    ; 3F space,            full-width
    DW    aa_font48_bits + 0x06EF    ; END OF INDEX
