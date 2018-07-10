//
//  main.m
//  hook_block_demo
//
//  Created by Leo on 2018/7/10.
//  Copyright © 2018年 culeo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ffi/ffi.h>
#import <sys/mman.h>
#import "fishhook.h"

struct __block_imp {
    Class _isa;
    int _flags;
    int _reserver;
    void *_FuncPtr;
    struct __block_desc *_desc;
};

struct __block_desc {
    size_t _reserved;
    size_t _block_size;
    void *_rest[1];
};

NSMutableArray *g_allocations;

static const char *
blockSignature(id block) {
    struct __block_imp *imp = (__bridge void *)block;
    struct __block_desc *desc = imp->_desc;
    
    assert(imp->_flags & 1 << 30);
    
    int index = 0;
    if(imp->_flags & 1 << 25)
        index += 2;
    
    return desc->_rest[index];
}

int
argumentsCount(const char *str) {
    int count = -1; // 第一个是返回值
    while (str && *str) {
        str = NSGetSizeAndAlignment(str, NULL, NULL);
        while (isdigit(*str)) {
            str++;
        }
        count++;
    }
    return count;
}

void *
allocate(size_t howmuch) {
    NSMutableData *data = [NSMutableData dataWithLength:howmuch];
    [g_allocations addObject: data];
    return [data mutableBytes];
}

static ffi_type *
ffiArgumentForEncode(const char *str) {
#define SINT(type) do { \
if(str[0] == @encode(type)[0]) {\
if(sizeof(type) == 1) return &ffi_type_sint8; \
if(sizeof(type) == 2) return &ffi_type_sint16;\
if(sizeof(type) == 4) return &ffi_type_sint32;\
if(sizeof(type) == 8) return &ffi_type_sint64; \
NSLog(@"Unknown size for type %s", #type); \
abort();\
} \
} while(0)
    
#define UINT(type) do { \
if(str[0] == @encode(type)[0]) { \
if(sizeof(type) == 1) return &ffi_type_uint8; \
if(sizeof(type) == 2) return &ffi_type_uint16; \
if(sizeof(type) == 4) return &ffi_type_uint32; \
if(sizeof(type) == 8) return &ffi_type_uint64; \
NSLog(@"Unknown size for type %s", #type); \
abort(); \
} \
} while(0)
    
#define INT(type) do { \
SINT(type); \
UINT(unsigned type); \
} while(0)
    
#define COND(type, name) do { \
if(str[0] == @encode(type)[0]) return &ffi_type_ ## name; \
} while(0)
    
#define PTR(type) COND(type, pointer)
    
#define STRUCT(structType, ...) do { \
if(strncmp(str, @encode(structType), strlen(@encode(structType))) == 0) \
{ \
ffi_type *elementsLocal[] = { __VA_ARGS__, NULL }; \
ffi_type **elements = allocate(sizeof(elementsLocal)); \
memcpy(elements, elementsLocal, sizeof(elementsLocal)); \
\
ffi_type *structType = allocate(sizeof(*structType)); \
structType->type = FFI_TYPE_STRUCT; \
structType->elements = elements; \
return structType; \
} \
} while(0)
    
    SINT(_Bool);
    SINT(signed char);
    UINT(unsigned char);
    INT(short);
    INT(int);
    INT(long);
    INT(long long);
    
    PTR(id);
    PTR(Class);
    PTR(SEL);
    PTR(void *);
    PTR(char *);
    PTR(void (*)(void));
    
    COND(float, float);
    COND(double, double);
    
    COND(void, void);
    
    ffi_type *CGFloatFFI = sizeof(CGFloat) == sizeof(float) ? &ffi_type_float : &ffi_type_double;
    STRUCT(CGRect, CGFloatFFI, CGFloatFFI, CGFloatFFI, CGFloatFFI);
    STRUCT(CGPoint, CGFloatFFI, CGFloatFFI);
    STRUCT(CGSize, CGFloatFFI, CGFloatFFI);
    
