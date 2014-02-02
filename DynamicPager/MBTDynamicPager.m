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

static const NSString *kMinPageWidthKey = @"MinPageWidthKey";
static const NSString *kMaxPageWidthKey = @"MaxPageWidthKey";
static const NSString *kIsolatedBlockKey = @"isolatedBlockKey";
static const NSString *kPageBlockFittingInfoArrayKey = @"PageBlockFittingInfoArrayKey";
static const NSString *kFlexibleContentKey = @"flexibleContent";

static BOOL userRequestedLog(void)
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"MBTDynamicPagerLogging"];
}

static BOOL userRequestedVisualAids(void)
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"MBTDynamicPagerVisualAids"];
}

static BOOL userRequestedConsistencyCheck (void)
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"MBTDynamicPagerConsistencyCheck"];
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

@property (nonatomic, assign) NSSize minContentSize;
@property (nonatomic, assign) NSSize maxContentSize;
@property (nonatomic) NSViewController *blockController;

@end

@implementation BlockFittingInfo

- (id)initWithMinContentSize:(NSSize)minContentSize
              maxContentSize:(NSSize)maxContentSize
         blockController:(NSViewController *)blockController
{
  self = [super init];
  if (self) {
    _minContentSize = minContentSize;
    _maxContentSize = maxContentSize;
    _blockController = blockController;
  }

  return self;
}

@end






@interface MBTDynamicPager ()

@property (nonatomic, strong) id contentArrayObservableObject;
@property (nonatomic, strong) NSString *contentArrayBindingKeyPath;

@property (nonatomic, strong) NSTabView *tabView;
@property (nonatomic, strong) NSMutableArray *pages;
@property (nonatomic, strong) NSMapTable *observingBlockAutoresizingMaskTranslationMap;

@property (nonatomic, assign) BOOL isChangingTabs;

- (NSArray *)currentBlockArray;
- (void)updateBlockObservations;

@end


@implementation MBTDynamicPager

