//
//  MBTAppDelegate.m
//  DynamicPagerExample
//
//  Created by tegtmeye on 6/22/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import "MBTAppDelegate.h"

#import "BlockViewController.h"


@interface MBTAppDelegate ()

@property (nonatomic, readwrite) BOOL canPageDown;
@property (nonatomic, readwrite) BOOL canPageUp;

@end

@implementation MBTAppDelegate

- (void)updateSegmentCount
{
  [self.segmentPageControl setSegmentCount:self.dynamicPager.numberOfPages];
  
  for(NSInteger i=0; i<[self.segmentPageControl segmentCount]; ++i)
    [self.segmentPageControl setWidth:32.0f forSegment:i];
}

- (void)updatePageNavigation
{
//  NSLog(@"number of pages %li",(long)self.dynamicPager.numberOfPages);

  NSUInteger currentPage = self.dynamicPager.currentPage;
  self.canPageDown = (currentPage > 0);
  self.canPageUp = (currentPage < self.dynamicPager.numberOfPages-1);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  [self.drawer open];

  self.dynamicPager.blocksDefaultToIsolated = NO;
  
  // must set the primitive value directly because we don't want to
  // use the setUseContentBinding method before we are stable
  _useContentBinding = YES;

  self.dynamicPager.delegate = self;
  
  [self updateSegmentCount];
  [self updatePageNavigation];
  
  [self.dynamicPager addObserver:self forKeyPath:@"currentPage" options:0 context:nil];
  [self.dynamicPager addObserver:self forKeyPath:@"numberOfPages" options:0 context:nil];
  [self.dynamicPager bind:NSContentArrayBinding toObject:self.viewArrayController withKeyPath:@"arrangedObjects" options:nil];
  [self.segmentPageControl bind:@"selectedIndex" toObject:self.dynamicPager withKeyPath:@"currentPage" options:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if(object == self.dynamicPager && [keyPath isEqualToString:@"currentPage"]) {
    [self updatePageNavigation];
  }
  else if(object == self.dynamicPager && [keyPath isEqualToString:@"numberOfPages"]) {
//    NSLog(@"Number of pages changed");
    [self updateSegmentCount];
    [self updatePageNavigation];
  }
  else if(object == self.viewArrayController && [keyPath isEqualToString:@"arrangedObjects"]) {
    assert(self.useContentBinding == NO);
    
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
    [self.dynamicPager unbind:NSContentArrayBinding];
    [self.viewArrayController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
  }
  // turn on
  else if(!self.useContentBinding && useContentBinding) {
    [self.viewArrayController removeObserver:self forKeyPath:@"arrangedObjects"];
    [self.dynamicPager bind:NSContentArrayBinding toObject:self.viewArrayController withKeyPath:@"arrangedObjects" options:nil];
  }
  _useContentBinding = useContentBinding;
  
}

- (IBAction)updateView:(id)sender {
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
  [self.dynamicPager logBlockFramesForPage:[self.dynamicPager currentPage]];
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
