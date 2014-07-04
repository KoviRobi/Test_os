@i boilerplate.w

\def\title{ARM Timer}
\def\contentsfile{arm_timer_contents}

@* Introduction. The system timer is used to generate interrupts at
a programmable interval. The timer is first loaded with a value, from
which it counts down to zero at a set speed. The speed of counting down
is set by the timer pre-divide register as given.

\bigskip\centretable
{ \hfill # & \vrule height 3ex\quad # \hfill \cr
Pre-scale bits & Count down speed \cr\noalign{\hrule height 0.8pt}
00 (and 11)    & CPU clock        \cr
01             & CPU clock/16     \cr
10             & CPU clock/256    \cr
}\bigskip

@ We have a function to initialise the timer to a set amount of clock cycles

@d timer_load        (volatile uint32_t *)0x2000B400
@d timer_value       (volatile uint32_t *)0x2000B404
@d timer_control     (volatile uint32_t *)0x2000B408
@d timer_irq_clear   (volatile uint32_t *)0x2000B40C
@d timer_reload      (volatile uint32_t *)0x2000B418 /* Accessed when timer finished counting down */
@d timer_ctrl_32bit  0x2
@d timer_ctrl_irq    0x20
@d timer_ctrl_enable 0x80
@p
#include <common.h>
#include <drivers/arm_timer.h>
#include <drivers/exceptions.h>

static uint8_t sys_prescale = 3;
static uint32_t sys_interval_count = 0;

uint32_t timer_init(uint32_t interval_count, uint8_t prescale) //
{
    if (prescale > 2)
        return WRONG_PRESCALE;
    if (interval_count == 0)
        return INTERVAL_TOO_SMALL;
    *timer_control = 0;
    sys_prescale = prescale;
    sys_interval_count = interval_count;
    *timer_load = interval_count;
    *timer_control = (prescale<<2) | timer_ctrl_32bit | timer_ctrl_irq | timer_ctrl_enable;

    return SUCCESS;
}

uint32_t sleep (uint32_t interval_count)
{
    if (sys_prescale == 3 || sys_interval_count == 0)
        return UNINITIALISED_TIMER;
    *timer_load = interval_count;
    /* TODO: Block process */@^TODO@>
    /* TODO: What about two sleeps?
            -> Sleep heap?
             * Push remaining time and new time onto heap
               then get smallest, sleep that amount, then
               subtract that value from heap */@^TODO@>
    /* Wait for arm timer to load new value,
       barrier won't help, same peripheral */ @^empirical@>
    volatile int i;
    for (i = 0; i < 75; i++);
    *timer_reload = sys_interval_count;
    return SUCCESS;
}

@
@(arm_timer.h@>=
#define WRONG_PRESCALE -1
#define UNINITIALISED_TIMER -2
#define INTERVAL_TOO_SMALL -3

/* Pre-scale is 0 for counting down at CPU clock speed, 1 for counting down at CPU clock speed/16 and 2 for counting down at CPU clock speed/256 */
uint32_t timer_init(uint32_t interval_count, uint8_t prescale);

uint32_t sleep(uint32_t interval_count);
