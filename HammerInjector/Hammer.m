//
//  Hammer.m
//  pie33.com
//
//  Created by Moises Anthony Baligod Aranas on 6/20/17.
//  Copyright © 2017 pie33.com. All rights reserved.
//

#import "Hammer.h"
#import <objc/runtime.h>
#import <dlfcn.h>

static NSString * const kHammerDylibDirectory = @"hammer";

@interface Hammer()
@property (nonatomic, strong) NSPointerArray* libraryHandles;
@end

@implementation Hammer
+ (instancetype)sharedInstance {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (void) triggerHammer
{
    // 1. deswizzle
    // 2. unload stuff, if any
    for (NSUInteger i = 0; i < self.libraryHandles.count; i++) {
        dlclose([self.libraryHandles pointerAtIndex:i]);
    }
    self.libraryHandles = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsOpaqueMemory];

    // 3. Load stuff
    NSURL *documentsDirectory = [[NSFileManager defaultManager]
                                 URLsForDirectory:NSDocumentDirectory
                                 inDomains:NSUserDomainMask].lastObject;
    NSError *error = nil;
    NSURL *hammerDirectory = [documentsDirectory URLByAppendingPathComponent:kHammerDylibDirectory];
    NSArray* contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:hammerDirectory.path
                                                                            error:&error];

    [contents enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *filename = (NSString *)obj;
        NSURL *resourcePath = [hammerDirectory URLByAppendingPathComponent:filename];
        void * handle = dlopen([resourcePath.path cStringUsingEncoding:NSUTF8StringEncoding], RTLD_NOW);
        if (handle == NULL) {
            NSLog(@"%@", [NSString stringWithUTF8String:dlerror()]);
        }
        else {
            [self.libraryHandles addPointer:handle];
            NSString *className = [[filename componentsSeparatedByString:@"."] firstObject];

            Class originalClass = NSClassFromString(className);
            NSString* mangledClassName = [NSString stringWithFormat:@"OBJC_CLASS_$_%@", className];
            Class class = CFBridgingRelease(dlsym(handle, [mangledClassName cStringUsingEncoding:NSUTF8StringEncoding]));
            hammerIntoOldClass(class, originalClass);
        }
    }];
    // 4. profit
}

void hammerIntoOldClass(Class newClass, Class oldClass) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(newClass, &methodCount);

    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        // check if it exists in the old class
        Method oldMethod = class_getInstanceMethod(oldClass, method_getName(method));
        if (oldMethod == NULL) {
            //add
        }
        else {
            // swizzle
            HammerSwizzleInstanceMethod(oldClass, method_getName(oldMethod), newClass, method_getName(method));
        }
    }

    free(methods);
}

void HammerSwizzleInstanceMethod(Class classToSwizzle, SEL origSEL, Class myClass, SEL newSEL) {
    Method methodToSwizzle = class_getInstanceMethod(classToSwizzle, origSEL);
    Method myMethod = class_getInstanceMethod(myClass, newSEL);
    class_replaceMethod(classToSwizzle, newSEL, method_getImplementation(methodToSwizzle), method_getTypeEncoding(methodToSwizzle));
    class_replaceMethod(classToSwizzle, origSEL, method_getImplementation(myMethod), method_getTypeEncoding(myMethod));
}
@end
