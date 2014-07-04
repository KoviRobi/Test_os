@i boilerplate.w

\def\title{Memory Management (Virtual Memory)}
\def\contentsfile{memory_management_contents}

@* Introduction.

@ See [1, \S 6.4.1].

@ We first have to program the relevant CP15 registers, which are [1, \S 6.13]

When the CP15 Control Register c1 Bit 23 is set to 1 in the corresponding world, the subpage
AP bits are disabled and the page tables have support for ARMv6 MMU features. Four new page
table bits are added to support these features:

@ Note, page table colouring, as in [1, \S 6.11.3].

@ TTBCR = 2 for 4K translation table 0 size?

@ The page table is stored in memory, pointed to by translation table
base register 0 (TTBR0) or base register 1 (TTBR1), depending on (a)
the value of the translation table base control register $N$; (b) the
requested virtual address. If the virtual address $v$ is $0\leq v <
2^{32-N}$ then TTBR0 is used, otherwise ($2^{32-N}\leq v < 4\rm{GiB}$)
TTBR1 is used.

This is so that we can have a constant page table for kernel routines
which we don't have to invalidate on context switches. This also means
that we need a smaller page table for TTBR0, as it does not need to
cover the whole range.

Note, for debugging purposes, if we should wish to do so, we could
disable the hardware page table walk separately for either TTBR0 or
TTBR1 in the TTBRCR, see [1, \S 3.2.15].

For our operating system, we will allow custom values of the translation
table control register by providing a simple function to set the split.
\verbboxfalse
@(mmu_asm.S@>=
@=.set WRONG_TTBR0_SIZE, -1@> @;
@=.globl set_ttbr0_size@> @;
@=set_ttbr0_size:@> @;
@=	CMP r0, #7@> @;
@=	MOVHI r0, #WRONG_TTBR0_SIZE@> @;
@=	MOV pc, lr@> @; /* Return with error */
@=	MRC p15, 0, r1, c2, c0, 2@> @; /* Read TTBRCR */
@=	BIC r0, r0, #7@> @;
@=	ORR r0, r0, r1@> @;
@=	MCR p15, 0, r1, c2, c0, 2@> @; /* Write TTBRCR */

@ We also make this function public.
@(memory_management.h@>=
#ifndef MEMORY_MANAGEMENT_H
#define MEMORY_MANAGEMENT_H

#include <common.h>

#define WRONG_TTBR0_SIZE -1 @^errno@>
uint32_t set_ttbr0_size(uint8_t size); /* size is $N$, max 7 */

#endif /* end of include guard: \.{MEMORY\_MANAGEMENT\_H} */

@ To enable page tables, we set bit zero of the control coprocessor's c1 register. Note that because the \.{MMU} bit is banked, we can enable the \.{MMU} in non-secure (privileged) mode only.
\verbboxfalse
@(mmu_asm.S@>=
@=.globl mmu_enable@> @;
@=mmu_enable:@> @;
@=	MRC p15, 0, r0, c1, c0, 0@> @; /* Read Control Register configuration data */
@=	AND r0, r0, #1@> @;
@=	MCR p15, 0, r0, c1, c0, 0@> @; /* Write Control Register configuration data */

@
@p
#include <common.h>
#include <drivers/uart.h>

void mmu_abort_handler()
{
    uart_puts("MMU ABORT!");
    return;
}

@* @^TODO@> Further developments.
