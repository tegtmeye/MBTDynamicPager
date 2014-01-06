//
//  BlockViewController.h
//  MBTDynamicPager
//
//  Created by tegtmeye on 6/24/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MBTSimpleView.h"


/**
 *  BlockViewController is a simple view controller for the sake of simplicity 
 *  and testing.
 */
@interface BlockViewController : NSViewController

@property (nonatomic, weak) IBOutlet MBTSimpleView *backgroundView;

@property (nonatomic, strong) NSString *label;
@property (nonatomic, strong) NSColor *backgroundColor;

@property (nonatomic, assign) BOOL isolatedBlock;

-(id)init;

/**
 *  Set label and color to nil to have them cycle
 */
-(id)initWithLabel:(NSString *)label
             color:(NSColor *)color
          isolated:(BOOL)isolated
        forNibName:(NSString *)nibName;

@end
