********************************************************************
* search - find and replace
*
* Searches go forward from the cursor and do not wrap.  Letters match
* either case unless Options > Match case is on.  The page buffers are
* scanned directly for the first character; only a candidate is
* compared a character at a time (and may run into the next page).

* fold: A in upper case, unless the search matches case
fold                tst       <fcase
                    bne       fo9
                    cmpa      #'a
                    blo       fo9
                    cmpa      #'z
                    bhi       fo9
                    suba      #$20
fo9                 rts

* strcpy: the string at X (ending in 0) to Y
strcpy              pshs      a,x,y
scp1                lda       ,x+
                    sta       ,y+
                    bne       scp1
                    puls      a,x,y,pc

* find_fwd: find fstr from the cursor on.  The match becomes the
* selection, with the cursor at its end.  Carry if there is none.
find_fwd            lbsr      ff_init
                    lbeq      ff_no
                    lbsr      cp_wp
                    ldd       #0
                    std       <tmpc               carriage returns passed
ff_page             ldx       <wp
                    lbsr      pg_map
                    sty       <fbuf
                    ldd       DS.USED,x
                    leau      d,y
                    stu       <fend
                    ldd       <wp+2
                    leau      d,y
ff_s1               cmpu      <fend
                    bhs       ff_next
                    lda       ,u+
                    cmpa      #C$CR
                    bne       ff_s2
                    lbsr      tmpc_inc
                    bra       ff_s1
ff_s2               bsr       fold
                    cmpa      <fch
                    bne       ff_s1
                    tfr       u,d                 a candidate: its offset
                    subd      <fbuf
                    subd      #1
                    std       <wp+2
                    lbsr      ff_match
                    bcc       ff_found
                    ldd       <wp+2               no: scan on after it
                    addd      #1
                    std       <wp+2
                    bra       ff_page
ff_next             ldx       <wp
                    ldx       DS.NEXT,x
                    beq       ff_no
                    stx       <wp
                    ldd       #0
                    std       <wp+2
                    bra       ff_page
ff_found            ldd       <wp                 anchor at the start, cursor at the end
                    std       <cpos
                    std       <apos
                    ldd       <wp+2
                    std       <cpos+2
                    std       <apos+2
                    ldd       <curline
                    addd      <tmpc
                    std       <curline
                    std       <aline
                    lbsr      a_cpos
                    lbsr      p_col
                    std       <acol
                    lda       #1
                    sta       <selon
                    ldd       <fpos
                    std       <cpos
                    ldd       <fpos+2
                    std       <cpos+2
                    lbsr      p_col
                    std       <curcol
                    lbsr      rd_all
                    andcc     #^Carry
                    rts
ff_no               orcc      #Carry
                    rts

* ff_init: flen and fch for fstr; Z if it is empty
ff_init             ldy       <base
                    leay      fstr,y
                    lbsr      strlen
                    stb       <flen
                    beq       fi9
                    ldx       <base
                    lda       fstr,x
                    lbsr      fold
                    sta       <fch
                    andcc     #^Zero
fi9                 rts

* find_bwd: find fstr before the cursor, or before the selection's start
* (so a match found last time is passed over), going back.  As
* find_fwd, the match becomes the selection.  Carry if there is none.
find_bwd            bsr       ff_init
                    beq       ff_no
                    lbsr      cp_wp               from the cursor,
                    ldd       <curline
                    tst       <selon
                    beq       fb0
                    lbsr      sel_order
                    bcc       fb0
                    ldd       <apos               or the anchor if it comes first
                    std       <wp
                    ldd       <apos+2
                    std       <wp+2
                    ldd       <aline
fb0                 pshs      d                   the line it starts in
                    ldd       #0
                    std       <tmpc               carriage returns passed
fb_page             ldx       <wp
                    lbsr      pg_map
                    sty       <fbuf
fb_s1               ldd       <wp+2               the character before wp
                    beq       fb_prev
                    subd      #1
                    std       <wp+2
                    ldu       <fbuf
                    lda       d,u
                    cmpa      #C$CR
                    bne       fb_s2
                    lbsr      tmpc_inc
                    bra       fb_s1
fb_s2               lbsr      fold
                    cmpa      <fch
                    bne       fb_s1
                    bsr       ff_match
                    bcc       fb_found
                    bra       fb_page             (ff_match may have mapped others)
fb_prev             ldx       <wp
                    ldx       DS.PREV,x
                    beq       fb_no
                    stx       <wp
                    ldd       DS.USED,x
                    std       <wp+2
                    bra       fb_page
