; ============================================================
;  SPACE INVADERS (concept edition), 32-bit x86 Windows, pure NASM
;
;  Graphics: a 384x256 32-bit DIB in memory, drawn pixel by pixel from
;  1-bit sprite rows (dw, MSB = leftmost pixel), shown with GDI
;  StretchDIBits at 2x.  No linker needed: the PE headers and import
;  tables are written by hand, so NASM alone builds the .exe.
;
;  Build:  nasm -f bin invaders_gdi.asm -o invaders_gdi.exe
;
;  Controls: LEFT/RIGHT (or A/D) move, SPACE shoot, Z use power-up,
;            UP/DOWN or 1-5 pick a power-up slot, P or ESC pause.
; ============================================================

bits 32

ImageBase   equ 0x400000
W           equ 384
H           equ 256
PIX         equ 0x409000        ; pixel buffer, 384*256*4 bytes (zero-filled by loader)
PBUL        equ 0x469000        ; pools: 32-byte entries
EBUL        equ 0x469100
PART        equ 0x469200
EXPL        equ 0x469E00
DROP        equ 0x469F00
STARS       equ 0x46A000        ; 64 stars, 16 bytes each
BUNK        equ 0x46A400        ; 6 bunkers * 60 cells
ALIEN       equ 0x46A600        ; 4 rows * 9 columns of hit points
NPBUL       equ 8
NEBUL       equ 8
NPART       equ 96
NEXPL       equ 8
NDROP       equ 6
NSTAR       equ 64

K_LEFT equ 0
K_RIGHT equ 1
K_UP equ 2
K_DOWN equ 3
K_SPACE equ 4
K_ENTER equ 5
K_ESC equ 6
K_Z equ 7
K_P equ 8
K_1 equ 9
NK equ 14

WSTYLE equ 0x00CA0000           ; caption, system menu, minimize box

; palette from the concept sheet (0x00RRGGBB)
C_BG        equ 0x05080E
C_PBLUE     equ 0x3AA7FF
C_PRED      equ 0xFF3038
C_SQUID     equ 0x31E887
C_CRAB      equ 0xFF3B3B
C_OCTO      equ 0xB84DFF
C_TANK      equ 0x1685FF
C_GOLD      equ 0xFFC52E
C_ORANGE    equ 0xFF8A18
C_UFOM      equ 0xFF2FD6
C_UFOC      equ 0x21D9FF
C_PUSHIELD  equ 0x318BFF
C_PUSPEED   equ 0x72F542
C_PUSPREAD  equ 0x2FD9FF
C_PULIFE    equ 0xFF3344
C_PUX2      equ 0xFFD43B
C_PBUL      equ 0x49C7FF
C_EBUL      equ 0xFF4040
C_EXPO      equ 0xFF7A18
C_EXPY      equ 0xFFE044
C_PWHITE    equ 0xE8F7FF
C_FRAME     equ 0x1E64D0

; ============================================================
;  PE headers
; ============================================================
section .hdr start=0 vstart=0

    db 'MZ'
    times 58 db 0
    dd 0x40
    db 'PE', 0, 0
    dw 0x014C
    dw 1
    dd 0
    dd 0, 0
    dw 224
    dw 0x0103
    dw 0x010B
    db 0, 0
    dd textsize
    dd 0
    dd 0
    dd start - ImageBase
    dd 0x1000
    dd 0x1000
    dd ImageBase
    dd 0x1000
    dd 0x200
    dw 4, 0
    dw 0, 0
    dw 4, 0
    dd 0
    dd 0x71000                  ; SizeOfImage
    dd 0x200
    dd 0
    dw 2                        ; subsystem: Windows GUI
    dw 0
    dd 0x100000, 0x1000
    dd 0x100000, 0x1000
    dd 0
    dd 16
    dd 0, 0
    dd imp_dir - ImageBase
    dd imp_dir_end - imp_dir
    times 14*8 db 0

    db '.text', 0, 0, 0
    dd 0x70000                  ; VirtualSize: code+data (32 KB) then frame buffer and pools
    dd 0x1000
    dd textsize
    dd 0x200
    dd 0, 0
    dw 0, 0
    dd 0xE0000020

    times 0x200 - ($ - $$) db 0

; ============================================================
;  Imports
; ============================================================
section .text follows=.hdr vstart=0x401000 align=512

text_start:
    jmp start

%macro KLIST 1
    %1 ExitProcess
    %1 Sleep
%endmacro
%macro ULIST 1
    %1 RegisterClassA
    %1 CreateWindowExA
    %1 DefWindowProcA
    %1 PeekMessageA
    %1 TranslateMessage
    %1 DispatchMessageA
    %1 PostQuitMessage
    %1 GetDC
    %1 ReleaseDC
    %1 GetAsyncKeyState
    %1 GetForegroundWindow
    %1 AdjustWindowRect
    %1 LoadCursorA
%endmacro
%macro GLIST 1
    %1 StretchDIBits
%endmacro
%macro MLIST 1
    %1 timeBeginPeriod
    %1 timeGetTime
%endmacro

%macro hint 1
hn_%1:
    dw 0
    %defstr hname %1
    db hname, 0
    align 2, db 0
%endmacro
%macro ilt_entry 1
    dd hn_%1 - ImageBase
%endmacro
%macro iat_entry 1
_%1: dd hn_%1 - ImageBase
%endmacro

imp_dir:
    dd k_ilt - ImageBase, 0, 0, k_name - ImageBase, k_iat - ImageBase
    dd u_ilt - ImageBase, 0, 0, u_name - ImageBase, u_iat - ImageBase
    dd g_ilt - ImageBase, 0, 0, g_name - ImageBase, g_iat - ImageBase
    dd m_ilt - ImageBase, 0, 0, m_name - ImageBase, m_iat - ImageBase
    dd 0, 0, 0, 0, 0
imp_dir_end:

k_name: db 'kernel32.dll', 0
u_name: db 'user32.dll', 0
g_name: db 'gdi32.dll', 0
m_name: db 'winmm.dll', 0
    align 4, db 0

k_ilt:
    KLIST ilt_entry
    dd 0
k_iat:
    KLIST iat_entry
    dd 0
u_ilt:
    ULIST ilt_entry
    dd 0
u_iat:
    ULIST iat_entry
    dd 0
g_ilt:
    GLIST ilt_entry
    dd 0
g_iat:
    GLIST iat_entry
    dd 0
m_ilt:
    MLIST ilt_entry
    dd 0
m_iat:
    MLIST iat_entry
    dd 0

    KLIST hint
    ULIST hint
    GLIST hint
    MLIST hint

; ============================================================
;  Program: startup and main loop
; ============================================================
%macro CALLSAVE 1
    push esi
    push ecx
    call %1
    pop ecx
    pop esi
%endmacro

start:
    push 32512                  ; IDC_ARROW
    push 0
    call [_LoadCursorA]
    mov [wc+24], eax
    push wc
    call [_RegisterClassA]
    push 0
    push WSTYLE
    push rect
    call [_AdjustWindowRect]
    push 0
    push ImageBase
    push 0
    push 0
    mov eax, [rect+12]
    sub eax, [rect+4]
    push eax                    ; height
    mov eax, [rect+8]
    sub eax, [rect]
    push eax                    ; width
    push 0x80000000
    push 0x80000000
    push WSTYLE | 0x10000000
    push s_wtitle
    push s_class
    push 0
    call [_CreateWindowExA]
    mov [hwnd], eax
    push 1
    call [_timeBeginPeriod]     ; 1 ms timer so Sleep(1) is accurate
    call [_timeGetTime]
    mov [nexttick], eax
    mov [seed], eax
    call initstars
    mov dword [scene], 0

mainloop:
.pump:
    push 1                      ; PM_REMOVE
    push 0
    push 0
    push 0
    push msg
    call [_PeekMessageA]
    test eax, eax
    jz .nomsg
    cmp dword [msg+4], 0x12     ; WM_QUIT
    je quit
    push msg
    call [_TranslateMessage]
    push msg
    call [_DispatchMessageA]
    jmp .pump
.nomsg:
    call pollkeys
    call gamestep
    call render
    call present
    mov ebx, [nexttick]         ; fixed 16 ms step (about 60 updates per second)
    add ebx, 16
    mov [nexttick], ebx
.wait:
    call [_timeGetTime]
    cmp eax, ebx
    jae .done
    push 1
    call [_Sleep]
    jmp .wait
.done:
    lea edx, [ebx+100]
    cmp eax, edx
    jbe mainloop
    mov [nexttick], eax         ; fell far behind: resync instead of racing to catch up
    jmp mainloop

quit:
    push 0
    call [_ExitProcess]

wndproc:                        ; stdcall (hwnd, msg, wparam, lparam)
    mov eax, [esp+8]
    cmp eax, 2                  ; WM_DESTROY
    jne .n1
    push 0
    call [_PostQuitMessage]
    xor eax, eax
    ret 16
.n1:
    cmp eax, 0x14               ; WM_ERASEBKGND
    jne .n2
    mov eax, 1
    ret 16
.n2:
    jmp [_DefWindowProcA]

present:
    push dword [hwnd]
    call [_GetDC]
    mov [hdc], eax
    push 0x00CC0020             ; SRCCOPY
    push 0                      ; DIB_RGB_COLORS
    push bmi
    push PIX
    push H
    push W
    push 0
    push 0
    push H*2
    push W*2
    push 0
    push 0
    push dword [hdc]
    call [_StretchDIBits]
    push dword [hdc]
    push dword [hwnd]
    call [_ReleaseDC]
    ret

; ------------------------------------------------------------
;  keyboard: kdown / kpress per logical key
; ------------------------------------------------------------
isvk:                           ; EAX = virtual key (0 = none) -> EAX = 1 if down
    test eax, eax
    jz .no
    push eax
    call [_GetAsyncKeyState]
    movzx eax, ax
    test eax, 0x8001            ; held now, or tapped since the last poll
    setnz al
    movzx eax, al
    ret
.no:
    xor eax, eax
    ret

pollkeys:
    call [_GetForegroundWindow]
    xor edx, edx
    cmp eax, [hwnd]
    sete dl
    mov [fg], edx
    xor esi, esi
.l:
    mov al, [kdown+esi]
    mov [kprev+esi], al
    xor edi, edi
    cmp dword [fg], 0
    je .st
    movzx eax, byte [keymap+esi*2]
    call isvk
    mov edi, eax
    movzx eax, byte [keymap+esi*2+1]
    call isvk
    or edi, eax
.st:
    mov eax, edi
    mov [kdown+esi], al
    movzx eax, byte [kprev+esi]
    xor eax, 1
    and eax, edi
    mov [kpress+esi], al
    inc esi
    cmp esi, NK
    jb .l
    ret

rnd:                            ; 15 random bits in EAX
    push edx
    mov eax, [seed]
    imul eax, eax, 1664525
    add eax, 1013904223
    mov [seed], eax
    shr eax, 16
    and eax, 0x7FFF
    pop edx
    ret

; ------------------------------------------------------------
;  drawing primitives (all preserve every register)
; ------------------------------------------------------------
fillrect:                       ; EAX=color EBX=x ECX=y EDX=w ESI=h (clipped)
    pushad
    mov edi, eax
    mov eax, ebx
    add eax, edx
    mov ebp, ecx
    add ebp, esi
    test ebx, ebx
    jge .xa
    xor ebx, ebx
.xa:
    cmp eax, W
    jle .xb
    mov eax, W
.xb:
    test ecx, ecx
    jge .ya
    xor ecx, ecx
.ya:
    cmp ebp, H
    jle .yb
    mov ebp, H
.yb:
    cmp ebx, eax
    jge .done
    cmp ecx, ebp
    jge .done
    sub eax, ebx
    mov edx, eax
    sub ebp, ecx
    mov eax, ecx
    imul eax, eax, W*4
    lea esi, [PIX+eax+ebx*4]
    mov eax, edi
    cld
.row:
    mov edi, esi
    mov ecx, edx
    rep stosd
    add esi, W*4
    dec ebp
    jnz .row
.done:
    popad
    ret

putpix:                         ; EAX=color EBX=x ECX=y
    cmp ebx, W
    jae .r
    cmp ecx, H
    jae .r
    push edx
    mov edx, ecx
    imul edx, edx, W
    add edx, ebx
    mov [PIX+edx*4], eax
    pop edx
