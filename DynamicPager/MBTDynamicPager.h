//
//  MBTDynamicPager.h
//  DynamicPager
//
//  Created by tegtmeye on 6/3/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol MBTDynamicPagerDelegate <NSObject>

@optional

/**
 *  Return the desired width for the given block. This delegate method is
 *  only called if the width field of '[[blockController view] fittingSize]'
 *  returns zero. If this method also returns zero or is not implemented, then
 *  MBTDynamicPager's 'defaultBlockWidth' is used.
 */
- (CGFloat)widthForUnconstrainedBlock:(NSViewController *)blockController;

/**
 *  Return the desired height for the given block. This delegate method is
 *  only called if the height field of '[[blockController view] fittingSize]'
 *  returns zero. If this method also returns zero or is not implemented, then
 *  MBTDynamicPager's 'defaultBlockHeight' is used.
 */
- (CGFloat)heightForUnconstrainedBlock:(NSViewController *)blockController;

/**
 *  Return YES if the block should be isolated on its own page. Only called
 *  once per layout
 */
- (BOOL)blockShouldBeIsolated:(NSViewController *)controller;




@end



/**
 *  MBTDynamicPager is binding aware for the 'contentArray'. For example, to
 *  bind to an NSArrayController, bind the MBTDynamicPager
 *  'NSContentArrayBinding' binding name to the 'arrangedObjects' keypath of
 *  the NSArrayController.
 *
 *  eg:
 *    [dynamicPager bind:NSContentArrayBinding
 *              toObject:viewArrayController
 *           withKeyPath:@"arrangedObjects"
 *               options:nil];
 */
@interface MBTDynamicPager : NSView<NSTabViewDelegate>

@property (nonatomic, weak) id<MBTDynamicPagerDelegate> delegate;

/**
 *  An array of NSViewController objects containing the blocks to dynammically
 *  page. The 'view' property of each view controller is observed for changes.
 *  Any change to 'view' will cause the pager to retile.
 */
@property (nonatomic, strong) NSArray *contentArray;

/**
 *  The current displayed page
 */
@property(nonatomic, assign) NSInteger currentPage;

/**
 *  The current displayed page
 */
@property(nonatomic, readonly) NSInteger numberOfPages;


#pragma mark - Display options

/**
 *  The padding between blocks. Also used for padding between the blocks and
 *  The superview in the x-axis.
 */
@property (nonatomic, assign) CGFloat interblockPadding;

/**
 *  The width that will be assigned to a block if it does not have a fitting
 *  width and one cannot be determined from the delegate.
 *
 *  The block layout system looks at each block's fittingSize property to
 *  determine how many blocks should appear on a single page. If fittingSize
 *  has a zero parameter, the delegate does not implement or returns a zero
 *  value from widthForUnconstrainedBlock:blockController, or there is no
 *  delegate, then this value is used. The default is 100.
 */
@property (nonatomic, assign) CGFloat defaultBlockWidth;

/**
 *  The height that will be assigned to a block if it does not have a fitting
 *  height and one cannot be determined from the delegate.
 *
 *  The block layout system looks at each block's fittingSize property to
 *  determine how many blocks should appear on a single page. If fittingSize
 *  has a zero parameter, the delegate does not implement or returns a zero
 *  value from heightForUnconstrainedBlock:blockController, or there is no
 *  delegate, then this value is used. The default is 100.
 */
@property (nonatomic, assign) CGFloat defaultBlockHeight;

/**
 *  If set, each block will appear on its own page. If a delegate is set and
 *  the delegate responds to blockShouldBeIsolated:, then the delegate
 *  method return value is used instead.
 */
@property (nonatomic, assign) BOOL blocksDefaultToIsolated;


#pragma mark - auto layout overloads

//@property (nonatomic, assign, readonly) NSSize intrinsicContentSize;


#pragma mark - pager methods

- (void)noteLayoutChanged;

#pragma mark - debugging support

- (void)logBlockFramesForPage:(NSUInteger)page;

@end
