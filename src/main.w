@i boilerplate.w

\def\title{Kernel start}
\def\contentsfile{main_contents}

@* Common types. This is just a bunch of type declarations which will
be used in the kernel. This is so that we can use the same type across
different platforms. The sizes of each type we know from [6, \S 11.2].
We also have a one inline function for delaying a few clock cycles.

@(common.h@>=
#ifndef COMMON_H
#define COMMON_H

#define NULL@, (void *)0
#define SUCCESS 0

typedef unsigned int        size_t;
typedef unsigned long long  uint64_t;
typedef          long long  int64_t;
typedef unsigned int        uint32_t;
typedef          int        int32_t;
typedef unsigned short      uint16_t;
typedef          short      int16_t;
typedef unsigned char       uint8_t;
typedef          char       int8_t;

inline void delay(int32_t count)
{
    asm volatile("__delay_%=: subs %[count], %[count], #1; bne __delay_%=\n"
	     : : [count]"r"(count) : "cc");
}

#endif /* end of include guard: \.{COMMON\_H} */

@* Boot code. First we set up our stack pointers. We have linked our code
into |0x8000|, so we set up the stack (growing downwards) at addresses
less than |0x8000|.

\centretable
{ # & \vrule height 3ex\hfill # \hfill \vrule height 3ex\cr
\cr \noalign{\hrule}
|0x8000| & Monitor call stack \cr \noalign{\hrule}
|0x7f00| & Undefined instruction exception stack \cr \noalign{\hrule}
|0x7e00| & Abort exception stack \cr \noalign{\hrule}
|0x7d00| & Supervisor call stack \cr \noalign{\hrule}
|0x7c00| & Interrupt request stack \cr \noalign{\hrule}
|0x7b00| & User and system mode stack \cr
$\vdots$ & $\vdots$ \cr
}
\verbboxfalse
@(boot.S@>=
/* To keep this in the first portion of the binary. */
@=.section ".text.boot"@> @;
@=.globl Start@> @;

/*
Entry point of kernel, registers are:
\smallskip
\centretable
{\vrule height 3ex\hfill # $\gets$ & # \vrule height 3ex\cr
\noalign{\hrule}
r0       & |0x00000000| \cr
r1       & |0x00000C42| \cr
r2       & |0x00000100| \cr
r15 (PC) & |0x00008000| \cr \noalign{\hrule}
}
\smallskip
We want to preserve these values (except PC) for |void kernel_main(uint32_t r0, uint32_t r1, uint32_t r2)|
*/
@=Start:@> @;
    /* Set up IRQ, SVC, ABT, UND, MON and System/User stack (TechRef Table 2-7) */
@=	mov r4, #0x7b00@> @;
@=	cps #18@> @; /* IRQ */
@=	add sp, r4, #0x100@> @;
@=	cps #19@> @; /* SVC */
@=	add sp, r4, #0x200@> @;
@=	cps #23@> @; /* ABT */
@=	add sp, r4, #0x300@> @;
@=	cps #27@> @; /* UND */
@=	add sp, r4, #0x400@> @;
@=	cps #22@> @; /* MON */
@=	add sp, r4, #0x500@> @;
@=	cps #31@> @; /* Back to system */
@=	mov sp, r4@> @;

@ Then we clear out the bss segment as it contains non-initialised
static variables.
\verbboxfalse
@(boot.S@>=
    /* Clear out bss. */
@=	ldr r4, =_bss_start@> @;
@=	ldr r9, =_bss_end@> @;
@=	mov r5, #0@> @;
@=	mov r6, #0@> @;
@=	mov r7, #0@> @;
@=	mov r8, #0@> @;
@=	b 2f@> @;

@=1:@> @;
    /* Store multiple at r4. */
@=	stmia   r4!, {r5-r8}@> @;

    /* If we are still below |bss_end|, loop. */
@=2:@> @;
@=	cmp r4, r9@> @;
@=	blo 1b@> @;

@ Finally we can call our kernel entry function and we put a protective
infinite loop after it, should the kernel return for some reason.
\verbboxfalse
@(boot.S@>=
    /* Call |kernel_main| */
@=	ldr r3, =kernel_main@> @;
@=	blx r3@> @;

    /* Halt */
@=halt:@> @;
@=	wfe@> @;
@=	b   halt@> @;

@* Main program. This is where you can do most of the customising, the other files are expected to be pretty similar between different kernels. Here we have included a small kernel that initialises all the drivers we currently have and starts a shell program@^TODO@>. First we include the necessary headers.
@p
#include <common.h>
#include <drivers/uart.h>
#include <drivers/exceptions.h>
#include <drivers/arm_timer.h>

@<Debug functions@> @;
void kernel_main(uint32_t r0, uint32_t r1, uint32_t atags)
{@<Kernel main@>}

@ Then, we initialise the UART and exceptions.
@<Kernel main@>=
uint32_t tmp;

uart_init();
exceptions_init();

@ Then, we initialise the timer with interrupts, printing messages as
we go along, to tell the user how far we have got.
@<Kernel main@>=
uart_puts("Hello, world!\n");

cerror(add_irq_handler(7, &put_timer_value), "setting the timer handler");
cerror(timer_init(0x10000, 1), "loading the timer");

uart_puts("Ok, so far!\n");

@ We then enter an infinite loop in which we parse simple commands@^TODO@>
TODO: launch shell.
@<Kernel main@>=
static volatile uint32_t * irq_basic_pending = (uint32_t *) 0x2000B200;
while(1==1) @/
{@+ char c = uart_getc(); @;
    switch(c)
    {
        case 'i': @;
            uart_puts("Base IRQ: 0x"); @+ uart_putbin(*irq_basic_pending);    @+ uart_putc('\n'); @;
            uart_puts("Reg1 IRQ: 0x"); @+ uart_putbin(*(irq_basic_pending+1));@+ uart_putc('\n'); @;
            uart_puts("Reg2 IRQ: 0x"); @+ uart_putbin(*(irq_basic_pending+2));@+ uart_putc('\n'); @;
            break;

        case 'u':
            cerror(del_irq_handler(7), "unsetting the timer handler");
            break;

        case 'r':
            cerror(add_irq_handler(7, &put_timer_value), "setting the timer handler");
            break;

        case 's':
            asm volatile ("MRS %[tmp], CPSR" : [tmp] "=r" (tmp));
            dump_psr(tmp);
            break;

        case 'j':
            if ((tmp = sleep(0x400)) != 0)
            {uart_puts("Something went wrong: ");uart_putsgn(tmp);uart_putc('\n');}
            break;

        case 'k':
            if ((tmp = sleep(0x40000)) != 0)
            {uart_puts("Something went wrong: ");uart_putsgn(tmp);uart_putc('\n');}
            break;

        default:
            uart_putc(c);
            break;
    }
}

@ We stop the compiler complaining about unused variables.
@d UNUSED(x) (void)(x)
@<Kernel main@>=
UNUSED(r0);
UNUSED(r1);
UNUSED(atags);

@ The |cerror(uint32_t rtn, char *string)| used above is just a simple
function that prints an error message along with the string if something
went wrong.
@<Debug functions@>=
void cerror (uint32_t rtn, const char *string)
{
    if (rtn != 0)
    {
        uart_puts("Something went wrong");
        uart_puts(string);
        uart_puts(": ");
        uart_putsgn(rtn);
        uart_putc('\n');
    }
}

@ We also have a function to print the stacks, in case we want to detect
stack overflow.
@<Debug functions@>=
void print_stacks()
{
    uart_puts("Stacks are (currently) at:\n");

    register uint32_t sp;

    asm volatile ("cps #18\nmov %[sp], sp\ncps #31" : [sp] "=r" (sp));

    uart_puts("IRQ Stack: ");
    uart_puthex(sp);
    uart_putc('\n');

    asm volatile ("cps #19\nmov %[sp], sp\ncps #31" : [sp] "=r" (sp));

    uart_puts("SVC Stack: ");
    uart_puthex(sp);
    uart_putc('\n');

    asm volatile ("cps #23\nmov %[sp], sp\ncps #31" : [sp] "=r" (sp));

    uart_puts("ABT Stack: ");
    uart_puthex(sp);
    uart_putc('\n');

    asm volatile ("cps #27\nmov %[sp], sp\ncps #31" : [sp] "=r" (sp));

    uart_puts("UND Stack: ");
    uart_puthex(sp);
    uart_putc('\n');

    asm volatile ("cps #22\nmov %[sp], sp\ncps #31" : [sp] "=r" (sp));

    uart_puts("MON Stack: ");
    uart_puthex(sp);
    uart_putc('\n');

    asm volatile ("cps #16\nmov %[sp], sp\ncps #31" : [sp] "=r" (sp));

    uart_puts("Usr Stack: ");
    uart_puthex(sp);
    uart_putc('\n');
}

@ And also a function to print the processor status register (taken as
an argument so that we can use this for both the current and the saved
processor status register).
@<Debug functions@>=
void dump_psr(uint32_t psr)
{ /* Capital is flag enabled */
    uart_puts((psr&0x80000000)?"- ":"+ ");
    uart_puts((psr&0x40000000)?"==0 ":"!=0 ");
    uart_puts((psr&0x20000000)?"C ":"c "); /* Carry */
    uart_puts((psr&0x10000000)?"V ":"v "); /* Overflow */
    uart_puts((psr&0x08000000)?"Q ":"q "); /* |@^TODO@>| TODO */
    uart_puts((psr&0x01000000)?"J ":"j "); /* Jazelle */
    uart_putdec((psr&0x000F0000)>>16);uart_putc(' ');
    uart_puts((psr&0x00000200)?"E ":"e "); /* Endianness */
    uart_puts((psr&0x00000100)?"a ":"A "); /* Abort exception */
    uart_puts((psr&0x00000080)?"i ":"I "); /* IRQ exception */
    uart_puts((psr&0x00000040)?"f ":"F "); /* FIQ exceptin */
    uart_puts((psr&0x00000020)?"T ":"t "); /* Thumb state */
    switch(psr&0x0000001F)
    {
        case 16: uart_puts("Usr\n"); @+ break;
        case 17: uart_puts("FIQ\n"); @+ break;
        case 18: uart_puts("IRQ\n"); @+ break;
        case 19: uart_puts("SVC\n"); @+ break;
        case 22: uart_puts("SMC\n"); @+ break;
        case 23: uart_puts("ABT\n"); @+ break;
        case 27: uart_puts("UND\n"); @+ break;
        case 31: uart_puts("Sys\n"); @+ break;
        default: uart_puts("???\n"); @+ break;
    }
}

void put_timer_value(@qr0, r1, r2, r3@>)
    @quint32_t r0;@>
    @quint32_t r1;@>
    @quint32_t r2;@>
    @quint32_t r3;@>
{
    @quart_puts("0x ");uart_puthex(r0);uart_putc(' ');@>
    @quart_puts("0x ");uart_puthex(r1);uart_putc(' ');@>
    @quart_puts("0x ");uart_puthex(r2);uart_putc(' ');@>
    @quart_puts("0x ");uart_puthex(r3);uart_putc('\n');@>
    static volatile uint32_t *armTimerClear = (uint32_t *)0x2000b40c;
    static volatile uint32_t *armTimerValue = (uint32_t *)0x2000b404;

    *armTimerClear = 0; // ARM Timer IRQ clear
    uart_puts("Timer value: "); uart_putdec(*armTimerValue); uart_putc('\n');
}