+ (BOOL)requiresConstraintBasedLayout
{
  return YES;
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    _interblockPadding = 8.0f;
    _defaultMinBlockWidth = 100.0f;
    _defaultMaxBlockWidth = -1.0f;
    _defaultMinBlockHeight = 100.0f;
    _defaultMaxBlockHeight = -1.0f;
    _blocksDefaultToIsolated = YES;
    
    _tabView = [[NSTabView alloc] initWithFrame:frame];
    self.tabView.delegate = self;
    [self.tabView setTabViewType:NSNoTabsLineBorder];
    [self.tabView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:self.tabView];

    _pages = [NSMutableArray array];
    _observingBlockAutoresizingMaskTranslationMap = [NSMapTable strongToStrongObjectsMapTable];

    _isChangingTabs = NO;

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

- (void)dealloc
{
  if(self.contentArrayObservableObject && self.contentArrayBindingKeyPath) {
    [self.contentArrayObservableObject removeObserver:self
                                           forKeyPath:self.contentArrayBindingKeyPath];
  }

  // reset the blockController's view translatesAutoresizingMaskIntoConstraints
  // and stop observations
  NSArray *observingBlocks = NSAllMapTableKeys(self.observingBlockAutoresizingMaskTranslationMap);
  for(NSViewController *blockController in observingBlocks) {
    NSNumber *autoLayoutTranslation = [self.observingBlockAutoresizingMaskTranslationMap objectForKey:blockController];

    [blockController removeObserver:self forKeyPath:@"view"];
    blockController.view.translatesAutoresizingMaskIntoConstraints = [autoLayoutTranslation boolValue];

    [self.observingBlockAutoresizingMaskTranslationMap removeObjectForKey:blockController];
  }
}

- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath options:(NSDictionary *)options
{
  if([binding isEqualToString:NSContentArrayBinding]) {
    // reset if we were bound to something else or had content prior
    if(self.contentArrayObservableObject && self.contentArrayBindingKeyPath) {
      [self.contentArrayObservableObject removeObserver:self forKeyPath:self.contentArrayBindingKeyPath];
    }
    else {
      // don't trigger duplicitive operations
      _contentArray = nil;
    }


    self.contentArrayObservableObject = observable;
    self.contentArrayBindingKeyPath = keyPath;
    
    NSLog(@"MBTDynamicPager: binding and adding self as observer for object %@ and keypath %@",
          self.contentArrayObservableObject,self.contentArrayBindingKeyPath);

    [self.contentArrayObservableObject addObserver:self
                                        forKeyPath:self.contentArrayBindingKeyPath
                                           options:0
                                           context:nil];

    NSLog(@"MBTDynamicPager: done binding, triggering noteLayoutChanged");
    [self updateBlockObservations];
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

    NSLog(@"MBTDynamicPager: unbinding. triggering retile");

    [self updateBlockObservations];
    [self noteLayoutChanged];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if(object == self.contentArrayObservableObject &&
     [keyPath isEqualToString:self.contentArrayBindingKeyPath])
  {
    [self updateBlockObservations];
    [self noteLayoutChanged];
  }
}


- (void)setCurrentPage:(NSInteger)currentPage
{
  assert(currentPage >= 0 && currentPage < self.tabView.numberOfTabViewItems);
  
  NSTabViewItem *selectedItem = [self.tabView selectedTabViewItem];
  
  if(selectedItem != [self.tabView tabViewItemAtIndex:currentPage]) {
    self.isChangingTabs = YES;
    [self.tabView selectTabViewItemAtIndex:currentPage];
    self.isChangingTabs = NO;
  }
}

- (NSInteger)currentPage
{
  NSTabViewItem *selectedItem = [self.tabView selectedTabViewItem];

  if(selectedItem == nil)
    return -1;
  
  return [self.tabView indexOfTabViewItem:selectedItem];
}

- (NSInteger)numberOfPages
{
  return self.tabView.numberOfTabViewItems;
}

- (void)setInterblockPadding:(CGFloat)interblockPadding
{
  _interblockPadding = interblockPadding;

//  NSLog(@"setInterblockPadding to %f, triggering retile",interblockPadding);
  [self noteLayoutChanged];
}

- (void)setDefaultMinBlockWidth:(CGFloat)defaultMinBlockWidth
{
  assert((defaultMinBlockWidth < 0) || (defaultMinBlockWidth < self.defaultMaxBlockWidth));

  _defaultMinBlockWidth = defaultMinBlockWidth;

  [self noteLayoutChanged];
}

- (void)setDefaultMaxBlockWidth:(CGFloat)defaultMaxBlockWidth
{
  assert(self.defaultMinBlockWidth < defaultMaxBlockWidth);

  _defaultMaxBlockWidth = defaultMaxBlockWidth;

  [self noteLayoutChanged];
}

- (void)setDefaultMinBlockHeight:(CGFloat)defaultMinBlockHeight
{
  assert((defaultMinBlockHeight < 0) || (defaultMinBlockHeight < self.defaultMaxBlockHeight));

  _defaultMinBlockHeight = defaultMinBlockHeight;

  [self noteLayoutChanged];
}

- (void)setDefaultMaxBlockHeight:(CGFloat)defaultMaxBlockHeight
{
  assert(self.defaultMinBlockHeight < defaultMaxBlockHeight);

  _defaultMaxBlockHeight = defaultMaxBlockHeight;

  [self noteLayoutChanged];
}






- (void)setBlocksDefaultToIsolated:(BOOL)blocksDefaultToIsolated
{
  _blocksDefaultToIsolated = blocksDefaultToIsolated;

//  NSLog(@"setBlocksDefaultToIsolated to %i, triggering retile",blocksDefaultToIsolated);
  [self noteLayoutChanged];
}

- (void)setContentArray:(NSArray *)contentArray
{
  // if we are bound to something, then ignore updates to the contentArray.
  if(!(self.contentArrayObservableObject && self.contentArrayBindingKeyPath)) {
    NSLog(@"setContentArray. triggering retile");
    _contentArray = contentArray;

    [self updateBlockObservations];
    [self noteLayoutChanged];
  }
}


- (void)setFrame:(NSRect)frameRect
{
//  NSLog(@"MBTDynamicPager setFrame start with %lu pages and %lu block",
//        [self.pages count],[self.currentBlockArray count]);

  [super setFrame:frameRect];
  
  // todo prob should have a pad that triggers retile...
  // todo defer retile if it isn't needed to properly display this tab

  CGFloat tabviewframeWidth = NSWidth(self.tabView.contentRect);
  NSDictionary *previousPage = 0;
  NSUInteger pageIndex;
  for(pageIndex=0; pageIndex<[self.pages count]; ++pageIndex) {
    NSDictionary *pageDict = [self.pages objectAtIndex:pageIndex];

//    NSLog(@"PageDict %@",pageDict);

    NSNumber *minPageWidthNumber = [pageDict objectForKey:kMinPageWidthKey];
    assert(minPageWidthNumber);

    CGFloat minPageWidth = [minPageWidthNumber floatValue];


    // first check and see if the frame became too small and we need to push
    // a block onto the next page
    if((tabviewframeWidth - minPageWidth) < 0) {
//      NSLog(@"MBTDynamicPager. Sufficient additional space. Triggering retile");
      [self performSelectorOnMainThread:@selector(noteLayoutChanged)
                             withObject:nil
                          waitUntilDone:NO];
//      NSLog(@"MBTDynamicPager setFrame finished");
      return;
    }

    // don't trigger retile on unbounded last blocks



    if(previousPage) {
      NSNumber *previousPageIsolated = [previousPage objectForKey:kIsolatedBlockKey];
      NSNumber *currentPageIsolated = [pageDict objectForKey:kIsolatedBlockKey];
      assert(previousPageIsolated && currentPageIsolated);

      /**
        Don't try and move blocks forward if:
          - the previous block was marked as being isolated
          - this block was marked as being isolated
          - the previous page's frame width minus minPageWidth is less than the
            the first blocks minBlockWidth;
       */

      //      NSNumber *previousPageIsolated = [previousPage objectForKey:kIsolatedBlockKey];
//      NSNumber *currentPageIsolated = [pageDict objectForKey:kIsolatedBlockKey];
//      assert(previousPageIsolated && currentPageIsolated);

//      NSLog(@"previousPageIsolated: %@ and currentPageIsolated %@",previousPageIsolated,currentPageIsolated);
      
      if(![previousPageIsolated boolValue] && ![currentPageIsolated boolValue]) {
        NSNumber *previousPageMaxPageWidthNumber = [previousPage objectForKey:kMaxPageWidthKey];
        assert(previousPageMaxPageWidthNumber);

        CGFloat previousPageMaxPageWidth = [previousPageMaxPageWidthNumber floatValue];

        NSArray *blockArray = [pageDict objectForKey:kPageBlockFittingInfoArrayKey];
        assert(blockArray);

        BlockFittingInfo *firstBlockFittingInfo = [blockArray objectAtIndex:0];

        if((NSWidth(self.tabView.contentRect)-previousPageMaxPageWidth) >= firstBlockFittingInfo.minContentSize.width)
        {
          [self performSelectorOnMainThread:@selector(noteLayoutChanged)
                                 withObject:nil
                              waitUntilDone:NO];
          //          NSLog(@"MBTDynamicPager setFrame finished");
          return;
        }


//        NSSize contentSize = [firstBlock fittingSize];
//        CGFloat blockWidth = (contentSize.width > 0 ? contentSize.width : self.defaultBlockWidth);
//      
////        NSLog(@"blockWidth %f and pageFittingWidth %f",blockWidth,prevPageFittingWidth);
//        
//        CGFloat additionalBlockWidth = (blockWidth + self.interblockPadding);
//        CGFloat availableWidth = (tabviewframeWidth - prevPageFittingWidth);
//        if(additionalBlockWidth < availableWidth) {
//          // just need on to trigger retile
////          NSLog(@"MBTDynamicPager. Sufficient additional space with previous page. Triggering retile");
//          [self performSelectorOnMainThread:@selector(noteLayoutChanged)
//                                 withObject:nil
//                              waitUntilDone:NO];
////          NSLog(@"MBTDynamicPager setFrame finished");
//          return;
//        }
      }
    }

    previousPage = pageDict;
  }

//  NSLog(@"MBTDynamicPager setFrame (final) finished");
}

-(void)updateConstraints
{
//  NSLog(@">>>>>>>>>>>>>>>MBTDynamicPager updateConstraints start");

  assert(self.pages.count == self.tabView.numberOfTabViewItems);
  for(NSInteger pageIndex=0; pageIndex<self.pages.count; ++pageIndex) {
    NSDictionary *pageDict = [self.pages objectAtIndex:pageIndex];
    NSTabViewItem *tabViewItem = [self.tabView.tabViewItems objectAtIndex:pageIndex];

//    NSLog(@"Tabview %@ (view %@) has subviews %@",tabViewItem,tabViewItem.view,[tabViewItem.view subviews]);

    [tabViewItem.view removeConstraints:[tabViewItem.view constraints]];

    NSView *previousBlock = 0;
    NSArray *blockFittingArray = [pageDict objectForKey:kPageBlockFittingInfoArrayKey];
    assert(blockFittingArray);

    if(MBTDYNAMICPAGER_DEBUG && userRequestedConsistencyCheck()) {
      if([[tabViewItem.view subviews] count] != blockFittingArray.count) {
        NSLog(@"Subviews (%lu) for tabView %@ does not equal the number of blocks (%lu) for this page",(unsigned long)[[tabViewItem.view subviews] count],tabViewItem,
              (unsigned long)blockFittingArray.count);
        assert(false);
      }

    }
    
    for(BlockFittingInfo *fittingInfo in blockFittingArray) {
      NSView *blockView = fittingInfo.blockController.view;

      NSLog(@"Constraints on %@ (translatedAutoResizeMask: %i) before remove: %@",fittingInfo.blockController,blockView.translatesAutoresizingMaskIntoConstraints,blockView.constraints);
      
//      NSLog(@"Block %@ (view %@) has superview %@",fittingInfo.blockController,
//            fittingInfo.blockController.view,blockView.superview);
      assert(blockView.superview);


      // Take care of widths first
      // don't leading pad the first block
      if(!previousBlock) {
        [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                           constraintWithItem:blockView
                                           attribute:NSLayoutAttributeLeading
                                           relatedBy:NSLayoutRelationEqual
                                           toItem:[tabViewItem view]
                                           attribute:NSLayoutAttributeLeading
                                           multiplier:1.0f
                                           constant:0.0f]];
      }
      else {
        [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                           constraintWithItem:blockView
                                           attribute:NSLayoutAttributeLeading
                                           relatedBy:NSLayoutRelationEqual
                                           toItem:previousBlock
                                           attribute:NSLayoutAttributeTrailing
                                           multiplier:1.0f
                                           constant:self.interblockPadding]];
      }


      NSLog(@"Widthconstraints min %f max %f",fittingInfo.minContentSize.width,fittingInfo.maxContentSize.width);

      // We always set a minimum constraint, even if it is zero (which is the
      // trivial case)
      [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                         constraintWithItem:blockView
                                         attribute:NSLayoutAttributeWidth
                                         relatedBy:NSLayoutRelationGreaterThanOrEqual
                                         toItem:nil
                                         attribute:NSLayoutAttributeNotAnAttribute
                                         multiplier:1.0f
                                         constant:fittingInfo.minContentSize.width]];

      // if the maximum is non-negative, assign it (negative is unbounded)
      if(fittingInfo.maxContentSize.width >= 0) {
        [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                           constraintWithItem:blockView
                                           attribute:NSLayoutAttributeWidth
                                           relatedBy:NSLayoutRelationLessThanOrEqual
                                           toItem:nil
                                           attribute:NSLayoutAttributeNotAnAttribute
                                           multiplier:1.0f
                                           constant:fittingInfo.maxContentSize.width]];
      }













      // top always gets pinned to the top
      [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                         constraintWithItem:blockView
                                         attribute:NSLayoutAttributeTop
                                         relatedBy:NSLayoutRelationEqual
                                         toItem:[tabViewItem view]
                                         attribute:NSLayoutAttributeTop
                                         multiplier:1.0f
                                         constant:0.0f]];

