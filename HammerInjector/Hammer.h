//
//  Hammer.h
//  pie33.com
//
//  Created by Moises Anthony Baligod Aranas on 6/20/17.
//  Copyright © 2017 pie33.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Hammer : NSObject
+ (instancetype)sharedInstance;
- (void) initialize;
- (void) triggerHammer;
@end
