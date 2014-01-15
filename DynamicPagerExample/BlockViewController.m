//
//  BlockViewController.m
//  MBTDynamicPager
//
//  Created by tegtmeye on 6/24/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import "BlockViewController.h"

@implementation BlockViewController

@synthesize maxBlockWidth=_maxBlockWidth;
@synthesize maxBlockHeight=_maxBlockHeight;

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

- (id)init
{
  return nil;
}

-(id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundleOrNil
{
  self = [self initWithLabel:[BlockViewController labelCounter] color:[BlockViewController colorCycler] forNibName:nibName];
  if(self) {

  }

  return self;
}

-(void)dealloc
{
  NSLog(@"Deallocing controller");

}

-(id)initWithLabel:(NSString *)label
             color:(NSColor *)color
        forNibName:(NSString *)nibName
{
  self = [super initWithNibName:nibName bundle:Nil];
  if (self) {
    _label = label;
    _backgroundColor = color;

    _minBlockWidth = [NSNumber numberWithFloat:100.0f];
    _maxBlockWidth = [NSNumber numberWithFloat:100.0f];
    _unboundedWidth = NO;
    _minBlockHeight = [NSNumber numberWithFloat:100.0f];
    _maxBlockHeight = [NSNumber numberWithFloat:100.0f];
    _unboundedHeight = NO;

    _isolatedBlock = NO;
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

- (void)setMinBlockWidth:(NSNumber *)minBlockWidth
{
  _minBlockWidth = minBlockWidth;

  // maxBlockWidth getter mods value. use low-level accessor
  if([minBlockWidth floatValue] > [_maxBlockWidth floatValue]) {
    self.maxBlockWidth = minBlockWidth;
  }

  assert(self.minBlockWidth>0);
}

- (void)setMaxBlockWidth:(NSNumber *)maxBlockWidth
{
  _maxBlockWidth = maxBlockWidth;

  if([maxBlockWidth floatValue] < [self.minBlockWidth floatValue]) {
    self.minBlockWidth = maxBlockWidth;
  }
}

- (void)setMinBlockHeight:(NSNumber *)minBlockHeight
{
  _minBlockHeight = minBlockHeight;

  // maxBlockHeight getter mods value. use low-level accessor
  if([minBlockHeight floatValue] > [_maxBlockHeight floatValue]) {
    self.maxBlockHeight = minBlockHeight;
  }

  assert(minBlockHeight>0);
}

- (void)setMaxBlockHeight:(NSNumber *)maxBlockHeight
{
  _maxBlockHeight = maxBlockHeight;

  if([maxBlockHeight floatValue] < [self.minBlockHeight floatValue]) {
    self.minBlockHeight = maxBlockHeight;
  }
}

- (BOOL)usesAutoLayout
{
  return (self.view.constraints && [self.view.constraints count]);
}

@end
