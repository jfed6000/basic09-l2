********************************************************************
* pp - pretty print
*
* Basic09 keeps no source, only I-code, and its LIST decompiles that
* with the keywords in capitals, standard spacing and the control
* structures indented: that was stock Basic09's pretty print.  So
* pretty print makes sure the procedure is loaded as it stands (Make),
* asks l2b09run to "list" it, cleans each line up, and puts the result
* in place of the procedure's lines, the PROCEDURE line included.  The
* body is indented PPIND under PROCEDURE (a line number sits in that
* gutter), except a top-level END, which lines up with PROCEDURE.
*
* LIST's first line is "PROCEDURE <name>".  The others are " XXXX" (a
* marker and the I-code offset), a space, then a line number if there
* is one, and the text from column PPCOL on, two columns more for each
* level of indent.  A line longer than
* the decompiler's margin goes on after an LF and more spaces.
*
* The line count does not change (every source line is one I-code
* line), so the cursor, the window and the breakpoints go back to
* their lines, and the procedure counts as loaded: its text came from
* the loaded code.  One undo takes the whole pretty print back.

PPCOL               equ       11                  LIST text column, indent level 0
PPIND               equ       2                   the body's indent under PROCEDURE

* c_pp: pretty print the procedure at the cursor
c_pp                ldx       <base
                    clr       ppall,x
                    bra       pp_go
* c_ppall: pretty print every procedure
c_ppall             ldx       <base
                    lda       #1
                    sta       ppall,x
pp_go               tst       <dbgon
                    beq       pg1
                    leax      ppdbms,pcr
                    stx       <msgp
                    rts
pg1                 lbsr      sel_off
                    lbsr      c_make
                    bcc       pg2
                    rts                           (Make says why)
pg2                 tst       <nproc
                    bne       pg3
                    leax      noprms,pcr
                    stx       <msgp
                    rts
pg3                 ldx       <base               where everything is, by line
                    ldd       <curline
                    std       ppcl,x
                    ldd       <curcol
                    std       ppcc,x
                    ldd       <topline
                    std       pptl,x
                    lbsr      bp_keep
                    lda       #1                  the undo records go together
                    sta       <ulink
                    ldx       <base
                    tst       ppall,x
                    bne       pg_all
                    ldd       <curline            the procedure at the cursor
                    addd      #1
                    lbsr      bp_proc
                    bcc       pg5
                    leax      ppnoms,pcr
                    stx       <msgp
                    bra       pg_done
pg5                 lbsr      pp_one
                    bra       pg_done
pg_all              clrb
pg6                 cmpb      <nproc
                    bhs       pg_done
                    pshs      b
                    lbsr      pt_at
                    tfr       x,y
                    lda       PR.FLAG,y           (not the DEFTYPE blocks)
                    bita      #PF.DEF
                    bne       pg6a
                    lbsr      pp_one
pg6a                puls      b
                    bcs       pg_done
                    incb
                    bra       pg6
pg_done             clr       <ulink
                    tst       <child
                    beq       pg7
                    lbsr      mk_scan             it counts as loaded
                    lda       #PF.SEND
                    lbsr      pt_flags
pg7                 lbsr      bp_back
                    ldx       <base               the window's top line
                    ldd       pptl,x
                    lbsr      goto_line
                    ldd       <cpos
                    std       <tpos
                    ldd       <cpos+2
                    std       <tpos+2
                    ldx       <base
                    ldd       pptl,x
                    std       <topline
                    ldd       ppcl,x              the cursor
                    lbsr      goto_line
                    lbsr      a_cpos
                    ldx       <base
                    ldd       ppcc,x
                    lbsr      p_tocol
                    lbsr      p_col
                    std       <curcol
                    std       <wantcol
                    clr       <setwant
                    lbra      rd_all
ppdbms              fcn       "The program is stopped: reset it first (^P)"
ppnoms              fcn       "The cursor is not in a procedure"

