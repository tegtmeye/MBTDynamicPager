//
//  MBTDynamicPager.m
//  DynamicPager
//
//  Created by tegtmeye on 6/3/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import "MBTDynamicPager.h"


static const CGFloat kBlockPadY=0.0f;

static const NSString *kFittingWidthKey = @"fittingWidth";


@interface MyContainerView : NSView

@end

@implementation MyContainerView

- (void)drawRect:(NSRect)dirtyRect
{
//  NSLog(@"MyContainerView Drawing %@ in %@",NSStringFromRect(self.frame),NSStringFromRect([[self superview] frame]));
  
  [[NSColor greenColor] setFill];
  
  NSRectFill(self.bounds);
  
  [[NSColor redColor] setStroke];
  
  NSFrameRect(self.bounds);
  
}

@end









@interface MBTDynamicPager ()

@property (nonatomic, strong) id contentArrayObservableObject;
@property (nonatomic, strong) NSString *contentArrayBindingKeyPath;
@property (nonatomic, strong) NSSet *viewBindingObservers;
@property (nonatomic, strong) NSMapTable *blockViewMap;

@property (nonatomic, strong) NSTabView *tabView;
@property (nonatomic, strong) NSMutableArray *pages;

@property (nonatomic, assign, readwrite) NSInteger numberOfPages;
@property (nonatomic, assign, readwrite) NSSize intrinsicContentSize;

- (NSArray *)currentBlockArray;

- (void)updateViewObservations;

- (void)updateBlockContents;
- (void)configureBlocksInTabview;

@end

@implementation MBTDynamicPager

//+ (BOOL)requiresConstraintBasedLayout
//{
//  return YES;
//}

- (id)initWithFrame:(NSRect)frame
{
//  NSLog(@"Creating new pager!!!!!!!!");
  self = [super initWithFrame:frame];
  if (self) {
    self.interblockPadding = 8.0f;
    self.defaultBlockWidth = 100.0f;
    self.blocksDefaultToIsolated = YES;
    
    self.viewBindingObservers = [NSSet set];

    self.tabView = [[NSTabView alloc] initWithFrame:frame];
    self.tabView.delegate = self;
    [self.tabView setTabViewType:NSNoTabsLineBorder];
    [self.tabView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:self.tabView];

    self.pages = [NSMutableArray array];

    NSDictionary *viewsDictionary = @{@"view" : self.tabView};
    [self addConstraints:[NSLayoutConstraint
                          constraintsWithVisualFormat:@"|-[view]-|"
                          options:0
                          metrics:nil
                          views:viewsDictionary]];

    [self addConstraints:[NSLayoutConstraint
                          constraintsWithVisualFormat:@"V:|-[view]-|"
                          options:0
                          metrics:nil
                          views:viewsDictionary]];
    
  }
  
  return self;
}


- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath options:(NSDictionary *)options
{
  if([binding isEqualToString:NSContentArrayBinding]) {
    [self unbind:NSContentArrayBinding];
    
    self.contentArrayObservableObject = observable;
    self.contentArrayBindingKeyPath = keyPath;
    
    [self.contentArrayObservableObject addObserver:self
                                        forKeyPath:self.contentArrayBindingKeyPath
                                           options:0
                                           context:nil];
    [self updateViewObservations];

    [self noteLayoutChanged];
  }
  else {
    [super bind:binding toObject:observable withKeyPath:keyPath options:options];
  }
}