.r: ret

blit:                           ; ESI=data EAX=color EBX=x ECX=y EDX=words/row EDI=rows
    pushad
    mov [b_x], ebx
    mov [b_col], eax
    mov [b_w], edx
    mov [b_rows], edi
    mov edi, ecx
.row:
    mov ebp, [b_x]
    mov eax, [b_w]
    mov [b_w2], eax
.wd:
    movzx eax, word [esi]
    add esi, 2
    mov ecx, 16
.px:
    shl ax, 1
    jnc .nx
    cmp ebp, W
    jae .nx
    cmp edi, H
    jae .nx
    push eax
    mov eax, edi
    imul eax, eax, W
    add eax, ebp
    mov edx, [b_col]
    mov [PIX+eax*4], edx
    pop eax
.nx:
    inc ebp
    dec ecx
    jnz .px
    dec dword [b_w2]
    jnz .wd
    inc edi
    dec dword [b_rows]
    jnz .row
    popad
    ret

blit16:
    push edx
    push edi
    mov edx, 1
    mov edi, 16
    call blit
    pop edi
    pop edx
    ret
blit24:
    push edx
    push edi
    mov edx, 2
    mov edi, 16
    call blit
    pop edi
    pop edx
    ret
blit32:
    push edx
    push edi
    mov edx, 2
    mov edi, 32
    call blit
    pop edi
    pop edx
    ret

drawtext:                       ; ESI=string EBX=x ECX=y EDX=scale EAX=color
    pushad
    mov [t_col], eax
    mov [t_scale], edx
    mov [t_x], ebx
    mov [t_y], ecx
.ch:
    movzx eax, byte [esi]
    inc esi
    test eax, eax
    jz .done
    sub eax, 32
    xor edi, edi
    cmp eax, 58
    ja .glyph
    movzx edi, word [font35+eax*2]
.glyph:
    xor ebp, ebp
.r:
    xor ebx, ebx
.c:
    lea ecx, [ebp+ebp*2]
    add ecx, ebx
    neg ecx
    add ecx, 14
    bt edi, ecx
    jnc .n
    pushad
    mov eax, [t_scale]
    imul ebx, eax
    imul ebp, eax
    add ebx, [t_x]
    mov ecx, ebp
    add ecx, [t_y]
    mov edx, eax
    mov esi, eax
    mov eax, [t_col]
    call fillrect
    popad
.n:
    inc ebx
    cmp ebx, 3
    jb .c
    inc ebp
    cmp ebp, 5
    jb .r
    mov eax, [t_scale]
    shl eax, 2
    add [t_x], eax
    jmp .ch
.done:
    popad
    ret

drawtextc:                      ; ESI=string ECX=y EDX=scale EAX=color, centred
    pushad
    mov [tc_col], eax
    mov edi, esi
    xor ebx, ebx
.l: cmp byte [edi], 0
    je .d
    inc edi
    inc ebx
    jmp .l
.d:
    mov eax, ebx
    shl eax, 2
    imul eax, edx
    sub eax, edx
    mov ebx, W
    sub ebx, eax
    shr ebx, 1
    mov [tc_x], ebx
    mov eax, [tc_col]
    call drawtext
    popad
    ret

numstr:                         ; EAX=value ECX=digits -> numbuf
    pushad
    mov edi, numbuf
    add edi, ecx
    mov byte [edi], 0
    mov ebx, 10
.l: dec edi
    xor edx, edx
    div ebx
    add dl, '0'
    mov [edi], dl
    dec ecx
    jnz .l
    popad
    ret

; ------------------------------------------------------------
;  pools
; ------------------------------------------------------------
findfree:                       ; ESI=pool ECX=count -> EAX=entry or 0
.l: cmp dword [esi], 0
    je .f
    add esi, 32
    dec ecx
    jnz .l
    xor eax, eax
    ret
.f: mov eax, esi
    ret

addpart:                        ; EBX=x ECX=y EDX=vx ESI=vy EDI=kind EAX=life
    pushad
    push eax
    push edi
    push esi
    push edx
    push ecx
    push ebx
    mov esi, PART
    mov ecx, NPART
    call findfree
    pop ebx
    pop ecx
    pop edx
    pop esi
    pop edi
    pop ebp
    test eax, eax
    jz .r
    shl ebx, 4
    shl ecx, 4
    mov dword [eax], 1
    mov [eax+4], ebx
    mov [eax+8], ecx
    mov [eax+12], edx
    mov [eax+16], esi
    mov [eax+20], edi
    mov [eax+24], ebp
.r: popad
    ret

burst:                          ; EBX=x ECX=y EDI=kind EAX=count
    pushad
    mov ebp, eax
    mov [bu_x], ebx
    mov [bu_y], ecx
    mov [bu_k], edi
.l: test ebp, ebp
    jz .r
    call rnd
    and eax, 31
    sub eax, 16
    mov edx, eax
    call rnd
    and eax, 31
    sub eax, 22
    mov esi, eax
    call rnd
    and eax, 15
    add eax, 14
    mov ebx, [bu_x]
    mov ecx, [bu_y]
    mov edi, [bu_k]
    call addpart
    dec ebp
    jmp .l
.r: popad
    ret

addexpl:                        ; EBX=cx ECX=cy EAX=kind (0 small, 1 medium, 2 large)
    pushad
    mov ebp, eax
    push ebx
    push ecx
    mov esi, EXPL
    mov ecx, NEXPL
    call findfree
    pop ecx
    pop ebx
    test eax, eax
    jz .r
    mov dword [eax], 1
    mov [eax+4], ebx
    mov [eax+8], ecx
    mov [eax+20], ebp
    mov dword [eax+24], 0
.r: popad
    ret

adddrop:                        ; EAX=type EBX=x ECX=y (centre)
    pushad
    mov ebp, eax
    push ebx
    push ecx
    mov esi, DROP
    mov ecx, NDROP
    call findfree
    pop ecx
    pop ebx
    test eax, eax
    jz .r
    mov dword [eax], 1
    mov [eax+4], ebx
    mov [eax+8], ecx
    mov [eax+20], ebp
.r: popad
    ret

addebul:                        ; EBX=x ECX=y EDX=dx
    pushad
    push ebx
    push ecx
    push edx
    mov esi, EBUL
    mov ecx, NEBUL
    call findfree
    pop edx
    pop ecx
    pop ebx
    test eax, eax
    jz .r
    mov dword [eax], 1
    mov [eax+4], ebx
    mov [eax+8], ecx
    mov [eax+12], edx
    mov edx, 2
    cmp dword [stage], 3
    jb .s
    inc edx
.s: mov [eax+16], edx
.r: popad
    ret

addpbul:                        ; EBX=x EDX=dx (starts just above the ship)
    pushad
    push ebx
    push edx
    mov esi, PBUL
    mov ecx, NPBUL
    call findfree
    pop edx
    pop ebx
    test eax, eax
    jz .r
    mov dword [eax], 1
    mov [eax+4], ebx
    mov ecx, [py]
    add ecx, 2
    mov [eax+8], ecx
    mov [eax+12], edx
    mov dword [eax+16], -5
.r: popad
    ret

addscore:                       ; EAX = base points (doubled while Score x2 is active)
    cmp dword [t_x2], 0
    je .a
    add eax, eax
.a: add [score], eax
    ret

; ============================================================
;  Game logic
; ============================================================
gamestep:
    inc dword [frame]
    cmp dword [scene], 3
    je .skipbg
    call upd_bg
.skipbg:
    mov eax, [scene]
    test eax, eax
    jz menu_step
    cmp eax, 1
    je opt_step
    cmp eax, 2
    je play_step
    cmp eax, 3
    je pause_step
    jmp over_step

initstars:
    xor ebp, ebp
.l:
    call rnd
    xor edx, edx
    mov ecx, W
    div ecx
    mov eax, ebp
    shl eax, 4
    mov [STARS+eax], edx
    push eax
    call rnd
    xor edx, edx
    mov ecx, H
    div ecx
    pop eax
    mov [STARS+eax+4], edx
    xor ecx, ecx
    cmp ebp, 32
    jb .ly
    inc ecx
    cmp ebp, 56
    jb .ly
    inc ecx
.ly:
    mov [STARS+eax+8], ecx
    mov [STARS+eax+12], ebp
    inc ebp
    cmp ebp, NSTAR
    jb .l
    mov dword [gx0], 70
    mov dword [gy0], 60
    mov dword [gx1], 290
    mov dword [gy1], 170
    ret

upd_bg:
    xor ebp, ebp
.l:
    mov esi, ebp
    shl esi, 4
    mov eax, [STARS+esi+8]
    mov ecx, [frame]
    cmp eax, 0
    jne .a
    test cl, 3
    jnz .n
    jmp .mv
.a: cmp eax, 1
    jne .mv
    test cl, 1
    jnz .n
.mv:
    inc dword [STARS+esi+4]
    cmp dword [STARS+esi+4], H
    jl .n
    mov dword [STARS+esi+4], 0
    call rnd
    xor edx, edx
    mov ecx, W
    div ecx
    mov [STARS+esi], edx
.n: inc ebp
    cmp ebp, NSTAR
    jb .l
    test byte [frame], 3
    jnz .r
    inc dword [gy0]
    cmp dword [gy0], H+16
    jl .g1
    mov dword [gy0], -16
.g1:
    inc dword [gy1]
    cmp dword [gy1], H+16
    jl .r
    mov dword [gy1], -16
.r: ret

; ------------------------------------------------------------
;  menus
; ------------------------------------------------------------
menu_nav:                       ; ECX = item count -> EAX = 1 when SPACE/ENTER pressed
    cmp byte [kpress+K_UP], 0
    je .nu
    dec dword [menusel]
    jns .nu
    lea eax, [ecx-1]
    mov [menusel], eax
.nu:
    cmp byte [kpress+K_DOWN], 0
    je .nd
    inc dword [menusel]
    cmp [menusel], ecx
    jb .nd
    mov dword [menusel], 0
.nd:
    xor eax, eax
    cmp byte [kpress+K_SPACE], 0
    jne .act
    cmp byte [kpress+K_ENTER], 0
    je .r
.act:
    mov eax, 1
.r: ret

menu_step:
    mov ecx, 3
    call menu_nav
    test eax, eax
    jz .r
    mov eax, [menusel]
    test eax, eax
    jz .start
    cmp eax, 1
    je .opt
    jmp quit
.start:
    call newgame
    mov dword [scene], 2
    ret
.opt:
    mov dword [scene], 1
    mov dword [menusel], 0
.r: ret

opt_step:
    cmp byte [kpress+K_ESC], 0
    jne .back
    mov ecx, 2
    call menu_nav
    mov edx, eax
    cmp dword [menusel], 0
    jne .item1
    cmp byte [kpress+K_LEFT], 0
    je .nl
    mov eax, [shipcol]
    dec eax
    jns .sl
    mov eax, 2
.sl:
    mov [shipcol], eax
.nl:
    cmp byte [kpress+K_RIGHT], 0
    jne .fwd
    test edx, edx
    jz .r
.fwd:
    mov eax, [shipcol]
    inc eax
    cmp eax, 3
    jb .sr
    xor eax, eax
.sr:
    mov [shipcol], eax
    ret
.item1:
    test edx, edx
    jz .r
.back:
    mov dword [scene], 0
    mov dword [menusel], 1
.r: ret

pause_step:
    cmp byte [kpress+K_P], 0
    jne .resume
    cmp byte [kpress+K_ESC], 0
    jne .resume
    mov ecx, 3
    call menu_nav
    test eax, eax
    jz .r
    mov eax, [menusel]
    test eax, eax
    jz .resume
    cmp eax, 1
    je .restart
    jmp quit
.restart:
    call newgame
.resume:
    mov dword [scene], 2
.r: ret

over_step:
    mov ecx, 2
    call menu_nav
    test eax, eax
    jz .r
    cmp dword [menusel], 0
    jne quit
    call newgame
    mov dword [scene], 2
.r: ret

