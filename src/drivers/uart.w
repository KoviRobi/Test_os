@i boilerplate.w

\def\title{UART}
\def\contentsfile{uart_contents}

@* Introduction. The universal asynchronous receiver/transmitter (UART)
is a way of translating parallel data (such as bytes) into serial
form to communicate over a single wire (two in this case, one wire for
transmission and one for reception).

@ Externally, we plan to support setting up the UART, transmitting a
character (and also strings and numbers) and receiving a character.
@(uart.h@>=
#ifndef UART_H
#define UART_H

#include <common.h>

uint32_t uart_init();
void uart_putc(uint8_t);
void uart_puts(const char *);
void uart_puthex(uint32_t);
void uart_putbin(uint32_t);
void uart_putdec(uint32_t);
void uart_putsgn(int32_t); /* Signed decimal */
uint8_t uart_getc();

#endif /* end of include guard: \.{UART\_H} */

@ Then we include the necessary header files and define the base address
for \.{UART0} on the Raspberry Pi. It may be better to convert |uart_init|
to take the base address as an argument, so that we can have different
UART devices. We have put the definitions of the registers at the end,
as they are not very interesting.
@p
#include "uart.h"
#include <common.h>
#include <drivers/gpio.h>

#define UART_BASE 0x20201000

@<Registers for UART@>

@ Initialising the UART is done in the following stages.
@p
uint32_t uart_init()
{
    @<Wait for UART to stop being busy@> @;
    @<Disable UART and set up GPIO pins @> @;
    @<Clear FIFO and set up baud@> @;
    @<Set transmission to 8N1 with FIFO@> @;
    @<Unmask interrupts@> @;
    @<Set up FIFO interrupt trigger levels@> @;
    @<Enable UART and transmission/reception of data@> @;

    return 0;
}

@ TODO
@<Wait for UART to stop being busy@>=
/* If still transmitting, wait for finish */
*(volatile uint32_t *)uart_imsc = 0x0;
while (uart_cr->UARTEN && uart_fr->BUSY) ;

@ TODO
@<Disable UART and set up GPIO pins @>=
uart_cr->UARTEN = 0;

if (set_GPIO_function(14, gpio_alt0)@|
|| set_GPIO_function(15, gpio_alt0))
    return 1;

@ TODO
@<Clear FIFO and set up baud@>=
/* Flush FIFO */
uart_lcrh->FEN = 0;

/* Clear interrupt flags */
*(volatile uint32_t *)uart_icr = 0x7FF;

/* Set integer and fractional part of baud rate */
*uart_ibrd = 1;
*uart_fbrd = 40;

@ TODO
@<Set transmission to 8N1 with FIFO@>=
uart_lcrh->FEN = 1;
uart_lcrh->WLEN = 3; /* {\bf 8} bits; */
uart_lcrh->PEN = 0;  /* {\bf N}o parity */
uart_lcrh->STP2 = 0; /* {\bf 1} stop bit */

@ TODO
@<Unmask interrupts@>=
/* Interrupts still need registering with |add_irq_handler| */
uart_imsc->CTSMIM = 1;
uart_imsc->RXIM   = 1;
uart_imsc->TXIM   = 1;
uart_imsc->RTIM   = 1;
uart_imsc->FEIM   = 1;
uart_imsc->PEIM   = 1;
uart_imsc->BEIM   = 1;
uart_imsc->OEIM   = 1;

@ TODO
@<Set up FIFO interrupt trigger levels@>=
uart_ifls->RXIFLSEL = 2; /* ${1\over 2}$ full */
uart_ifls->TXIFLSEL = 2; /* ${1\over 2}$ full */

@ TODO
@<Enable UART and transmission/reception of data@>=
uart_cr->UARTEN = 1;
uart_cr->TXE    = 1;
uart_cr->RXE    = 1;

@ TODO@^TODO@> Use circular buffer? Block process if buffer full? Also, software flow control too (if hardware flow control is off)?
@p
void uart_putc(uint8_t c)
{
    while (uart_fr->TXFF) ;
    uart_dr->DATA = c;
}

@ TODO
@p
void uart_puts(const char * s)
{
    while (*s)
        uart_putc(*s++);
}

uint8_t uart_getc()
{
    while (uart_fr->RXFE) ;
    return uart_dr->DATA;
}

void uart_puthex(uint32_t h)
{
    char hex[16] = { '0', '1', '2', '3',
                     '4', '5', '6', '7',
                     '8', '9', 'A', 'B',
                     'C', 'D', 'E', 'F' };
    uart_putc(hex[(h&0xF0000000)>>28]);
    uart_putc(hex[(h&0x0F000000)>>24]);
    uart_putc(hex[(h&0x00F00000)>>20]);
    uart_putc(hex[(h&0x000F0000)>>16]);
    uart_putc(hex[(h&0x0000F000)>>12]);
    uart_putc(hex[(h&0x00000F00)>>8 ]);
    uart_putc(hex[(h&0x000000F0)>>4 ]);
    uart_putc(hex[(h&0x0000000F)    ]);
}

void uart_putbin(uint32_t b)
{
    uint32_t i;
    for (i = 0; i < 32; i++)
    {
        uart_putc((b&(0x1<<(31-i)))?'1':'0');
    }
}

void uart_putdec(uint32_t d)
{
    uint32_t rem;
    if (d == 0) uart_putc('0');
    while (d != 0)
    {
        rem = d%10;
        d  /= 10;
        uart_putc('0' + rem);
    }
}

void uart_putsgn(int32_t d)
{
    uint32_t rem;
    if (d < 0)
    {
        uart_putc('-');
        d *= -1;
    }
    if (d == 0) uart_putc('0');
    while (d != 0)
    {
        rem = d%10;
        d  /= 10;
        uart_putc('0' + rem);
    }
}

@ Here are the registers for UART, in the same order as listed in [2,
\S 13.4].  We first implement the data register. The bit fields may be
endian specific, I am not sure.
@^TODO@>@^little-endian@>
@<Registers for UART@>=
volatile struct UART_DR
{
    uint8_t DATA;
    uint32_t FE : 1;
    uint32_t PE : 1;
    uint32_t BE : 1;
    uint32_t OE : 1;
    uint32_t    : 20;
} * uart_dr = (struct UART_DR *)(UART_BASE + 0x00); @#

@ We do not implement the receive status/error clear register.
@<Registers for UART@>=
/* |@^TODO@>|Not implemented \\{RSRECR} */ @#

@ Then the flag register, which contains information about the current
status of the UART.
@<Registers for UART@>=
volatile struct UART_FR
{
    uint32_t CTS  : 1;
    uint32_t DSR  : 1;
    uint32_t DCD  : 1;
    uint32_t BUSY : 1;
    uint32_t RXFE : 1;
    uint32_t TXFF : 1;
    uint32_t RXFF : 1;
    uint32_t TXFE : 1;
    uint32_t RI   : 1;
    uint32_t      : 23;
} * uart_fr = (struct UART_FR *)(UART_BASE + 0x18); @#

@ We do not implement the \\{ILPR} register either, as it is for the
infra red capability, which our UART does not support.
@<Registers for UART@>=
/* |@^TODO@>|Not implemented \\{ILPR} */ @#

@ For the integer part of the baud rate, we use |uint16_t| as it is
exactly 16 bits long, but the fractional part is only 6 bits long,
which we will have to remember ourselves.
@<Registers for UART@>=
volatile uint16_t * uart_ibrd = (uint16_t *)(UART_BASE + 0x24); @/
volatile uint8_t * uart_fbrd = (uint8_t *)(UART_BASE + 0x28); @#

@ The line control register controls options for the format of data
transmission and must not be changed when the UART is enabled or is
completing a transmission before becoming disabled.
@<Registers for UART@>=
volatile struct UART_LCRH
{
    uint32_t BRK  : 1;
    uint32_t PEN  : 1;
    uint32_t EPS  : 1;
    uint32_t STP2 : 1;
    uint32_t FEN  : 1;
    uint32_t WLEN : 2;
    uint32_t SPS  : 1;
    uint32_t      : 24;
} * uart_lcrh = (struct UART_LCRH *)(UART_BASE + 0x2C); @#

@ To program the control register (1) disable the UART; (2) wait for
end of transmission/reception of current character; (3) flush the FIFO
by setting $\\{uart\_lcrh}\MG\.{FEN}\K\T{0}{}$; (4) Set the desired options in the
control register; (5) enable the UART.
@<Registers for UART@>=
volatile struct UART_CR
{
    uint32_t UARTEN : 1;
    uint32_t SIREN  : 1;
    uint32_t SIRLP  : 1;
    uint32_t        : 4;
    uint32_t LBE    : 1;
    uint32_t TXE    : 1;
    uint32_t RXE    : 1;
    uint32_t DTR    : 1;
    uint32_t RTS    : 1;
    uint32_t OUT1   : 1;
    uint32_t OUT2   : 1;
    uint32_t RTSEN  : 1;
    uint32_t CTSEN  : 1;
    uint32_t        : 16;
} * uart_cr = (struct UART_CR *)(UART_BASE + 0x30); @#

@ Interrupt level select is the level at which the interrupt signal is
asserted. Note that this happens based on a transmission through that
level, rather than the current level, thus when lowering the level, it
may be a good idea to call the relevant handler to be on the safe side.
The options are $1\over 8$, $1\over 4$, $1\over 2$, $3\over 4$ and
$7\over 8$ for 0--4 respectively (in binary of course).
@<Registers for UART@>=
volatile struct UART_IFLS
{
    uint32_t          : 26;
    uint32_t RXIFLSEL : 3;
    uint32_t TXIFLSEL : 3;
} * uart_ifls = (struct UART_IFLS *)(UART_BASE + 0x34); @#

@ The interrupt mask register is a read and write register where reading
returns the current value and writing sets the current value (a value
of 1 means that interrupt is enabled).
@<Registers for UART@>=
volatile struct UART_IMSC
{
    uint32_t RIMIM  : 1;
    uint32_t CTSMIM : 1;
    uint32_t DCDMIM : 1;
    uint32_t DSRMIM : 1;
    uint32_t RXIM   : 1;
    uint32_t TXIM   : 1;
    uint32_t RTIM   : 1;
    uint32_t FEIM   : 1;
    uint32_t PEIM   : 1;
    uint32_t BEIM   : 1;
    uint32_t OEIM   : 1;
    uint32_t        : 21;
} * uart_imsc = (struct UART_IMSC *)(UART_BASE + 0x38); @#

@ We do not implement the raw interrupt status register as the masked
interrupt status register should be used instead. (Why handle interrupts
we did not want to know about?)
@<Registers for UART@>=
/* |@^TODO@>|Not implemented \\{RIS} */ @/

@ The masked interrupt status register is useful for a handler to know
which actions it needs to take.
@<Registers for UART@>=
volatile struct UART_MIS
{
    uint32_t RIMMIS  : 1;
    uint32_t CTSMMIS : 1;
    uint32_t DCDMMIS : 1;
    uint32_t DSRMMIS : 1;
    uint32_t RXMIS   : 1;
    uint32_t TXMIS   : 1;
    uint32_t RTMIS   : 1;
    uint32_t FEMIS   : 1;
    uint32_t PEMIS   : 1;
    uint32_t BEMIS   : 1;
    uint32_t OEMIS   : 1;
    uint32_t        : 21;
} * uart_mis = (struct UART_MIS *)(UART_BASE + 0x44); @#

@ The interrupt clear register is what an interrupt handler should then
write into after it has handled the relevant interrupt.
@<Registers for UART@>=
volatile struct UART_ICR
{
    uint32_t RIMIC  : 1;
    uint32_t CTSMIC : 1;
    uint32_t DCDMIC : 1;
    uint32_t DSRMIC : 1;
    uint32_t RXIC   : 1;
    uint32_t TXIC   : 1;
    uint32_t RTIC   : 1;
    uint32_t FEIC   : 1;
    uint32_t PEIC   : 1;
    uint32_t BEIC   : 1;
    uint32_t OEIC   : 1;
    uint32_t        : 21;
} * uart_icr = (struct UART_ICR *)(UART_BASE + 0x44); @#

@ We do not implement the DMA control register (Raspberry Pi does not
support it) or any of the test registers (not going to be used in the
kernel).
@<Registers for UART@>=
/* |@^TODO@>|Not implemented \\{DMACR} */ @;
/* Not implemented test registers \\{ITCR}, \\{ITIP}, \\{ITOP} and \\{TDR} */ @;
