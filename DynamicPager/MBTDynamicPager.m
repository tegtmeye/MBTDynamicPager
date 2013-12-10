//
//  MBTDynamicPager.m
//  DynamicPager
//
//  Created by tegtmeye on 6/3/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import "MBTDynamicPager.h"

#ifdef DEBUG
#define MBTDYNAMICPAGER_DEBUG 1
#else
#define MBTDYNAMICPAGER_DEBUG 0
#endif

static const NSString *kFittingWidthKey = @"fittingWidth";
static const NSString *kIsolatedBlockKey = @"isolatedBlockKey";
static const NSString *kPageBlockKey = @"pageBlocks";
static const NSString *kFlexibleContentKey = @"flexibleContent";
static const NSString *kFittingInfoArrayKey = @"fittingInfoArrayKey";

static BOOL userRequestedLog(void)
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"MBTDynamicPagerLogging"];
}

static BOOL userRequestedVisualAids(void)
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"MBTDynamicPagerVisualAids"];
}



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

// Simple container object for storing block fitting data in an NSArray
@interface BlockFittingInfo : NSObject

@property (nonatomic, assign) BOOL widthConstrained;
@property (nonatomic, assign) BOOL heightConstrained;
@property (nonatomic, assign) NSSize fittingSize;

@end

@implementation BlockFittingInfo

- (id)initWithConstraint:(BOOL)width height:(BOOL)height andFittingSize:(NSSize)fittingSize
{
  self = [super init];
  if (self) {
    _widthConstrained = width;
    _heightConstrained = height;
    _fittingSize = fittingSize;
  }

  return self;
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
//@property (nonatomic, assign, readwrite) NSSize intrinsicContentSize;

- (NSArray *)currentBlockArray;

- (void)updateViewObservations;

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
    self.defaultBlockHeight = 100.0f;
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
                          constraintsWithVisualFormat:@"|[view]|"
                          options:0
                          metrics:nil
                          views:viewsDictionary]];

    [self addConstraints:[NSLayoutConstraint
                          constraintsWithVisualFormat:@"V:|[view]|"
                          options:0
                          metrics:nil
                          views:viewsDictionary]];
    
  }
  
  return self;
}


- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath options:(NSDictionary *)options
{
  if([binding isEqualToString:NSContentArrayBinding]) {
    if(self.contentArrayObservableObject && self.contentArrayBindingKeyPath)
      [self unbind:NSContentArrayBinding];
    
    self.contentArrayObservableObject = observable;
    self.contentArrayBindingKeyPath = keyPath;
    
    NSLog(@"MBTDynamicPager: binding and adding self as keybath observer");
    [self.contentArrayObservableObject addObserver:self
                                        forKeyPath:self.contentArrayBindingKeyPath
                                           options:0
                                           context:nil];
    NSLog(@"MBTDynamicPager: binding and calling updateViewObservations");
    [self updateViewObservations];

    NSLog(@"MBTDynamicPager: done binding, triggering noteLayoutChanged");
    [self noteLayoutChanged];
  }
  else {
    [super bind:binding toObject:observable withKeyPath:keyPath options:options];
  }
}

