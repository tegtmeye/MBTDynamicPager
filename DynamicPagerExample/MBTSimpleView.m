//
//  MBTSimpleView.m
//  MBTDynamicPager
//
//  Created by tegtmeye on 7/5/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import "MBTSimpleView.h"

@interface MBTSimpleView ()

// this is the property that can be changed by the user
@property (nonatomic, strong) NSTextField *labelField;

@end

@implementation MBTSimpleView



- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  if(self) {
    self.backgroundColor = [NSColor clearColor];
  }
  
  return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
  [self.backgroundColor setFill];
  
  NSRectFill(self.bounds);
  
  [[NSColor redColor] setStroke];
  
  NSFrameRect(self.bounds);
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
  _backgroundColor = backgroundColor;
  
  [self setNeedsDisplay:YES];
}

@end
