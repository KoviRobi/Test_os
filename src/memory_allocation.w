@i boilerplate.w

\def\title{Memory allocation}
\def\contentsfile{mem_alloc_contents}

@* Introduction. This module is designed for dynamic memory allocation. It
works by using a doubly linked list to represent the memory, initially
just one item on the list, of type free, representing the whole
allocatable memory. Then as memory is allocated, the start and size
bits are changed of the free section and a new block is inserted into
the list, such that the order in the list represents the order in the
(@^TODO@>virtual?) memory. Then when memory is deleted, merging back
together is easy, just changing the type from used to free and checking
if the previous/next block type is also free. We also have a pointer at
the beginning of the block pointing to the end of the block (which is a
pointer to the beginning of the block). This is useful to check memory
consistency, which we should check periodically and if something is wrong,
core-dump the program (this may result in heisenbugs, but still should
catch errors earlier than just waiting for the program to dereference a
memory position it has overwritten or something similar). Also see [5,
The Heap]

@p
#include <common.h>

uint32_t kmalloc(uint32_t size)
{
    return size;
}