- (void)unbind:(NSString *)binding
{
  if([binding isEqualToString:NSContentArrayBinding]) {
    NSLog(@"MBTDynamicPager: starting unbinding.");
    if(self.contentArrayObservableObject && self.contentArrayBindingKeyPath) {
      [self.contentArrayObservableObject removeObserver:self forKeyPath:self.contentArrayBindingKeyPath];
    }
    
    self.contentArrayObservableObject = nil;
    self.contentArrayBindingKeyPath = nil;
    
    // this may cause things to revert back to self.contentArray;
    [self updateViewObservations];

    NSLog(@"MBTDynamicPager: unbinding. triggering retile");
    [self noteLayoutChanged];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if(object == self.contentArrayObservableObject && [keyPath isEqualToString:self.contentArrayBindingKeyPath]) {
    NSLog(@"MBTDynamicPager: content changed. calling updateViewObservations");
    [self updateViewObservations];


    NSLog(@"MBTDynamicPager: content changed. triggering retile");
    [self noteLayoutChanged];
  }
  else if([self.viewBindingObservers containsObject:object] && [keyPath isEqualToString:@"view"]) {
    NSView *view = [self.blockViewMap objectForKey:object];
    
    if((id)view != [NSNull null]) {
      [view removeFromSuperview];
    }

    view = [object valueForKeyPath:@"view"];
    [self.blockViewMap setObject:(view?view:[NSNull null]) forKey:object];
    
    NSLog(@"MBTDynamicPager: observed view content change. triggering retile");
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

  NSLog(@"setInterblockPadding to %f, triggering retile",interblockPadding);
  [self noteLayoutChanged];
}

- (void)setBlocksDefaultToIsolated:(BOOL)blocksDefaultToIsolated
{
  _blocksDefaultToIsolated = blocksDefaultToIsolated;

  NSLog(@"setBlocksDefaultToIsolated to %i, triggering retile",blocksDefaultToIsolated);
  [self noteLayoutChanged];
}

- (void)setContentArray:(NSArray *)contentArray
{
  _contentArray = contentArray;
  
  // if we are bound to something, then ignore updates to the contentArray.
  if(!self.contentArrayObservableObject) {
    [self updateViewObservations];

    NSLog(@"setContentArray. triggering retile");
    [self noteLayoutChanged];
  }
}

#if 0
- (void)drawRect:(NSRect)dirtyRect
{
//  NSLog(@"MBTDynamicPager Drawing %@ in %@",NSStringFromRect(self.frame),NSStringFromRect([[self superview] frame]));

  [[NSColor yellowColor] setFill];
  
  NSRectFill(self.bounds);
}
#endif

- (void)setFrame:(NSRect)frameRect
{
  NSLog(@"MBTDynamicPager setFrame start with %lu pages and %lu block",
        [self.pages count],[self.currentBlockArray count]);

  [super setFrame:frameRect];
  
  CGFloat tabviewframeWidth = NSWidth(self.tabView.frame);
  NSDictionary *previousPage = 0;
  CGFloat prevPageFittingWidth = 0.0f;
  NSUInteger pageIndex;
  for(pageIndex=0; pageIndex<[self.pages count]; ++pageIndex) {
    NSDictionary *pageDict = [self.pages objectAtIndex:pageIndex];

    NSLog(@"PageDict %@",pageDict);

    // first check and see if the frame became too small and we need to push
    // a block onto the next page
    NSNumber *pageFittingWidth = [pageDict objectForKey:kFittingWidthKey];
    assert(pageFittingWidth);
    
    if(tabviewframeWidth - [pageFittingWidth floatValue] < 0) {
      NSLog(@"MBTDynamicPager. Sufficient additional space. Triggering retile");
      [self performSelectorOnMainThread:@selector(noteLayoutChanged) withObject:nil waitUntilDone:NO];
      NSLog(@"MBTDynamicPager setFrame finished");
      return;
    }
  
    if(previousPage) {
      NSNumber *previousPageIsolated = [previousPage objectForKey:kIsolatedBlockKey];
      NSNumber *currentPageIsolated = [pageDict objectForKey:kIsolatedBlockKey];
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
          NSLog(@"MBTDynamicPager. Sufficient additional space with previous page. Triggering retile");
          [self performSelectorOnMainThread:@selector(noteLayoutChanged) withObject:nil waitUntilDone:NO];
          NSLog(@"MBTDynamicPager setFrame finished");
          return;
        }
      }
    }

    previousPage = pageDict;
    prevPageFittingWidth = [pageFittingWidth floatValue];
  }

  NSLog(@"MBTDynamicPager setFrame (final) finished");
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
  
  NSLog(@"updating observations. Removing %lu blocks",(unsigned long)[deletedBlocks count]);

  NSIndexSet *indices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [deletedBlocks count])];
  [[deletedBlocks allObjects] removeObserver:self fromObjectsAtIndexes:indices forKeyPath:@"view"];

  self.viewBindingObservers = currentBlockSet;

  NSLog(@"updateViewObservations build maptable");
  // build a maptable from the blockControllers to their views. We need to
  // do this first because calling the view method may cause trigger the
  // observation.
  // Also, since we are here, set translatesAutoresizingMaskIntoConstraints
  // to no since we are handling the view's positioning in the superview
  // ourselves
  self.blockViewMap = [NSMapTable weakToWeakObjectsMapTable];
  for(NSViewController *blockController in self.viewBindingObservers) {
    NSLog(@"Got fittingsize in update %@",NSStringFromSize([blockController.view fittingSize]));

    [blockController.view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.blockViewMap setObject:blockController.view forKey:blockController];
  }

  NSLog(@"updating observations. Added %lu blocks",[addedBlocks count]);
  indices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [addedBlocks count])];
  [[addedBlocks allObjects] addObserver:self
                     toObjectsAtIndexes:indices
                             forKeyPath:@"view"
                                options:0
                                context:0];
}



#pragma mark - pager methods

