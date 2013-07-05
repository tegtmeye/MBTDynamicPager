//
//  BlockViewController.h
//  MBTDynamicPager
//
//  Created by tegtmeye on 6/24/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BlockViewController : NSViewController

@property (nonatomic, strong) NSString *label;
@property (nonatomic, strong) NSColor *backgroundColor;

@property (nonatomic, assign) BOOL isolatedBlock;

// designated initializer
- (id)initWithLabel:(NSString *)label;

@end