; ------------------------------------------------------------
;  new game / waves
; ------------------------------------------------------------
newgame:
    cld
    mov edi, PBUL
    mov ecx, 1008
    xor eax, eax
    rep stosd
    mov dword [score], 0
    mov dword [lives], 3
    mov dword [stage], 1
    mov dword [wave], 1
    mov dword [px], 184
    mov dword [py], 214
    mov dword [pcool], 0
    mov dword [flash], 0
    mov dword [invuln], 0
    mov dword [bank], 0
    mov dword [pdead], 0
    mov dword [t_shield], 0
    mov dword [t_speed], 0
    mov dword [t_spread], 0
    mov dword [t_x2], 0
    mov dword [sel], 0
    mov dword [uon], 0
    mov dword [utimer], 900
    mov dword [wclear], 0
    mov edi, inv
    mov ecx, 5
    xor eax, eax
    rep stosd
    call initbunkers
    call initformation
    ret

initbunkers:
    cld
    mov edi, BUNK
    mov ecx, 6
.l: mov esi, bunk_tpl
    push ecx
    mov ecx, 60
    rep movsb
    pop ecx
    dec ecx
    jnz .l
    ret

initformation:
    xor ebp, ebp
.rr:
    xor edi, edi
.cc:
    lea eax, [ebp+ebp*8]
    add eax, edi
    mov dl, 1
    cmp byte [coltype+edi], 3
    jne .hp
    mov dl, 2
.hp:
    mov [ALIEN+eax], dl
    inc edi
    cmp edi, 9
    jb .cc
    inc ebp
    cmp ebp, 4
    jb .rr
    mov dword [acnt], 36
    mov dword [fx], 96
    mov eax, [stage]
    dec eax
    cmp eax, 3
    jbe .sy
    mov eax, 3
.sy:
    lea eax, [eax+eax*2]
    add eax, 60
    mov [fy], eax
    mov dword [fdir], 2
    mov dword [acount], 0
    mov dword [anim], 0
    mov dword [bon], 0
    mov dword [bflash], 0
    cmp dword [wave], 3
    jne .r
    mov dword [bon], 1          ; the boss comes on the third wave of every stage
    mov dword [bossx], -24
    mov dword [bdir], 1
    mov eax, [stage]
    add eax, eax
    add eax, 10
    mov [bhp], eax
    mov dword [bcool], 90
.r: ret

nextwave:
    inc dword [wave]
    cmp dword [wave], 4
    jb .same
    mov dword [wave], 1
    inc dword [stage]
    call initbunkers
.same:
    call initformation
    ret

; ------------------------------------------------------------
;  playing
; ------------------------------------------------------------
play_step:
    cmp byte [kpress+K_P], 0
    jne .pause
    cmp byte [kpress+K_ESC], 0
    je .go
.pause:
    mov dword [scene], 3
    mov dword [menusel], 0
    ret
.go:
    cmp dword [pdead], 0
    je .alive
    dec dword [pdead]
    jnz .world
    mov dword [scene], 4
    mov dword [menusel], 0
    ret
.alive:
    call player_step
.world:
    call upd_pbul
    call upd_ebul
    call upd_drops
    call upd_part
    call upd_expl
    call upd_formation
    call upd_boss
    call upd_ufo
    call enemy_fire
    call col_pbul
    call col_ebul
    call col_drops
    call check_wave
    ret

player_step:
    cmp dword [pcool], 0
    je .a
    dec dword [pcool]
.a: cmp dword [invuln], 0
    je .b
    dec dword [invuln]
.b: cmp dword [flash], 0
    je .c
    dec dword [flash]
.c: cmp dword [t_shield], 0
    je .d
    dec dword [t_shield]
.d: cmp dword [t_speed], 0
    je .e
    dec dword [t_speed]
.e: cmp dword [t_spread], 0
    je .f
    dec dword [t_spread]
.f: cmp dword [t_x2], 0
    je .g
    dec dword [t_x2]
.g:
    mov eax, 2
    cmp dword [t_speed], 0
    je .sp
    mov eax, 4
.sp:
    mov dword [bank], 0
    cmp byte [kdown+K_LEFT], 0
    je .nl
    sub [px], eax
    mov dword [bank], 1
.nl:
    cmp byte [kdown+K_RIGHT], 0
    je .nr
    add [px], eax
    mov dword [bank], 2
.nr:
    cmp dword [px], 6
    jge .c1
    mov dword [px], 6
.c1:
    cmp dword [px], 362
    jle .c2
    mov dword [px], 362
.c2:
    cmp dword [t_speed], 0      ; speed boost leaves a green-white spark trail
    je .nt
    test byte [frame], 1
    jnz .nt
    mov ebx, [px]
    add ebx, 8
    mov ecx, [py]
    add ecx, 16
    xor edx, edx
    mov esi, 24
    xor edi, edi
    mov eax, 10
    call addpart
.nt:
    cmp dword [pcool], 0        ; fire
    jne .nofire
    cmp byte [kdown+K_SPACE], 0
    je .nofire
    mov ebx, [px]
    add ebx, 8
    xor edx, edx
    call addpbul
    cmp dword [t_spread], 0
    je .cd
    mov edx, -2
    call addpbul
    mov edx, 2
    call addpbul
.cd:
    mov dword [pcool], 14
    mov dword [flash], 6
.nofire:
    cmp byte [kpress+K_UP], 0   ; power-up slot selection
    je .nu
    mov eax, [sel]
    inc eax
    cmp eax, 5
    jb .su
    xor eax, eax
.su:
    mov [sel], eax
.nu:
    cmp byte [kpress+K_DOWN], 0
    je .nd
    mov eax, [sel]
    dec eax
    jns .sd
    mov eax, 4
.sd:
    mov [sel], eax
.nd:
    xor ecx, ecx
.k: cmp byte [kpress+K_1+ecx], 0
    je .kn
    mov [sel], ecx
.kn:
    inc ecx
    cmp ecx, 5
    jb .k
    cmp byte [kpress+K_Z], 0    ; use the selected power-up
    je .done
    mov ebx, [sel]
    cmp dword [inv+ebx*4], 0
    je .done
    cmp ebx, 3
    jne .go
    cmp dword [lives], 5
    jge .done
.go:
    dec dword [inv+ebx*4]
    test ebx, ebx
    jnz .p1
    mov dword [t_shield], 420
    jmp .fx
.p1:
    cmp ebx, 1
    jne .p2
    mov dword [t_speed], 480
    jmp .fx
.p2:
    cmp ebx, 2
    jne .p3
    mov dword [t_spread], 480
    jmp .fx
.p3:
    cmp ebx, 3
    jne .p4
    inc dword [lives]
    jmp .fx
.p4:
    mov dword [t_x2], 600
.fx:
    mov ebx, [px]
    add ebx, 8
    mov ecx, [py]
    add ecx, 8
    mov eax, 10
    xor edi, edi
    call burst
.done:
    ret

; ------------------------------------------------------------
;  object updates
; ------------------------------------------------------------
upd_pbul:
    mov esi, PBUL
    mov ecx, NPBUL
.l: cmp dword [esi], 0
    je .n
    mov eax, [esi+12]
    add [esi+4], eax
    mov eax, [esi+16]
    add [esi+8], eax
    cmp dword [esi+8], 22
    jl .kill
    cmp dword [esi+4], 0
    jl .kill
    cmp dword [esi+4], W
    jge .kill
    test byte [frame], 1        ; blue trail behind the bullet
    jnz .n
    pushad
    mov ebx, [esi+4]
    mov ecx, [esi+8]
    add ecx, 7
    xor edx, edx
    xor esi, esi
    mov edi, 2
    mov eax, 10
    call addpart
    popad
    jmp .n
.kill:
    mov dword [esi], 0
.n: add esi, 32
    dec ecx
    jnz .l
    ret

upd_ebul:
    mov esi, EBUL
    mov ecx, NEBUL
.l: cmp dword [esi], 0
    je .n
    mov eax, [esi+12]
    add [esi+4], eax
    mov eax, [esi+16]
    add [esi+8], eax
    cmp dword [esi+8], 238
    jg .k
    cmp dword [esi+4], -4
    jl .k
    cmp dword [esi+4], W+4
    jg .k
    jmp .n
.k: mov dword [esi], 0
.n: add esi, 32
    dec ecx
    jnz .l
    ret

upd_drops:
    mov esi, DROP
    mov ecx, NDROP
.l: cmp dword [esi], 0
    je .n
    inc dword [esi+8]
    cmp dword [esi+8], 240
    jle .n
    mov dword [esi], 0
.n: add esi, 32
    dec ecx
    jnz .l
    ret

upd_part:
    mov esi, PART
    mov ecx, NPART
.l: cmp dword [esi], 0
    je .n
    mov eax, [esi+12]
    add [esi+4], eax
    mov eax, [esi+16]
    add [esi+8], eax
    cmp dword [esi+20], 1       ; debris falls
    jne .ng
    add dword [esi+16], 2
.ng:
    dec dword [esi+24]
    jg .n
    mov dword [esi], 0
.n: add esi, 32
    dec ecx
    jnz .l
    ret

upd_expl:
    mov esi, EXPL
    mov ecx, NEXPL
.l: cmp dword [esi], 0
    je .n
    inc dword [esi+24]
    mov eax, [esi+20]
    movzx eax, byte [expdur+eax]
    cmp [esi+24], eax
    jb .n
    mov dword [esi], 0
.n: add esi, 32
    dec ecx
    jnz .l
    ret

upd_formation:
    cmp dword [acnt], 0
    je .r
    inc dword [acount]
    mov eax, [acnt]
    shr eax, 3
    inc eax
    mov ecx, [stage]
    dec ecx
    sub eax, ecx
    cmp eax, 1
    jge .ok
    mov eax, 1
.ok:
    cmp [acount], eax
    jb .r
    mov dword [acount], 0
    xor dword [anim], 1
    mov edx, 8                  ; leftmost live column
    xor ebx, ebx                ; rightmost live column
    mov dword [maxr], 0         ; lowest live row
    xor ebp, ebp
.rr:
    xor edi, edi
.cc:
    lea eax, [ebp+ebp*8]
    add eax, edi
    cmp byte [ALIEN+eax], 0
    je .nx
    cmp edi, edx
    jae .a
    mov edx, edi
.a: cmp edi, ebx
    jbe .b
    mov ebx, edi
.b: mov [maxr], ebp
.nx:
    inc edi
    cmp edi, 9
    jb .cc
    inc ebp
    cmp ebp, 4
    jb .rr
    mov eax, [fdir]
    imul ecx, edx, 22
    add ecx, [fx]
    add ecx, eax                ; left edge after the step
    imul esi, ebx, 22
    add esi, [fx]
    add esi, 16
    add esi, eax                ; right edge after the step
    cmp ecx, 6
    jl .turn
    cmp esi, 378
    jg .turn
    add [fx], eax
    jmp .chk
.turn:
    neg dword [fdir]
    add dword [fy], 8
.chk:
    mov eax, [maxr]
    imul eax, eax, 18
    add eax, [fy]
    add eax, 12
    cmp eax, 184                ; invaders reached the defenders
    jl .r
    cmp dword [pdead], 0
    jne .r
    mov dword [invuln], 0
    mov dword [t_shield], 0
    mov dword [lives], 1
    call player_hit
.r: ret

upd_boss:
    cmp dword [bflash], 0
    je .a
    dec dword [bflash]
.a: cmp dword [bon], 0
    je .r
    mov eax, [bdir]
    add [bossx], eax
    cmp dword [bdir], 0
    jl .left
    cmp dword [bossx], 354
    jl .fire
    neg dword [bdir]
    jmp .fire
.left:
    cmp dword [bossx], 6
    jg .fire
    neg dword [bdir]
.fire:
    dec dword [bcool]
    jg .r
    mov dword [bcool], 70
    mov ebx, [bossx]
    add ebx, 12
    mov ecx, 56
    mov edx, -1
    call addebul
    xor edx, edx
    call addebul
    mov edx, 1
    call addebul
.r: ret

upd_ufo:
    cmp dword [uon], 0
    jne .move
    cmp dword [acnt], 0
    je .r
    dec dword [utimer]
    jg .r
    mov dword [uon], 1
    call rnd
    test al, 1
    jz .fromright
    mov dword [ux], -24
    mov dword [udir], 1
    jmp .val
.fromright:
    mov dword [ux], 384
    mov dword [udir], -1
