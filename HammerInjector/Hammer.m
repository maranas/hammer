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
@property (nonatomic, strong) NSMutableArray* originalClasses;
@property (nonatomic, strong) NSMutableArray* loadedClasses;
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

- (void) initialize {
    // clears patches from previous run
    [self removePatches];
}

- (void) triggerHammer
{
    // 1. deswizzle
    for (NSUInteger index = 0; index < self.loadedClasses.count; index++) {
        hammerIntoOldClass(self.loadedClasses[index], self.originalClasses[index]);
    }
    
    self.originalClasses = [NSMutableArray array];
    self.loadedClasses = [NSMutableArray array];
    
    // 2. unload stuff, if any
    for (NSUInteger i = 0; i < self.libraryHandles.count; i++) {
        void * handle = [self.libraryHandles pointerAtIndex:i];
        [self.libraryHandles removePointerAtIndex:i];
        if (dlclose(handle) < 0) {
            NSLog(@"%@", [NSString stringWithUTF8String:dlerror()]);
        }
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
        NSArray* filenameComponents = [filename componentsSeparatedByString:@"."];
        if (filenameComponents.count == 2 && [[filenameComponents lastObject] isEqualToString:@"dylib"]) {
            NSLog(@"Loading library %@", filename);
            NSURL *resourcePath = [hammerDirectory URLByAppendingPathComponent:filename];
            void * handle = dlopen([resourcePath.path cStringUsingEncoding:NSUTF8StringEncoding], RTLD_NOW);
            
            if (handle == NULL) {
                NSLog(@"%@", [NSString stringWithUTF8String:dlerror()]);
            }
            else {
                [self.libraryHandles addPointer:handle];
                NSString *className = [[[filenameComponents firstObject] componentsSeparatedByString:@"-"] firstObject];
                NSLog(@"Loading class %@", className);
                Class originalClass = NSClassFromString(className);
                NSString* mangledClassName = [NSString stringWithFormat:@"OBJC_CLASS_$_%@", className];
                Class class = CFBridgingRelease(dlsym(handle, [mangledClassName cStringUsingEncoding:NSUTF8StringEncoding]));
                hammerIntoOldClass(class, originalClass);
                [self.loadedClasses addObject:class];
                [self.originalClasses addObject:originalClass];
            }
        }
    }];
    // 4. profit
}

- (void) removePatches {
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
        [[NSFileManager defaultManager] removeItemAtURL:resourcePath error:nil];
    }];
    
    [self triggerHammer];
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
            NSLog(@"Adding implemetation for %@",  NSStringFromSelector(method_getName(method)));
            class_addMethod(oldClass, method_getName(method), class_getMethodImplementation(newClass, method_getName(method)), method_getTypeEncoding(method));
        }
        else {
            // swizzle
            NSLog(@"Updating implemetation for %@",  NSStringFromSelector(method_getName(method)));
            Method originalMethod = class_getInstanceMethod(oldClass, method_getName(oldMethod));
            Method newMethod = class_getInstanceMethod(newClass, method_getName(method));
            method_exchangeImplementations(originalMethod, newMethod);
        }
    }

    free(methods);
}

@end
