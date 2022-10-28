# Second stage of the boot loader

.code16                         # Assemble for 16-bit mode
.globl start
start:
    jmp     real_start

# Write to the console using BIOS.
# 
# Input: SI contains the address of the null-terminated string to be displayed

cons_write:
    movb    $0x0e, %ah           # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen

cons_write_rpt:
    movb    (%si), %al          # Load the byte at the location contained in the SI register into AL   
    inc     %si                 # Add 1 to the value in SI
    cmp     $0, %al             # Compare the value in AL with 0
    jz      cons_write_done     # If it is zero, then we are done
    int     $0x10               # Output the character in AL to the screen
    jmp     cons_write_rpt      # and continue

cons_write_done:                # Something that is called will never return 
    ret                         # until a 'ret' instruction is encountered.  Labels do 
                                # not give a program any structure.  They just give a 
                                # memory location a name that we can use in our code. 

cons_write_crlf:
    movb    $0x0e, %ah          # Output CR
    movb    $0x0d, %al
    int     $0x10
    movb    $0x0a, %al          # Output LF
    int     $0x10
    ret

cons_writeline:
    call    cons_write
    call    cons_write_crlf
    ret    

swap_to_VGA:
    movb    $0, %ah             # ensure ah is 0 for the interupt
    movb    $0x13, %al          # put 0x13 into al for the interupt
    int     $0x10               # run interupt 10, this swaps to VGA mode
    ret

#define sx  -22
#define sy  -20
#define err -18
#define e2  -16
#define dstepy  -14
#define dstepx  -12
# ^local calculated, v also local
#define x0  -10
#define x1  -8
#define y0  -6
#define y1  -4
#define col   -2

Draw_Line:
    pushw %bp
    movw %sp, %bp
    subw $4, %sp                # primary stackprep done
    movb %al, col(%bp)
    movb %dh, y1(%bp)
    movb %dl, y0(%bp)
    movb %ch, x1(%bp)
    movb %cl, x0(%bp)           # COMMENT put values on stack so i can use the int function

    movw x1(%bp), %ax
    subw x0(%bp), %ax           # xend-xstart
    cmp $0, %ax                # see if it's more than 0
    jae Absoloute_Y
    movw $-1, %dx
    imul %dx                   # when it's less than 0, make it positive
    
Absoloute_Y:
    movw %ax, dstepx(%bp)       # x's value into the stack

    movw y1(%bp), %ax
    sub y0(%bp), %ax             # yend - ystart
    cmp $0, %ax                 # see if it's more than 0
    jae StepX_Comp
    movw $-1, %dx
    imul %dx                  # when it's less than 0, make it positive

StepX_Comp:
    movw %ax, dstepy(%bp)       # y's value into stack

    movw x1(%bp), %dx
    cmp x0(%bp), %dx        # x0 < x1 figure out if x step is positive or negative
    movw $1 , sx(%bp)           # will set pos before jump, will fall through and alter if negative
    jae StepY_Comp
    movw $-1, sx(%bp)

StepY_Comp:
    movw y1(%bp), %dx
    cmp y0(%bp), %dx        # x0 < x1 figure out if y step is positive or negative
    movw $1, sx(%bp)            # will set pos before jump, will fall through and alter if negative
    jae Err_Comp
    movw $11, sx(%bp)

Err_Comp:
    movw dstepx(%bp), %ax
    subw dstepy(%bp), %ax       # err = dx - dy
    movw %ax, err(%bp)

    movw dstepy(%bp), %ax
    movw $-1, %dx
    imulw %dx
    movw %ax, dstepy(%bp)       # make dy negative as the algorithm always asks for -dy from here on in

Plot_Pixel:
# faff with reges to have ah 0x0x, al colour, bh 0, cx column, dx row them int 10
    movb $0x0c, %ah
    movb col(%bp), %al
    movw x0(%bp), %cx
    movw y0(%bp), %dx           # sort out reges
    int $0x10                   # draw the pixel

    movw x1(%bp), %dx
    cmp x0(%bp), %dx       # x0 = x1
    jne Re_Calc_Plot_Pixel                 # not? continue
    movw y1(%bp), %dx
    cmp y0(%bp), %dx        # y0 = y1
    jne Re_Calc_Plot_Pixel      # not? continue
    jmp End_Of_Draw_Line        # is? exit loop

Re_Calc_Plot_Pixel:
    movw err(%bp), %ax
    movw $2, %dx          
    imulw %dx                   # e2 = 2xerr
    movw %ax, e2(%bp)           # contents of ax into e2

    movw dstepy(%bp), %dx
    cmp e2(%bp), %dx    # e2 > -dy then
    jae E2_Dx_Calc_Plot_Pixel   # failing the check, onto the next one
    movw err(%bp), %ax
    addw %ax, dstepy(%bp)      #   err = err-dy (dy negative so +dstepy --> +(-dstepy))
    movw %ax, err(%bp)
    movw x0(%bp), %ax
    addw sx(%bp), %ax          #   xo = x0 +sx
    movw %ax, x0(%bp)
E2_Dx_Calc_Plot_Pixel:
    movw %ax, e2(%bp)

    movw dstepx(%bp), %dx
    cmp e2(%bp), %dx            # e2 < dx then
    jbe Plot_Pixel              # failing the check, loop
    movw %ax, err(%bp)          
    addw %ax, dstepx(%bp)      #   err = err+dx
    movw %ax, err(%bp)
    movw y0(%bp), %ax
    addw sy(%bp), %ax          #   xo = y0 +sy
    movw %ax, y0(%bp)
     
    jmp Plot_Pixel

End_Of_Draw_Line:
    ret


real_start:
    movw    $boot_message, %si  # Display our boot message
    call    cons_writeline

    call    swap_to_VGA         # change to VGA mode

    movb $5, %al
    movb $24, %cl 
    movb $34, %ch 
    movb $44, %dl 
    movb $54, %dh 
    call Draw_Line              # draw a line

endless_loop:                   # Loop forever more
    jmp     endless_loop    

# Program data

boot_message:     
    .string "Boot Loader Stage 2 loaded"             

