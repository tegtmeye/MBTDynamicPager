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

@property (nonatomic, assign) BOOL widthConstrained;
@property (nonatomic, assign) BOOL heightConstrained;
@property (nonatomic, assign) NSSize fittingSize;
@property (nonatomic) NSViewController *blockController;

@end

@implementation BlockFittingInfo

- (id)initWithConstraint:(BOOL)width
                  height:(BOOL)height
             fittingSize:(NSSize)fittingSize
         blockController:(NSViewController *)blockController
{
  self = [super init];
  if (self) {
    _widthConstrained = width;
    _heightConstrained = height;
    _fittingSize = fittingSize;
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
@property (nonatomic, strong) NSSet *observingBlocks;

@property (nonatomic, assign, readwrite) NSInteger numberOfPages;

- (NSArray *)currentBlockArray;
- (void)updateBlockObservations;

@end


@implementation MBTDynamicPager

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.interblockPadding = 8.0f;
    self.defaultBlockWidth = 100.0f;
    self.defaultBlockHeight = 100.0f;
    self.blocksDefaultToIsolated = YES;
    
    self.tabView = [[NSTabView alloc] initWithFrame:frame];
    self.tabView.delegate = self;
    [self.tabView setTabViewType:NSNoTabsLineBorder];
    [self.tabView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:self.tabView];

    self.pages = [NSMutableArray array];
    self.observingBlocks = [NSSet set];

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

  for(NSViewController *blockController in self.observingBlocks) {
      [blockController removeObserver:self forKeyPath:@"view"];
  }
}

- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath options:(NSDictionary *)options
{
  if([binding isEqualToString:NSContentArrayBinding]) {
    // reset if we were bound to something else or had content prior
    if(self.contentArrayObservableObject && self.contentArrayBindingKeyPath)
      [self unbind:NSContentArrayBinding];
    else {
      self.contentArray = nil;
    }


    self.contentArrayObservableObject = observable;
    self.contentArrayBindingKeyPath = keyPath;
    
    NSLog(@"MBTDynamicPager: binding and adding self as observer for object %@ and keypath %@",
          self.contentArrayObservableObject,self.contentArrayBindingKeyPath);

    [self.contentArrayObservableObject addObserver:self
                                        forKeyPath:self.contentArrayBindingKeyPath
                                           options:0
                                           context:nil];


    NSArray *currentBlockArray = [self currentBlockArray];

    for(NSViewController *blockController in currentBlockArray) {
      [blockController.view setTranslatesAutoresizingMaskIntoConstraints:NO];

      [blockController addObserver:self forKeyPath:@"view" options:0 context:nil];
    }

    self.observingBlocks = [NSSet setWithArray:currentBlockArray];

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

    for(NSViewController *blockController in self.observingBlocks) {
      [blockController removeObserver:self forKeyPath:@"view"];
    }

    self.contentArrayObservableObject = nil;
    self.contentArrayBindingKeyPath = nil;
    self.observingBlocks = [NSSet set];

    NSLog(@"MBTDynamicPager: unbinding. triggering retile");

    // this may cause things to revert back to self.contentArray;
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
  assert(currentPage >= 0);
  
  NSTabViewItem *selectedItem = [self.tabView selectedTabViewItem];
  
  if(selectedItem != [self.tabView tabViewItemAtIndex:currentPage]) {
    [self.tabView selectTabViewItemAtIndex:currentPage];
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
    // todo prob should have a pad that triggers retile...
    if(tabviewframeWidth - [pageFittingWidth floatValue] < 0) {
//      NSLog(@"MBTDynamicPager. Sufficient additional space. Triggering retile");
      [self performSelectorOnMainThread:@selector(noteLayoutChanged)
                             withObject:nil
                          waitUntilDone:NO];
//      NSLog(@"MBTDynamicPager setFrame finished");
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
//          NSLog(@"MBTDynamicPager. Sufficient additional space with previous page. Triggering retile");
          [self performSelectorOnMainThread:@selector(noteLayoutChanged)
                                 withObject:nil
                              waitUntilDone:NO];
//          NSLog(@"MBTDynamicPager setFrame finished");
          return;
        }
      }
    }

    previousPage = pageDict;
    prevPageFittingWidth = [pageFittingWidth floatValue];
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

    BlockFittingInfo *previousFittingInfo = 0;
    NSView *previousBlock = 0;
    NSView *previousFittingBlock = 0;
    NSArray *blockFittingArray = [pageDict objectForKey:kPageBlockFittingInfoArrayKey];

    if(MBTDYNAMICPAGER_DEBUG && userRequestedConsistencyCheck()) {
      if([[tabViewItem.view subviews] count] != blockFittingArray.count) {
        NSLog(@"Subviews (%lu) for tabView %@ does not equal the number of blocks (%lu) for this page",(unsigned long)[[tabViewItem.view subviews] count],tabViewItem,
              (unsigned long)blockFittingArray.count);
        assert(false);
      }

    }
    
    for(BlockFittingInfo *fittingInfo in blockFittingArray) {
      NSView *blockView = fittingInfo.blockController.view;

//      NSLog(@"Block %@ (view %@) has superview %@",fittingInfo.blockController,
//            fittingInfo.blockController.view,blockView.superview);
      assert(blockView.superview);

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


      // top always gets pinned to the top
      [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                         constraintWithItem:blockView
                                         attribute:NSLayoutAttributeTop
                                         relatedBy:NSLayoutRelationEqual
                                         toItem:[tabViewItem view]
                                         attribute:NSLayoutAttributeTop
                                         multiplier:1.0f
                                         constant:0.0f]];

      if(fittingInfo.heightConstrained) {
        //add height constraint
        [[tabViewItem view] addConstraint:[NSLayoutConstraint
                                           constraintWithItem:blockView
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
                                           constraintWithItem:blockView
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
                                           constraintWithItem:blockView
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
                                             constraintWithItem:blockView
                                             attribute:NSLayoutAttributeWidth
                                             relatedBy:NSLayoutRelationEqual
                                             toItem:previousFittingBlock
                                             attribute:NSLayoutAttributeWidth
                                             multiplier:1.0f
                                             constant:ratio]];
        }

        previousFittingInfo = fittingInfo;
        previousFittingBlock = blockView;
      }

      previousBlock = blockView;
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

  NSMutableSet *blocksToIgnore = [NSMutableSet setWithSet:self.observingBlocks];
  [blocksToIgnore minusSet:blocksToObserve];

  NSMutableSet *blocksToAdd = [NSMutableSet setWithSet:blocksToObserve];
  [blocksToAdd minusSet:self.observingBlocks];

  for(NSViewController *blockController in blocksToIgnore) {
//    NSLog(@"Removing observations for blockController %@",blockController);
    // also remove the view from any TabViewItem
    [blockController.view removeFromSuperview];

    [blockController removeObserver:self forKeyPath:@"view"];
  }

  for(NSViewController *blockController in blocksToAdd) {
//    NSLog(@"Adding observations for blockController %@",blockController);
    [blockController addObserver:self forKeyPath:@"view" options:0 context:nil];
  }

  self.observingBlocks = blocksToObserve;
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
    NSLog(@"MBTDynamicPager Retiling!");

  BOOL previousIsolated = NO;
  CGFloat fittingWidth = 0.0;
  CGFloat availableWidth = 0.0;
  NSMutableArray *blockFittingArray = 0;
  NSMutableDictionary *currentpage = 0;

  self.pages = [NSMutableArray array];

  NSArray *blockArray = [self currentBlockArray];

//  NSLog(@"MBTDynamicPager laying out space for %lu blocks",[blockArray count]);

  // partition the blocks into pages
  for(NSViewController *blockController in blockArray) {
    NSView *blockView = [blockController view];
    assert(blockView);

    [blockView setTranslatesAutoresizingMaskIntoConstraints:NO];

    // get the blocks fittingSize
    NSSize contentSize = [blockView fittingSize];

    if(MBTDYNAMICPAGER_DEBUG && userRequestedLog())
      NSLog(@"MBTDynamicPager got fittingWidth %@ for block: %@",
            NSStringFromSize(contentSize),blockController);

    NSLog(@"Got autoresizemask\n"
          "\tNSViewMinXMargin: %lu\n"
          "\tNSViewWidthSizable: %lu\n"
          "\tNSViewMaxXMargin: %lu\n"
          "\tNSViewMinYMargin: %lu\n"
          "\tNSViewHeightSizable: %lu\n"
          "\tNSViewMaxYMargin: %lu",
          (unsigned long)([blockView autoresizingMask] & NSViewMinXMargin),
          (unsigned long)([blockView autoresizingMask] & NSViewWidthSizable),
          (unsigned long)([blockView autoresizingMask] & NSViewMaxXMargin),
          (unsigned long)([blockView autoresizingMask] & NSViewMinYMargin),
          (unsigned long)([blockView autoresizingMask] & NSViewHeightSizable),
          (unsigned long)([blockView autoresizingMask] & NSViewMaxYMargin));

    NSLog(@"Got intrinsicSize %@",NSStringFromSize([blockView intrinsicContentSize]));


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

    BlockFittingInfo *fittingInfo =
      [[BlockFittingInfo alloc] initWithConstraint:needsWidthConstraint
                                            height:needsHeightConstraint
                                       fittingSize:contentSize
                                   blockController:blockController];




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

      blockFittingArray = [NSMutableArray arrayWithObject:fittingInfo];

      [currentpage setObject:blockFittingArray forKey:kPageBlockFittingInfoArrayKey];
      [currentpage setObject:[NSNumber numberWithBool:(needsWidthConstraint==NO)]
                      forKey:kFlexibleContentKey];

      fittingWidth = contentSize.width;
    }
    else {
      [blockFittingArray addObject:fittingInfo];

      if(needsWidthConstraint==NO)
        [currentpage setObject:@YES forKey:kFlexibleContentKey];

      availableWidth -= (contentSize.width+self.interblockPadding);

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


  NSLog(@"Building the tabView");
  // Now actually build the tabview.
  //
  // First make sure the number of tabs matches the number of pages. If we
  // have too many tabs, then removal of the tabs will release any subviews
  // than are not part of the current content.
  while(self.tabView.numberOfTabViewItems < self.pages.count) {
    [self.tabView addTabViewItem:[[NSTabViewItem alloc] initWithIdentifier:nil]];
  }

  while(self.tabView.numberOfTabViewItems > self.pages.count) {
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
//
  [self willChangeValueForKey:@"numberOfPages"];
  [self didChangeValueForKey:@"numberOfPages"];
  //  self.numberOfPages = tabView.numberOfTabViewItems;
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
  assert(tabView == self.tabView);

//  NSLog(@"MBTDynamicPager (NSTabViewDelegate) changed tabviewselection to %lu of %lu",
//        [self.tabView indexOfTabViewItem:[self.tabView selectedTabViewItem]],
//        [self.tabView numberOfTabViewItems]);

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