* pp_one: pretty print the procedure of entry Y; carry (and a message)
* if it could not be done
pp_one              lda       PR.FLAG,y
                    bita      #PF.ERR
                    beq       po1
                    leax      pperms,pcr
                    lbra      po_msg
po1                 pshs      y
                    lbsr      pp_usei             (USE lines stay as they are)
                    ldy       ,s
                    lbsr      a_rline             "list <name>"
                    leay      listcm,pcr
                    lbsr      s_str
                    ldy       ,s
                    lbsr      s_str
                    lda       #C$CR
                    sta       ,x
                    lbsr      rt_cmd
                    lbcs      po_gone
                    lbsr      d_alloc             a chain for the new text
                    bcs       po_full0
                    ldu       <base
                    stx       pprec+UR.CH,u
                    clr       pphdr,u
                    clr       ppcont,u
po2                 lbsr      rt_line             the listing, up to %READY
                    bcs       po_gone1
                    ldx       <base
                    lda       rline,x
                    cmpa      #'%
                    beq       po4
                    tst       pphdr,x             its first line, PROCEDURE <name>,
                    bne       po3                 goes in as it is
                    inc       pphdr,x
                    inc       ppcont,x
po3                 lbsr      pp_clean
                    bcc       po2
                    bra       po_full             (read the rest first)
po4                 lda       rline+1,x
                    cmpa      #'R                 %READY
                    bne       po2
                    puls      y
                    lbsr      pp_put
                    pshs      cc
                    ldx       <base
                    ldx       pprec+UR.CH,x
                    lbsr      chain_free
                    puls      cc
                    bcs       po_fullm
                    rts
po_full             lbsr      rt_line             no pages: read the rest, give up
                    bcs       po_gone1
                    ldx       <base
                    lda       rline,x
                    cmpa      #'%
                    bne       po_full
                    ldx       <base
                    ldx       pprec+UR.CH,x
                    lbsr      chain_free
po_full0            leas      2,s
po_fullm            leax      fullms,pcr
po_msg              stx       <msgp
                    orcc      #Carry
                    rts
po_gone1            ldx       <base
                    ldx       pprec+UR.CH,x
                    lbsr      chain_free
po_gone             puls      y
                    orcc      #Carry
                    rts
pperms              fcn       "The procedure has errors"
listcm              fcn       "list "

* pp_clean: turn the LIST line in rline (Y bytes) into source and add it
* to the new text; carry if the pages ran out
pp_clean            ldu       <base
                    tst       ppuse,u
                    beq       ppc0
                    pshs      y
                    lbsr      pp_use
                    puls      y
                    bcs       ppc0a               (carry: no pages)
                    beq       ppc0                ..not a USE line
ppc0a               rts
ppc0                tfr       y,d
                    lbsr      a_rline
                    leau      d,x                 U = the end of what was read
                    pshs      u
                    leay      ,x                  Y = where the source goes
                    ldu       <base
                    tst       ppcont,u
                    bne       ppc5                the rest of a line too long to read
                    leax      6,x                 past the marker and the offset
                    clr       ppw,u
ppc1                cmpx      ,s                  a line number goes in the gutter
                    lbhs      ppc9
                    lda       ,x
                    cmpa      #'0
                    blo       ppc2
                    cmpa      #'9
                    bhi       ppc2
                    sta       ,y+
                    leax      1,x
                    ldu       <base
                    inc       ppw,u
                    bra       ppc1
ppc2                cmpx      ,s                  the spaces up to the text go
                    lbhs      ppc9
                    lda       ,x
                    cmpa      #C$SPAC
                    bne       ppc3
                    leax      1,x
                    bra       ppc2
ppc3                tfr       x,d                 the text's column: PPIND, and two
                    subd      <base               more for each level of indent
                    subd      #rline+PPCOL
                    bpl       ppc3a
                    clrb
