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

  [self.nibNameArrayController addObjects:[NSArray arrayWithObjects:
                                           @"MBTSimpleSpringsAndStruts",
                                           @"MBTSimpleAutoLayout",
                                           @"MBTComplexSpringsAndStruts",
                                           @"MBTComplexAutoLayout",nil]];

  [self.viewArrayController addObserver:self forKeyPath:@"selection" options:0 context:nil];
  [self.viewArrayController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];

  [self.dynamicPager addObserver:self forKeyPath:@"currentPage" options:0 context:nil];
  [self.dynamicPager addObserver:self forKeyPath:@"numberOfPages" options:0 context:nil];
  self.dynamicPager.contentArray = self.viewArrayController.arrangedObjects;

  [self.segmentPageControl bind:@"selectedIndex" toObject:self.dynamicPager withKeyPath:@"currentPage" options:nil];

  [self addBlock:self];

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
  else if(object == self.viewArrayController && [keyPath isEqualToString:@"selection"]) {
    [self willChangeValueForKey:@"selectedNibIndex"];
    [self didChangeValueForKey:@"selectedNibIndex"];
    NSLog(@"Selection changed!!!!!!!!!!!");
  }
}

- (NSInteger)selectedNibIndex
{
  NSInteger result = NSNotFound;

  id selectedView = [self.viewArrayController selection];
  if(selectedView) {
    NSArray *arrangedNibNames = self.nibNameArrayController.arrangedObjects;
    for(NSUInteger i=0; i<arrangedNibNames.count; ++i) {
      NSString *nibName = [arrangedNibNames objectAtIndex:i];
      if([nibName isEqualToString:[selectedView valueForKey:@"nibName"]])
        result = i;
    }
  }

  NSLog(@"returning %li for nibName %@",(long)result,[selectedView valueForKey:@"nibName"]);
  return result;
}

- (void)setSelectedNibIndex:(NSInteger)selectedNibIndex
{
  NSString *nibName = [self.nibNameArrayController.arrangedObjects objectAtIndex:selectedNibIndex];
  id selection = [self.viewArrayController selection];
  assert(nibName && selection);

  BlockViewController *oldBlockController = [selection valueForKey:@"self"];
  NSUInteger oldBlockControllerSelectionIndex = [self.viewArrayController selectionIndex];

  BlockViewController *blockController =
    [[BlockViewController alloc] initWithLabel:oldBlockController.label
                                         color:oldBlockController.backgroundColor
                                      isolated:oldBlockController.isolatedBlock
                                    forNibName:nibName];

  [self.viewArrayController removeObjectAtArrangedObjectIndex:oldBlockControllerSelectionIndex];
  [self.viewArrayController insertObject:blockController
                   atArrangedObjectIndex:oldBlockControllerSelectionIndex];
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


- (IBAction)addBlock:(id)sender
{
  NSString *firstNibName = [self.nibNameArrayController.arrangedObjects objectAtIndex:0];
  BlockViewController *blockController = [[BlockViewController alloc] initWithNibName:firstNibName bundle:nil];

  [self.viewArrayController addObject:blockController];
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

  NSArray *arrangedObjects = [self.viewArrayController arrangedObjects];
  assert(arrangedObjects);

  NSInteger currentPage = [self.dynamicPager currentPage];
  assert(currentPage >= 0);

  NSViewController *block = [arrangedObjects objectAtIndex:currentPage];

  [self.window visualizeConstraints:[block.view constraints]];

  NSLog(@"view constraints: %@",[self.window.contentView constraints]);
}


- (IBAction)drawerDebug:(id)sender
{
  id selectedView = [self.viewArrayController selection];
  assert(selectedView);



  NSLog(@"nibMatrix %@ with rows %@ and selected %lu (should be %@)",self.nibMatrix,[self.nibMatrix cells],[self.nibMatrix selectedRow],[selectedView valueForKey:@"nibName"]);

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
