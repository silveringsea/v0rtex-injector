//
//  kernel.m
//  v0rtex
//
//  Created by Ben on 16/12/2017.
//  Copyright © 2017 Sticktron. All rights reserved.
//

#include "kernel.h"
#include <mach/mach.h>
#include <stdio.h>
#include <stdlib.h>

extern task_t tfp0;

void init_kernel(task_t task_for_port0) {
    tfp0 = task_for_port0;
}

uint64_t rk64(task_t tfp0, uint64_t kaddr) {
    uint64_t lower = rk32_via_tfp0(tfp0, kaddr);
    uint64_t higher = rk32_via_tfp0(tfp0, kaddr + 4);
    return ((higher << 32) | lower);
}

uint32_t rk32_via_tfp0(task_t tfp0, uint64_t kaddr) {
    kern_return_t err;
    uint32_t val = 0;
    mach_vm_size_t outsize = 0;
    
    // mach (for kern r/w primitives)
    kern_return_t mach_vm_write(
                                vm_map_t target_task,
                                mach_vm_address_t address,
                                vm_offset_t data,
                                mach_msg_type_number_t dataCnt);
    
    err = mach_vm_read_overwrite(tfp0,
                                 (mach_vm_address_t)kaddr,
                                 (mach_vm_size_t)sizeof(uint32_t),
                                 (mach_vm_address_t)&val,
                                 &outsize);
    
    if (err != KERN_SUCCESS) {
        // printf("tfp0 read failed %s addr: 0x%llx err:%x port:%x\n", mach_error_string(err), kaddr, err, tfp0);
        // sleep(3);
        return 0;
    }
    
    if (outsize != sizeof(uint32_t)) {
        // printf("tfp0 read was short (expected %lx, got %llx\n", sizeof(uint32_t), outsize);
        // sleep(3);
        return 0;
    }
    
    return val;
}

void wk32(task_t tfp0, uint64_t kaddr, uint32_t val) {
    if (tfp0 == MACH_PORT_NULL) {
        // printf("attempt to write to kernel memory before any kernel memory write primitives available\n");
        // sleep(3);
        return;
    }
    
    kern_return_t err;
    err = mach_vm_write(tfp0,
                        (mach_vm_address_t)kaddr,
                        (vm_offset_t)&val,
                        (mach_msg_type_number_t)sizeof(uint32_t));
    
    if (err != KERN_SUCCESS) {
        // printf("tfp0 write failed: %s %x\n", mach_error_string(err), err);
        return;
    }
}



void wk64(uint64_t kaddr, uint64_t val) {
    uint32_t lower = (uint32_t)(val & 0xffffffff);
    uint32_t higher = (uint32_t)(val >> 32);
    wk32(tfp0, kaddr, lower);
    wk32(tfp0, kaddr + 4, higher);
}

size_t kwrite(uint64_t where, const void *p, size_t size) {
    int rv;
    size_t offset = 0;
    while (offset < size) {
        size_t chunk = 2048;
        if (chunk > size - offset) {
            chunk = size - offset;
        }
        rv = mach_vm_write(tfp0,
                           where + offset,
                           (mach_vm_offset_t)p + offset,
                           (mach_msg_type_number_t)chunk);
        
        if (rv) {
            printf("[kernel] error copying buffer into region: @%p \n", (void *)(offset + where));
            break;
        }
        
        offset +=chunk;
    }
    
    return offset;
}


size_t kwrite_uint64(uint64_t where, uint64_t value) {
    return kwrite(where, &value, sizeof(value));
}