.val:
    call rnd
    and eax, 3
    mov eax, [ufovals+eax*4]
    mov [uval], eax
    ret
.move:
    mov eax, [udir]
    add [ux], eax
    cmp dword [ux], -30
    jl .off
    cmp dword [ux], 390
    jg .off
    ret
.off:
    mov dword [uon], 0
    call rnd
    and eax, 0x1FF
    add eax, 900
    mov [utimer], eax
.r: ret

enemy_fire:
    cmp dword [acnt], 0
    je .r
    call rnd
    mov ecx, [stage]
    lea ecx, [ecx+ecx*2]
    neg ecx
    add ecx, 50
    cmp ecx, 16
    jge .n
    mov ecx, 16
.n: xor edx, edx
    div ecx
    test edx, edx
    jnz .r
    call rnd
    xor edx, edx
    mov ecx, 9
    div ecx
    mov ebp, edx                ; random column
    mov edi, 3
.f: lea eax, [edi+edi*8]
    add eax, ebp
    cmp byte [ALIEN+eax], 0
    jne .found
    dec edi
    jns .f
.r: ret
.found:
    imul ebx, ebp, 22
    add ebx, [fx]
    add ebx, 8
    imul ecx, edi, 18
    add ecx, [fy]
    add ecx, 12
    xor edx, edx
    call addebul
    ret

check_wave:
    cmp dword [acnt], 0
    jne .r
    cmp dword [bon], 0
    jne .r
    cmp dword [wclear], 0
    jne .tick
    mov dword [wclear], 90
    ret
.tick:
    dec dword [wclear]
    jnz .r
    call nextwave
.r: ret

; ------------------------------------------------------------
;  collisions
; ------------------------------------------------------------
randdrop:                       ; EBX=x ECX=y: drop a random power-up
    push ebx
    push ecx
    call rnd
    xor edx, edx
    mov ecx, 5
    div ecx
    mov eax, edx
    pop ecx
    pop ebx
    call adddrop
    ret

player_hit:
    cmp dword [invuln], 0
    jne .absorb
    cmp dword [t_shield], 0
    jne .absorb
    dec dword [lives]
    mov ebx, [px]
    add ebx, 8
    mov ecx, [py]
    add ecx, 8
    mov eax, 2
    call addexpl
    mov eax, 14
    xor edi, edi
    call burst
    mov eax, 10
    mov edi, 1
    call burst
    mov dword [invuln], 150
    cld
    mov edi, EBUL
    mov ecx, NEBUL*8
    xor eax, eax
    rep stosd
    cmp dword [lives], 0
    jg .r
    mov dword [pdead], 90
    ret
.absorb:
    mov ebx, [px]
    add ebx, 8
    mov ecx, [py]
    mov eax, 4
    xor edi, edi
    call burst
.r: ret

cellkill:                       ; ECX=row EDX=col, [bk_i]=bunker -> EAX=1 if a cell died
    cmp ecx, 6
    jae .no
    cmp edx, 10
    jae .no
    mov eax, [bk_i]
    imul eax, eax, 60
    lea ecx, [ecx+ecx*4]
    add ecx, ecx
    add eax, ecx
    add eax, edx
    cmp byte [BUNK+eax], 0
    je .no
    mov byte [BUNK+eax], 0
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

bunkhit:                        ; EAX=x EBX=y EDX=dy (+1 down / -1 up) -> EAX=1 if hit
    mov [bk_dy], edx
    sub ebx, 186
    cmp ebx, 18
    jae .no
    sub eax, 27
    cmp eax, 360
    jae .no
    xor edx, edx
    mov ecx, 60
    div ecx
    cmp edx, 30
    jae .no
    mov [bk_i], eax
    mov eax, edx
    xor edx, edx
    mov ecx, 3
    div ecx
    mov [bk_c], eax
    mov eax, ebx
    xor edx, edx
    div ecx
    mov [bk_r], eax
    mov ecx, eax
    mov edx, [bk_c]
    call cellkill
    test eax, eax
    jz .no
    mov ecx, [bk_r]             ; the bite goes one cell deeper
    add ecx, [bk_dy]
    mov edx, [bk_c]
    call cellkill
    call rnd                    ; and chips one side neighbour
    mov ecx, [bk_r]
    mov edx, [bk_c]
    test al, 1
    jz .l
    inc edx
    jmp .k
.l: dec edx
.k: call cellkill
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

pb_bunker:                      ; ESI = player bullet
    mov eax, [esi+4]
    mov ebx, [esi+8]
    mov edx, -1
    push esi
    call bunkhit
    pop esi
    test eax, eax
    jnz .r
    mov eax, [esi+4]
    mov ebx, [esi+8]
    add ebx, 3
    mov edx, -1
    push esi
    call bunkhit
    pop esi
.r: ret

eb_bunker:                      ; ESI = enemy bullet
    mov eax, [esi+4]
    mov ebx, [esi+8]
    add ebx, 4
    mov edx, 1
    push esi
    call bunkhit
    pop esi
    test eax, eax
    jnz .r
    mov eax, [esi+4]
    mov ebx, [esi+8]
    mov edx, 1
    push esi
    call bunkhit
    pop esi
.r: ret

alien_hit:                      ; EBP=row EDI=col
    lea eax, [ebp+ebp*8]
    add eax, edi
    dec byte [ALIEN+eax]
    jnz .dmg
    dec dword [acnt]
    movzx edx, byte [coltype+edi]
    mov eax, [pts+edx*4]
    call addscore
    imul ebx, edi, 22
    add ebx, [fx]
    add ebx, 8
    imul ecx, ebp, 18
    add ecx, [fy]
    add ecx, 8
    mov [ah_x], ebx
    mov [ah_y], ecx
    xor eax, eax
    call addexpl
    mov eax, 6
    xor edi, edi
    call burst
    mov eax, 4
    mov edi, 1
    call burst
    call rnd
    xor edx, edx
    mov ecx, 100
    div ecx
    cmp edx, 14
    jge .r
    mov ebx, [ah_x]
    mov ecx, [ah_y]
    call randdrop
.r: ret
.dmg:
    imul ebx, edi, 22
    add ebx, [fx]
    add ebx, 8
    imul ecx, ebp, 18
    add ecx, [fy]
    add ecx, 8
    mov eax, 4
    xor edi, edi
    call burst
    ret

pb_aliens:                      ; ESI = player bullet -> EAX=1 on hit
    cmp dword [acnt], 0
    je .no
    mov eax, [esi+4]
    mov [h_x], eax
    mov eax, [esi+8]
    mov [h_y], eax
    xor ebp, ebp
.rr:
    xor edi, edi
.cc:
    lea eax, [ebp+ebp*8]
    add eax, edi
    cmp byte [ALIEN+eax], 0
    je .nx
    imul ecx, edi, 22
    add ecx, [fx]
    sub ecx, 2
    imul edx, ebp, 18
    add edx, [fy]
    sub edx, 2
    mov eax, [h_x]
    sub eax, ecx
    cmp eax, 20
    jae .nx
    mov eax, [h_y]
    sub eax, edx
    cmp eax, 19
    jae .nx
    call alien_hit
    mov eax, 1
    ret
.nx:
    inc edi
    cmp edi, 9
    jb .cc
    inc ebp
    cmp ebp, 4
    jb .rr
.no:
    xor eax, eax
    ret

pb_boss:
    cmp dword [bon], 0
    je .no
    mov eax, [esi+4]
    sub eax, [bossx]
    add eax, 2
    cmp eax, 28
    jae .no
    mov eax, [esi+8]
    sub eax, 35
    cmp eax, 25
    jae .no
    mov dword [bflash], 4
    mov ebx, [esi+4]
    mov ecx, [esi+8]
    mov eax, 5
    xor edi, edi
    call burst
    dec dword [bhp]
    jg .hit
    mov dword [bon], 0          ; boss destroyed
    mov eax, 500
    call addscore
    mov ebx, [bossx]
    add ebx, 12
    mov ecx, 48
    mov eax, 2
    call addexpl
    mov eax, 20
    xor edi, edi
    call burst
    mov eax, 14
    mov edi, 1
    call burst
    sub ebx, 10
    call randdrop
    add ebx, 20
    call randdrop
.hit:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

pb_ufo:
    cmp dword [uon], 0
    je .no
    mov eax, [esi+4]
    sub eax, [ux]
    add eax, 2
    cmp eax, 28
    jae .no
    mov eax, [esi+8]
    sub eax, 20
    cmp eax, 21
    jae .no
    mov dword [uon], 0
    call rnd
    and eax, 0x1FF
    add eax, 900
    mov [utimer], eax
    mov eax, [uval]
    call addscore
    mov ebx, [ux]
    add ebx, 12
    mov ecx, 30
    mov eax, 1
    call addexpl
    mov eax, 10
    xor edi, edi
    call burst
    call randdrop
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

col_pbul:
    mov esi, PBUL
    mov ecx, NPBUL
.l: cmp dword [esi], 0
    je .n
    CALLSAVE pb_bunker
    test eax, eax
    jnz .kill
    CALLSAVE pb_aliens
    test eax, eax
    jnz .kill
    CALLSAVE pb_boss
    test eax, eax
    jnz .kill
    CALLSAVE pb_ufo
    test eax, eax
    jz .n
.kill:
    mov dword [esi], 0
.n: add esi, 32
    dec ecx
    jnz .l
    ret

col_ebul:
    mov esi, EBUL
    mov ecx, NEBUL
.l: cmp dword [esi], 0
    je .n
    CALLSAVE eb_bunker
    test eax, eax
    jnz .kill
    cmp dword [pdead], 0
    jne .n
    mov eax, [esi+4]
    sub eax, [px]
    inc eax
    cmp eax, 18
    jae .n
    mov eax, [esi+8]
    add eax, 4
    sub eax, [py]
    sub eax, 2
    cmp eax, 12
    jae .n
    CALLSAVE player_hit
.kill:
    mov dword [esi], 0
.n: add esi, 32
    dec ecx
    jnz .l
    ret

col_drops:
    cmp dword [pdead], 0
    jne .r
    mov esi, DROP
    mov ecx, NDROP
.l: cmp dword [esi], 0
    je .n
    mov eax, [esi+4]
    sub eax, [px]
    add eax, 8
    cmp eax, 32
    jae .n
    mov eax, [esi+8]
    sub eax, [py]
    add eax, 8
    cmp eax, 32
    jae .n
    mov eax, [esi+20]
    cmp dword [inv+eax*4], 9
    jge .full
    inc dword [inv+eax*4]
.full:
    mov dword [esi], 0
    push ecx
    mov ebx, [esi+4]
    mov ecx, [esi+8]
    mov eax, 6
    xor edi, edi
    call burst
    pop ecx
.n: add esi, 32
    dec ecx
    jnz .l
.r: ret

; ============================================================
;  Rendering
; ============================================================
render:
    cld
    mov edi, PIX
    mov ecx, W*H
    mov eax, C_BG
    rep stosd
    call draw_bg
    mov eax, [scene]
    test eax, eax
    jz draw_menu
    cmp eax, 1
    je draw_options
    call draw_play
    mov eax, [scene]
    cmp eax, 3
    je draw_pause
    cmp eax, 4
    je draw_over
    ret

draw_bg:
    mov ebx, [gx0]
    mov ecx, [gy0]
    mov esi, galaxy_glow
    mov eax, 0x2A2060
    call blit16
    mov esi, galaxy_core
    mov eax, 0x7A55D8
    call blit16
    mov ebx, [gx1]
    mov ecx, [gy1]
    mov esi, galaxy_glow
    mov eax, 0x1E2A66
    call blit16
    mov esi, galaxy_core
    mov eax, 0x5577E0
    call blit16
    xor ebp, ebp
.l:
    mov esi, ebp
    shl esi, 4
    mov ebx, [STARS+esi]
    mov ecx, [STARS+esi+4]
    mov edx, [STARS+esi+8]
    cmp edx, 0
    jne .l1
    mov eax, 0x26324E
    call putpix
    jmp .n
.l1:
    cmp edx, 1
    jne .l2
    mov eax, 0x7088C8
    call putpix
    jmp .n
.l2:
    mov eax, [frame]
    shr eax, 4
    add eax, [STARS+esi+12]
    test al, 1
    mov edi, sparkle_big
    jz .bg
    mov edi, sparkle_small