- (void)unbind:(NSString *)binding
{
  if([binding isEqualToString:NSContentArrayBinding]) {
    [self.contentArrayObservableObject removeObserver:self];
    
    self.contentArrayObservableObject = nil;
    self.contentArrayBindingKeyPath = nil;
    
    // this may cause things to revert back to self.contentArray;
    [self updateViewObservations];

    [self noteLayoutChanged];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if(object == self.contentArrayObservableObject && [keyPath isEqualToString:self.contentArrayBindingKeyPath]) {
    [self updateViewObservations];

    [self noteLayoutChanged];
  }
  else if([self.viewBindingObservers containsObject:object] && [keyPath isEqualToString:@"view"]) {
    NSView *view = [self.blockViewMap objectForKey:object];
    
    if((id)view != [NSNull null]) {
      [view removeFromSuperview];
    }

    view = [object valueForKeyPath:@"view"];
    [self.blockViewMap setObject:(view?view:[NSNull null]) forKey:object];
    
    [self noteLayoutChanged];
  }
}


- (void)setCurrentPage:(NSInteger)currentPage
{
  assert(currentPage >= 0);
  
  NSTabViewItem *selectedItem = [self.tabView selectedTabViewItem];
  
  if(selectedItem != [self.tabView tabViewItemAtIndex:currentPage])
    [self.tabView selectTabViewItemAtIndex:currentPage];
}

- (NSInteger)currentPage
{
  NSTabViewItem *selectedItem = [self.tabView selectedTabViewItem];

  if(selectedItem == nil)
    return -1;
  
  return [self.tabView indexOfTabViewItem:selectedItem];
}

- (void)setInterblockPadding:(CGFloat)interblockPadding
{
  _interblockPadding = interblockPadding;

  [self noteLayoutChanged];
}

- (void)setBlocksDefaultToIsolated:(BOOL)blocksDefaultToIsolated
{
  _blocksDefaultToIsolated = blocksDefaultToIsolated;

  [self noteLayoutChanged];
}

- (void)setContentArray:(NSArray *)contentArray
{
  _contentArray = contentArray;
  
  // if we are bound to something, then ignore updates to the contentArray.
  if(!self.contentArrayObservableObject) {
    [self updateViewObservations];
    [self noteLayoutChanged];
  }
}


- (void)drawRect:(NSRect)dirtyRect
{
//  NSLog(@"MBTDynamicPager Drawing %@ in %@",NSStringFromRect(self.frame),NSStringFromRect([[self superview] frame]));

  [[NSColor yellowColor] setFill];
  
  NSRectFill(self.bounds);
}

- (void)setFrame:(NSRect)frameRect
{
//  NSLog(@"MBTDynamicPager setFrame start");

  [super setFrame:frameRect];
  
  CGFloat tabviewframeWidth = NSWidth(self.tabView.frame);
  NSDictionary *previousPage = 0;
  CGFloat prevPageFittingWidth = 0.0f;
  for(NSDictionary *pageDict in self.pages) {
    // first check and see if the frame became too small and we need to push
    // a block onto the next page
    NSNumber *pageFittingWidth = [pageDict objectForKey:kFittingWidthKey];
    assert(pageFittingWidth);
    
    if(tabviewframeWidth - [pageFittingWidth floatValue] < 0) {
      [self performSelectorOnMainThread:@selector(configureBlocksInTabview) withObject:nil waitUntilDone:NO];
      return;
    }
  
    if(previousPage) {
      NSNumber *previousPageIsolated = [previousPage objectForKey:@"isolated"];
      NSNumber *currentPageIsolated = [pageDict objectForKey:@"isolated"];
      assert(previousPageIsolated && currentPageIsolated);

//      NSLog(@"previousPageIsolated: %@ and currentPageIsolated %@",previousPageIsolated,currentPageIsolated);
      
      if(![previousPageIsolated boolValue] && ![currentPageIsolated boolValue]) {
        NSArray *blockArray = [pageDict objectForKey:@"blocks"];
        NSView *firstBlock = [blockArray objectAtIndex:0];

        NSSize contentSize = [firstBlock fittingSize];
        CGFloat blockWidth = (contentSize.width > 0 ? contentSize.width : self.defaultBlockWidth);
      
//        NSLog(@"blockWidth %f and pageFittingWidth %f",blockWidth,prevPageFittingWidth);
        
        CGFloat additionalBlockWidth = (blockWidth + self.interblockPadding);
        CGFloat availableWidth = (tabviewframeWidth - prevPageFittingWidth);
        if(additionalBlockWidth < availableWidth) {
          // just need on to trigger retile
          [self performSelectorOnMainThread:@selector(configureBlocksInTabview) withObject:nil waitUntilDone:NO];
          return;
        }
      }
    }

    previousPage = pageDict;
    prevPageFittingWidth = [pageFittingWidth floatValue];
  }
}


#pragma mark - private methods

- (NSArray *)currentBlockArray
{
  NSArray *blockArray = 0;
  
  if(self.contentArrayObservableObject) {
    blockArray = [self.contentArrayObservableObject valueForKeyPath:self.contentArrayBindingKeyPath];
  }
  else {
    blockArray = self.contentArray;
  }

  if(!blockArray)
    blockArray = [NSArray array];
  

  return blockArray;
}

- (void)updateViewObservations
{
  NSArray *blockArray = [self currentBlockArray];

  NSSet *currentBlockSet = [NSSet setWithArray:blockArray];

  NSMutableSet *intersection = [NSMutableSet setWithSet:currentBlockSet];
  [intersection intersectSet:self.viewBindingObservers];
  
  NSMutableSet *deletedBlocks = [NSMutableSet setWithSet:self.viewBindingObservers];
  [deletedBlocks minusSet:intersection];
  
  NSMutableSet *addedBlocks = [NSMutableSet setWithSet:currentBlockSet];
  [addedBlocks minusSet:intersection];
  
  NSIndexSet *indices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [deletedBlocks count])];
  [[deletedBlocks allObjects] removeObserver:self fromObjectsAtIndexes:indices forKeyPath:@"view"];

  indices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [addedBlocks count])];
  [[addedBlocks allObjects] addObserver:self
                     toObjectsAtIndexes:indices
                             forKeyPath:@"view"
                                options:0
                                context:0];

  self.viewBindingObservers = currentBlockSet;
  
  // build a maptable from the blockControllers to their views
  // this way when we get a view changed observation, we know which was the old
  // view to remove from the tabviewitem
  self.blockViewMap = [NSMapTable weakToWeakObjectsMapTable];
  for(NSViewController *blockController in self.viewBindingObservers) {
    [self.blockViewMap setObject:blockController.view forKey:blockController];
  }
}

