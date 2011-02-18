;Read Boot 1.0 Copyright (c) 1999 by Marcelo Gornstein
;This program is under the GNU/GPL version 2 license.
;Saves the first 512 bytes from the first floppy drive.
;You may pass the the output file name in the command tail.
;If there are no parameters, the default output file will be
;the one contained in DEF_FILENAME below. Has to end with 0 (ASCIIZ string).
;---------------------
;----- Main code -----
;---------------------
Main:
        xor ax, ax              ;After the XOR AX=0
        push ds                 ;We have to do this
        pop es                  ;to have ES=DS
        lea dx, COPYRIGHT       ;Make DX a pointer to the first
                                ;character in the copyright msg.
                                ;That is COPYRIGHT[0].
        call ShowStr            ;Print it in stdout.        
        mov si, 80h             ;When the program is run,
                                ;we have in the PSP offset 80h the
                                ;total length of the command tail.
                                ;In the subsequent bytes, is the command tail.
        xor cx, cx              ;Clear CX
        mov cl, [si]            ;Load the total length in CL
        dec cl                  ;CL=total length - carriage return (enter).
        cmp cx, 255             ;If CX=255 (-1) there are no parameters
        je Noparam              ;so JuMP the immediate below code
        add si, 2               ;But if there IS a parameter, setup
                                ;SI to point there. SI=82h.
        jmp LoadParam           ;Copy the argument from the command tail
                                ;to our buffer.
Noparam:
        mov cl, DEFLENGTH       ;Get the length of the default filename in CL.
        lea si, DEF_FILENAME    ;Setup SI to point to our buffer.
;-------------------------------------------------------------------------
;----- Load Param:                                                   -----
;----- This routine is ALWAYS reached. If we have arguments, then we -----
;----- have SI pointing there, if not, SI is pointing to the default -----
;----- file name defined at the end of the code. So, in either case  -----
;----- we end up copying CX bytes from DS:SI to ES:DI. CX was setup  -----
;----- to the value located in the PSP offset 80h at the beggining.  -----
;----- Or, in a no-arguments case, CX has the length for the default -----
;----- filename.                                                     -----
;-------------------------------------------------------------------------
LoadParam:
        lea di, FILE_NAME       ;Destiny: our buffer.
        rep movsb               ;Copy each byte at the time.
;----------------------------------------------------------------
;----- CreateFile: We use the DOS create file service (3Ch) -----
;----------------------------------------------------------------
CreateFile:
        mov ax, 3C00h           ;DOS Create file service.
        lea dx, FILE_NAME       ;DX points to our ASCIIZ buffer.
                                ;We have to set CX to the attributes
                                ;to the new file, but since the normal
                                ;attributes makes CX=0 and CX was already
                                ;0 because of the 'rep movsb', we don't
                                ;touch it and save a few bytes.
        int 21h                 ;Do it.
        jc Error                ;Oops.
;---------------------------------------------------------------------
;----- Malloc: Allocates 512 bytes for the buffer for the sector -----
;---------------------------------------------------------------------
Malloc:
        mov ax, 4900h   ;DOS Allocate memory function.
        mov bx, BUFFLEN ;BX=total length in paragraphs.
        int 21h         ;Gimme! Gimme!
        jc Error        ;Oops!
        push ax         ;If everything turned ok, we save AX wich now
                        ;contains the segment of the allocated memory.
;---------------------------------------------------------------
;----- ReadSector: Using BIOS int 25h (Absolute disk read) -----
;----- we read sector 0 from drive 0 (A)                   -----
;---------------------------------------------------------------
ReadSector:
        xor ax, ax      ;Clear AX.
        pop bx          ;BX=Segment allocated above.
        push bx         ;Save BX for later
        mov cx, 1       ;We're gonna read 1 sector.
        xor dx, dx      ;And that's sector 0.
        int 25h         ;Read.
        pop ax          ;We do this because when we get back from the
                        ;interrupt, we have the flags pushed in the stack.
                        ;Not a very good thing.
        jc Error        ;Did we get an error?
;-------------------------------------------------
;----- OpenFile: Opens a filename for output -----
;-------------------------------------------------
OpenFile:
        mov ax, 3D01h      ;DOS open file service.
        lea dx, FILE_NAME  ;DX points to the filename.
        int 21h            ;Do it.
        jc Error           ;Oops.
        push ax            ;We get the new handle in AX. Save it.
;----------------------------------------------------------------------
;----- WriteBuffer: Writes the contents from the allocated memory -----
;----------------------------------------------------------------------
WriteBuffer:
        mov ax, 4000h   ;DOS write to file with handle service.
        pop bx          ;Pop the file handle. (Now the memory segment is
                        ;in top of the stack ;)
        mov cx, 512     ;Read 512 bytes.
        pop dx          ;Pop the buffer segment. 
        push dx         ;Save it.
        int 21h         ;Do it.
        jc Error        ;Error?
;-------------------------------------------------------------------
;----- CloseFile: after writing the buffer, we close the file. -----
;----- Just like nice gentlemen do.                            -----
;-------------------------------------------------------------------
CloseFile:
        mov ax, 3E00h   ;DOS close file service.
        int 21h         ;Close it.
        jc Error        ;No error, please?
;-------------------------------------------------------
;----- Free: Finally, we free the allocated memory -----
;-------------------------------------------------------
Free:
        mov ax, 4900h   ;DOS free memory service.
        pop es          ;Recover the segment.
        jc Error        ;Error?
        xor al, al      ;Exit with 0 as error code (success)
;----------------------------------------------------------------------
;----- Exit: Quits to DOS with the corresponding error code in AL -----
;----------------------------------------------------------------------
Exit:
        mov ah, 4Ch     ;Load in AH the service request (4Ch to quit).
                        ;We don't set AL because it's supposed to be
                        ;already set before calling this routine.
        int 21h         ;Call DOS and quit.
        db 'Never'      ;As you might now, if you call Exit,
        db 'reached'    ;the program ends without getting here.
;-------------------------------------------------------------------
;----- ShowStr: This routine displays the string pointed by DX -----
;----- via the DOS service 09h.                                -----
;-------------------------------------------------------------------
ShowStr:
        push ax         ;Save AX because we are going to use it
        mov ax, 0900h   ;Load in AH the service request (09h to print
                        ;a string. The string has to end with '$').
        int 21h         ;Call DOS to print the string.
        pop ax          ;Recover old AX value.
        ret             ;Return to where we were called from.
;----------------------------------------------------
;----- Error: Prints an error message and quits -----
;----------------------------------------------------
Error:
        lea dx, ERRORMSG ;DX points to our msg.
        call ShowStr     ;Print it.
        mov al, 255      ;Exit with 255 (-1) as error code.
        jmp Exit         ;Outta'here.
;------------------------------
;----- Data and variables -----
;------------------------------
FILE_NAME DB 00,00,00,00,00,00,00,00,00,00,00,00
BUFFLEN equ (512 / 16) + 1
FILEMSG db 'Using file name: ', '$'
COPYRIGHT db 'Read Boot 1.0 Copyright (c) 1999 by Marcelo Gornstein.', 0a, 0d
          db 'This program is under the GNU/GPL version 2 license.', 0a, 0d, '$'
ERRORMSG db 'Error', 0a, 0d, '$'
Dummy_label:
        DEF_FILENAME db 'boot.sct', 0
        DEFLENGTH equ ($ - Dummy_label - 1)
