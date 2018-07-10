//
//  ffi_demo.c
//  BlockTest
//
//  Created by Leo on 2018/7/10.
//  Copyright © 2018年 culeo. All rights reserved.
//

#include "ffi_demo.h"
#import <ffi/ffi.h>
#import <sys/mman.h>
#import <stdlib.h>
#import <Foundation/Foundation.h>

int fun1 (int a, int b) {
    return a + b;
}

int fun2 (int a, int b) {
    return 2 * a + b;
}

void ffi_function(ffi_cif *cif, void *ret, void **args, void *userdata) {
    int x = *((int *)args[0]);
    int y = *((int *)args[1]);
    ffi_call(cif, (void (*)(void))userdata,  ret, args);
    NSLog(@"%d + %d = %d", x, y, *(int *)ret);
};

void ffi_demo_main(void)
{
    ffi_type **types;
    types = malloc(sizeof(ffi_type *) * 2);
    types[0] = &ffi_type_sint;
    types[1] = &ffi_type_sint;
    
    ffi_type *retType = &ffi_type_sint;
    
    void **args = malloc(sizeof(void *) * 2);
    int x = 1, y = 2;
    args[0] = &x;
    args[1] = &y;
    
    int ret = 0;
    
    ffi_cif cif;
    // 生成模板
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, retType, types);
    // 动态调用fun1
    ffi_call(&cif, (void (*)(void))fun1,  &ret, args);
    
    ffi_closure *closure = mmap(NULL, sizeof(ffi_closure), PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    
    ffi_status status = ffi_prep_closure(closure, &cif, ffi_function, fun1);
    if(status != FFI_OK) {
        NSLog(@"ffi_prep_closure returned %d", (int)status);
        abort();
    }
    if(mprotect(closure, sizeof(closure), PROT_READ | PROT_EXEC) == -1) {
        perror("mprotect");
        abort();
    }
    ret = ((int(*)(int , int))closure)(1, 2);
    NSLog(@"ret %d", ret);
    
}