- (void)updateBlockContents
{
//  NSLog(@"Updating Block Contents!");

  NSArray *blockArray = [self currentBlockArray];

  // we setTranslatesAutoresizingMaskIntoConstraints to NO for each block
  // and manually manage the translation
  for(NSViewController *blockController in blockArray) {
    NSView *block = blockController.view;
    
    [block setTranslatesAutoresizingMaskIntoConstraints:NO];
//    NSLog(@"Block %@ has constraints %@",block,[block constraints]);
    
//    if([block translatesAutoresizingMaskIntoConstraints]) {
//      [block removeConstraints:[block constraints]];
//      [block setTranslatesAutoresizingMaskIntoConstraints:NO];
//      
//      NSUInteger autoresizingMask = [block autoresizingMask];
//      if(!(autoresizingMask&NSViewWidthSizable)) {
//        [block addConstraint:[NSLayoutConstraint
//                              constraintWithItem:block
//                              attribute:NSLayoutAttributeWidth
//                              relatedBy:NSLayoutRelationEqual
//                              toItem:nil
//                              attribute:NSLayoutAttributeNotAnAttribute
//                              multiplier:1.0f
//                              constant:NSWidth(block.bounds)]];
//      }
//      
//      if(!(autoresizingMask&NSViewHeightSizable)) {
//        [block addConstraint:[NSLayoutConstraint
//                              constraintWithItem:block
//                              attribute:NSLayoutAttributeHeight
//                              relatedBy:NSLayoutRelationEqual
//                              toItem:nil
//                              attribute:NSLayoutAttributeNotAnAttribute
//                              multiplier:1.0f
//                              constant:NSHeight(block.bounds)]];
//      }
//    }
  }
}



