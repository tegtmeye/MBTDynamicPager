//
//  BlockViewController.h
//  MBTDynamicPager
//
//  Created by tegtmeye on 6/24/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MBTSimpleView.h"


static NSString *kSimpleSpringsAndStrutsNibName = @"MBTSimpleSpringsAndStruts";
static NSString *kComplexSpringsAndStrutsNibName = @"MBTComplexSpringsAndStruts";
static NSString *kSimpleAutoLayoutNibName = @"MBTSimpleAutoLayout";
static NSString *kComplexAutoLayoutNibName = @"MBTComplexAutoLayout";

enum BlockControllerStyle {
  simpleStyle = 0,
  complexStyle = 1
};


/**
 *  BlockViewController is a simple view controller that switches out its view
 *  based on the state of 'blockStyle', 'viewUsesAutoLayout', and 
 *  'viewIsResizable'. For the sake of simplicity and testing, one of 8
 *  nib files are loaded based on these possible choices. Although it is
 *  probably easier to construct these programmatically for testing and code
 *  reduction/simplification, by using a seperate nib, the behavior of any
 *  object that uses these view can be tested knowing that the view was
 *  constructed "correctly" ie from interface builder
 */
@interface BlockViewController : NSViewController

@property (nonatomic, weak) IBOutlet MBTSimpleView *backgroundView;

@property (nonatomic, strong) NSString *label;
@property (nonatomic, strong) NSColor *backgroundColor;

@property (nonatomic, assign) BOOL isolatedBlock;

@property (nonatomic, readonly) enum BlockControllerStyle blockStyle;
@property (nonatomic, readonly) BOOL viewUsesAutoLayout;

-(id)init;

/**
 *  Set label and color to nil to have them cycle
 */
-(id)initWithBlockStyle:(enum BlockControllerStyle)blockStyle
     viewUsesAutoLayout:(BOOL)viewUsesAutoLayout
                  label:(NSString *)label
                  color:(NSColor *)color
               isolated:(BOOL)isolated
             forNibName:(NSString *)nibName;

@end