//      if(fittingInfo.heightConstrained) {
//        //add height constraint
//        [[tabViewItem view] addConstraint:[NSLayoutConstraint
//                                           constraintWithItem:blockView
//                                           attribute:NSLayoutAttributeHeight
//                                           relatedBy:NSLayoutRelationEqual
//                                           toItem:nil
//                                           attribute:NSLayoutAttributeNotAnAttribute
//                                           multiplier:1.0f
//                                           constant:fittingInfo.fittingSize.height]];
//      }
//      else {
        // pin to bottom
        [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                           constraintWithItem:blockView
                                           attribute:NSLayoutAttributeBottom
                                           relatedBy:NSLayoutRelationEqual
                                           toItem:[tabViewItem view]
                                           attribute:NSLayoutAttributeBottom
                                           multiplier:1.0f
                                           constant:0.0f]];
//      }







//      if(fittingInfo.widthConstrained) {
//        //add width constraint
//        [[tabViewItem view] addConstraint:[NSLayoutConstraint
//                                           constraintWithItem:blockView
//                                           attribute:NSLayoutAttributeWidth
//                                           relatedBy:NSLayoutRelationEqual
//                                           toItem:nil
//                                           attribute:NSLayoutAttributeNotAnAttribute
//                                           multiplier:1.0f
//                                           constant:fittingInfo.fittingSize.width]];
//
//      }
//      else {
//        if(previousFittingBlock && previousFittingInfo) {
//          // For each page, proportionally constrain each flexible block
//          // compared to its size within the block
//          CGFloat ratio = (previousFittingInfo.fittingSize.width /
//                           fittingInfo.fittingSize.width);
//
//          [[tabViewItem view] addConstraint:[NSLayoutConstraint
//                                             constraintWithItem:blockView
//                                             attribute:NSLayoutAttributeWidth
//                                             relatedBy:NSLayoutRelationEqual
//                                             toItem:previousFittingBlock
//                                             attribute:NSLayoutAttributeWidth
//                                             multiplier:1.0f
//                                             constant:ratio]];
//        }
//
//        previousFittingInfo = fittingInfo;
//        previousFittingBlock = blockView;
//      }

      previousBlock = blockView;
    }

