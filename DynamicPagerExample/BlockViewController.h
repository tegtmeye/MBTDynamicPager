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

@property (nonatomic, strong) NSNumber *minBlockWidth;
@property (nonatomic, strong) NSNumber *maxBlockWidth;
@property (nonatomic, assign) BOOL unboundedWidth;

@property (nonatomic, strong) NSNumber *minBlockHeight;
@property (nonatomic, strong) NSNumber *maxBlockHeight;
@property (nonatomic, assign) BOOL unboundedHeight;

@property (nonatomic, assign) BOOL isolatedBlock;

@property (nonatomic, readonly) BOOL usesAutoLayout;

/**
 *  Initializer that sets default values
 */
-(id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundleOrNil;


/**
 *  Designated initializer to set parameters
 */
-(id)initWithLabel:(NSString *)label
             color:(NSColor *)color
        forNibName:(NSString *)nibName;

@end
