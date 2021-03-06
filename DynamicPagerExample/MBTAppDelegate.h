//
//  MBTAppDelegate.h
//  DynamicPagerExample
//
//  Created by tegtmeye on 6/22/13.
//  Copyright (c) 2013 Mike Tegtmeyer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MBTDynamicPager.h"

@interface MBTAppDelegate : NSObject <NSApplicationDelegate,MBTDynamicPagerDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet MBTDynamicPager *dynamicPager;

@property (weak) IBOutlet NSArrayController *viewArrayController;
@property (weak) IBOutlet NSArrayController *nibNameArrayController;

@property (weak) IBOutlet NSSegmentedControl *segmentPageControl;
@property (weak) IBOutlet NSDrawer *drawer;
@property (weak) IBOutlet NSBox *box;
@property (weak) IBOutlet NSMatrix *nibMatrix;

@property (nonatomic, assign) NSInteger selectedNibIndex;

// glue to enable/disable UI items for ignored UI input
@property (nonatomic, readonly) BOOL selectedMinWidthEnabled;
@property (nonatomic, readonly) BOOL selectedMaxWidthEnabled;
@property (nonatomic, readonly) BOOL selectedMinHeightEnabled;
@property (nonatomic, readonly) BOOL selectedMaxHeightEnabled;


// if set, then block isolation is the same as the default value
// of dynamicPager blocksDefaultToIsolated
@property (nonatomic, assign) BOOL ignorePerBlockIsolation;

// if set, then the pager content is bound to the viewArrayController
// otherwise it is set directly. If everything is working correctly
// setting this should have no effect.
@property (nonatomic, assign) BOOL useContentBinding;

@property (nonatomic, readonly) BOOL canPageDown;
@property (nonatomic, readonly) BOOL canPageUp;

- (IBAction)addBlock:(id)sender;

- (IBAction)triggerPagerUpdate:(id)sender;

- (IBAction)previousPage:(id)sender;
- (IBAction)nextPage:(id)sender;

- (IBAction)dumpPage:(id)sender;

- (IBAction)drawerDebug:(id)sender;
@end