ppc3a               tstb                          an END at the top level closes the
                    bne       ppc3b               procedure: column 0, under PROCEDURE
                    ldu       <base
                    tst       ppw,u
                    bne       ppc3b
                    lbsr      pp_isend
                    beq       ppc5
ppc3b               addb      #PPIND
                    ldu       <base
                    subb      ppw,u               spaces after the line number
                    bgt       ppc4
                    ldb       ppw,u               (at least one after a number)
                    beq       ppc5
                    ldb       #1
ppc4                lda       #C$SPAC
ppc4a               sta       ,y+
                    decb
                    bne       ppc4a
ppc5                cmpx      ,s                  the text, as it is
                    bhs       ppc9
                    lda       ,x+
                    cmpa      #C$CR
                    beq       ppc8
                    cmpa      #C$LF
                    beq       ppc6
                    sta       ,y+
                    bra       ppc5
ppc6                cmpx      ,s                  a wrapped line: join it, with a
                    bhs       ppc9                space only between two words
                    lda       ,x
                    cmpa      #C$SPAC
                    bne       ppc7
                    leax      1,x
                    bra       ppc6
ppc7                lbsr      is_word
                    bcc       ppc5
                    lda       -1,y
                    lbsr      is_word
                    bcc       ppc5
                    lda       #C$SPAC
                    sta       ,y+
                    bra       ppc5
ppc8                ldu       <base               the end of the line: no trailing
                    leau      rline,u             spaces
ppc8a               pshs      u
                    cmpy      ,s++
                    bls       ppc8b
                    lda       -1,y
                    cmpa      #C$SPAC
                    bne       ppc8b
                    leay      -1,y
                    bra       ppc8a
ppc8b               lda       #C$CR
                    sta       ,y+
                    ldu       <base
                    clr       ppcont,u
                    bra       ppc10
ppc9                ldu       <base               no CR: the line goes on in the next read
                    lda       #1
                    sta       ppcont,u
ppc10               leas      2,s
                    lbsr      a_rline             add it to the chain
                    ldu       <base               (keywords in lower case first)
                    tst       kwup,u
                    bne       ppc10a
                    bsr       pp_lower
ppc10a              pshs      y
ppc11               cmpx      ,s
                    bhs       ppc12
                    lda       ,x+
                    pshs      x
                    ldx       <base
                    leax      pprec,x
                    lbsr      chain_app
                    puls      x
                    bcc       ppc11
                    puls      y,pc                (carry)
ppc12               andcc     #^Carry
                    puls      y,pc

* pp_lower: the keywords in the text from X to Y in lower case.  Strings,
* comments, numbers and names stay as they are.  Keeps all registers.
pp_lower            pshs      d,x,y,u
plw1                cmpx      4,s                 (Y on the stack: the end)
                    lbhs      plw9
                    lda       ,x
                    cmpa      #'"                 a string
                    beq       plw_str
                    cmpa      #'(                 (* ... *)
                    bne       plw2
                    lda       1,x
                    cmpa      #'*
                    beq       plw_cmt
                    bra       plw_next
plw2                cmpa      #'$                 $hex
                    beq       plw_num
                    cmpa      #'0                 a number (with its E)
                    blo       plw_next
                    cmpa      #'9
                    bls       plw_num
                    lbsr      is_word             a word
                    bcs       plw_word
plw_next            leax      1,x
                    bra       plw1
plw_str             leax      1,x                 to the closing quote
                    cmpx      4,s
                    lbhs      plw9
                    lda       ,x
                    cmpa      #'"
                    bne       plw_str
                    bra       plw_next
plw_cmt             leax      2,x                 to "*)"
plwc1               cmpx      4,s
                    lbhs      plw9
                    ldd       ,x
                    cmpd      #'**256+')
                    beq       plwc2
                    leax      1,x
                    bra       plwc1
plwc2               leax      2,x
                    bra       plw1