fb_found            puls      d
                    subd      <tmpc
                    std       <curline
                    ldd       #0
                    std       <tmpc
                    lbra      ff_found
fb_no               leas      2,s
                    orcc      #Carry
                    rts

* ff_match: does fstr match at wp?  fpos = the end of the match.
ff_match            ldd       <wp
                    std       <fpos
                    ldd       <wp+2
                    std       <fpos+2
                    ldu       <base
                    leau      fpos,u
                    ldx       <base
                    leax      fstr,x
                    ldb       <flen
fm1                 lbsr      p_char
                    bcs       fm_no
                    lbsr      fold
                    pshs      a
                    lda       ,x+
                    lbsr      fold
                    cmpa      ,s+
                    bne       fm_no
                    lbsr      p_next
                    decb
                    bne       fm1
                    andcc     #^Carry
                    rts
fm_no               orcc      #Carry
                    rts

* c_find: ask for the text, then find it
c_find              ldx       <base
                    leax      fstr,x
                    lbsr      a_inby
                    lbsr      strcpy
                    leax      findtl,pcr
                    lbsr      dlg_inp
                    bcs       cfd9
                    lbsr      a_inbx
                    ldy       <base
                    leay      fstr,y
                    lbsr      strcpy
                    tst       ,y
                    beq       cfd9
                    bra       cfn1

* c_fnext: find the same text again
c_fnext             ldx       <base
                    tst       fstr,x
                    beq       c_find
cfn1                lbsr      find_fwd
                    bcc       cfd9
                    leax      nfmsg,pcr
                    stx       <msgp
cfd9                rts

* c_fprev: find the same text again, going back
c_fprev             ldx       <base
                    tst       fstr,x
                    beq       c_find
                    lbsr      find_bwd
                    bcc       cfp9
                    leax      nfmsg,pcr
                    stx       <msgp
cfp9                rts

* c_repl: find and replace, asking at each match (Y, N, A = all, Esc)
c_repl              ldx       <base
                    leax      fstr,x
                    lbsr      a_inby
                    lbsr      strcpy
                    leax      repltl,pcr
                    lbsr      dlg_inp
                    lbcs      crp9
                    lbsr      a_inbx
                    ldy       <base
                    leay      fstr,y
                    lbsr      strcpy
                    tst       ,y
                    lbeq      crp9
                    ldx       <base
                    leax      rstr,x
                    lbsr      a_inby
                    lbsr      strcpy
                    leax      withtl,pcr
                    lbsr      dlg_inp
                    bcs       crp9
                    lbsr      a_inbx
                    ldy       <base
                    leay      rstr,y
                    lbsr      strcpy
                    clra
                    clrb
                    std       <frep
                    clr       <fall
crp1                lbsr      find_fwd
                    bcs       crp_done
                    tst       <fall
                    bne       crp_do
crp2                leax      replq,pcr           ask on the hint line
                    stx       <msgp
                    lbsr      v_fix
                    lbsr      v_draw
                    lbsr      getkey
                    ldx       #0
                    stx       <msgp
                    cmpa      #EK.ESC
                    beq       crp_done
                    cmpa      #EK.EOF
                    beq       crp_done
                    anda      #$DF
                    cmpa      #'N
                    beq       crp1
                    cmpa      #'Y
                    beq       crp_do
                    cmpa      #'A
                    bne       crp2
                    inc       <fall
crp_do              lbsr      sel_del
                    ldx       <base
                    leax      rstr,x
crp3                lda       ,x+
                    beq       crp4
                    lbsr      ed_ins
                    bcc       crp3
                    lbsr      c_full
                    bra       crp_done
crp4                ldd       <frep
                    addd      #1
                    std       <frep
                    bra       crp1
crp_done            lbsr      a_mbuf              "<n> replaced"
                    stx       <msgp
                    ldd       <frep
                    lbsr      n_dec
                    leay      repdm,pcr
                    lbsr      s_str
                    clr       ,x
                    lbra      rd_all
crp9                rts

* c_mcase: Options > Match case
c_mcase             com       <fcase
                    leax      mcon,pcr
                    tst       <fcase
                    bne       cmc1
                    leax      mcoff,pcr
cmc1                stx       <msgp
                    rts

findtl              fcn       "Find"
repltl              fcn       "Replace: find"
withtl              fcn       "Replace with"
nfmsg               fcn       "Not found"
replq               fcn       "Replace this one?  Y = yes  N = no  A = all  Esc = stop"
repdm               fcn       " replaced"
mcon                fcn       "Match case on"
mcoff               fcn       "Match case off"
