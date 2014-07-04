@i boilerplate.w

\def\title{Exceptions}
\def\contentsfile{exceptions_contents}

@* Introduction. Exceptions are a hardware based way of telling the
operating system something went wrong or just needs attention. The
alternative is either a software based method, which would be slow and
unreliable or just letting the program carry on mindlessly. The table of
exceptions below gives the type of exceptions the processor can expect
along with an offset into an exception vector table, a table of function
addresses to go to when the given exception occurs (see [3, \S 6.4],
the Raspberry Pi processor is an ARMv6k).

\bigskip\centretable
{ \hfill # \vrule height 3ex\quad & \sc # \hfill\cr
Offset & \rm Interrupt \cr \noalign{\hrule height 0.8pt}
|0x00| & Reset \cr
|0x04| & Undefined instruction \cr
|0x08| & Supervisor call (SVC, formerly SWI) \cr
|0x0C| & Prefetch abort \cr
|0x10| & Data abort \cr
|0x14| & --- \cr
|0x18| & Interrupt request (IRQ) \cr
|0x1C| & Fast interrupt request (FIQ) \cr
}\bigskip

\desc Reset \rm[1, \S 2.12.5]. This is exception will jump to the base
of the memory and continue execution from there, so we do not deal with
it as it is not very useful for us. Perhaps we could store a branch to
|kernel_main| there, if we wanted to.
\medskip

\desc Undefined instruction \rm[1, \S 2.12.14]. This occurs when we
the processor encounters an instruction it can not decode (and nor can
its coprocessors). This can be used to extend the instruction set.
\medskip

\desc Supervisor call (formerly software interrupt) \rm[1, \S
2.12.12]. This is a special instruction to enter supervisor mode from
non-secure mode, to execute a trusted code at the interrupt handler
end. During a supervisor call, interrupt requests are disabled. This
also has a 24 bit number at the bottom to allow for different supervisor
call functions.
\medskip

\desc Abort \rm[1, \S 2.12.10]. This is called when the memory
management unit can not get the requested data. If the data is an
instruction to be executed, it is called a {\bf prefetch abort} otherwise
it is a {\bf data abort}.
\medskip

\desc Interrupt request (IRQ) \rm[1, \S 2.12.5]. This happens when a
physical line is asserted low (when there is a voltage drop). This is
used by hardware to get attention.
\medskip

\desc Fast interrupt request (FIQ) \rm[1, \S 2.12.5]. This is like the
IRQ, except it provides eight private registers to minimise (or remove)
register saving. It is also tactically placed at the end, so that you
can put the handler code there, rather than branching.

@ So this code needs to do (a) provide an initialisation mechanism for
the exceptions; (b) provide function stubs for each exception. We are
only providing stubs as handling the interrupts is driver specific,
for example receiving a timer IRQ belongs to the scheduling code.

Because supervisor calls are specific to the kernel interface, we are not
going to change them during runtime, on the other hand what happens on
an IRQ can change, so we provide a functionality to register (and remove)
handlers to interrupt numbers. Interrupt numbers are given in
[2, page 113].

The exception handling initialisation, along with the stubs are programmed
in assembly, we only program the IRQ registration code in \CEE/, which
we shall discuss first.

@p
@<Preprocessor definitions@>@;
@<Interrupt request handlers@>@;

@ In the preprocessor definitions, we include our header file, as well
as hardcode the memory mapped IRQ handling registers.
@<Preproc...@>=
#include "exceptions.h"
#define ENABLE_IRQ_BASIC       @,(uint32_t *)0x2000B218
#define ENABLE_IRQ_REGISTER_1  @,(uint32_t *)0x2000B210
#define ENABLE_IRQ_REGISTER_2  @,(uint32_t *)0x2000B214
#define DISABLE_IRQ_BASIC      @,(uint32_t *)0x2000B224
#define DISABLE_IRQ_REGISTER_1 @,(uint32_t *)0x2000B21C
#define DISABLE_IRQ_REGISTER_2 @,(uint32_t *)0x2000B220