//    NSNumber *flexibleContent = [pageDict objectForKey:kFlexibleContentKey];
//    assert(flexibleContent);
//    if([flexibleContent boolValue]) {
      // pin the right size to the tabViewItem
    NSLayoutConstraint *endConstraint = [NSLayoutConstraint
                                         constraintWithItem:previousBlock
                                         attribute:NSLayoutAttributeTrailing
                                         relatedBy:NSLayoutRelationEqual
                                         toItem:[tabViewItem view]
                                         attribute:NSLayoutAttributeTrailing
                                         multiplier:1.0f
                                         constant:0.0f];
    endConstraint.priority = NSLayoutPriorityDragThatCannotResizeWindow;

    [[tabViewItem view] addConstraint:endConstraint];
//    }
  }

  [super updateConstraints];

  NSLog(@"\n\n\n\n");

//  NSLog(@"MBTDynamicPager updateConstraints finished");
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

- (void)updateBlockObservations
{
  NSSet *blocksToObserve = [NSSet setWithArray:[self currentBlockArray]];


//  NSLog(@"MBTDynamicPager: content changed (now %lu blocks). triggering retile",blocksToObserve.count);

  NSSet *currentObservingBlocks = [NSSet setWithArray:NSAllMapTableKeys(self.observingBlockAutoresizingMaskTranslationMap)];

  NSMutableSet *blocksToIgnore = [NSMutableSet setWithSet:currentObservingBlocks];
  [blocksToIgnore minusSet:blocksToObserve];

  NSMutableSet *blocksToAdd = [NSMutableSet setWithSet:blocksToObserve];
  [blocksToAdd minusSet:currentObservingBlocks];

  for(NSViewController *blockController in blocksToIgnore) {
    NSNumber *autoLayoutTranslation = [self.observingBlockAutoresizingMaskTranslationMap objectForKey:blockController];
    assert(autoLayoutTranslation);

    //    NSLog(@"Removing observations for blockController %@",blockController);
    // also remove the view from any TabViewItem
    [blockController.view removeFromSuperview];

    NSLog(@"updateBlockObservations: Constraints before set: %@",blockController.view.constraints);

    blockController.view.translatesAutoresizingMaskIntoConstraints = [autoLayoutTranslation boolValue];

    NSLog(@"updateBlockObservations: Constraints after set: %@",blockController.view.constraints);

    [blockController removeObserver:self forKeyPath:@"view"];

    [self.observingBlockAutoresizingMaskTranslationMap removeObjectForKey:blockController];
  }

  for(NSViewController *blockController in blocksToAdd) {
    NSLog(@"VIEW TRANSLATESAUTORESIZEMASKINTOCONSTRAINTS %i",blockController.view.translatesAutoresizingMaskIntoConstraints);

    NSNumber *autoLayoutTranslation = [NSNumber numberWithBool:blockController.view.translatesAutoresizingMaskIntoConstraints];

    [self.observingBlockAutoresizingMaskTranslationMap setObject:autoLayoutTranslation
                                              forKey:blockController];

    [blockController.view setTranslatesAutoresizingMaskIntoConstraints:NO];

    NSLog(@"Adding observations for blockController %@. AutoLayoutTranslation %@ (%i)",blockController,autoLayoutTranslation,
          blockController.view.translatesAutoresizingMaskIntoConstraints);

    [blockController addObserver:self forKeyPath:@"view" options:0 context:nil];
  }
}