.bg:
    push ebx
    push ecx
    sub ebx, 8
    sub ecx, 8
    mov esi, edi
    mov eax, 0x3C60C8
    call blit16
    pop ecx
    pop ebx
    mov eax, C_PWHITE
    call putpix
.n: inc ebp
    cmp ebp, NSTAR
    jb .l
    ret

; ------------------------------------------------------------
draw_play:
    call draw_bunk
    call draw_aliens
    call draw_boss
    call draw_ufo
    call draw_drops
    call draw_ship
    call draw_bullets
    call draw_parts
    call draw_expls
    call draw_shield
    call draw_hud
    cmp dword [wclear], 0
    je .r
    mov esi, s_waveclear
    mov ecx, 110
    mov edx, 3
    mov eax, C_PWHITE
    call drawtextc
.r: ret

draw_bunk:
    xor ebp, ebp
.b: xor edi, edi
.c: imul eax, ebp, 60
    add eax, edi
    cmp byte [BUNK+eax], 0
    je .n
    mov eax, edi
    xor edx, edx
    mov ecx, 10
    div ecx
    imul ebx, ebp, 60
    add ebx, 27
    lea edx, [edx+edx*2]
    add ebx, edx
    lea ecx, [eax+eax*2]
    add ecx, 186
    mov eax, 0x2DB85C
    mov edx, 3
    mov esi, 3
    call fillrect
    mov eax, 0x86F5A4
    mov edx, 1
    mov esi, 1
    call fillrect
.n: inc edi
    cmp edi, 60
    jb .c
    inc ebp
    cmp ebp, 6
    jb .b
    ret

draw_aliens:
    cmp dword [acnt], 0
    je .r
    xor ebp, ebp
.rr:
    xor edi, edi
.cc:
    lea eax, [ebp+ebp*8]
    add eax, edi
    movzx edx, byte [ALIEN+eax]
    test edx, edx
    jz .nx
    imul ebx, edi, 22
    add ebx, [fx]
    imul ecx, ebp, 18
    add ecx, [fy]
    movzx esi, byte [coltype+edi]
    mov eax, [encol+esi*4]
    cmp esi, 3
    jne .col
    cmp edx, 1                  ; damaged tank turns pale
    jne .col
    mov eax, 0x9AD8FF
.col:
    shl esi, 1
    add esi, [anim]
    shl esi, 5
    add esi, en_squid0
    call blit16
.nx:
    inc edi
    cmp edi, 9
    jb .cc
    inc ebp
    cmp ebp, 4
    jb .rr
.r: ret

draw_boss:
    cmp dword [bon], 0
    je .r
    mov ebx, [bossx]
    mov ecx, 40
    mov eax, [frame]
    shr eax, 4
    and eax, 1
    shl eax, 6
    mov edx, eax
    lea esi, [boss_gold0+edx]
    mov eax, C_GOLD
    cmp dword [bflash], 0
    je .g
    mov eax, 0xFFFFFF
.g: call blit24
    lea esi, [boss_orange0+edx]
    mov eax, C_ORANGE
    call blit24
    mov esi, boss_eye
    mov eax, C_PRED
    call blit24
.r: ret

draw_ufo:
    cmp dword [uon], 0
    je .r
    mov ebx, [ux]
    mov ecx, 22
    mov esi, ufo_body
    mov eax, C_UFOM
    call blit24
    mov eax, [frame]
    shr eax, 3
    and eax, 1
    shl eax, 6
    lea esi, [ufo_lights0+eax]
    mov eax, C_UFOC
    call blit24
.r: ret

draw_drops:
    mov ebp, DROP
    mov edi, NDROP
.l: cmp dword [ebp], 0
    je .n
    mov ebx, [ebp+4]
    sub ebx, 8
    mov ecx, [ebp+8]
    sub ecx, 8
    mov eax, [ebp+20]
    call drawpu
.n: add ebp, 32
    dec edi
    jnz .l
    ret

drawpu:                         ; EAX=type EBX=x ECX=y
    pushad
    mov ebp, eax
    mov esi, [pu_data+ebp*4]
    mov eax, [pu_col+ebp*4]
    call blit16
    test ebp, ebp
    jnz .n0
    mov esi, pu_shield_hl
    mov eax, C_PBUL
    call blit16
    jmp .r
.n0:
    cmp ebp, 4
    jne .r
    add ebx, 5
    add ecx, 6
    mov esi, s_x2
    mov edx, 1
    mov eax, C_BG
    call drawtext
.r: popad
    ret

draw_ship:                      ; the player ship (hidden while exploding, blinks after a hit)
    cmp dword [pdead], 0
    jne .r
    cmp dword [scene], 4
    je .r
    cmp dword [invuln], 0
    je .show
    test byte [frame], 4
    jnz .r
.show:
    mov ebx, [px]
    mov ecx, [py]
    call drawshipat
    cmp dword [flash], 0        ; muzzle flash at the nose
    je .r
    mov eax, [flash]
    shr eax, 1
    inc eax
    mov esi, eax
    mov ecx, [py]
    sub ecx, eax
    mov ebx, [px]
    add ebx, 7
    mov edx, 2
    mov eax, C_PBUL
    call fillrect
.r: ret

drawshipat:                     ; EBX=x ECX=y, uses [bank] and the chosen colour
    pushad
    mov eax, [frame]
    shr eax, 2
    and eax, 1
    shl eax, 5
    lea esi, [ship_flame+eax]
    mov eax, C_EXPO
    call blit16
    mov edx, [bank]
    shl edx, 5
    lea esi, [ship_body+edx]
    mov eax, [shipcol]
    mov eax, [shipcols+eax*4]
    call blit16
    lea esi, [ship_red+edx]
    mov eax, C_PRED
    call blit16
    popad
    ret

draw_bullets:
    mov ebp, PBUL
    mov edi, NPBUL
.p: cmp dword [ebp], 0
    je .pn
    mov ebx, [ebp+4]
    sub ebx, 8
    mov ecx, [ebp+8]
    sub ecx, 8
    mov eax, [ebp+12]
    test eax, eax
    jz .straight
    mov esi, spread_l
    jl .sp
    mov esi, spread_r
.sp:
    mov eax, C_PUSPREAD
    call blit16
    jmp .pn
.straight:
    mov edx, [frame]
    shr edx, 2
    and edx, 1
    shl edx, 5
    lea esi, [pbul0+edx]
    mov eax, C_PBUL
    call blit16
    lea esi, [pbul_core0+edx]
    mov eax, C_PWHITE
    call blit16
.pn:
    add ebp, 32
    dec edi
    jnz .p
    mov ebp, EBUL
    mov edi, NEBUL
.e: cmp dword [ebp], 0
    je .en
    mov ebx, [ebp+4]
    sub ebx, 8
    mov ecx, [ebp+8]
    sub ecx, 8
    mov edx, [frame]
    shr edx, 2
    and edx, 1
    shl edx, 5
    lea esi, [ebul0+edx]
    mov eax, C_EBUL
    call blit16
.en:
    add ebp, 32
    dec edi
    jnz .e
    ret

draw_parts:
    mov ebp, PART
    mov edi, NPART
.l: cmp dword [ebp], 0
    je .n
    mov ebx, [ebp+4]
    sar ebx, 4
    mov ecx, [ebp+8]
    sar ecx, 4
    mov edx, [ebp+20]
    mov eax, [ebp+24]
    cmp edx, 1
    je .debris
    cmp edx, 2
    je .trail
    mov esi, eax                ; spark: yellow / white twinkle
    mov eax, C_EXPY
    test esi, 2
    jz .s1
    mov eax, C_PWHITE
.s1:
    call putpix
    cmp esi, 8
    jle .n
    inc ebx
    call putpix
    jmp .n
.debris:
    mov esi, 2
    mov edx, 2
    mov eax, C_EXPO
    test dword [ebp+24], 1
    jz .d1
    mov eax, C_CRAB
.d1:
    call fillrect
    jmp .n
.trail:
    mov esi, 2
    mov edx, 1
    mov eax, C_PBUL
    cmp dword [ebp+24], 5
    jg .t1
    mov eax, 0x2A6EA0
.t1:
    call fillrect
.n: add ebp, 32
    dec edi
    jnz .l
    ret

draw_expls:
    mov ebp, EXPL
    mov edi, NEXPL
.l: cmp dword [ebp], 0
    je .n
    mov eax, [ebp+24]
    shr eax, 2
    mov edx, [ebp+20]
    cmp eax, edx
    jbe .ok
    mov eax, edx
.ok:
    mov ebx, [ebp+4]
    mov ecx, [ebp+8]
    test eax, eax
    jnz .m
    sub ebx, 8
    sub ecx, 8
    mov esi, expl_small_orange
    jmp .small
.m: cmp eax, 1
    jne .big
    sub ebx, 8
    sub ecx, 8
    mov esi, expl_medium_orange
.small:
    mov eax, C_EXPO
    call blit16
    add esi, 32
    mov eax, C_EXPY
    call blit16
    add esi, 32
    mov eax, C_PWHITE
    call blit16
    jmp .n
.big:
    sub ebx, 16
    sub ecx, 16
    mov esi, expl_large_orange
    mov eax, C_EXPO
    call blit32
    add esi, 128
    mov eax, C_EXPY
    call blit32
    add esi, 128
    mov eax, C_PWHITE
    call blit32
.n: add ebp, 32
    dec edi
    jnz .l
    ret

draw_shield:
    cmp dword [t_shield], 0
    je .r
    cmp dword [pdead], 0
    jne .r
    cmp dword [t_shield], 90    ; flickers when about to run out
    jg .show
    test byte [frame], 4
    jnz .r
.show:
    mov ebx, [px]
    sub ebx, 8
    mov ecx, [py]
    sub ecx, 8
    mov esi, shield_ring
    mov eax, C_PUSHIELD
    call blit32
.r: ret

; ------------------------------------------------------------
draw_hud:
    mov eax, C_FRAME            ; top and bottom panel outlines
    mov ebx, 2
    mov edx, 380
    mov esi, 1
    mov ecx, 1
    call fillrect
    mov ecx, 18
    call fillrect
    mov ecx, 238
    call fillrect
    mov ecx, 254
    call fillrect
    mov edx, 1
    mov esi, 18
    mov ecx, 1
    mov ebx, 2
    call fillrect
    mov ebx, 381
    call fillrect
    mov esi, 17
    mov ecx, 238
    mov ebx, 2
    call fillrect
    mov ebx, 381
    call fillrect

    mov esi, s_score
    mov ebx, 8
    mov ecx, 2
    mov edx, 1
    mov eax, 0x6FA8FF
    call drawtext
    mov eax, [score]
    mov ecx, 6
    call numstr
    mov esi, numbuf
    mov ebx, 8
    mov ecx, 8
    mov edx, 2
    mov eax, C_PWHITE
    call drawtext
    cmp dword [t_x2], 0
    je .nox2
    mov esi, s_x2
    mov ebx, 34
    mov ecx, 3
    mov edx, 1
    mov eax, C_PUX2
    call drawtext
.nox2:
    mov esi, s_lives
    mov ebx, 84
    mov ecx, 7
    mov edx, 1
    mov eax, 0x6FA8FF
    call drawtext
    xor ebp, ebp
.lv:
    cmp ebp, [lives]
    jge .lvd
    imul ebx, ebp, 18
    add ebx, 112
    mov ecx, 2
    mov dword [bank], 0
    call drawshipat
    inc ebp
    jmp .lv
.lvd:
    mov esi, s_stage
    mov ebx, 212
    mov ecx, 7
    mov edx, 1
    mov eax, 0x6FA8FF
    call drawtext
    mov eax, [stage]
    add al, '0'
    mov [stagestr], al
    mov eax, [wave]
    add al, '0'
    mov [stagestr+2], al
    mov esi, stagestr
    mov ebx, 240
    mov ecx, 6
    mov edx, 2
    mov eax, C_PWHITE
    call drawtext
    xor ebp, ebp                ; power-up slots with counters
