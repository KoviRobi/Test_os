@i boilerplate.w

\def\title{System calls}
\def\contentsfile{syscalls_contents}

@*Introduction. This handles \.{SVC}s

A sample handler is:
@p
/* TODO */@^TODO@>
#include <common.h>
#include <drivers/uart.h>
void svc_handler(uint32_t svc_no, uint32_t *regs_r0_to_r3_r12)
{
  uart_puts("SVC Number is: 0x");
  uart_puthex(svc_no);
  uart_putc('\n');
  uart_putc('\n');
  uart_puts("R0  is: "); uart_puthex(*regs_r0_to_r3_r12);     uart_putc('\n');
  uart_puts("R1  is: "); uart_puthex(*(regs_r0_to_r3_r12+1)); uart_putc('\n');
  uart_puts("R2  is: "); uart_puthex(*(regs_r0_to_r3_r12+2)); uart_putc('\n');
  uart_puts("R3  is: "); uart_puthex(*(regs_r0_to_r3_r12+3)); uart_putc('\n');
  uart_puts("R12 is: "); uart_puthex(*(regs_r0_to_r3_r12+4)); uart_putc('\n');
}