#pragma mark - pager methods

// Determing the number of pages need to display all of the blocks given the
// size and constraints of the block.
//
// If the block's view has translatesAutoresizingMaskIntoConstraints was set to
// YES when it was added to the dynamicPager's content, then the determination
// of whether or not the block is resizable is determined by the
// autoresizingMask constants, otherwise it is determined by the value of
// fittingwidth. If translatesAutoresizingMaskIntoConstraints was set to YES,
// it is set to NO as autolayout is used internally. Non-autolayout changes are
// not recognized after the block is added.
//
// If translatesAutoresizingMaskIntoConstraints is set to YES
//  - If either NSViewWidthSizable or NSViewHeightSizable is not set, then the
//    respective initial block's view dimension is used and a constraint is
//    applied.
//
//  - If NSViewWidthSizable is set, then the delegate is queried for the
//    desired block width.  If no delegate is set, or a non-positive value is
//    returned, then the default fitting size width is used. In either case, a
//    width constraint is added to the block.
//
//  - If NSViewHeightSizable is set, then the delegate is queried for the
//    desired block height.  If no delegate is set, or a non-positive value is
//    returned, then the default fitting size height is used. In either case, a
//    height constraint is added to the block.

// If translatesAutoresizingMaskIntoConstraints is set to NO
//  - If a block has a non-zero fitting size width, then that number is used as
//    the necessary block width.
//
//  - If the fitting width is zero, then the delegate is queried for the
//    desired block width. If no delegate is set, or a non-positive value is
//    returned, then the default fitting size width is used. In either case, a
//    width constraint is added to the block.
//
//  - If the fitting height is zero, then the delegate is queried for the
//    desired block height. If no delegate is set, or a non-positive value is
//    returned, then the default fitting size height is used. In either case, a
//    height constraint is added to the block.

