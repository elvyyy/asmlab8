.model tiny
.code
org 100h 
start:
jmp main
;file                       
file_name db 50 dup (0), '$'    
file_handle dw 0000h    

new_file_name db "print.txt", 0    
new_file_id dw 0000h

read_bytes dw 0000h

;error messages
pathError        db "IO Error: cannot fild path!$" 
openedFilesError db "IO Error: too many opened files!$"     
accessError      db "IO Error: access error!$"       
IOError          db "IO Error!$" 
maxSizeOfWordError db "Error: word that you have entered is bigger than max size of word!$"
invalidIdentifierError db "IO Error: invalid identifier$"
hello_message         db "Enter anything to start: $"  
message_opening_file         db "Try to open file...!$"
message_opened_file      db "File has been opened!$" 
fileNotExistError    db 	"Error: empty command line!$" 
 
 
string db 50, 52 dup ('$')   
word_ db 50, 52 dup ('$')
file_buffer db 202 dup ('$')  


messageOpenFile db "Open file...$"
messageCloseFile db "Closing...$"   

old_interrupt_offset     dw  0
old_interrupt_segment    dw  0          

win_buffer dw 2000 dup (?)

 
save_interrupt proc  
    push es  
    push ax
    push bx
    
    mov ah, 35h ; получить адрес обработчика прерывания
    mov al, 05h ; номер прерывания
    int 21h
    
    mov old_interrupt_segment, es 
    mov old_interrupt_offset, bx  
     
    pop bx   
    pop ax
    pop es
    ret
save_interrupt endp 
                                          
set_new_interrupt proc    
    cli     
    push ax
    push dx
    push es
       
    push ds   
    pop  es   ;es = ds
    
    mov dx, offset new_interrupt  
    mov ah, 25h                   
    mov al, 05h                   
    int 21h
    
    pop es
    pop ax
    pop dx 
    sti    
    
    ret
set_new_interrupt endp 

set_old_interrupt proc 
    cli
    push bx
    push es
    push ax  
    
    push ds   
    pop  es   ;es = ds
    
    mov dx, old_interrupt_offset
    mov ds, old_interrupt_segment 
    mov ah, 25h
    mov al, 05h
    int 21h
    
    pop ax
    pop es
    pop bx  
    sti 
    ret
set_old_interrupt endp

new_interrupt proc far        
   cli     ;запрет прерываний
   pushf   
   pusha   
   
   push ds
   push es
   
   push cs
   pop ds   ;ds = cs
   
   call cs:create_new_file  ;ñîçäà¸ì ôàéë print.txt
    
	;--------------
	mov ax,0B800h               ;Получение адреса экрана
	mov ds,ax                   ;Получение адреса для пересылки DS:SI   
	
	mov ax, cs
	mov es, ax

	mov di, offset win_buffer   ;Копирование консоли
	xor si, si
	mov cx, 2000                ;Размера экрана 80х25 
	rep movsw
            
	call process_buf
    mov ax, 2025
    call write_whole_buffer
    xor ax, ax
         
   ;call close
   call close_new_file
   pop es
   pop ds
   
   popa
   popf
   sti     
   iret
new_interrupt endp        

close_new_file proc
    pusha
    
    mov bx, new_file_id
    xor ax, ax    
    mov ah, 3Eh    
    int 21h
    
    popa
    ret
close_new_file endp                                               

open_file proc
    push dx

    mov ax, 3D02h  
    lea dx, file_name  
    int 21h       
    jc io_error

    pop dx
    ret
open_file endp

read_file proc 
    push bx
    push cx
    push dx
    
    mov bx, file_handle 
    mov ah, 3Fh           
    mov cx, 00C8h    ;200         
    mov dx, offset file_buffer
    int 21h   
    
    mov read_bytes, ax
	mov si, ax  
    lea si, file_buffer
    add si, ax
    mov [si], '$'
    
    pop dx
    pop cx
    pop bx
    ret
read_file endp

process_buf proc                  ;ФИЛЬТР БУФЕРА КОНСОЛИ
	mov ax, cs
	mov ds, ax
	mov cx, 2000
	mov di, offset win_buffer
	xor si, si
	xor bl, bl  
	