// Determing the number of pages need to display all of the blocks given the
// size and constraints of the block
//  - If a block has a non-zero fitting size width, then that number is used as
//    the necessary block width.
//
//  - If the fitting width is zero, then the delegate is queried for the
//    desired block width. If no delegate is set, or a value less than 1 is
//    returned, then the default fitting size width is used. In either case, a
//    width constraint is added to the block.
//
//  - If the fitting height is zero, then the delegate is queried for the
//    desired block height. If no delegate is set, or a value less than 1 is
//    returned, then the default fitting size height is used. In either case, a
//    height constraint is added to the block.
- (void)noteLayoutChanged
{
  if(MBTDYNAMICPAGER_DEBUG && userRequestedLog())
    NSLog(@"MBTDynamicPager Retiling!");

  BOOL previousIsolated = NO;
  CGFloat fittingWidth = 0.0;
  CGFloat availableWidth = 0.0;
  NSMutableArray *pageBlocks = 0;
  NSMutableArray *blockFittingArray = 0;
  NSMutableDictionary *currentpage = 0;
  self.pages = [NSMutableArray array];

  NSArray *blockArray = [self currentBlockArray];

  NSLog(@"MBTDynamicPager laying out space for %lu blocks",[blockArray count]);

  // partition the blocks into pages
  for(NSViewController *blockController in blockArray) {
    NSView *block = [blockController view];
    [block layoutSubtreeIfNeeded];
    // get the blocks fittingSize
    NSSize contentSize = [block fittingSize];

    if(MBTDYNAMICPAGER_DEBUG && userRequestedLog())
      NSLog(@"MBTDynamicPager got fittingWidth %@ for block: %@",
            NSStringFromSize(contentSize),blockController);

    BOOL isolatedBlock = self.blocksDefaultToIsolated;

    if(self.delegate && [self.delegate respondsToSelector:@selector(blockShouldBeIsolated:)])
      isolatedBlock = [self.delegate blockShouldBeIsolated:blockController];

    // if nonpositive fitting width, then see if the delegate wants to set one.
    // In either case, flag that we need to add a block size constraint
    BOOL needsWidthConstraint = NO;
    if(!(contentSize.width > 0)) {
      needsWidthConstraint = YES;

      if(self.delegate &&
         [self.delegate respondsToSelector:@selector(widthForUnconstrainedBlock:)])
      {
        contentSize.width = [self.delegate widthForUnconstrainedBlock:blockController];
      }

      // if still zero, use the default.
      if(!(contentSize.width > 0))
        contentSize.width = self.defaultBlockWidth;
    }


    // if nonpositive fitting height, then see if the delegate wants to set one.
    // In either case, flag that we need to add a block size constraint
    BOOL needsHeightConstraint = NO;
    if(!(contentSize.height > 0)) {
      needsHeightConstraint = YES;

      if(self.delegate &&
         [self.delegate respondsToSelector:@selector(heightForUnconstrainedBlock:)])
      {
        contentSize.height = [self.delegate heightForUnconstrainedBlock:blockController];
      }

      // if still zero, use the default.
      if(!(contentSize.height > 0))
        contentSize.height = self.defaultBlockHeight;
    }



    if(MBTDYNAMICPAGER_DEBUG && userRequestedLog()) {
      NSLog(@"MBTDynamicPager: Calculated block content size: %f %@, %f %@",
            contentSize.width,(needsWidthConstraint?@"(constrained)":@""),
            contentSize.height,(needsHeightConstraint?@"(constrained)":@""));

      NSLog(@"MBTDynamicPager: Current page availableWidth %f, needed %f",
            availableWidth,contentSize.width + self.interblockPadding);
    }

    BlockFittingInfo *blockInfo = [[BlockFittingInfo alloc] initWithConstraint:needsWidthConstraint height:needsHeightConstraint andFittingSize:contentSize];

    // see if we need to make a new page
    if(isolatedBlock || previousIsolated ||
       availableWidth < (contentSize.width + self.interblockPadding))
    {
      if(MBTDYNAMICPAGER_DEBUG && userRequestedLog())
        NSLog(@"\tMBTDynamicPager: Making a new page with availableWidth %f: ",
              NSWidth(self.frame));

      // stash previous fittingWidth if this was not the first page
      if(currentpage)
        [currentpage setObject:[NSNumber numberWithFloat:fittingWidth]
                        forKey:kFittingWidthKey];

      currentpage = [NSMutableDictionary dictionary];
      [self.pages addObject:currentpage];

      // todo, what if the contentSize.width is too large for the new width?
      // padding is always calculated before the block, except for the first
      availableWidth = NSWidth(self.tabView.frame) - contentSize.width;
      pageBlocks = [NSMutableArray arrayWithObject:block];
      [currentpage setObject:pageBlocks forKey:kPageBlockKey];
      blockFittingArray = [NSMutableArray arrayWithObject:blockInfo];
      [currentpage setObject:blockFittingArray forKey:kFittingInfoArrayKey];
      [currentpage setObject:[NSNumber numberWithBool:(needsWidthConstraint==NO)]
                      forKey:kFlexibleContentKey];

      fittingWidth = contentSize.width;
    }
    else {
      [pageBlocks addObject:block];
      if(needsWidthConstraint==NO)
        [currentpage setObject:@YES forKey:kFlexibleContentKey];

      availableWidth -= (contentSize.width+self.interblockPadding);
      [blockFittingArray addObject:blockInfo];

      fittingWidth += (contentSize.width+self.interblockPadding);

      if(MBTDYNAMICPAGER_DEBUG && userRequestedLog())
        NSLog(@"\tMBTDynamicPager: Added to existing page, availablewidth is now: %f",availableWidth);
    }

    [currentpage setObject:[NSNumber numberWithBool:isolatedBlock]
                    forKey:kIsolatedBlockKey];

    previousIsolated = isolatedBlock;
  }

  // stash the fittingWidth of the final page
  [currentpage setObject:[NSNumber numberWithFloat:fittingWidth]
                  forKey:kFittingWidthKey];


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

      [self.tabView addTabViewItem:tabViewItem];
    }


    NSView *block = 0;
    BlockFittingInfo *fittingInfo = 0;
    BlockFittingInfo *previousFittingInfo = 0;
    NSView *previousBlock = 0;
    NSView *previousFittingBlock = 0;
    pageBlocks = [pageDict objectForKey:kPageBlockKey];
    blockFittingArray = [pageDict objectForKey:kFittingInfoArrayKey];
    for(NSUInteger i=0; i<[pageBlocks count]; ++i) {
      block = [pageBlocks objectAtIndex:i];
      fittingInfo = [blockFittingArray objectAtIndex:i];

      if([block superview] != [tabViewItem view]) {
        [block removeFromSuperview];
        [[tabViewItem view] addSubview:block];
      }

      // don't leading pad the first block
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


      // top always gets pinned to the top
      [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                         constraintWithItem:block
                                         attribute:NSLayoutAttributeTop
                                         relatedBy:NSLayoutRelationEqual
                                         toItem:[tabViewItem view]
                                         attribute:NSLayoutAttributeTop
                                         multiplier:1.0f
                                         constant:0.0f]];

      if(fittingInfo.heightConstrained) {
        //add height constraint
        [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                           constraintWithItem:block
                                           attribute:NSLayoutAttributeHeight
                                           relatedBy:NSLayoutRelationEqual
                                           toItem:nil
                                           attribute:NSLayoutAttributeNotAnAttribute
                                           multiplier:1.0f
                                           constant:fittingInfo.fittingSize.height]];
      }
      else {
        // pin to bottom
        [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                           constraintWithItem:block
                                           attribute:NSLayoutAttributeBottom
                                           relatedBy:NSLayoutRelationEqual
                                           toItem:[tabViewItem view]
                                           attribute:NSLayoutAttributeBottom
                                           multiplier:1.0f
                                           constant:0.0f]];
      }

      if(fittingInfo.widthConstrained) {
        //add width constraint
        [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                           constraintWithItem:block
                                           attribute:NSLayoutAttributeWidth
                                           relatedBy:NSLayoutRelationEqual
                                           toItem:nil
                                           attribute:NSLayoutAttributeNotAnAttribute
                                           multiplier:1.0f
                                           constant:fittingInfo.fittingSize.width]];

      }
      else {
        if(previousFittingBlock && previousFittingInfo) {
          // For each page, proportionally constrain each flexible block
          // compared to its size within the block
          CGFloat ratio = (previousFittingInfo.fittingSize.width /
            fittingInfo.fittingSize.width);

          [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                             constraintWithItem:block
                                             attribute:NSLayoutAttributeWidth
                                             relatedBy:NSLayoutRelationEqual
                                             toItem:previousFittingBlock
                                             attribute:NSLayoutAttributeWidth
                                             multiplier:1.0f
                                             constant:ratio]];
        }

        previousFittingInfo = fittingInfo;
        previousFittingBlock = block;
      }

      previousBlock = block;
    }

    NSNumber *flexibleContent = [pageDict objectForKey:kFlexibleContentKey];
    assert(flexibleContent);
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
  }

  // remove any remaining tabs
  [tabViewItems enumerateObjectsUsingBlock:^(NSTabViewItem *item, NSUInteger idx, BOOL *stop) {
    //    assert([[item.view subviews] count] == 0);
    [self.tabView removeTabViewItem:item];
  }];
  
  // trigger redisplay
  [self setNeedsDisplay:YES];

  if(MBTDYNAMICPAGER_DEBUG && userRequestedLog())
    NSLog(@"MBTDynamicPager retiling complete");
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