// In the end, the tabview should have the right number of tabs, the block views
// should be added as a subview of the correct tabViewItem and the pages array
// should be correctly filled out.
 - (void)noteLayoutChanged
{
// We do this in two passes. First pass builds the pages dictionary which
// partitions the blocks into pages---the number based on the size of the
// blocks. The second pass actually builds the tabview with the appropriate
// number of TabViewItems and adds each block's view as a subview of the
// TabViewItem's view.

  if(MBTDYNAMICPAGER_DEBUG && userRequestedLog())
    NSLog(@"MBTDynamicPager retiling on frame of size %@",NSStringFromSize(self.tabView.contentRect.size));

  BOOL previousIsolated = NO;
  CGFloat minPageWidth = 0.0;
  CGFloat maxPageWidth = 0.0;
  NSMutableArray *blockFittingArray = 0;
  NSMutableDictionary *currentpage = 0;

  self.pages = [NSMutableArray array];

  NSArray *blockArray = [self currentBlockArray];

  NSLog(@"MBTDynamicPager laying out space for %lu blocks",[blockArray count]);

  // partition the blocks into pages
  for(NSViewController *blockController in blockArray) {
    NSLog(@"Laying out block %@",blockController);

    NSView *blockView = [blockController view];
    assert(blockView);


    // Since we reset the translatesAutoresizingMaskIntoConstraints to no
    // query the statshed value for the real value.

    NSNumber *usesAutoResizeMaskNumber = [self.observingBlockAutoresizingMaskTranslationMap objectForKey:blockController];
    assert(usesAutoResizeMaskNumber);
    BOOL usesAutoResizeMask = [usesAutoResizeMaskNumber boolValue];

    // get the blocks fittingSize
    // unbounded growth is less than zero when using springs and struts and
    // non-positive when using autolayout
    NSSize minContentSize = NSMakeSize(0.0f,0.0f);
    NSSize maxContentSize = NSMakeSize(-1.0f,-1.0f);

    if(usesAutoResizeMask) {
      if(MBTDYNAMICPAGER_DEBUG && userRequestedLog()) {
        NSLog(@"MBTDynamicPager: Springs and struts detected for block: %@",
              blockController);
      }

      // query the autoresizingMask
      if(!(blockView.autoresizingMask & NSViewWidthSizable)) {
        minContentSize.width = blockView.frame.size.width;
        maxContentSize.width = blockView.frame.size.width;
      }

      if(!(blockView.autoresizingMask & NSViewHeightSizable)) {
        minContentSize.height = blockView.frame.size.height;
        maxContentSize.height = blockView.frame.size.height;
      }
    }
    else {
      if(MBTDYNAMICPAGER_DEBUG && userRequestedLog()) {
        NSLog(@"MBTDynamicPager: Autolayout detected for block: %@",
              blockController);
      }

      minContentSize = [blockView fittingSize];
    }



//    NSLog(@"Got autoresizemask\n"
//          "\tNSViewMinXMargin: %lu\n"
//          "\tNSViewWidthSizable: %lu\n"
//          "\tNSViewMaxXMargin: %lu\n"
//          "\tNSViewMinYMargin: %lu\n"
//          "\tNSViewHeightSizable: %lu\n"
//          "\tNSViewMaxYMargin: %lu",
//          (unsigned long)([blockView autoresizingMask] & NSViewMinXMargin),
//          (unsigned long)([blockView autoresizingMask] & NSViewWidthSizable),
//          (unsigned long)([blockView autoresizingMask] & NSViewMaxXMargin),
//          (unsigned long)([blockView autoresizingMask] & NSViewMinYMargin),
//          (unsigned long)([blockView autoresizingMask] & NSViewHeightSizable),
//          (unsigned long)([blockView autoresizingMask] & NSViewMaxYMargin));

//    NSLog(@"Got intrinsicSize %@",NSStringFromSize([blockView intrinsicContentSize]));

    if(MBTDYNAMICPAGER_DEBUG && userRequestedLog()) {
      NSLog(@"MBTDynamicPager: Pre-delegate calculated block content size: "
            "minContentSize %@ and maxContentSize %@ for block: %@",
            NSStringFromSize(minContentSize),NSStringFromSize(maxContentSize),
            blockController);
    }


    BOOL isolatedBlock = self.blocksDefaultToIsolated;

    if(self.delegate && [self.delegate respondsToSelector:@selector(blockShouldBeIsolated:)])
      isolatedBlock = [self.delegate blockShouldBeIsolated:blockController];

    // if nonpositive fitting width, then see if the delegate wants to set one.
    // In either case, flag that we need to add a block size constraint
    if(minContentSize.width == 0.0f) {
      if(self.delegate &&
         [self.delegate respondsToSelector:@selector(minWidthForUnconstrainedBlock:)])
      {
        minContentSize.width = [self.delegate minWidthForUnconstrainedBlock:blockController];
        assert(minContentSize.width > 0);
      }
      else
        minContentSize.width = self.defaultMinBlockWidth;
    }

    if(maxContentSize.width <= 0.0f) {
      if(self.delegate &&
         [self.delegate respondsToSelector:@selector(maxWidthForUnconstrainedBlock:)])
      {
        maxContentSize.width = [self.delegate maxWidthForUnconstrainedBlock:blockController];
      }
      else
        maxContentSize.width = self.defaultMaxBlockWidth;
    }
    assert(maxContentSize.width < 0.0f || maxContentSize.width >= minContentSize.width);

    if(minContentSize.height == 0.0f) {
      if(self.delegate &&
         [self.delegate respondsToSelector:@selector(minHeightForUnconstrainedBlock:)])
      {
        minContentSize.height = [self.delegate minHeightForUnconstrainedBlock:blockController];
        assert(minContentSize.height > 0);
      }
      else
        minContentSize.height = self.defaultMinBlockHeight;
    }

    if(maxContentSize.height <= 0.0f) {
      if(self.delegate &&
         [self.delegate respondsToSelector:@selector(maxHeightForUnconstrainedBlock:)])
      {
        maxContentSize.height = [self.delegate maxHeightForUnconstrainedBlock:blockController];
      }
      else
        maxContentSize.height = self.defaultMaxBlockHeight;
    }
    assert(maxContentSize.height < 0.0f || maxContentSize.height >= minContentSize.height);



    if(MBTDYNAMICPAGER_DEBUG && userRequestedLog()) {
      NSLog(@"MBTDynamicPager: Calculated block content size: "
            "minContentSize %@ and maxContentSize %@ for block: %@",
            NSStringFromSize(minContentSize),NSStringFromSize(maxContentSize),
            blockController);
    }

    BOOL flexibleContent = (minContentSize.width != maxContentSize.width);

    BlockFittingInfo *fittingInfo =
      [[BlockFittingInfo alloc] initWithMinContentSize:minContentSize
                                        maxContentSize:maxContentSize
                                       blockController:blockController];


    // see if we need to make a new page
    if(!currentpage || isolatedBlock || previousIsolated || (maxPageWidth < 0.0f) ||
       (minContentSize.width + self.interblockPadding) > (NSWidth(self.tabView.contentRect)-minPageWidth))
    {
      if(MBTDYNAMICPAGER_DEBUG && userRequestedLog())
        NSLog(@"\tMBTDynamicPager: Making a new page with availableWidth %f: ",
              NSWidth(self.tabView.contentRect));

      // stash previous fittingWidth if this was not the first page
      if(currentpage) {
        [currentpage setObject:[NSNumber numberWithFloat:minPageWidth]
                        forKey:kMinPageWidthKey];
        [currentpage setObject:[NSNumber numberWithFloat:maxPageWidth]
                        forKey:kMaxPageWidthKey];
      }

      currentpage = [NSMutableDictionary dictionary];
      [self.pages addObject:currentpage];

      // todo, what if the contentSize.width is too large for the new width?
      // padding is always calculated before the block, except for the first

      /**
       If the current block has an unbounded maximum width, then this
       automatically becomes the last block on this page.
       */
      minPageWidth = minContentSize.width;
      maxPageWidth = maxContentSize.width;

      blockFittingArray = [NSMutableArray arrayWithObject:fittingInfo];

      [currentpage setObject:blockFittingArray forKey:kPageBlockFittingInfoArrayKey];

      [currentpage setObject:[NSNumber numberWithBool:flexibleContent]
                      forKey:kFlexibleContentKey];

      [currentpage setObject:[NSNumber numberWithBool:isolatedBlock]
                      forKey:kIsolatedBlockKey];
    }
    else {
      [blockFittingArray addObject:fittingInfo];

      if(flexibleContent)
        [currentpage setObject:@YES forKey:kFlexibleContentKey];

      minPageWidth += minContentSize.width + self.interblockPadding;

      if(maxContentSize.width < 0.0f)
        maxPageWidth = -1.0f;
      else
        maxPageWidth += maxContentSize.width + self.interblockPadding;

      if(MBTDYNAMICPAGER_DEBUG && userRequestedLog())
        NSLog(@"MBTDynamicPager: Placing block on current page with availableWidth %f",
              (NSWidth(self.tabView.contentRect)-minPageWidth));
    }

//    [currentpage setObject:[NSNumber numberWithBool:isolatedBlock]
//                    forKey:kIsolatedBlockKey];

    previousIsolated = isolatedBlock;
  }

  // stash the minimum and maximum page widths for the last block
  [currentpage setObject:[NSNumber numberWithFloat:minPageWidth]
                  forKey:kMinPageWidthKey];
  [currentpage setObject:[NSNumber numberWithFloat:maxPageWidth]
                  forKey:kMaxPageWidthKey];


  NSLog(@"Building the tabView for %lu tabs",(unsigned long)self.pages.count);
  // Now actually build the tabview.
  //
  // First make sure the number of tabs matches the number of pages. If we
  // have too many tabs, then removal of the tabs will release any subviews
  // than are not part of the current content.
  while(self.tabView.numberOfTabViewItems < self.pages.count) {
    NSLog(@"Adding a new tabviewitem");
    [self.tabView addTabViewItem:[[NSTabViewItem alloc] initWithIdentifier:nil]];
  }

  while(self.tabView.numberOfTabViewItems > self.pages.count) {
    NSLog(@"Getting rid of a unneeded tabviewitem");
    [self.tabView removeTabViewItem:[self.tabView.tabViewItems lastObject]];
  }

  NSArray *tabViewItems = self.tabView.tabViewItems;
  for(NSUInteger pageIndex=0; pageIndex<self.pages.count; ++pageIndex) {
    NSDictionary *pageDict = [self.pages objectAtIndex:pageIndex];
    NSTabViewItem *tabViewItem = [tabViewItems objectAtIndex:pageIndex];

    NSArray *fittingInfoArray = [pageDict objectForKey:kPageBlockFittingInfoArrayKey];
    for(BlockFittingInfo *fittingInfo in fittingInfoArray) {
      if(fittingInfo.blockController.view.superview != tabViewItem.view) {
        [fittingInfo.blockController.view removeFromSuperview];
        [tabViewItem.view addSubview:fittingInfo.blockController.view];
      }

//      NSLog(@"BlockController %@ view has superView %@",fittingInfo.blockController,fittingInfo.blockController.view.superview);
    }
  }

//  NSLog(@"Number of tabviews %lu",self.tabView.numberOfTabViewItems);
  if(self.tabView.numberOfTabViewItems > 0 && ![self.tabView selectedTabViewItem]) {
//    NSLog(@"selected tabview %@. Selecting the first tab",[self.tabView selectedTabViewItem]);

    [self.tabView selectTabViewItemAtIndex:0];
//    NSLog(@"selected tabview %@",[self.tabView selectedTabViewItem]);
  }

  // trigger redisplay
  self.needsUpdateConstraints = YES;
  [self setNeedsDisplay:YES];

  if(MBTDYNAMICPAGER_DEBUG && userRequestedLog())
    NSLog(@"MBTDynamicPager retiling complete");
}



#pragma mark - NSTabViewDelegate

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
  assert(tabView == self.tabView);

//  NSLog(@"MBTDynamicPager (NSTabViewDelegate) changed numberOfTabViewItems to %lu",tabView.numberOfTabViewItems);

  [self willChangeValueForKey:@"numberOfPages"];
  [self didChangeValueForKey:@"numberOfPages"];

  if([self.tabView selectedTabViewItem] == nil)
    [self.tabView selectFirstTabViewItem:self];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
  assert(tabView == self.tabView);

//  NSLog(@"MBTDynamicPager (NSTabViewDelegate) changed tabviewselection to %lu of %lu",
//        [self.tabView indexOfTabViewItem:[self.tabView selectedTabViewItem]],
//        [self.tabView numberOfTabViewItems]);

  if(!self.isChangingTabs) {
    [self willChangeValueForKey:@"currentPage"];
    [self didChangeValueForKey:@"currentPage"];
  }
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