.pu:
    imul ebx, ebp, 23
    add ebx, 266
    mov ecx, 2
    mov eax, ebp
    call drawpu
    mov eax, [inv+ebp*4]
    add al, '0'
    mov [cntstr], al
    mov esi, cntstr
    add ebx, 17
    mov ecx, 8
    mov edx, 1
    mov eax, C_PWHITE
    cmp dword [inv+ebp*4], 0
    jne .c1
    mov eax, 0x3A4A70
.c1:
    call drawtext
    cmp ebp, [sel]
    jne .pn
    imul ebx, ebp, 23
    add ebx, 265
    mov eax, C_PWHITE
    mov ecx, 1
    mov edx, 22
    mov esi, 1
    call fillrect
    mov ecx, 18
    call fillrect
    mov edx, 1
    mov esi, 18
    mov ecx, 1
    call fillrect
    add ebx, 21
    call fillrect
.pn:
    inc ebp
    cmp ebp, 5
    jb .pu
    mov esi, s_hints
    mov ebx, 8
    mov ecx, 244
    mov edx, 1
    mov eax, 0x6FA8FF
    call drawtext
    mov ebx, 250                ; remaining time of active power-ups
    mov esi, 2
    mov edx, [t_shield]
    shr edx, 2
    mov ecx, 241
    mov eax, C_PUSHIELD
    call .bar
    mov edx, [t_speed]
    shr edx, 2
    mov ecx, 244
    mov eax, C_PUSPEED
    call .bar
    mov edx, [t_spread]
    shr edx, 2
    mov ecx, 247
    mov eax, C_PUSPREAD
    call .bar
    mov edx, [t_x2]
    shr edx, 2
    mov ecx, 250
    mov eax, C_PUX2
.bar:
    test edx, edx
    jz .bd
    call fillrect
.bd:
    ret

; ------------------------------------------------------------
;  menu screens
; ------------------------------------------------------------
drawmenu:                       ; ESI = table of string pointers, ECX = count, EBX = first y
    pushad
    mov [dm_tab], esi
    mov [dm_cnt], ecx
    mov [dm_y], ebx
    xor ebp, ebp
.l: mov esi, [dm_tab]
    mov esi, [esi+ebp*4]
    mov ecx, [dm_y]
    mov edx, 2
    mov eax, 0x4A6FB5
    cmp ebp, [menusel]
    jne .c
    mov eax, C_PWHITE
.c: call drawtextc
    cmp ebp, [menusel]
    jne .n
    mov ebx, [tc_x]
    sub ebx, 12
    mov ecx, [dm_y]
    mov esi, s_gt
    mov edx, 2
    mov eax, C_PBUL
    call drawtext
.n: add dword [dm_y], 20
    inc ebp
    cmp ebp, [dm_cnt]
    jb .l
    popad
    ret

panel:                          ; EBX=x ECX=y EDX=w ESI=h: dark panel with blue outline
    pushad
    mov [pn_x], ebx
    mov [pn_y], ecx
    mov [pn_w], edx
    mov [pn_h], esi
    mov eax, 0x070C18
    call fillrect
    mov eax, C_FRAME
    mov ebx, [pn_x]
    mov ecx, [pn_y]
    mov edx, [pn_w]
    mov esi, 1
    call fillrect
    add ecx, [pn_h]
    dec ecx
    call fillrect
    mov ecx, [pn_y]
    mov edx, 1
    mov esi, [pn_h]
    call fillrect
    add ebx, [pn_w]
    dec ebx
    call fillrect
    popad
    ret

draw_menu:
    mov ebx, 80
    mov ecx, 36
    mov edx, 224
    mov esi, 72
    call panel
    mov esi, s_space
    mov ecx, 46
    mov edx, 4
    mov eax, C_PBUL
    call drawtextc
    mov esi, s_invaders
    mov ecx, 70
    mov edx, 4
    mov eax, C_PWHITE
    call drawtextc
    mov esi, menu_items
    mov ecx, 3
    mov ebx, 130
    call drawmenu
    mov ebx, 84                 ; the whole cast, animated
    mov ecx, 196
    mov ebp, 0
.e: mov eax, [frame]
    shr eax, 4
    and eax, 1
    add eax, ebp
    add eax, ebp
    shl eax, 5
    lea esi, [en_squid0+eax]
    mov eax, [encol+ebp*4]
    call blit16
    add ebx, 40
    inc ebp
    cmp ebp, 4
    jb .e
    mov ecx, 196
    mov eax, [frame]
    shr eax, 4
    and eax, 1
    shl eax, 6
    mov edx, eax
    lea esi, [boss_gold0+edx]
    mov eax, C_GOLD
    call blit24
    lea esi, [boss_orange0+edx]
    mov eax, C_ORANGE
    call blit24
    mov esi, boss_eye
    mov eax, C_PRED
    call blit24
    add ebx, 40
    mov esi, ufo_body
    mov eax, C_UFOM
    call blit24
    mov eax, [frame]
    shr eax, 3
    and eax, 1
    shl eax, 6
    lea esi, [ufo_lights0+eax]
    mov eax, C_UFOC
    call blit24
    mov ebx, 184
    mov ecx, 216
    mov dword [bank], 0
    call drawshipat
    mov esi, s_hints
    mov ebx, 8
    mov ecx, 244
    mov edx, 1
    mov eax, 0x6FA8FF
    call drawtext
    ret

draw_options:
    mov esi, s_options
    mov ecx, 46
    mov edx, 4
    mov eax, C_PWHITE
    call drawtextc
    mov esi, s_shipcolor
    mov ecx, 108
    mov edx, 2
    mov eax, 0x4A6FB5
    cmp dword [menusel], 0
    jne .a
    mov eax, C_PWHITE
.a: call drawtextc
    mov eax, [shipcol]
    mov esi, [colnames+eax*4]
    mov ecx, 128
    mov edx, 2
    mov eax, [shipcol]
    mov eax, [shipcols+eax*4]
    call drawtextc
    mov eax, [frame]            ; preview with idle / left / right frames
    shr eax, 5
    and eax, 3
    mov ecx, [bankseq+eax*4]
    mov [bank], ecx
    mov ebx, 184
    mov ecx, 152
    call drawshipat
    mov dword [bank], 0
    mov esi, s_back
    mov ecx, 196
    mov edx, 2
    mov eax, 0x4A6FB5
    cmp dword [menusel], 1
    jne .b
    mov eax, C_PWHITE
.b: call drawtextc
    mov esi, s_optkeys
    mov ecx, 244
    mov edx, 1
    mov eax, 0x6FA8FF
    call drawtextc
    ret

draw_pause:
    mov ebx, 112
    mov ecx, 84
    mov edx, 160
    mov esi, 96
    call panel
    mov esi, s_paused
    mov ecx, 94
    mov edx, 3
    mov eax, C_PWHITE
    call drawtextc
    mov esi, pause_items
    mov ecx, 3
    mov ebx, 126
    call drawmenu
    ret

draw_over:
    mov ebx, 96
    mov ecx, 80
    mov edx, 192
    mov esi, 104
    call panel
    mov esi, s_gameover
    mov ecx, 90
    mov edx, 3
    mov eax, C_CRAB
    call drawtextc
    mov eax, [score]
    mov ecx, 6
    call numstr
    mov esi, s_final
    mov ebx, 122
    mov ecx, 118
    mov edx, 2
    mov eax, 0x6FA8FF
    call drawtext
    mov esi, numbuf
    mov ebx, 206
    mov ecx, 118
    mov edx, 2
    mov eax, C_PWHITE
    call drawtext
    mov esi, over_items
    mov ecx, 2
    mov ebx, 144
    call drawmenu
    ret

; ============================================================
;  Data
; ============================================================
s_class     db 'InvadersGDI', 0
s_wtitle    db 'SPACE INVADERS', 0
s_score     db 'SCORE', 0
s_lives     db 'LIVES', 0
s_stage     db 'STAGE', 0
s_x2        db 'X2', 0
s_gt        db '>', 0
s_space     db 'SPACE', 0
s_invaders  db 'INVADERS', 0
s_start     db 'START', 0
s_options   db 'OPTIONS', 0
s_quit      db 'QUIT', 0
s_paused    db 'PAUSED', 0
s_resume    db 'RESUME', 0
s_restart   db 'RESTART', 0
s_gameover  db 'GAME OVER', 0
s_final     db 'SCORE', 0
s_waveclear db 'WAVE CLEAR', 0
s_shipcolor db 'SHIP COLOR', 0
s_back      db 'BACK', 0
s_blue      db '< BLUE >', 0
s_green     db '< GREEN >', 0
s_purple    db '< PURPLE >', 0
s_optkeys   db 'UP DOWN SELECT   LEFT RIGHT CHANGE   ESC BACK', 0
s_hints     db 'ARROWS MOVE  SPACE SHOOT  Z USE  UP 1-5 PICK  P PAUSE', 0
stagestr    db '1-1', 0
cntstr      db '0', 0
numbuf      times 16 db 0

menu_items  dd s_start, s_options, s_quit
pause_items dd s_resume, s_restart, s_quit
over_items  dd s_restart, s_quit
colnames    dd s_blue, s_green, s_purple
shipcols    dd C_PBLUE, C_SQUID, C_OCTO
bankseq     dd 0, 1, 0, 2
encol       dd C_SQUID, C_CRAB, C_OCTO, C_TANK
pts         dd 10, 20, 30, 40
ufovals     dd 50, 100, 150, 300
coltype     db 0, 0, 0, 1, 1, 2, 2, 3, 3
expdur      db 8, 12, 20
pu_data     dd pu_shield, pu_speed, pu_spread, pu_life, pu_star
pu_col      dd C_PUSHIELD, C_PUSPEED, C_PUSPREAD, C_PULIFE, C_PUX2

; logical key -> two virtual-key codes (arrows or WASD, etc.)
keymap      db 0x25,0x41, 0x27,0x44, 0x26,0x57, 0x28,0x53, 0x20,0, 0x0D,0, 0x1B,0, 0x5A,0
            db 0x50,0, 0x31,0, 0x32,0, 0x33,0, 0x34,0, 0x35,0

; bunker template: 10 x 6 cells, 1 = block
bunk_tpl    db 0,1,1,1,1,1,1,1,1,0
            db 1,1,1,1,1,1,1,1,1,1
            db 1,1,1,1,1,1,1,1,1,1
            db 1,1,1,1,1,1,1,1,1,1
            db 1,1,1,0,0,0,0,1,1,1
            db 1,1,1,0,0,0,0,1,1,1

    align 4, db 0
wc          dd 0, wndproc, 0, 0, ImageBase, 0, 0, 0, 0, s_class
rect        dd 0, 0, W*2, H*2
bmi         dd 40, W, -H
            dw 1, 32
            dd 0, 0, 0, 0, 0, 0
msg         times 32 db 0

hwnd dd 0
hdc dd 0
nexttick dd 0
seed dd 1
frame dd 0
scene dd 0
menusel dd 0
shipcol dd 0
fg dd 0
score dd 0
lives dd 3
stage dd 1
wave dd 1
px dd 184
py dd 214
pcool dd 0
flash dd 0
invuln dd 0
bank dd 0
pdead dd 0
t_shield dd 0
t_speed dd 0
t_spread dd 0
t_x2 dd 0
inv dd 0, 0, 0, 0, 0
sel dd 0
fx dd 96
fy dd 60
fdir dd 2
acount dd 0
anim dd 0
acnt dd 36
maxr dd 0
wclear dd 0
bon dd 0
bossx dd 0
bdir dd 1
bhp dd 0
bcool dd 0
bflash dd 0
uon dd 0
ux dd 0
udir dd 1
uval dd 50
utimer dd 900
gx0 dd 0
gy0 dd 0
gx1 dd 0
gy1 dd 0
b_x dd 0
b_col dd 0
b_w dd 0
b_w2 dd 0
b_rows dd 0
t_col dd 0
t_scale dd 0
t_x dd 0
t_y dd 0
tc_x dd 0
tc_col dd 0
bu_x dd 0
bu_y dd 0
bu_k dd 0
bk_i dd 0
bk_c dd 0
bk_r dd 0
bk_dy dd 0
h_x dd 0
h_y dd 0
ah_x dd 0
ah_y dd 0
dm_tab dd 0
dm_cnt dd 0
dm_y dd 0
pn_x dd 0
pn_y dd 0
pn_w dd 0
pn_h dd 0
kdown times NK db 0
kprev times NK db 0
kpress times NK db 0
    align 4, db 0

