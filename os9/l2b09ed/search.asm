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
find_fwd            ldy       <base
                    leay      fstr,y
                    lbsr      strlen
                    stb       <flen
                    lbeq      ff_no
                    ldx       <base
                    lda       fstr,x
                    bsr       fold
                    sta       <fch
                    ldd       <cpos
                    std       <wp
                    ldd       <cpos+2
                    std       <wp+2
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
                    ldd       <tmpc
                    addd      #1
                    std       <tmpc
                    bra       ff_s1
ff_s2               bsr       fold
                    cmpa      <fch
                    bne       ff_s1
                    tfr       u,d                 a candidate: its offset
                    subd      <fbuf
                    subd      #1
                    std       <wp+2
                    bsr       ff_match
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
                    ldu       <base
                    leau      cpos,u
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
                    ldy       <base
                    leay      inbuf,y
                    lbsr      strcpy
                    leax      findtl,pcr
                    lbsr      dlg_inp
                    bcs       cfd9
                    ldx       <base
                    leax      inbuf,x
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

* c_repl: find and replace, asking at each match (Y, N, A = all, Esc)
c_repl              ldx       <base
                    leax      fstr,x
                    ldy       <base
                    leay      inbuf,y
                    lbsr      strcpy
                    leax      repltl,pcr
                    lbsr      dlg_inp
                    lbcs      crp9
                    ldx       <base
                    leax      inbuf,x
                    ldy       <base
                    leay      fstr,y
                    lbsr      strcpy
                    tst       ,y
                    lbeq      crp9
                    ldx       <base
                    leax      rstr,x
                    ldy       <base
                    leay      inbuf,y
                    lbsr      strcpy
                    leax      withtl,pcr
                    lbsr      dlg_inp
                    lbcs      crp9
                    ldx       <base
                    leax      inbuf,x
                    ldy       <base
                    leay      rstr,y
                    lbsr      strcpy
                    ldd       #0
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
crp_done            ldx       <base               "<n> replaced"
                    leax      mbuf,x
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