plw_num             leax      1,x                 digits, letters and "."
                    cmpx      4,s
                    lbhs      plw9
                    lda       ,x
                    cmpa      #'.
                    beq       plw_num
                    lbsr      is_word
                    bcs       plw_num
                    bra       plw1
plw_word            ldu       <base               the word, upper case, to hlbuf
                    leau      hlbuf,u
                    clrb
                    pshs      x
plww1               cmpx      6,s
                    bhs       plww3
                    lda       ,x
                    cmpa      #'$                 (LEFT$: the $ ends it, and is part)
                    beq       plww2
                    lbsr      is_word
                    bcc       plww3
                    cmpa      #'a
                    blo       plww2
                    cmpa      #'z
                    bhi       plww2
                    suba      #$20
plww2               cmpb      #HLMAX
                    bhs       plww2a
                    sta       b,u
plww2a              incb
                    leax      1,x
                    lda       -1,x
                    cmpa      #'$
                    bne       plww1
plww3               cmpb      #HLMAX
                    bhs       plww4
                    clr       b,u
plww4               tfr       x,y                 Y = the end of the word
                    puls      x
                    pshs      y
                    lbsr      kw_find
                    tstb
                    beq       plww8               a name: as it is
plww5               cmpx      ,s                  a keyword: lower case
                    bhs       plww6
                    lda       ,x
                    cmpa      #'A
                    blo       plww5a
                    cmpa      #'Z
                    bhi       plww5a
                    adda      #$20
                    sta       ,x
plww5a              leax      1,x
                    bra       plww5
plww6               ldu       <base               REM: the rest is a comment
                    ldd       hlbuf,u
                    cmpd      #'R*256+'E
                    bne       plww8
                    ldd       hlbuf+2,u
                    cmpd      #'M*256
                    beq       plww9
plww8               puls      x
                    lbra      plw1
plww9               leas      2,s
plw9                puls      d,x,y,u,pc

* pp_isend: Z if the text at X is the END statement
pp_isend            pshs      d
                    ldd       ,x
                    cmpd      #'E*256+'N
                    bne       pie8
                    lda       2,x
                    cmpa      #'D
                    bne       pie8
                    lda       3,x                 not ENDIF, ENDWHILE, ...
                    lbsr      is_word
                    bcs       pie8
                    orcc      #Zero
                    puls      d,pc
pie8                andcc     #^Zero
                    puls      d,pc

* pp_usei: for entry Y: if it has USE lines, usep = its PROCEDURE line,
* so that pp_use can follow the LIST lines in the text
pp_usei             ldu       <base
                    clr       ppmid,u
                    clr       ppskip,u
                    clr       ppuse,u
                    lda       PR.FLAG,y
                    bita      #PF.USE
                    beq       pui9
                    inc       ppuse,u
                    ldd       PR.LINE,y
                    lbsr      goto_line           cpos
                    ldu       <base
                    ldd       <cpos
                    std       usep,u
                    ldd       <cpos+2
                    std       usep+2,u
pui9                rts

* pp_use: LIST printed the TYPE text a USE line brought in (mk_types)
* in front of the comment, so the line in the text goes in instead.
* For the LIST line in rline (Y bytes): NE if it was such a line (or
* the rest of one), carry if the pages ran out
pp_use              tfr       y,d
                    lbsr      a_rline
                    leax      d,x
                    lda       -1,x                its last character
                    suba      #C$CR               (not 0: the line goes on)
                    pshs      a
                    ldu       <base
                    tst       ppmid,u             the start of a line?
                    beq       pus2
                    tst       ppskip,u            ..no: drop the rest of a USE line
                    beq       pus_no
                    bra       pus_yes
pus2                clr       ppskip,u
                    lbsr      us_xu
                    lbsr      ln_use
                    bcc       pus3a
                    lbsr      us_xu               ..not one: on to the next line
                    lbsr      p_nextln
                    bra       pus_no