#if !TARGET_OS_IPHONE
    STRUCT(NSRect, CGFloatFFI, CGFloatFFI, CGFloatFFI, CGFloatFFI);
    STRUCT(NSPoint, CGFloatFFI, CGFloatFFI);
    STRUCT(NSSize, CGFloatFFI, CGFloatFFI);
#endif
    
    NSLog(@"Unknown encode string %s", str);
    abort();
}

static ffi_type **
argsWithEncodeString(const char *str, int *outCount)
{
    
    int argsCount = argumentsCount(str);
    ffi_type **argTypes = allocate(argsCount * sizeof(*argTypes));
    int i = -1; // 第一个是返回值
    while(str && *str) {
        if (i > -1) {
            argTypes[i] = ffiArgumentForEncode(str);
        }
        str = NSGetSizeAndAlignment(str, NULL, NULL);
        while (isdigit(*str)) {
            str++;
        }
        i++;
    }
    *outCount = argsCount;
    return argTypes;
}

// MARK:- 第一题

void printHelloWord() {
    NSLog(@"Hello, World!");
}

void HookBlockToPrintHelloWord(id block) {
    struct __block_imp *imp = (__bridge struct __block_imp *)block;
    imp->_FuncPtr = &printHelloWord;
}

// MARK:- 第二题

void block_ffi_function(ffi_cif *cif, void *ret, void **args, void *userdata) {
    int a = *((int *)args[1]);
    NSString *b = (__bridge NSString *)(*((void **)args[2]));
    NSLog(@"%d, %@", a, b);
    ffi_call(cif, (void (*)(void))userdata, ret, args);
}

ffi_cif g_cif;
ffi_closure *g_closure;
void *g_fptr;
id g_block;

void HookBlockToPrintArguments(id block) {
    g_block = g_block;
    struct __block_imp *imp = (__bridge struct __block_imp *)block;
    const char *signature = blockSignature(block);
    int argCount;
    ffi_type **types = argsWithEncodeString(signature, &argCount);
    
    // 生成模板
    ffi_prep_cif(&g_cif, FFI_DEFAULT_ABI, argCount, ffiArgumentForEncode(signature), types);
    
    g_closure = mmap(NULL, sizeof(ffi_closure), PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    g_fptr = imp->_FuncPtr;
    ffi_status status = ffi_prep_closure(g_closure, &g_cif, block_ffi_function, g_fptr);
    if(status != FFI_OK) {
        NSLog(@"ffi_prep_closure returned %d", (int)status);
        abort();
    }
    if(mprotect(g_closure, sizeof(g_closure), PROT_READ | PROT_EXEC) == -1) {
        perror("mprotect");
        abort();
    }
    
    imp->_FuncPtr = g_closure;
}

// MARK:- 第三题

static id (*orig_objc_retainBlock)(id);

id hook_objc_retainBlock(id block) {
    id ret = orig_objc_retainBlock(block);
    HookBlockToPrintArguments(ret);
    return ret;
}

void HookEveryBlockToPrintArguments() {
    rebind_symbols((struct rebinding[1]){{"objc_retainBlock", hook_objc_retainBlock, (void *)&orig_objc_retainBlock}}, 1);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        void(^blockTest1)(void) = ^{
            NSLog(@"block1 invoke");
        };
        HookBlockToPrintHelloWord(blockTest1);
        blockTest1();
        
        void(^blockTest2)(int, NSString *) = ^(int a, NSString *b) {
            NSLog(@"block2 invoke");
        };
        HookBlockToPrintArguments(blockTest2);
        blockTest2(123, @"aaa");
        
        HookEveryBlockToPrintArguments();
        void(^blockTest3)(int, NSString *) = ^(int a, NSString *b) {
            NSLog(@"block3 invoke");
        };
        blockTest3(456, @"bbb");
    }
    return 0;
}