- (void)configureBlocksInTabview
{
//  NSLog(@"RETILING!");
  BOOL flexibleContent = NO;
  BOOL previousIsolated = NO;
  CGFloat fittingWidth = 0.0;
  CGFloat availableWidth = 0.0;
  NSMutableArray *pageBlocks = 0;
  NSMutableDictionary *currentpage = 0;
  self.pages = [NSMutableArray array];

  NSArray *blockArray = [self currentBlockArray];
  
  // partition the blocks into pages
  for(NSViewController *blockController in blockArray) {
    NSView *block = [blockController view];
    [block layoutSubtreeIfNeeded];
    NSSize contentSize = [block fittingSize];
    
//    NSLog(@"Got fittingWidth %@",NSStringFromSize(contentSize));
//    NSLog(@"contentHuggingPriorityForOrientation %f",[block contentHuggingPriorityForOrientation:NSLayoutConstraintOrientationHorizontal]);
//    NSLog(@"contentCompressionResistancePriorityForOrientation %f",[block contentCompressionResistancePriorityForOrientation:NSLayoutConstraintOrientationHorizontal]);

    BOOL isolatedBlock = self.blocksDefaultToIsolated;

    if(self.delegate && [self.delegate respondsToSelector:@selector(blockShouldBeIsolated:)])
      isolatedBlock = [self.delegate blockShouldBeIsolated:blockController];
    
    CGFloat blockWidth = (contentSize.width > 0 ? contentSize.width : self.defaultBlockWidth);
    
//    NSLog(@"Content size: %@, default block width %f",NSStringFromSize(contentSize),self.defaultBlockWidth);
//    NSLog(@"AvailableWidth %f, needed %f",availableWidth,blockWidth + self.interblockPadding);

    if(isolatedBlock || previousIsolated ||  availableWidth < (blockWidth + self.interblockPadding)) {
//      NSLog(@"\tMaking a new page with availableWidth %f: ",NSWidth(self.frame));
      currentpage = [NSMutableDictionary dictionary];
      [self.pages addObject:currentpage];
      fittingWidth = blockWidth;
      availableWidth = NSWidth(self.tabView.frame) - blockWidth;
      flexibleContent = (contentSize.width == 0);
      pageBlocks = [NSMutableArray arrayWithObject:block];
      [currentpage setObject:pageBlocks forKey:@"blocks"];
      [currentpage setObject:[NSNumber numberWithBool:isolatedBlock] forKey:@"isolated"];
      [currentpage setObject:[NSNumber numberWithBool:flexibleContent] forKey:@"flexibleContent"];
      [currentpage setObject:[NSNumber numberWithFloat:fittingWidth] forKey:kFittingWidthKey];
    }
    else {
      [pageBlocks addObject:block];
      if(!flexibleContent && contentSize.width == 0) {
        flexibleContent = YES;
        [currentpage setObject:@YES forKey:@"flexibleContent"];
      }
      fittingWidth += (blockWidth + self.interblockPadding);
      availableWidth -= (blockWidth + self.interblockPadding);
      [currentpage setObject:[NSNumber numberWithFloat:fittingWidth] forKey:kFittingWidthKey];
//      NSLog(@"\tAdded to existing page, availablewidth is now: %f",availableWidth);
    }
    
    previousIsolated = isolatedBlock;
  }
  
//  NSLog(@"Pages %@",self.pages);
  
  // actually build the tabview
  NSMutableArray *tabViewItems = [NSMutableArray arrayWithArray:[self.tabView tabViewItems]];
  for(NSDictionary *pageDict in self.pages) {
    // try to get an existing tabview first
    NSTabViewItem *tabViewItem = 0;
    if([tabViewItems count]) {
      tabViewItem = [tabViewItems objectAtIndex:0];
      [tabViewItems removeObjectAtIndex:0];
      [[tabViewItem view] removeConstraints:[[tabViewItem view] constraints]];
    }
    else {
      tabViewItem = [[NSTabViewItem alloc] initWithIdentifier:nil];
      // size wil get set by constraints
      NSView *containerView = [[MyContainerView alloc] initWithFrame:NSZeroRect];
      
      [tabViewItem setView:containerView];
      containerView = [tabViewItem view];

      [containerView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
      [self.tabView addTabViewItem:tabViewItem];
    }

    NSView *block = 0;
    NSView *previousBlock = 0;
    NSView *previousEqualBlock = 0;
    NSArray *blockArray = [pageDict objectForKey:@"blocks"];
    for(NSUInteger i=0; i<[blockArray count]; ++i) {
      block = [blockArray objectAtIndex:i];
      
      if([block superview] != [tabViewItem view]) {
        [block removeFromSuperview];
        [[tabViewItem view] addSubview:block];
      }
    
      [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                         constraintWithItem:block
                                         attribute:NSLayoutAttributeTop
                                         relatedBy:NSLayoutRelationEqual
                                         toItem:[tabViewItem view]
                                         attribute:NSLayoutAttributeTop
                                         multiplier:1.0f
                                         constant:kBlockPadY]];
      
      if([block fittingSize].height == 0) {
        // resizable in Y, pin to bottom
        [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                           constraintWithItem:block
                                           attribute:NSLayoutAttributeBottom
                                           relatedBy:NSLayoutRelationEqual
                                           toItem:[tabViewItem view]
                                           attribute:NSLayoutAttributeBottom
                                           multiplier:1.0f
                                           constant:-kBlockPadY]];
      
      }

      if(!previousBlock) {
        [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                           constraintWithItem:block
                                           attribute:NSLayoutAttributeLeading
                                           relatedBy:NSLayoutRelationEqual
                                           toItem:[tabViewItem view]
                                           attribute:NSLayoutAttributeLeading
                                           multiplier:1.0f
                                           constant:0.0f]];
      }
      else {
        [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                           constraintWithItem:block
                                           attribute:NSLayoutAttributeLeading
                                           relatedBy:NSLayoutRelationEqual
                                           toItem:previousBlock
                                           attribute:NSLayoutAttributeTrailing
                                           multiplier:1.0f
                                           constant:self.interblockPadding]];
      }
      if([block fittingSize].width == 0) {
        if(previousEqualBlock) {
          [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                             constraintWithItem:block
                                             attribute:NSLayoutAttributeWidth
                                             relatedBy:NSLayoutRelationEqual
                                             toItem:previousEqualBlock
                                             attribute:NSLayoutAttributeWidth
                                             multiplier:1.0f
                                             constant:0.0f]];
          }
        previousEqualBlock = block;
      }
      
      previousBlock = block;
    }
    
    NSNumber *flexibleContent = [pageDict objectForKey:@"flexibleContent"];
    if([flexibleContent boolValue]) {
      // pin the right size to the tabViewItem
      [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                         constraintWithItem:previousBlock
                                         attribute:NSLayoutAttributeTrailing
                                         relatedBy:NSLayoutRelationEqual
                                         toItem:[tabViewItem view]
                                         attribute:NSLayoutAttributeTrailing
                                         multiplier:1.0f
                                         constant:0.0f]];
    }
    
