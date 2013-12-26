//
//  BlockViewController.m
//  MBTDynamicPager
//
//  Created by tegtmeye on 6/24/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import "BlockViewController.h"

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


-(id)init
{
  self = [self initWithBlockStyle:simpleStyle viewUsesAutoLayout:NO label:nil color:nil isolated:NO forNibName:kSimpleSpringsAndStrutsNibName];
  if(self) {

  }

  return self;
}

-(void)dealloc
{
  NSLog(@"Deallocing controller");

}

-(id)initWithBlockStyle:(enum BlockControllerStyle)blockStyle
         viewUsesAutoLayout:(BOOL)viewUsesAutoLayout
                  label:(NSString *)label
                  color:(NSColor *)color
               isolated:(BOOL)isolated
             forNibName:(NSString *)nibName
{
  self = [super initWithNibName:nibName bundle:Nil];
  if (self) {
    _label = (label?label:[BlockViewController labelCounter]);
    _backgroundColor = (color?color:[BlockViewController colorCycler]);
    _isolatedBlock = isolated;
    _blockStyle = blockStyle;
    _viewUsesAutoLayout = viewUsesAutoLayout;
  }

  return self;
}


- (void)loadView
{
  [super loadView];

  [self.backgroundView bind:@"backgroundColor"
                   toObject:self
                withKeyPath:@"backgroundColor"
                    options:0];
}

@end
