//
//  BlockViewController.m
//  MBTDynamicPager
//
//  Created by tegtmeye on 6/24/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import "BlockViewController.h"




@interface TestView : NSView

@property (nonatomic, strong) NSColor *color;
@property (nonatomic, strong) NSTextField *labelField;

@end

@implementation TestView

- (id)initWithFrame:(NSRect)frameRect andColor:(NSColor *)aColor andLabel:(NSString *)label
{
  self = [super initWithFrame:frameRect];
  if(self) {
    self.color = aColor;
    
    self.labelField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [self.labelField setStringValue:label];
    [self.labelField setDrawsBackground:NO];
    [self.labelField setEditable:NO];
    [self.labelField setSelectable:NO];
    [self.labelField setBordered:NO];
    [self.labelField setTextColor:[NSColor whiteColor]];
    [self.labelField setFont:[NSFont boldSystemFontOfSize:36]];
    
    [self addSubview:self.labelField];
    
    [self.labelField setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSDictionary *viewsDictionary = @{@"view" : self.labelField};
    [self addConstraints:[NSLayoutConstraint
                          constraintsWithVisualFormat:@"[view(>=20)]"
                          options:0
                          metrics:nil
                          views:viewsDictionary]];
    
    [self addConstraint:[NSLayoutConstraint
                         constraintWithItem:self.labelField
                         attribute:NSLayoutAttributeCenterX
                         relatedBy:NSLayoutRelationEqual
                         toItem:self
                         attribute:NSLayoutAttributeCenterX
                         multiplier:1.0f
                         constant:0.0f]];
    
    [self addConstraint:[NSLayoutConstraint
                         constraintWithItem:self.labelField
                         attribute:NSLayoutAttributeCenterY
                         relatedBy:NSLayoutRelationEqual
                         toItem:self
                         attribute:NSLayoutAttributeCenterY
                         multiplier:1.0f
                         constant:0.0f]];
  }
  
  return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
//   NSLog(@"MyView Drawing %@ with at %@ in %@",self.label,NSStringFromRect(self.frame),NSStringFromRect([[self superview] frame]));
  
//  NSLog(@"TextView %@",NSStringFromRect([self.labelField frame]));
  
  [self.color setFill];
  
  NSRectFill(self.bounds);
  
  [[NSColor redColor] setStroke];
  
  NSFrameRect(self.bounds);
  
}

- (void)setColor:(NSColor *)color
{
  _color = color;
  
  [self setNeedsDisplay:YES];
}

@end








@interface BlockViewController ()

- (TestView *)testView;

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


- (id)initWithLabel:(NSString *)label
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        // Initialization code here.
      
      self.view = [[TestView alloc] initWithFrame:NSZeroRect
                                         andColor:[BlockViewController colorCycler]
                                         andLabel:label];
      [self.view setTranslatesAutoresizingMaskIntoConstraints:NO];

    }
    
    return self;
}

- (id)init
{
  return [self initWithLabel:[BlockViewController labelCounter]];
}

- (NSString *)label
{
  return [self.testView.labelField stringValue];
}

- (void)setLabel:(NSString *)label
{
  [self.testView.labelField setStringValue:label];
}

- (NSColor *)backgroundColor
{
  return self.testView.color;
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
  self.testView.color = backgroundColor;
}

- (void)setIsolatedBlock:(BOOL)isolatedBlock
{
  NSLog(@"Called setIsolated %i",isolatedBlock);
  
  _isolatedBlock = isolatedBlock;
}

#pragma mark - private methods

- (TestView *)testView
{
  return (TestView *)self.view;
}



@end
