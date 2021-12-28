; Vernamova sifra na architekture DLX
; Martin Zmitko xzmitk01

        .data 0x04          ; zacatek data segmentu v pameti
login:  .asciiz "xzmitk01"  ; <-- nahradte vasim loginem
cipher: .space 9 ; sem ukladejte sifrovane znaky (za posledni nezapomente dat 0)

        .align 2            ; dale zarovnavej na ctverice (2^2) bajtu
laddr:  .word login         ; 4B adresa vstupniho textu (pro vypis)
caddr:  .word cipher        ; 4B adresa sifrovaneho retezce (pro vypis)

        .text 0x40          ; adresa zacatku programu v pameti
        .global main        ; 

main:	lb r8, login(r9)
	slti r21, r8, 97
	bnez r21, end 	    ;kontrola jestli neni nactene cislo
	nop
	nop
	seqi r21, r15, 1
	bnez r21, charM     ;rozhodovani mezi kodovanim z, m
	nop
	nop

charZ:	addi r15, r0, 1
	j last
	nop
	nop

charM:	addi r15, r0, 0
	subi r8, r8, 13
	slti r21, r8, 97
	beqz r21, last
	nop
	nop
	addi r8, r8, 26

last:	sb cipher(r9), r8	;ulozit znak
	addi r9, r9, 1
	j main
	nop
	nop

end:    addi r9, r9, 1
	sb cipher(r9), r0	;na konec vypsat 0
	addi r14, r0, caddr ; <-- pro vypis sifry nahradte laddr adresou caddr
        trap 5  ; vypis textoveho retezce (jeho adresa se ocekava v r14)
        trap 0  ; ukonceni simulace
