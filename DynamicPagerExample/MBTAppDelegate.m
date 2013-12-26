//
//  MBTAppDelegate.m
//  DynamicPagerExample
//
//  Created by tegtmeye on 6/22/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import "MBTAppDelegate.h"

#import "BlockViewController.h"


BlockViewController * makeBlockController(enum BlockControllerStyle style,
                                          BOOL viewUsesAutoLayout,
                                          NSString *label,
                                          NSColor *backgroundColor,
                                          BOOL isolated)
{
  NSString *styleStr;
  NSString *layoutStr;

  if(style == simpleStyle)
    styleStr = @"Simple";
  else if(style == complexStyle)
    styleStr = @"Complex";
  else
    assert(false);

  if(viewUsesAutoLayout == YES)
    layoutStr = @"AutoLayout";
  else
    layoutStr = @"SpringsAndStruts";


  NSString *nibName = [NSString stringWithFormat:@"MBT%@%@",styleStr,layoutStr];

  return [[BlockViewController alloc] initWithBlockStyle:style
                                      viewUsesAutoLayout:viewUsesAutoLayout
                                                   label:label
                                                   color:backgroundColor
                                                isolated:isolated
                                              forNibName:nibName];
}














@interface MBTAppDelegate ()

@property (nonatomic, readwrite) BOOL canPageDown;
@property (nonatomic, readwrite) BOOL canPageUp;

@end

@implementation MBTAppDelegate