pus3a               lbsr      us_xu               ..one: copy it from the text,
                    lbsr      p_char              indented as the body is
                    bcs       pus4
                    cmpa      #C$SPAC
                    bne       pus3b
                    lbsr      p_next
                    bra       pus3a
pus3b               ldd       #C$SPAC*256+PPIND
pus3c               bsr       pus_app
                    bcs       pus_err
                    decb
                    bne       pus3c
pus3                lbsr      us_xu
                    lbsr      p_char
                    bcs       pus4
                    lbsr      p_next
                    bsr       pus_app
                    bcs       pus_err
                    cmpa      #C$CR
                    bne       pus3
                    bra       pus5
pus4                lda       #C$CR               (the last line of the text)
                    bsr       pus_app
                    bcs       pus_err
pus5                ldu       <base
                    inc       ppskip,u
pus_yes             lda       #1
                    bra       pus8
pus_no              clra
pus8                ldu       <base
                    ldb       ,s+
                    stb       ppmid,u
                    tsta
                    andcc     #^Carry
                    rts
pus_err             puls      a,pc
pus_app             pshs      d,x                 A to the new text
                    ldx       <base
                    leax      pprec,x
                    lbsr      chain_app
                    puls      d,x,pc

* pp_put: the new text in place of the lines of the procedure of entry
* Y (from the PROCEDURE line up to the next PROCEDURE or DEFTYPE line,
* or the end of the text); carry if the pages ran out
pp_put              ldd       PR.LINE,y           from the PROCEDURE line
                    pshs      d,y
                    lbsr      goto_line
                    ldu       <base
                    ldd       <cpos
                    std       usep,u
                    ldd       <cpos+2
                    std       usep+2,u
ppt1                lbsr      us_xu               to the end of the procedure
                    lbsr      ln_next
                    bcc       ppt1
                    ldd       ,x
                    std       <xpos
                    ldd       2,x
                    std       <xpos+2
                    puls      d,y
                    lbsr      goto_line
                    bsr       pp_same
                    bcc       pp_none             already pretty: no edit at all
                    lbsr      ed_delto            (recorded for undo)
                    ldx       <base
                    ldx       pprec+UR.CH,x
                    lbsr      chain_paste         (recorded too)
                    lda       #1
                    sta       <modif
                    andcc     #^Carry
                    rts
pp_none             andcc     #^Carry
                    rts

* pp_same: carry clear if the new text is the text from cpos to xpos
pp_same             pshs      d,x,y,u
                    lbsr      cp_wp
                    ldx       <base
                    ldx       pprec+UR.CH,x       X = a page of the new text,
                    ldd       #0
                    pshs      d                   ,s = the offset in it
pps1                cmpd      DS.USED,x
                    blo       pps2
                    ldx       DS.NEXT,x
                    beq       pps_end
                    ldd       #0
                    std       ,s
                    bra       pps1
pps2                lbsr      pg_map
                    leay      d,y
                    lda       ,y
                    pshs      a,x
                    ldu       <base
                    leau      wp,u
                    bsr       pp_atx              the old text ended first?
                    beq       pps_no
                    lbsr      p_char
                    bcs       pps_no
                    cmpa      ,s
                    bne       pps_no
                    lbsr      p_next
                    puls      a,x
                    ldd       ,s
                    addd      #1
                    std       ,s
                    bra       pps1
pps_no              leas      3,s
                    bra       pps_diff
pps_end             bsr       pp_atx              both ended together?
                    beq       pps_eq
pps_diff            leas      2,s
                    orcc      #Carry
                    puls      d,x,y,u,pc
pps_eq              leas      2,s
                    andcc     #^Carry
                    puls      d,x,y,u,pc

* pp_atx: Z if wp is at xpos
pp_atx              ldd       <wp
                    cmpd      <xpos
                    bne       pax9
                    ldd       <wp+2
                    cmpd      <xpos+2
pax9                rts