//    NSLog(@"Page constraints: %@",[[tabViewItem view] constraints]);
//    [[[tabViewItem view] window] visualizeConstraints:[[tabViewItem view] constraints]];
  }

  // remove any remaining tabs
  [tabViewItems enumerateObjectsUsingBlock:^(NSTabViewItem *item, NSUInteger idx, BOOL *stop) {
//    assert([[item.view subviews] count] == 0);
    [self.tabView removeTabViewItem:item];
  }];

  // trigger redisplay
  [self setNeedsDisplay:YES];
}

#pragma mark - pager methods

- (void)noteLayoutChanged
{
  [self updateBlockContents];
  [self configureBlocksInTabview];
}



#pragma mark - NSTabViewDelegate

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
  assert(tabView == self.tabView);
  
  self.numberOfPages = tabView.numberOfTabViewItems;
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
  assert(tabView == self.tabView);

  self.currentPage = [tabView indexOfTabViewItem:tabViewItem];
}

#pragma mark - debugging support

- (void)logBlockFramesForPage:(NSUInteger)page
{
  assert(page < [self.tabView numberOfTabViewItems]);
  
  NSTabViewItem *currentTabViewItem = [self.tabView tabViewItemAtIndex:page];
  NSView *itemView = [currentTabViewItem view];

  for(NSView *block in [itemView subviews]) {
    NSLog(@"block %@ frame: %@ constraints: %@",block,NSStringFromRect(block.frame),[block constraints]);
  }
  
}


@end