- (void)updatePageNavigation
{
//  NSLog(@"number of pages %li",(long)self.dynamicPager.numberOfPages);

  [self.segmentPageControl setSegmentCount:self.dynamicPager.numberOfPages];

  for(NSInteger i=0; i<[self.segmentPageControl segmentCount]; ++i)
    [self.segmentPageControl setWidth:32.0f forSegment:i];

//  NSLog(@"number of segments %li",(long)self.segmentPageControl.segmentCount);

  NSUInteger currentPage = self.dynamicPager.currentPage;

  self.segmentPageControl.selectedSegment = currentPage;
  self.canPageDown = (currentPage > 0);
  self.canPageUp = (currentPage < self.dynamicPager.numberOfPages-1);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  [self.drawer open];

  self.dynamicPager.blocksDefaultToIsolated = NO;
  
  // must set the primitive value directly because we don't want to
  // use the setUseContentBinding method before we are stable
  _useContentBinding = NO;

  self.dynamicPager.delegate = self;
  
  [self updatePageNavigation];
  
  [self.dynamicPager addObserver:self forKeyPath:@"currentPage" options:0 context:nil];
  [self.dynamicPager addObserver:self forKeyPath:@"numberOfPages" options:0 context:nil];

  [self.viewArrayController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
  self.dynamicPager.contentArray = self.viewArrayController.arrangedObjects;

  NSLog(@"applicationDidFinishLaunching COMPLETE");
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if(object == self.dynamicPager && [keyPath isEqualToString:@"currentPage"]) {
//    NSLog(@"CURRENT PAGE SELECTION CHANGED");
    [self updatePageNavigation];
  }
  else if(object == self.dynamicPager && [keyPath isEqualToString:@"numberOfPages"]) {
//    NSLog(@"Number of pages changed");
    [self updatePageNavigation];
  }
  else if(object == self.viewArrayController && [keyPath isEqualToString:@"arrangedObjects"]) {
    assert(self.useContentBinding == NO);

    NSLog(@"Content array changed without binding");
    self.dynamicPager.contentArray = self.viewArrayController.arrangedObjects;
  }
}

- (void)setIgnorePerBlockIsolation:(BOOL)ignorePerBlockIsolation
{
  _ignorePerBlockIsolation = ignorePerBlockIsolation;
  
  [self.dynamicPager noteLayoutChanged];
}

- (void)setUseContentBinding:(BOOL)useContentBinding
{
  // turn off
  if(self.useContentBinding && !useContentBinding) {
    NSLog(@"Turning OFF contentBinding");
    [self.dynamicPager unbind:NSContentArrayBinding];
    [self.viewArrayController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
    self.dynamicPager.contentArray = self.viewArrayController.arrangedObjects;
  }
  // turn on
  else if(!self.useContentBinding && useContentBinding) {
    NSLog(@"Turning ON contentBinding");
    [self.viewArrayController removeObserver:self forKeyPath:@"arrangedObjects"];
    [self.dynamicPager bind:NSContentArrayBinding toObject:self.viewArrayController withKeyPath:@"arrangedObjects" options:nil];
  }
  _useContentBinding = useContentBinding;
  
}

-(void)updateViewType:(id)sender
{
  NSButtonCell *selCell = [sender selectedCell];
  NSInteger tag = [selCell tag];

  BlockViewController *currentBlockController =
    [[self.viewArrayController selection] valueForKey:@"self"];

  assert(tag>=0 && tag<2);

  enum BlockControllerStyle style = (enum BlockControllerStyle)tag;

  BlockViewController *blockController =
    makeBlockController(style,
                        currentBlockController.viewUsesAutoLayout,
                        currentBlockController.label,
                        currentBlockController.backgroundColor,
                        currentBlockController.isolatedBlock);

  NSUInteger selectedIndex = [self.viewArrayController selectionIndex];
  [self.viewArrayController removeObjectAtArrangedObjectIndex:selectedIndex];
  [self.viewArrayController insertObject:blockController atArrangedObjectIndex:selectedIndex];
}

-(void)updateLayout:(id)sender
{
  NSButtonCell *selCell = [sender selectedCell];
  NSInteger tag = [selCell tag];

  BlockViewController *currentBlockController =
    [[self.viewArrayController selection] valueForKey:@"self"];

  assert(tag>=0 && tag<2);

  BOOL usesAutoLayout = tag;

  BlockViewController *blockController =
  makeBlockController(currentBlockController.blockStyle,
                      usesAutoLayout,
                      currentBlockController.label,
                      currentBlockController.backgroundColor,
                      currentBlockController.isolatedBlock);

  NSUInteger selectedIndex = [self.viewArrayController selectionIndex];
  [self.viewArrayController removeObjectAtArrangedObjectIndex:selectedIndex];
  [self.viewArrayController insertObject:blockController atArrangedObjectIndex:selectedIndex];
}

-(void)triggerPagerUpdate:(id)sender
{
  [self.dynamicPager noteLayoutChanged];
}




- (IBAction)previousPage:(id)sender
{
  if(self.dynamicPager.currentPage > 0)
    self.dynamicPager.currentPage = self.dynamicPager.currentPage-1;
}

- (IBAction)nextPage:(id)sender
{
  if(self.dynamicPager.currentPage < self.dynamicPager.numberOfPages-1)
    self.dynamicPager.currentPage = self.dynamicPager.currentPage+1;
}

- (IBAction)dumpPage:(id)sender
{
//  [self.dynamicPager logBlockFramesForPage:[self.dynamicPager currentPage]];
  [self.window visualizeConstraints:[self.window.contentView constraints]];

  NSViewController *block = [[self.viewArrayController arrangedObjects] objectAtIndex:[self.dynamicPager currentPage]];

  [self.window visualizeConstraints:[block.view constraints]];

  NSLog(@"view constraints: %@",[self.window.contentView constraints]);
}

#pragma mark - MBTDynamicPagerDelegate

- (BOOL)blockShouldBeIsolated:(NSViewController *)controller
{
//  NSLog(@"Called blockShouldBeIsolated");

  BOOL result = [self.dynamicPager blocksDefaultToIsolated];
  
  if(!self.ignorePerBlockIsolation && [controller respondsToSelector:@selector(isolatedBlock)])
    result = (BOOL)[controller performSelector:@selector(isolatedBlock)];
  
//  NSLog(@"Called blockShouldBeIsolated with result: %i",result);
  
  return result;
}


@end