@ In our header file, we have the usual header guard, but leave the rest
to be filled in later.
@(exceptions.h@>=
#ifndef EXCEPTIONS_H
#define EXCEPTIONS_H

#include <common.h>
@<Public definitions@>
#endif /* end of include guard: \.{EXCEPTIONS\_H} */

@ All of our interrupt handling functions take no arguments and return
no values.
@<Public...@>=
typedef void @[@] (*irq_handler_t)(void);

@ Then we define the table of interrupt handling functions, which is just
a 72 element array with values given in the table below.  The reason for
this reverse assignment is due to the way we poll IRQs in |exception_irq|
below @^TODO@>(TODO: reference correct section) (this also means the
table is in priority order).

\bigskip\centretable
{ \hfill # \vrule height 3ex\quad & \sc # \hfill\cr
Offset & Pending IRQ \cr \noalign{\hrule height 0.8pt}
0      & Illegal Access type 0 \cr
1      & Illegal Access type 1 \cr
2      & GPU1 halted \cr
3      & GPU0 halted (or GPU1 if bit 10 of control register is set) \cr
4      & ARM Doorbell 1 \cr
5      & ARM Doorbell 0 \cr
6      & ARM Mailbox \cr
7      & ARM Timer \cr
8--71  & IRQ63--IRQ0 \cr
}\bigskip

@<Interrupt request handlers@>=
irq_handler_t irq_vector_table[72] =
{ /* All values initialised to |NULL| */
NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,@/
NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,@/
NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,@/
NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,@/
NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,@/
NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,@/
NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,@/
NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,@/
NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
};

@ We now need functions to register and unregister a handler along with
enabling/disabling those IRQs, register values given in [2, \S 7.5]. The
IRQ numbers are to be understood as given in the table above.

@<Interrupt request handlers@>=
uint32_t add_irq_handler(uint32_t irq_no, irq_handler_t handler)
{
    if (irq_no > 71)
        return WRONG_IRQ_NO;
    else if (irq_vector_table[irq_no] != NULL)
        return IRQ_ALREADY_HANDLED;
    else if (irq_no < 8)
        *(ENABLE_IRQ_BASIC) = 1<<(7-irq_no);
    else if (irq_no < 40)
        *(ENABLE_IRQ_REGISTER_2) = 1<<(39-irq_no);
    else if (irq_no < 72)
        *(ENABLE_IRQ_REGISTER_1) = 1<<(71-irq_no);
    irq_vector_table[irq_no] = handler;
    return SUCCESS;
}

@ The code to unregister is similar, using the disable registers instead.
@<Interrupt request handlers@>=
uint32_t del_irq_handler(uint32_t irq_no)
{
    if (irq_no > 71)
        return WRONG_IRQ_NO;
    else if (irq_no < 8)
        *(DISABLE_IRQ_BASIC) = 1<<(7-irq_no);
    else if (irq_no < 40)
        *(DISABLE_IRQ_REGISTER_2) = 1<<(39-irq_no);
    else if (irq_no < 72)
        *(DISABLE_IRQ_REGISTER_1) = 1<<(71-irq_no);
    if (irq_vector_table[irq_no] == NULL)
        /* We still disabled IRQ to be safe */
        return IRQ_NOT_HANDLED;
    irq_vector_table[irq_no] = NULL;
    return SUCCESS;
}

@ We also put those function signatures into the header file. This
finishes our \CEE/ code.
@<Public...@>=
#define WRONG_IRQ_NO        -1 @^errno@>
#define IRQ_ALREADY_HANDLED -2
#define IRQ_NOT_HANDLED     -3
uint32_t add_irq_handler(uint32_t irq_no, irq_handler_t handler); /* Remember to clear IRQ manually! */
uint32_t del_irq_handler(uint32_t irq_no);

@ Initialising exception handling is just a matter of loading the address
of the exception vector table and enabling exceptions. Here {\tt r0}
is just a scratch register (that we don't need to save, see [4]).

\verbboxfalse
@(exceptions_asm.S@>=
@<Exceptions vector table@>
@=.globl exceptions_init@> @;
@=exceptions_init:@> @;
@=	LDR r0, =exceptions_vector_table@> @;
@=	MCR p15, 0, r0, c12, c0, 0@> /* Load address into coprocessor register */ @;
@=	CPSIE aif@> /* Enable ABORTs, IRQs, FIQs */ @;
@=	MOV pc, lr@> /* Return from function call */ @;

@ We also export our |exceptions_init()| function, reminding the linker
that it has the label |exceptions_init|, in case it does some name
mangling for usual function names. This may not be portable across
different compilers unfortunately.@^GCC@>
@<Public...@>=
uint32_t exceptions_init(void) asm ("exceptions_init");

@ Then we create the interrupt vector table, which we align on a 32-byte,
as the vector base address needs the last five bits to be zero [1,
\S 3.2.43].
\verbboxfalse
@<Exceptions vector table@>=
@=.align 5@> /* 5 bits in address or $2^5$ byte boundary */
@=.globl exceptions_vector_table@> @;
@=exceptions_vector_table:@> @;
@=	.extern exception_reset@> @;
@=	.extern exception_undef@> @;
@=	.extern exception_svc@> @;
@=	.extern exception_prefetch_abort@> @;
@=	.extern exception_data_abort@> @;
@=	.extern exception_irq@> @;
@=	.extern exception_fiq@> @;
@=	B exception_reset@> @;
@=	B exception_undef@> @;
@=	B exception_svc@> @;
@=	B exception_prefetch_abort@> @;
@=	B exception_data_abort@> @;
@=	B 0@> /* Undefined, should cause an prefetch abort */ @;
@=	B exception_irq@> @;
@=	B 0@> @; /* Unused FIQ */

@ We need one stub for each type of exception. Here, we are using the
instruction \.{SRS} and \.{RFE} to save the return state and to return
from the exception, using the address mode \.{DB} (decrement before) for
store and \.{IA} (increment after) for return, using the \.{SP} register,
that is we are going to use the banked stack (note, this requires the
banked stack to be set up), including an exclamation mark to store the
stack pointer back. However, this only saves the {\tt lr} and the {\tt
spsr} registers, we also want to save registers {\tt r0}--{\tt r12}. Note,
we even save the scratch registers {\tt r0}--{\tt r3} as exceptions could
happen within a function. In fact, saving {\tt r0}--{\tt r3} and {\tt r12}
is enough if we call a function (which saves the rest it uses).

For the reset exception we are just going to loop forever, after all,
this function will not be called at all, instead the execution will
restart from zero (for which we could perhaps during initialisation put
a branch instruction to the kernel entry point).

\verbboxfalse
@(exception_stubs.S@>=
@=.globl exception_reset@> @;
@=exception_reset:@> @.exception\_reset@> @;
@=	B exception_reset@> @;

@ For the undefined function stub, we are going to have a hashtable of
instruction codes, but for now we also do nothing (TODO@^TODO@>!).

\verbboxfalse
@(exception_stubs.S@>=
@=.globl exception_undef@> @;
@=exception_undef:@> @.exception\_undef@> @;
@=	B exception_undef@> @;

@ For the supervisor call, we will save the return state and then jump to
the system call handler. This code is modified from [1, \S 6.18], where
they have used \.{STMFD} instead of \.{PUSH} (and similarly for \.{POP})
to similar effect, as the carret ({\tt\^{}}) on the last \.{LDMFD}
instruction tells the processor to set the current processor status
register (\.{cpsr}) to the stored one (\.{spsr}).

\verbboxfalse
@(exception_stubs.S@>=
@=.globl exception_svc@> @;
@=exception_svc:@> @.exception\_svc@> @;
@=	STMFD   sp!, {r0-r3, r12, lr}@> @;  // \hfill Store registers
@=	MOV     r1, sp@> @;                 // \hfill Set pointer to parameters
@=	MRS     r0, spsr@> @;               // \hfill Get spsr
@=	STMFD   sp!, {r0, r3}@> @;          // \hfill Store spsr onto stack and align to 8-byte boundary
@=	TST     r0, #0x20@> @;              // \hfill SVC occurred in Thumb state?
@=	LDRNEH  r0, [lr,#-2]@> @;           // \hfill Yes: Load halfword and...
@=	BICNE   r0, r0, #0xFF00@> @;        // \hfill ...extract comment field
@=	LDREQ   r0, [lr,#-4]@> @;           // \hfill No: Load word and...
@=	BICEQ   r0, r0, #0xFF000000@> @;    // \hfill ...extract comment field
@=	BL      svc_handler@> @;            // \hfill Call |svc_handler(uint32_t svc_no, uint32_t *saved_regs);|
@=	LDMFD   sp!, {r0, r3}@> @;          // \hfill Get spsr from stack
@=	MSR     SPSR_cxsf, r0@> @;          // \hfill Restore spsr
@=	LDMFD   sp!, {r0-r3, r12, pc}^@> @; // \hfill Restore registers and return

@ For data and prefetch abort, we again defer the processing to another
function outside of this file, as this should be dealt with by the
MMU. The MMU Fault Address Register contains the address that caused the
abort [3, \S 6.10]. The only difference between the data and prefetch
abort is the return instruction. (TODO@^TODO@> Imprecise aborts? [1, table 6-12])

\verbboxfalse
@(exception_stubs.S@>=
@=.globl exception_prefetch_abort@> @;
@=.globl exception_data_abort@> @;
@=exception_prefetch_abort:@> @.exception\_prefetch\_abort@> @;
@=	SUB   lr, lr, #4@> @; // Change return address
@=	ADR   pc, 1f@> @; // Jump to \.{srsdb}
@=exception_data_abort:@> @.exception\_data\_abort@> @;
@=	SUB   lr, lr, #8@> @;
@=1:@> @; // Address for \.{adr}
@=	SRSDB sp!, #31@> @; // System mode stack
@=	CPS   #31@> @; // Also change into system mode
@=	PUSH  {r0-r3, r12}@> @;
@=	BL    mmu_abort_handler@> @;
@=	POP   {r0-r3, r12}@> @;
@=	RFEIA sp!@> @;


@ For interrupts requests, as promised we are going to have a table of
functions which we can call. Then when we get an IRQ, we look at the
pending interrupts and for each one, if there is a table entry then we
branch to the address.

Most of the assembly code is a modification of [3, \S 6.12], but for
simplicity we are not going to re-enable IRQs while handling one.

To poll the pending IRQs, we first clear bits 8--31, then count the
number of leading zeroes with \.{CLZ}, if we get zero, we move onto
pending register 1 then 2, then we check those registers too, otherwise
we just use the number of leading zeroes as the offset into the table.

\verbboxfalse
@(exception_stubs.S@>=
@=.globl exception_irq@> @;
@=.set irq_basic_pending, 0x2000B200@> @;
@=exception_irq:@> @.exception\_irq@> @;
@=	SUB   lr, lr, #4@> @;
@=	SRSDB sp!,#31@> @; /* Save \.{lr\_irq} and \.{spsr\_irq} to System mode stack */
@=	CPS   #31@> @; /* Switch to System mode */
@=	PUSH  {r0-r3,r12}@> @; /* Store other AAPCS registers */
@=	AND   r1, sp, #4@> @; /* Ensure stack is properly aligned */
@=	SUB   sp, sp, r1@> @;
@=	PUSH  {r1, lr}@> @; /* Stores stack alignment offset */
@=	LDR   r0, =irq_vector_table@> @;
@=	LDR   r1, =irq_basic_pending@> @;
@=	LDM   r1, {r1-r3}@> @; /* Basic and pending registers 1 and 2, no need for memory barrier, same peripheral */ @^TODO@>
@=	AND   r1, #0xFF@> @; /* Clear bits 8--31 */
@=	CLZ   r1, r1@> @;
@=	SUB   r1, r1, #24@> @; /* $\.{r1}-24=0$ implies Illegal access type 0 IRQ */
@=	TEQ   r1, #8@> @; /* If no bits in \.{r1}, move onto \.{r3} (\.{r3} first so we get 63--0 order with \.{CLZ}) */
@=	CLZEQ r3, r3@> @;
@=	ADDEQ r1, r3@> @;
@=	CMP   r1, #40@> @; /* If no bits so far, move onto \.{r2} */
@=	CLZEQ r2, r2@> @;
@=	ADDEQ r1, r2@> @;
@=	LSL   r1, #2@> @; /* Multiply by 4 (one pointer is 4 bytes) */
@=	LDR   r0, [r0, r1]@> @; /* Loads \.{r0} from *(\.{r0} + \.{r1}) */
@=	TEQ   r0, #0@> @; /* Check if we have NULL there */
@=	BNE   1f@> @;
@=	B     exception_undef@> @; /* Treat undefined interrupt as an undefined instruction */
@=	B     2f@> @;
@=1:@> @;
@=	ADR   lr, 2f@> @;
@=	MOV   pc, r0@> @;
@=2:@> @;
@=	POP   {r1,lr}@> @;
@=	ADD   sp, sp, r1@> @; /* Restore stack */
@=	POP   {r0-r3, r12}@> @; /* Restore registers */
@=	RFEIA sp!@> @; /* Return using RFE from System mode stack */

@* @^TODO@> Further developments. Perhaps lock down exception handling routines in the TLB? Also, perhaps make it tightly coupled (tightly coupled memory, TCM)?