rewrite:                     ;Формирование выходного буфера
	mov ah, [di]
	mov byte ptr win_buffer[si], ah
	cmp bl, 79                      ;Пока не конец строки       
	jne Next_line_buffer
	mov byte ptr win_buffer[si+1], 0Dh ;Занесение перехода на следующую строку
	mov byte ptr win_buffer[si+2], 0Ah ;Занесение перехода на следующую строку
	inc si
	inc si
	mov bl, -1
	
Next_line_buffer:                   ;Переход на следующую строку в буфере
	inc bl
	inc si
	add di, 2  	
loop rewrite 

    ret
process_buf endp  

close_file proc
    pusha
    
    mov bx, file_handle
    xor ax, ax    
    mov ah, 3Eh    
    int 21h
    
    popa
    ret
close_file endp   

create_new_file proc
    pusha
        mov ah, 3Ch
        mov cx, 0 
        lea dx, new_file_name
        int 21h
        mov new_file_id, ax
        jc io_error       
    popa
    ret
create_new_file endp   

write_whole_buffer proc
    pusha
        lea dx, win_buffer      
        mov bx, new_file_id
        mov cx, ax
        mov ah, 40h   
        int 21h
        jc io_error  ;if (cx != 0) io_error    
    popa
    ret  
write_whole_buffer endp    
 

  
io_error: 
    cmp ax, 0003h
    je cannot_find_path
    cmp ax, 0004h
    je too_many_opened_files
    cmp ax, 0005h
    je cannot_access
    cmp ax, 0006h
    je invalid_identifier
     
    mov dx, offset IOError
    call outputString   
    int 20h
     
    cannot_find_path: 
    mov dx, offset pathError
    call outputString   
    int 20h 
    
    too_many_opened_files:   
    mov dx, offset openedFilesError
    call outputString   
    int 20h  
    
    cannot_access:
    mov dx, offset accessError
    call outputString   
    int 20h    
    
    invalid_identifier:
    mov dx, offset invalidIdentifierError
    call outputString   
    int 20h    
    
    max_size_of_word_error:
    mov dx, offset maxSizeOfWordError  
    call outputString
    int 20h  
    
    file_not_exist_error:
     mov dx, offset  fileNotExistError  
    call outputString
    int 20h    
    call outputString
    int 20h  
    
outputString proc    
    push ax        
     
    mov AH, 09h
    int 21h  
    call new_line  
  
    pop ax
    ret              
outputString endp    
print_string proc    
    push ax        
     
    mov AH, 09h
    int 21h   
 
    pop ax
    ret              
print_string endp  
       
                     
inputString proc  
    push ax       
                     
    mov AH, 0Ah
    int 21h          
    call new_line  
    
    pop ax
    ret      
inputString endp   
               
                  
new_line proc    
    pusha  
    
    mov DL, 0Dh
    mov Ah, 02h
    int 21h 
    
    mov DL, 0Ah
    mov Ah, 02h
    int 21h
    
    popa
    ret    
new_line endp                 


copyData proc  
    push ax  
      
    cmp cx, 0000h
    jz endCopyData   
    
    loop2:  
        mov ax, [si]
        mov [di], ax 
        inc si
        inc di
        loop loop2
   
    endCopyData:        
    pop ax  
ret
copyData endp    

main:
mov si, 81h
mov di, 0

skip_space:
    mov al, es[si]
    cmp al, 0dh
    je file_not_exist_error
    cmp al, 20h			; space
    jne read_file_name
    inc si 
    jmp skip_space
    
    read_file_name:
        mov file_name[di], al
        inc si
        mov al, es[si]
        cmp al, 20h
        je _open_file
        cmp al, 0dh
        je _open_file
        inc di  
        jmp read_file_name

	lea dx, messageOpenFile
	call outputString      
	
_open_file:   
	
	call save_interrupt
	call set_new_interrupt                                    
	
	mov dx, offset message_opening_file  
	call outputString 
	
	call open_file
	mov file_handle, ax
	
		
	mov dx, offset message_opened_file   
	call outputString 
	
	mov dx, offset hello_message   
	call outputString 
	
	mov dx, offset string
	call inputString      
    
reading:     
    call read_file
    
    mov ax, read_bytes   
    cmp ax, 0              
    je ending
    
    
    mov si, offset file_buffer
    mov di, offset word_
    
    mov dx, offset file_buffer                      
    call print_string 
       
    jmp reading

ending:
 
	call new_line 
    
	lea dx, messageCloseFile
	call outputString 

	mov bx, file_handle
	call close_file  



	mov dx, main
	int 27h
int 20h

end start