; ============================================================
;  Sprite data: 1 bit per pixel, rows of 16-bit words (MSB = leftmost pixel).
;  16x16 sprites use 1 word per row, 24x16 and 32x32 use 2 words per row.
;  Each sprite is one colour; layers are drawn on top of each other.
; ============================================================
ship_body:   ; idle
    dw 0x0180   ; .......##.......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x07E0   ; .....######.....
    dw 0x47E2   ; .#...######...#.
    dw 0x4FF2   ; .#..########..#.
    dw 0x6FF6   ; .##.########.##.
    dw 0x6FF6   ; .##.########.##.
    dw 0x7FFE   ; .##############.
    dw 0xEFF7   ; ###.########.###
    dw 0xEFF7   ; ###.########.###
    dw 0xA7E5   ; #.#..######..#.#
    dw 0x87E1   ; #....######....#
    dw 0x07E0   ; .....######.....
    dw 0x0000   ; ................
    dw 0x0000   ; ................
ship_body_l:   ; bank left
    dw 0x0300   ; ......##........
    dw 0x0780   ; .....####.......
    dw 0x0780   ; .....####.......
    dw 0x0FC0   ; ....######......
    dw 0x8FC4   ; #...######...#..
    dw 0x9FE4   ; #..########..#..
    dw 0xDFEC   ; ##.########.##..
    dw 0x6FF6   ; .##.########.##.
    dw 0x7FFE   ; .##############.
    dw 0xEFF7   ; ###.########.###
    dw 0xEFF7   ; ###.########.###
    dw 0xA7E5   ; #.#..######..#.#
    dw 0x87E1   ; #....######....#
    dw 0x07E0   ; .....######.....
    dw 0x0000   ; ................
    dw 0x0000   ; ................
ship_body_r:   ; bank right
    dw 0x00C0   ; ........##......
    dw 0x01E0   ; .......####.....
    dw 0x01E0   ; .......####.....
    dw 0x03F0   ; ......######....
    dw 0x23F1   ; ..#...######...#
    dw 0x27F9   ; ..#..########..#
    dw 0x37FB   ; ..##.########.##
    dw 0x6FF6   ; .##.########.##.
    dw 0x7FFE   ; .##############.
    dw 0xEFF7   ; ###.########.###
    dw 0xEFF7   ; ###.########.###
    dw 0xA7E5   ; #.#..######..#.#
    dw 0x87E1   ; #....######....#
    dw 0x07E0   ; .....######.....
    dw 0x0000   ; ................
    dw 0x0000   ; ................
ship_red:   ; idle
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x4002   ; .#............#.
    dw 0x4002   ; .#............#.
    dw 0x0180   ; .......##.......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0xE007   ; ###..........###
    dw 0xE007   ; ###..........###
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
ship_red_l:
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x8004   ; #............#..
    dw 0x8004   ; #............#..
    dw 0x0300   ; ......##........
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0xE007   ; ###..........###
    dw 0xE007   ; ###..........###
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
ship_red_r:
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x2001   ; ..#............#
    dw 0x2001   ; ..#............#
    dw 0x00C0   ; ........##......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0xE007   ; ###..........###
    dw 0xE007   ; ###..........###
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
ship_flame:   ; thruster frame 0
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
ship_flame1:   ; thruster frame 1
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
en_squid0:   ; squid frame 0
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x07E0   ; .....######.....
    dw 0x1FF8   ; ...##########...
    dw 0x3FFC   ; ..############..
    dw 0x399C   ; ..###..##..###..
    dw 0x3FFC   ; ..############..
    dw 0x0E70   ; ....###..###....
    dw 0x1998   ; ...##..##..##...
    dw 0x300C   ; ..##........##..
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
en_squid1:   ; squid frame 1
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x07E0   ; .....######.....
    dw 0x1FF8   ; ...##########...
    dw 0x3FFC   ; ..############..
    dw 0x399C   ; ..###..##..###..
    dw 0x3FFC   ; ..############..
    dw 0x1C38   ; ...###....###...
    dw 0x399C   ; ..###..##..###..
    dw 0x1818   ; ...##......##...
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
en_crab0:   ; crab frame 0
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x1008   ; ...#........#...
    dw 0x0810   ; ....#......#....
    dw 0x1FF8   ; ...##########...
    dw 0x3BDC   ; ..###.####.###..
    dw 0x7FFE   ; .##############.
    dw 0x5FFA   ; .#.##########.#.
    dw 0x500A   ; .#.#........#.#.
    dw 0x0C30   ; ....##....##....
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
en_crab1:   ; crab frame 1
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x1008   ; ...#........#...
    dw 0x4812   ; .#..#......#..#.
    dw 0x5FFA   ; .#.##########.#.
    dw 0x7BDE   ; .####.####.####.
    dw 0x7FFE   ; .##############.
    dw 0x3FFC   ; ..############..
    dw 0x1FF8   ; ...##########...
    dw 0x1818   ; ...##......##...
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
en_octopus0:   ; octopus frame 0
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x07E0   ; .....######.....
    dw 0x3FFC   ; ..############..
    dw 0x7FFE   ; .##############.
    dw 0x73CE   ; .###..####..###.
    dw 0x7FFE   ; .##############.
    dw 0x1C38   ; ...###....###...
    dw 0x399C   ; ..###..##..###..
    dw 0x700E   ; .###........###.
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
en_octopus1:   ; octopus frame 1
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x07E0   ; .....######.....
    dw 0x3FFC   ; ..############..
    dw 0x7FFE   ; .##############.
    dw 0x73CE   ; .###..####..###.
    dw 0x7FFE   ; .##############.
    dw 0x0C30   ; ....##....##....
    dw 0x1BD8   ; ...##.####.##...
    dw 0x0C30   ; ....##....##....
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
en_tank0:   ; tank frame 0
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x03C0   ; ......####......
    dw 0x1FF8   ; ...##########...
    dw 0x3FFC   ; ..############..
    dw 0x7FFE   ; .##############.
    dw 0x77EE   ; .###.######.###.
    dw 0x7FFE   ; .##############.
    dw 0x399C   ; ..###..##..###..
    dw 0x300C   ; ..##........##..
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
en_tank1:   ; tank frame 1
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x03C0   ; ......####......
    dw 0x1FF8   ; ...##########...
    dw 0x3FFC   ; ..############..
    dw 0x7FFE   ; .##############.
    dw 0x77EE   ; .###.######.###.
    dw 0x7FFE   ; .##############.
    dw 0x1BD8   ; ...##.####.##...
    dw 0x33CC   ; ..##..####..##..
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
boss_gold0:   ; boss body frame 0
    dw 0x0000, 0x0000   ; ........................
    dw 0x03FF, 0xC000   ; ......############......
    dw 0x0FFF, 0xF000   ; ....################....
    dw 0x4FFF, 0xF200   ; .#..################..#.
    dw 0x6FFF, 0xF600   ; .##.################.##.
    dw 0x7FFF, 0xFE00   ; .######################.
    dw 0xFFFF, 0xFF00   ; ########################
    dw 0xDFFF, 0xFB00   ; ##.##################.##
    dw 0x9FFF, 0xF900   ; #..##################..#
    dw 0x8FFF, 0xF100   ; #...################...#
    dw 0x0F3C, 0xF000   ; ....####..####..####....
    dw 0x0E18, 0x7000   ; ....###....##....###....
    dw 0x1800, 0x1800   ; ...##..............##...
    dw 0x1000, 0x0800   ; ...#................#...
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
boss_gold1:   ; boss body frame 1
    dw 0x0000, 0x0000   ; ........................
    dw 0x03FF, 0xC000   ; ......############......
    dw 0x0FFF, 0xF000   ; ....################....
    dw 0x4FFF, 0xF200   ; .#..################..#.
    dw 0x6FFF, 0xF600   ; .##.################.##.
    dw 0x7FFF, 0xFE00   ; .######################.
    dw 0xFFFF, 0xFF00   ; ########################
    dw 0xDFFF, 0xFB00   ; ##.##################.##
    dw 0x9FFF, 0xF900   ; #..##################..#
    dw 0x4FFF, 0xF200   ; .#..################..#.
    dw 0x2F3C, 0xF400   ; ..#.####..####..####.#..
    dw 0x2E18, 0x7400   ; ..#.###....##....###.#..
    dw 0x6C00, 0x3600   ; .##.##............##.##.
    dw 0x0800, 0x1000   ; ....#..............#....
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
boss_orange0:   ; boss trim frame 0
    dw 0x0000, 0x0000   ; ........................
    dw 0x4000, 0x0200   ; .#....................#.
    dw 0x6000, 0x0600   ; .##..................##.
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0xC000, 0x0300   ; ##....................##
    dw 0x8000, 0x0100   ; #......................#
    dw 0x8000, 0x0100   ; #......................#
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
boss_orange1:   ; boss trim frame 1
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x4000, 0x0200   ; .#....................#.
    dw 0x6000, 0x0600   ; .##..................##.
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0xC000, 0x0300   ; ##....................##
    dw 0x8000, 0x0100   ; #......................#
    dw 0x8000, 0x0100   ; #......................#
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
boss_eye:   ; boss eye
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0018, 0x0000   ; ...........##...........
    dw 0x003C, 0x0000   ; ..........####..........
    dw 0x003C, 0x0000   ; ..........####..........
    dw 0x003C, 0x0000   ; ..........####..........
    dw 0x0018, 0x0000   ; ...........##...........
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
ufo_body:   ; saucer
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x01FF, 0x8000   ; .......##########.......
    dw 0x07FF, 0xE000   ; .....##############.....
    dw 0x1FFF, 0xF800   ; ...##################...
    dw 0x3FFF, 0xFC00   ; ..####################..
    dw 0xFFFF, 0xFF00   ; ########################
    dw 0xFFFF, 0xFF00   ; ########################
    dw 0x7FFF, 0xFE00   ; .######################.
    dw 0x0B42, 0xD000   ; ....#.##.#....#.##.#....
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
ufo_lights0:   ; lights 0
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x2224, 0x4400   ; ..#...#...#..#...#...#..
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
ufo_lights1:   ; lights 1
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x1118, 0x8800   ; ...#...#...##...#...#...
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
    dw 0x0000, 0x0000   ; ........................
pu_shield:   ; power-up: shield
    dw 0x0000   ; ................
    dw 0x3FFC   ; ..############..
    dw 0x7FFE   ; .##############.
    dw 0x7FFE   ; .##############.
    dw 0x7FFE   ; .##############.
    dw 0x7FFE   ; .##############.
    dw 0x7FFE   ; .##############.
    dw 0x3FFC   ; ..############..
    dw 0x3FFC   ; ..############..
    dw 0x1FF8   ; ...##########...
    dw 0x0FF0   ; ....########....
    dw 0x07E0   ; .....######.....
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0x0000   ; ................
    dw 0x0000   ; ................
pu_shield_hl:
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x3000   ; ..##............
    dw 0x3000   ; ..##............
    dw 0x3000   ; ..##............
    dw 0x3000   ; ..##............
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
pu_speed:   ; power-up: speed
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x38E0   ; ..###...###.....
    dw 0x1C70   ; ...###...###....
    dw 0x0E38   ; ....###...###...
    dw 0x071C   ; .....###...###..
    dw 0x0E38   ; ....###...###...
    dw 0x1C70   ; ...###...###....
    dw 0x38E0   ; ..###...###.....
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
pu_spread:   ; power-up: spread shot
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0180   ; .......##.......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x33CC   ; ..##..####..##..
    dw 0x7BDE   ; .####.####.####.
    dw 0x799E   ; .####..##..####.
    dw 0x781E   ; .####......####.
    dw 0x300C   ; ..##........##..
    dw 0x300C   ; ..##........##..
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
pu_life:   ; power-up: extra life
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x3C3C   ; ..####....####..
    dw 0x7E7E   ; .######..######.
    dw 0xFFFF   ; ################
    dw 0xFFFF   ; ################
    dw 0xFFFF   ; ################
    dw 0x7FFE   ; .##############.
    dw 0x3FFC   ; ..############..
    dw 0x1FF8   ; ...##########...
    dw 0x0FF0   ; ....########....
    dw 0x07E0   ; .....######.....
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0x0000   ; ................
    dw 0x0000   ; ................
