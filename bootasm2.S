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

# COMMENT SWAP TO VIDEO MODE
swap_to_VGA:
    movb    $0, %ah             # ensure ah is 0 for the interupt
    movb    $0x13, %al          # put 0x13 into al for the interupt
    int     $0x10               # run interupt 10, this swaps to VGA mode
    ret

# COMMENT BEGIN DRAW SINGLE LINE
#define stepx  -22
#define stepy  -20
#define err -18
#define e2  -16
#define dvaly  -14
#define dvalx  -12
# ^local calculated, v also local
#define x0  -10
#define x1  -8
#define y0  -6
#define y1  -4
#define col   -2

Draw_Line:
    pushw   %bp                 # primary stackprep done so i can store local variables
    movw    %sp, %bp
    subw    $22, %sp            # reserve space for local variables
    movb    %al, col(%bp)       # values into stack, bp is target, colour from al
    movb    %dh, y1(%bp)        # y1 from dh
    movb    %dl, y0(%bp)        # y0 from dl
    movb    %ch, x1(%bp)        # x1 from ch
    movb    %cl, x0(%bp)        # xo from cl

    movw    x1(%bp), %ax        # x1 into ax
    movw    x0(%bp), %dx
    subw    %dx, %ax            # xend-xstart, x1 is target
    cmp     $0, %ax             # compare to 0 ax is target
    jge     Absoloute_Y         # when target is greater than 0, it's already positive
    movw    $-1, %dx            # -1 into dx as multiply takes a register
    imul    %dx                 # when it's less than 0, make it positive
    
Absoloute_Y:
    movw    %ax, dvalx(%bp)     # dvalx into bp, bp is target
# example of jump then set the result

    movw    y1(%bp), %ax        # y1 into ax
    movw    y0(%bp), %dx
    sub     %dx, %ax            # yend - ystart, y1 is target
    cmp     $0, %ax             # compare to 0 > ax is target
    jge      StepX_Comp         # when target is greater than 0, it's already positive
    movw    $-1, %dx            # -1 into dx as multiply takes a reg
    imul    %dx                 # when it's less than 0, make it positive

StepX_Comp:
    movw    %ax, dvaly(%bp)     # dvaly's into bp, bp is target

    movw    x1(%bp), %dx        # x1 into dx, will be target
    cmp     %dx, x0(%bp)        # x1 > x0 , x0 is target
    movw    $1 , stepx(%bp)     # will set pos before jump, will fall through and alter if negative
    jl      StepY_Comp          # when target is less than the end point, step should remain +1
    movw    $-1, stepx(%bp)     # stepx changed to -1, bp is target
# example of set result, possibly jump, then re-calc and set again if no jump

StepY_Comp:
    movw    y1(%bp), %dx        # y1 into dx, will be target
    cmp     %dx, y0(%bp)        # y1 > y0 figure out if y step is positive or negative y0 is target
    movw    $1, stepy(%bp)      # will set pos before jump, will fall through and alter if negative
    jl      Err_Comp            # when target is less than the end point, step should remain +1
    movw    $-1, stepy(%bp)     # step y to -1

Err_Comp:
    movw    dvalx(%bp), %ax     # bring dvalx into ax
    movw    dvaly(%bp), %dx
    subw    %dx, %ax            # err = dx - dy, dvalx is target
    movw    %ax, err(%bp)       # result in ax goes into err

    movw    dvaly(%bp), %ax     # bring dy into ax
    movw    $-1, %dx            # -1 into dx
    imulw   %dx                 # dvaly * -1
    movw    %ax, dvaly(%bp)     # result in ax goes into dvaly
# make dy negative as the algorithm always asks for -dy from here on in

Plot_Pixel:
# faff with reges to have ah 0x0x, al colour, bh 0, cx column, dx row them int 10
    movb    $0x0c, %ah          # 0x0c into ah
    movb    col(%bp), %al       # colour into al
    movw    x0(%bp), %cx        # x coord into cx
    movw    y0(%bp), %dx        # y coord into dx
    int     $0x10               # draw the pixel via interupt

    movw    x1(%bp), %dx        # x end into dx
    cmp     x0(%bp), %dx        # x0 = x1 (if they're equal, at end of x) dx is target
    jne     Re_Calc_Plot_Pixel  # when target is not eaual to dx, go to the calcs
    movw    y1(%bp), %dx        # y end into dx
    cmp     y0(%bp), %dx        # y0 = y1 (if they're equal, at end of y) dx is target
    jne     Re_Calc_Plot_Pixel  # when target is not equal to dx, go to the calcs
    jmp     End_Of_Draw_Line    # both are equal so they fell through, exit loop

Re_Calc_Plot_Pixel:
    movw    err(%bp), %ax       # err into ax
    movw    $2, %dx             # 2 into dx
    imulw   %dx                 # e2 = 2err
    movw    %ax, e2(%bp)        # result in ax into e2

    movw    dvaly(%bp), %dx     # dy into dxreg, dval (delta value y) is -dy
    cmp     e2(%bp), %dx        # e2 > -dy we continue the calculations, dx is target
    jge     E2_Dx_Calc_Plot_Pixel   # when target is more than e2, skip to x calc
    movw    err(%bp), %ax       # err into ax
    movw    dvaly(%bp), %dx
    addw    %dx, %ax            # err = err-dy (dy was made negative), err in ax is target
    movw    %ax, err(%bp)       # result in ax into err, err is target

    movw    x0(%bp), %ax        # x0 into ax
    movw    stepx(%bp), %dx
    addw    $1, %ax
    # COMMENT OUT addw    %dx, %ax            # xo = x0 +sx, x0 is target
    movw    %ax, x0(%bp)        # save ax into x0

E2_Dx_Calc_Plot_Pixel:
    # COMMENTED OUT movw    e2(%bp), %ax        # bring out e2 into Ax [why am i doing this bit]
    movw    dvalx(%bp), %dx     # bring dx into Dx reg
    cmp     e2(%bp), %dx        # when e2 < dx we continue the calculations, dx is target
    jl      Plot_Pixel          # when target is less than e2, skip to loop, operand e2 > target

    movw    err(%bp), %ax       # err+ dvalx, err into ax, ax is target
    addw    dvalx(%bp), %ax     # err = err+dx, err is target
    movw    %ax, err(%bp)       # ax into err

    movw    y0(%bp), %ax        # y0 into ax
    movw    stepy(%bp), %dx
    addw    $1, %ax
    # COMMENT OUT addw    %dx, %ax        # xo = y0 +sy, y0 in ax is target
    movw    %ax, y0(%bp)        # result in ax into y0
     
    jmp Plot_Pixel              # after calcs we loop

End_Of_Draw_Line:
    popw %bp
    ret $22                     # return, removing the 11 local variables from the stack
# COMMENT END OF DRAW SINGLE LINE

real_start:
    movw    $boot_message, %si  # Display our boot message
    call    cons_writeline

    call    swap_to_VGA         # change to VGA mode

    movb    $5, %al             # colour
    movb    $24, %cl            # x0
    movb    $34, %ch            # x1
    movb    $44, %dl            # y0
    movb    $54, %dh            # y1
    call    Draw_Line           # draw a line

    movb    $10, %al
    movb    $39, %cl 
    movb    $29, %ch 
    movb    $59, %dl 
    movb    $39, %dh 
    # COMMENT OUT call    Draw_Line           # draw a line

endless_loop:                   # Loop forever more
    jmp     endless_loop    

# Program data

boot_message:     
    .string "Boot Loader Stage 2 loaded"             

