//
//  BlockViewController.m
//  MBTDynamicPager
//
//  Created by tegtmeye on 6/24/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import "BlockViewController.h"

#import "MBTSimpleView.h"

@interface BlockViewController ()

@property (nonatomic, weak) IBOutlet MBTSimpleView *backgroundView;

- (NSString *)nibNameForViewChoice;
- (void)replaceViewWithNib:(NSString *)nibName;

@end

@implementation BlockViewController

+ (NSColor *)colorCycler
{
  static NSUInteger index = 0;
  static NSArray *colorArray = 0;
  
  if(colorArray == 0) {
    colorArray = [NSArray arrayWithObjects:
                  [NSColor blackColor],
                  [NSColor blueColor],
                  [NSColor brownColor],
                  [NSColor cyanColor],
                  [NSColor grayColor],
                  [NSColor greenColor],
                  [NSColor lightGrayColor],
                  [NSColor magentaColor],
                  [NSColor orangeColor],
                  [NSColor purpleColor],
                  [NSColor redColor],
                  [NSColor yellowColor],
                  nil];
  }
  
  if(index >= [colorArray count])
    index = 0;
  
  return [colorArray objectAtIndex:index++];
}

+ (NSString *)labelCounter
{
  static NSUInteger index = 0;
  
  return [[NSNumber numberWithUnsignedInteger:index++] stringValue];
}

+ (NSSet *)keyPathsForValuesAffectingView
{
  return [NSSet setWithObjects:@"isolatedBlock", nil];
}


- (void)loadView
{
  [super loadView];

  self.label = [BlockViewController labelCounter];
  self.backgroundColor = [BlockViewController colorCycler];

  // Use normal view replacement machinary to set the initial view
  [self replaceViewWithNib:[self nibNameForViewChoice]];

  [self.backgroundView bind:@"backgroundColor" toObject:self withKeyPath:@"backgroundColor" options:0];
}

- (void)setIsolatedBlock:(BOOL)isolatedBlock
{
  _isolatedBlock = isolatedBlock;
}

- (NSString *)nibNameForViewChoice
{
  static NSString *nibNames[] = {
    @"MBTSimpleSpringsAndStruts",
    @"MBTSimpleSpringsAndStrutsResizable",
    @"MBTSimpleAutoLayout",
    @"MBTSimpleAutoLayoutResizable",
    @"MBTComplexSpringsAndStruts",
    @"MBTComplexSpringsAndStrutsResizable",
    @"MBTComplexAutoLayout",
    @"MBTComplexAutoLayoutResizable",
  };

  int index = (self.blockStyle << 2)|(self.viewUsesAutoLayout << 1)|self.viewIsResizable;
  assert(index < 8);
  
  return nibNames[index];
}

- (void)setBlockStyle:(enum BlockControllerStyle)blockStyle
{
  _blockStyle = blockStyle;

  [self replaceViewWithNib:[self nibNameForViewChoice]];
}

- (void)setViewUsesAutoLayout:(BOOL)viewUsesAutoLayout
{
  _viewUsesAutoLayout = viewUsesAutoLayout;
  
  [self replaceViewWithNib:[self nibNameForViewChoice]];
}

- (void)setViewIsResizable:(BOOL)viewIsResizable
{
  _viewIsResizable = viewIsResizable;

  [self replaceViewWithNib:[self nibNameForViewChoice]];
}


- (void)replaceViewWithNib:(NSString *)nibName
{
  [self.backgroundView unbind:@"backgroundColor"];
  
  // load new nib
  if(![NSBundle loadNibNamed:nibName owner:self]) {
    NSLog(@"ERROR! Could not load nib file: %@",nibName);
    assert(false);
  }
  
  [self.backgroundView bind:@"backgroundColor" toObject:self withKeyPath:@"backgroundColor" options:0];
}


@end