pu_star:   ; power-up: score x2
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0xFFFF   ; ################
    dw 0x7FFE   ; .##############.
    dw 0x3FFC   ; ..############..
    dw 0x1FF8   ; ...##########...
    dw 0x1FF8   ; ...##########...
    dw 0x3C3C   ; ..####....####..
    dw 0x381C   ; ..###......###..
    dw 0x700E   ; .###........###.
    dw 0x0000   ; ................
    dw 0x0000   ; ................
pbul0:   ; player bullet frame 0
    dw 0x0000   ; ................
    dw 0x0180   ; .......##.......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
pbul1:   ; player bullet frame 1
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0180   ; .......##.......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
pbul_core0:
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0100   ; .......#........
    dw 0x0100   ; .......#........
    dw 0x0100   ; .......#........
    dw 0x0100   ; .......#........
    dw 0x0100   ; .......#........
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
pbul_core1:
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0080   ; ........#.......
    dw 0x0080   ; ........#.......
    dw 0x0080   ; ........#.......
    dw 0x0080   ; ........#.......
    dw 0x0080   ; ........#.......
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
ebul0:   ; enemy bullet frame 0
    dw 0x0000   ; ................
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
ebul1:   ; enemy bullet frame 1
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0180   ; .......##.......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
spread_l:   ; spread bullet leaning left
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0700   ; .....###........
    dw 0x0700   ; .....###........
    dw 0x0380   ; ......###.......
    dw 0x0380   ; ......###.......
    dw 0x01C0   ; .......###......
    dw 0x01C0   ; .......###......
    dw 0x00E0   ; ........###.....
    dw 0x00E0   ; ........###.....
    dw 0x0070   ; .........###....
    dw 0x0070   ; .........###....
    dw 0x0038   ; ..........###...
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
spread_r:   ; spread bullet leaning right
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0038   ; ..........###...
    dw 0x0038   ; ..........###...
    dw 0x0070   ; .........###....
    dw 0x0070   ; .........###....
    dw 0x00E0   ; ........###.....
    dw 0x00E0   ; ........###.....
    dw 0x01C0   ; .......###......
    dw 0x01C0   ; .......###......
    dw 0x0380   ; ......###.......
    dw 0x0380   ; ......###.......
    dw 0x0700   ; .....###........
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
expl_small_orange:   ; small explosion, outer layer
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x09E0   ; ....#..####.....
    dw 0x03E0   ; ......#####.....
    dw 0x0FF0   ; ....########....
    dw 0x0FF0   ; ....########....
    dw 0x0FF0   ; ....########....
    dw 0x2FF0   ; ..#.########....
    dw 0x2FF0   ; ..#.########....
    dw 0x0FF0   ; ....########....
    dw 0x07E0   ; .....######.....
    dw 0x03D0   ; ......####.#....
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
expl_small_yellow:   ; small explosion, middle layer
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x07C0   ; .....#####......
    dw 0x07E0   ; .....######.....
    dw 0x07E0   ; .....######.....
    dw 0x07E0   ; .....######.....
    dw 0x0100   ; .......#........
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
expl_small_white:   ; small explosion, core
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
expl_medium_orange:   ; medium explosion, outer layer
    dw 0x0000   ; ................
    dw 0x09F0   ; ....#..#####....
    dw 0x07F0   ; .....#######....
    dw 0x2FF8   ; ..#.#########...
    dw 0x3FFC   ; ..############..
    dw 0x3FFD   ; ..############.#
    dw 0x3FFC   ; ..############..
    dw 0x3FFC   ; ..############..
    dw 0x3FFC   ; ..############..
    dw 0x3FFC   ; ..############..
    dw 0x3FFE   ; ..#############.
    dw 0x7FFC   ; .#############..
    dw 0x1FF8   ; ...##########...
    dw 0x0FE0   ; ....#######.....
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
expl_medium_yellow:   ; medium explosion, middle layer
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x07E0   ; .....######.....
    dw 0x0FF0   ; ....########....
    dw 0x0FF0   ; ....########....
    dw 0x0FF8   ; ....#########...
    dw 0x0FF8   ; ....#########...
    dw 0x0FF0   ; ....########....
    dw 0x0300   ; ......##........
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
expl_medium_white:   ; medium explosion, core
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0180   ; .......##.......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
expl_large_orange:   ; large explosion, outer layer
    dw 0x0008, 0x0000   ; ............#...................
    dw 0x0000, 0x8000   ; ................#...............
    dw 0x0000, 0x0000   ; ................................
    dw 0x00FE, 0x0100   ; ........#######........#........
    dw 0x05FF, 0xF800   ; .....#.##############...........
    dw 0x03FF, 0xFF40   ; ......##################.#......
    dw 0x03FF, 0xFFC0   ; ......####################......
    dw 0x07FF, 0xFFE0   ; .....######################.....
    dw 0x07FF, 0xFFF0   ; .....#######################....
    dw 0x0FFF, 0xFFF0   ; ....########################....
    dw 0x0FFF, 0xFFF0   ; ....########################....
    dw 0x0FFF, 0xFFF0   ; ....########################....
    dw 0x0FFF, 0xFFF0   ; ....########################....
    dw 0x8FFF, 0xFFF0   ; #...########################....
    dw 0x0FFF, 0xFFE0   ; ....#######################.....
    dw 0x0FFF, 0xFFC2   ; ....######################....#.
    dw 0x0FFF, 0xFFC0   ; ....######################......
    dw 0x0FFF, 0xFFE1   ; ....#######################....#
    dw 0x0FFF, 0xFFE0   ; ....#######################.....
    dw 0x0FFF, 0xFFE0   ; ....#######################.....
    dw 0x07FF, 0xFFE0   ; .....######################.....
    dw 0x07FF, 0xFFE0   ; .....######################.....
    dw 0x03FF, 0xFFC0   ; ......####################......
    dw 0x01FF, 0xFF80   ; .......##################.......
    dw 0x007F, 0xFF00   ; .........###############........
    dw 0x001F, 0xFC00   ; ...........###########..........
    dw 0x040F, 0xF000   ; .....#......########............
    dw 0x0003, 0xC000   ; ..............####..............
    dw 0x0010, 0x0000   ; ...........#....................
    dw 0x0001, 0x0000   ; ...............#................
    dw 0x0000, 0x4000   ; .................#..............
    dw 0x0000, 0x0000   ; ................................
expl_large_yellow:   ; large explosion, middle layer
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0003, 0x8000   ; ..............###...............
    dw 0x0007, 0xC000   ; .............#####..............
    dw 0x0007, 0xE000   ; .............######.............
    dw 0x000F, 0xE000   ; ............#######.............
    dw 0x001F, 0xF000   ; ...........#########............
    dw 0x003F, 0xF800   ; ..........###########...........
    dw 0x00FF, 0xFE00   ; ........###############.........
    dw 0x01FF, 0xFF00   ; .......#################........
    dw 0x03FF, 0xFF80   ; ......###################.......
    dw 0x03FF, 0xFF80   ; ......###################.......
    dw 0x01FF, 0xFF00   ; .......#################........
    dw 0x00FF, 0xFE00   ; ........###############.........
    dw 0x003F, 0xFC00   ; ..........############..........
    dw 0x003F, 0xFC00   ; ..........############..........
    dw 0x003F, 0xF800   ; ..........###########...........
    dw 0x001F, 0xF000   ; ...........#########............
    dw 0x001F, 0x8000   ; ...........######...............
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
expl_large_white:   ; large explosion, core
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0001, 0xC000   ; ...............###..............
    dw 0x000F, 0xE000   ; ............#######.............
    dw 0x000F, 0xF000   ; ............########............
    dw 0x000F, 0xF000   ; ............########............
    dw 0x0007, 0xE000   ; .............######.............
    dw 0x0003, 0xC000   ; ..............####..............
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
    dw 0x0000, 0x0000   ; ................................
sparkle_big:   ; twinkling star
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x03C0   ; ......####......
    dw 0x1FF8   ; ...##########...
    dw 0x1FF8   ; ...##########...
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0x0180   ; .......##.......
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
sparkle_small:
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0180   ; .......##.......
    dw 0x03C0   ; ......####......
    dw 0x03C0   ; ......####......
    dw 0x0180   ; .......##.......
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
galaxy_glow:   ; galaxy glow
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x1000   ; ...#............
    dw 0x2A80   ; ..#.#.#.#.......
    dw 0x5F40   ; .#.#####.#......
    dw 0x2FA0   ; ..#.#####.#.....
    dw 0x1FF0   ; ...#########....
    dw 0x0FF8   ; ....#########...
    dw 0x05F4   ; .....#.#####.#..
    dw 0x02FA   ; ......#.#####.#.
    dw 0x0154   ; .......#.#.#.#..
    dw 0x0008   ; ............#...
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
galaxy_core:   ; galaxy core
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0780   ; .....####.......
    dw 0x07C0   ; .....#####......
    dw 0x03E0   ; ......#####.....
    dw 0x01E0   ; .......####.....
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
    dw 0x0000   ; ................
shield_ring:   ; shield bubble 32x32
    dw 0x0000, 0x0000   ; ................................
    dw 0x001F, 0xF800   ; ...........##########...........
    dw 0x007F, 0xFE00   ; .........##############.........
    dw 0x01F0, 0x0F80   ; .......#####........#####.......
    dw 0x03C0, 0x03C0   ; ......####............####......
    dw 0x0700, 0x00E0   ; .....###................###.....
    dw 0x0E00, 0x0070   ; ....###..................###....
    dw 0x1C00, 0x0038   ; ...###....................###...
    dw 0x1800, 0x0018   ; ...##......................##...
    dw 0x3800, 0x001C   ; ..###......................###..
    dw 0x3000, 0x000C   ; ..##........................##..
    dw 0x7000, 0x000E   ; .###........................###.
    dw 0x6000, 0x0006   ; .##..........................##.
    dw 0x6000, 0x0006   ; .##..........................##.
    dw 0x6000, 0x0006   ; .##..........................##.
    dw 0x6000, 0x0006   ; .##..........................##.
    dw 0x6000, 0x0006   ; .##..........................##.
    dw 0x6000, 0x0006   ; .##..........................##.
    dw 0x6000, 0x0006   ; .##..........................##.
    dw 0x6000, 0x0006   ; .##..........................##.
    dw 0x7000, 0x000E   ; .###........................###.
    dw 0x3000, 0x000C   ; ..##........................##..
    dw 0x3800, 0x001C   ; ..###......................###..
    dw 0x1800, 0x0018   ; ...##......................##...
    dw 0x1C00, 0x0038   ; ...###....................###...
    dw 0x0E00, 0x0070   ; ....###..................###....
    dw 0x0700, 0x00E0   ; .....###................###.....
    dw 0x03C0, 0x03C0   ; ......####............####......
    dw 0x01F0, 0x0F80   ; .......#####........#####.......
    dw 0x007F, 0xFE00   ; .........##############.........
    dw 0x001F, 0xF800   ; ...........##########...........
    dw 0x0000, 0x0000   ; ................................

; 3x5 font, ASCII 32..90, one word per glyph (15 bits, row-major, MSB = top-left pixel)
font35:
    dw 0x0000, 0x2482, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
    dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x01C0, 0x0002, 0x12A4
    dw 0x7B6F, 0x2C97, 0x73E7, 0x73CF, 0x5BC9, 0x79CF, 0x79EF, 0x7249
    dw 0x7BEF, 0x7BCF, 0x0410, 0x0000, 0x1511, 0x0000, 0x4454, 0x0000
    dw 0x0000, 0x2BED, 0x6BAE, 0x3923, 0x6B6E, 0x79A7, 0x79A4, 0x396B
    dw 0x5BED, 0x7497, 0x126A, 0x5BAD, 0x4927, 0x5FED, 0x6B6D, 0x2B6A
    dw 0x6BA4, 0x2B73, 0x6BAD, 0x388E, 0x7492, 0x5B6F, 0x5B6A, 0x5BFD
    dw 0x5AAD, 0x5A92, 0x72A7

%if ($ - $$) > 0x8000
    %error "code and data no longer fit below the frame buffer"
%endif

    align 512, db 0
text_end:

textsize equ text_end - text_start
