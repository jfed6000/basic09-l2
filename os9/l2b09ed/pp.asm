********************************************************************
* pp - pretty print
*
* Basic09 keeps no source, only I-code, and its LIST decompiles that
* with the keywords in capitals, standard spacing and the control
* structures indented: that was stock Basic09's pretty print.  So
* pretty print makes sure the procedure is loaded as it stands (Make),
* asks l2b09run to "list" it, cleans each line up, and puts the result
* in place of the procedure's lines; the PROCEDURE line stays as typed.
*
* A LIST line is " XXXX" (a marker and the I-code offset), a space,
* then a line number if there is one, and the text from column PPCOL
* on, two columns more for each level of indent.  A line longer than
* the decompiler's margin goes on after an LF and more spaces.
*
* The line count does not change (every source line is one I-code
* line), so the cursor, the window and the breakpoints go back to
* their lines, and the procedure counts as loaded: its text came from
* the loaded code.  One undo takes the whole pretty print back.

PPCOL               equ       11                  LIST text column, indent level 0

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
                    lbsr      pp_one
                    puls      b
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
                    ldu       <base
                    leau      cpos,u
                    ldx       <base
                    ldd       ppcc,x
                    lbsr      p_tocol
                    lbsr      p_col
                    std       <curcol
                    std       <wantcol
                    clr       <setwant
                    lda       #RD.ALL
                    ora       <redraw
                    sta       <redraw
                    rts
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
                    ldx       <base               "list <name>"
                    leax      rline,x
                    leay      listcm,pcr
                    lbsr      s_str
                    ldy       ,s
                    lbsr      s_str
                    lda       #C$CR
                    sta       ,x
                    lbsr      rt_cmd
                    bcs       po_gone
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
                    tst       pphdr,x             its first line: PROCEDURE <name>
                    bne       po3
                    inc       pphdr,x
                    bra       po2
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
pp_clean            tfr       y,d
                    ldx       <base
                    leax      rline,x
                    leau      d,x                 U = the end of what was read
                    pshs      u
                    leay      ,x                  Y = where the source goes
                    ldu       <base
                    tst       ppcont,u
                    bne       ppc5                the rest of a line too long to read
                    leax      6,x                 past the marker and the offset
                    cmpx      ,s
                    lbhs      ppc9
                    lda       ,x                  a line number?
                    cmpa      #'0
                    blo       ppc2
                    cmpa      #'9
                    bhi       ppc2
ppc1                lda       ,x
                    cmpa      #'0
                    blo       ppc1e
                    cmpa      #'9
                    bhi       ppc1e
                    sta       ,y+
                    leax      1,x
                    cmpx      ,s
                    blo       ppc1
ppc1e               lda       #C$SPAC             (dropped again if nothing follows)
                    sta       ,y+
ppc2                ldu       <base               spaces up to column PPCOL go
                    leau      rline+PPCOL,u
ppc3                cmpx      ,s
                    bhs       ppc9
                    pshs      u
                    cmpx      ,s++
                    bhs       ppc5
                    lda       ,x
                    cmpa      #C$SPAC
                    bne       ppc5
                    leax      1,x
                    bra       ppc3
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
                    ldx       <base               add it to the chain
                    leax      rline,x
                    pshs      y
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

* pp_put: the new text in place of the lines of the procedure of entry
* Y (from the line after PROCEDURE up to the next PROCEDURE line or the
* end of the text); carry if the pages ran out
pp_put              ldd       PR.LINE,y           the first line of the body
                    addd      #1
                    cmpd      <nlines
                    bhi       pp_none             PROCEDURE is the last line
                    pshs      d,y
                    ldd       #$FFFF              the next PROCEDURE line
                    pshs      d
                    clrb
ppt1                cmpb      <nproc
                    bhs       ppt3
                    pshs      b                   0 entry, 1 next, 3 body start
                    lbsr      pt_at
                    ldd       PR.LINE,x
                    cmpd      3,s
                    blo       ppt2                (at or before this one)
                    cmpd      1,s
                    bhs       ppt2
                    std       1,s
ppt2                puls      b
                    incb
                    bra       ppt1
ppt3                puls      d
                    cmpd      #$FFFF
                    bne       ppt4
                    ldd       <nlines             no next one: the end of the text
                    lbsr      goto_line
                    ldu       <base
                    leau      cpos,u
                    lbsr      p_eol
                    bra       ppt5
ppt4                lbsr      goto_line
ppt5                ldd       <cpos
                    std       <xpos
                    ldd       <cpos+2
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
                    ldd       <cpos
                    std       <wp
                    ldd       <cpos+2
                    std       <wp+2
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
