@i boilerplate.w

\def\title{General purpose I/O}
\def\contentsfile{gpio_contents}

@* Introduction. The general purpose input/output pins are a simple but
flexible way of interfacing with the processor, and in the Raspberry Pi
chip the GPIO provides functions such as I$^2$C or UART.

@(gpio.h@>=
#ifndef GPIO_H
#define GPIO_H

#include <common.h>

enum gpio_fn
{
    gpio_input, gpio_output,
    gpio_alt0 = 4, // 0b100,
    gpio_alt1 = 5, // 0b101,
    gpio_alt2 = 6, // 0b110,
    gpio_alt3 = 7, // 0b111,
    gpio_alt4 = 2 // 0b010
};

enum gpio_pull
{
    gpio_pull_none = 0, // 0b00;
    gpio_pull_down = 1, // 0b01;
    gpio_pull_up   = 2  // 0b10;
};

// Return 1, invalid parameters
uint32_t set_GPIO_function(uint32_t, uint8_t);
uint32_t set_GPIO_pull(uint32_t, uint8_t);

#endif /* end of include guard: \.{GPIO\_H} */

@
@p
#include <common.h>

#define GPIO_BASE 0x20200000

// Return 1, invalid parameters
uint32_t set_GPIO_function(uint32_t pin, uint8_t fn)
{
    if (pin > 53 || fn > 7)
        return 1;
    volatile uint32_t * pinBank = (uint32_t *)(pin/10 + (uint32_t *)GPIO_BASE);
    pin = 3*(pin % 10);
    *pinBank = (*pinBank & ~(7 << pin)) | fn << pin;

    return 0;
}

uint32_t set_GPIO_pull(uint32_t pin, uint8_t pull)
{
    if (pin > 53 || pull > 2)
        return 1;
    volatile uint32_t * gppud = (uint32_t *)(GPIO_BASE + 0x94);
    volatile uint32_t * pinBank = (uint32_t *)(pin/32 + (uint32_t *)(GPIO_BASE + 0x98));

    *gppud = pull;

    delay(150);

    *pinBank = pin % 32;

    delay(150);

    *pinBank = 0;
    *gppud = 0;

    return 0;

}
