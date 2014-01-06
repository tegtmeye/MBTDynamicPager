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
 Return the minimum desired width for the given block. That is, resizing the
 dynamicPager to less then this width will cause the block to shift to the next
 page.
 
 This delegate method is only called if the value of
 translatesAutoresizingMaskIntoConstraints is set to YES for the block's view
 OR if it is set to NO AND a non-positive value is returned from
 '[[[blockController view] fittingSize] width]' is returned. N.B., if
 using autolayout and this value is less than the fitting width, it is possible
 that a combination of view constraints and compression priorities will cause
 this value to be ignored. If not implemented by the delegate, then 
 MBTDynamicPager's 'defaultMinBlockWidth' is used. 
 
 An assertion will fail if a non-positive value is returned.
 */
- (CGFloat)minWidthForUnconstrainedBlock:(NSViewController *)blockController;

/**
 Return the maximum desired width for the given block. That is, resizing the
 dynamicPager to greater then this width will not cause the block to grow
 further.

 This delegate method is only called if the value of
 translatesAutoresizingMaskIntoConstraints is set to YES for the block's view
 OR if it is set to NO AND a non-positive value is returned from
 '[[[blockController view] fittingSize] width]' is returned. N.B., if
 using autolayout it is possible that a combination of view constraints and 
 expansion priorities will cause this value to be ignored. If it is not 
 implemented by the delegate, then MBTDynamicPager's
 'defaultMaxBlockWidth' is used. If a negative value is returned, then the
 block will grow unbounded. That is, no further blocks will exist on the page.

 An assertion will fail if a non-negative value less than 
 minWidthForUnconstrainedBlock is returned.
 */
- (CGFloat)maxWidthForUnconstrainedBlock:(NSViewController *)blockController;

/**
 Return the minimum desired height for the given block. That is, resizing the
 dynamicPager to less than this value will cause the block to be to clipped.
 Conversely, resizing the dynamic pager to greater than this value will cause
 the block to grow until the value of maxHeightForUnconstrainedBlock.
 
 This delegate method is only called if the value of
 translatesAutoresizingMaskIntoConstraints is set to YES for the block's view
 OR if it is set to NO AND a non-positive value is returned from
 '[[[blockController view] fittingSize] height]' is returned. N.B., if
 using autolayout and this value is less than the fitting height, it is possible
 that a combination of view constraints and compression priorities will cause
 this value to be ignored. If not implemented by the delegate, then
 MBTDynamicPager's 'defaultMinBlockHeight' is used.

 An assertion will fail if a negative value is returned.
 */
- (CGFloat)minHeightForUnconstrainedBlock:(NSViewController *)blockController;

/**
 Return the maximum desired height for the given block. That is, resizing the
 dynamicPager to greater then this value will not cause the block to grow
 further.

 This delegate method is only called if the value of
 translatesAutoresizingMaskIntoConstraints is set to YES for the block's view
 OR if it is set to NO AND a non-positive value is returned from
 '[[[blockController view] fittingSize] height]' is returned. N.B., if
 using autolayout it is possible that a combination of view constraints and
 expansion priorities will cause this value to be ignored. If it is not
 implemented by the delegate, then MBTDynamicPager's
 'defaultMaxBlockHeight' is used.

 An assertion will fail if a negative value is returned or if a value less than
 minHeightForUnconstrainedBlock.
 */
- (CGFloat)maxHeightForUnconstrainedBlock:(NSViewController *)blockController;

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
 The minimum width that will be assigned to a block if it does not have a
 fitting width and one cannot be determined from the delegate. See the
 delegate method 'minWidthForUnconstrainedBlock' for more information on how
 this value is used. The default value is 100.
 
 An assertion will fail if a non-positive value is set.
 */
@property (nonatomic, assign) CGFloat defaultMinBlockWidth;

/**
 The maximum width that will be assigned to a block if it does not have a
 fitting width and one cannot be determined from the delegate. See the
 delegate method 'maxWidthForUnconstrainedBlock' for more information on how
 this value is used. The default value is -1.0f.
 
 An assertion will fail if a non-negative value less than defaultMinBlockWidth
 is set.
 */
@property (nonatomic, assign) CGFloat defaultMaxBlockWidth;

/**
 The minimum height that will be assigned to a block if it does not have a
 fitting height and one cannot be determined from the delegate. See the
 delegate method 'minHeightForUnconstrainedBlock' for more information on how
 this value is used. The default value is 100.

 An assertion will fail if a negative value is set.
 */
@property (nonatomic, assign) CGFloat defaultMinBlockHeight;

/**
 The maximum height that will be assigned to a block if it does not have a
 fitting height and one cannot be determined from the delegate. See the
 delegate method 'maxHeightForUnconstrainedBlock' for more information on how
 this value is used. The default value is 100.

 An assertion will fail if a value less than defaultMinBlockHeight is set.
 */
@property (nonatomic, assign) CGFloat defaultMaxBlockHeight;

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
