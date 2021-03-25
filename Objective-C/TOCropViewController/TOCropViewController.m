//
//  TOCropViewController.m
//
//  Copyright 2015-2018 Timothy Oliver. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "TOCropViewController.h"
#import "TOCropViewControllerTransitioning.h"
#import "TOActivityCroppedImageProvider.h"
#import "UIImage+CropRotate.h"
#import "TOCroppedImageAttributes.h"
#import "TOCropOverlayView.h"

static const CGFloat kTOCropViewControllerToolbarHeight = 44.0f;

@interface TOCropViewController () <UIActionSheetDelegate, UIViewControllerTransitioningDelegate, TOCropViewDelegate>

/* The target image */
@property (nonatomic, readwrite) UIImage *image;

/* The cropping style of the crop view */
@property (nonatomic, assign, readwrite) TOCropViewCroppingStyle croppingStyle;

/* Views */
@property (nonatomic, strong) TOCropToolbar *toolbar;
@property (nonatomic, strong, readwrite) TOCropView *cropView;
@property (nonatomic, strong) UIView *toolbarSnapshotView;
@property (nonatomic, strong) UIButton *buttonAdjustThumbnail;

/* Transition animation controller */
@property (nonatomic, copy) void (^prepareForTransitionHandler)(void);
@property (nonatomic, strong) TOCropViewControllerTransitioning *transitionController;
@property (nonatomic, assign) BOOL inTransition;

/* If pushed from a navigation controller, the visibility of that controller's bars. */
@property (nonatomic, assign) BOOL navigationBarHidden;
@property (nonatomic, assign) BOOL toolbarHidden;

/* State for whether content is being laid out vertically or horizontally */
@property (nonatomic, readonly) BOOL verticalLayout;

/* Convenience method for managing status bar state */
@property (nonatomic, readonly) BOOL overrideStatusBar; // Whether the view controller needs to touch the status bar
@property (nonatomic, readonly) BOOL statusBarHidden;   // Whether it should be hidden or visible at this point
@property (nonatomic, readonly) CGFloat statusBarHeight; // The height of the status bar when visible

/* Convenience method for getting the vertical inset for both iPhone X and status bar */
@property (nonatomic, readonly) UIEdgeInsets statusBarSafeInsets;

/* Flag to perform initial setup on the first run */
@property (nonatomic, assign) BOOL firstTime;

/* On iOS 7, the popover view controller that appears when tapping 'Done' */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@property (nonatomic, strong) UIPopoverController *activityPopoverController;
#pragma clang diagnostic pop

@end

@implementation TOCropViewController

- (instancetype)initWithCroppingStyle:(TOCropViewCroppingStyle)style image:(UIImage *)image
{
    NSParameterAssert(image);

    self = [super init];
    if (self) {
        // Init parameters
        _image = image;
        _croppingStyle = style;
        
        // Set up base view controller behaviour
        self.automaticallyAdjustsScrollViewInsets = NO;
        
        // Controller object that handles the transition animation when presenting / dismissing this app
        _transitionController = [[TOCropViewControllerTransitioning alloc] init];

        // Default initial behaviour
        _aspectRatioPreset = TOCropViewControllerAspectRatioPresetOriginal;
        _toolbarPosition = TOCropViewControllerToolbarPositionBottom;
    }
	
    return self;
}

- (instancetype)initWithImage:(UIImage *)image
{
    return [self initWithCroppingStyle:TOCropViewCroppingStyleDefault image:image];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set up view controller properties
    self.transitioningDelegate = self;
    self.view.backgroundColor = self.cropView.backgroundColor;

    // Layout the views initially
    self.cropView.frame = [self frameForCropViewWithVerticalLayout:self.verticalLayout];
    self.toolbar.frame = [self frameForToolbarWithVerticalLayout:self.verticalLayout];
    self.buttonAdjustThumbnail.frame = [self frameForButtonAdjustThumbnail];

    // Set up the toolbar button actions
    __weak typeof(self) weakSelf = self;
    self.toolbar.originalButtonTapped = ^{ [weakSelf setAspectRatioPreset:TOCropViewControllerAspectRatioPresetOriginal animated:YES]; };
    self.toolbar.squareButtonTapped = ^{ [weakSelf setAspectRatioPreset:TOCropViewControllerAspectRatioPresetSquare animated:YES]; };
    self.toolbar.horizontalButtonTapped = ^{ [weakSelf setAspectRatioPreset:TOCropViewControllerAspectRatioPreset6x5 animated:YES]; };
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    UIColor *pinkColor = [UIColor colorWithRed:255. / 255. green:68. / 255. blue:119. / 255. alpha:1];

    [self setNeedsStatusBarAppearanceUpdate];

    // Transparent navigation bar
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    [self.navigationController.navigationBar setShadowImage:[UIImage new]];
    [self.navigationController.navigationBar setTranslucent:YES];
    [self.navigationController.navigationBar setTintColor:pinkColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [UIColor whiteColor]
    }];

    if (self.aspectRatioLockEnabled) {
        [self.toolbar removeFromSuperview];
        [self.cropView setCropBoxResizeEnabled:NO];
        [self.cropView setGridOverlayHidden:YES];
    } else {
        [self.cropView setCropBoxResizeEnabled:YES];
    }

    // Navigation Buttons
    if (self.navigationController.viewControllers.count == 1) {
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", "")
                                                                         style:UIBarButtonItemStylePlain
                                                                        target:self
                                                                        action:@selector(cancelButtonTapped)];

        [cancelButton setTintColor:pinkColor];
        self.navigationItem.leftBarButtonItem = cancelButton;
    }

    UIBarButtonItem *buttonNext = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", "") style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonTapped)];
    [buttonNext setTintColor:pinkColor];
    self.navigationItem.rightBarButtonItem = buttonNext;

    // If an initial aspect ratio was set before presentation, set it now once the rest of
    // the setup will have been done
    if (self.aspectRatioPreset != TOCropViewControllerAspectRatioPresetOriginal) {
        [self setAspectRatioPreset:self.aspectRatioPreset animated:NO];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Disable the transition flag for the status bar
    self.inTransition = NO;
    
    // Re-enable translucency now that the animation has completed
    self.cropView.simpleRenderMode = NO;

    // Now that the presentation animation will have finished, animate
    // the status bar fading out, and if present, the title label fading in
    void (^updateContentBlock)(void) = ^{
        [self setNeedsStatusBarAppearanceUpdate];
    };

    if (animated) {
        [UIView animateWithDuration:0.3f animations:updateContentBlock];
    }
    else {
        updateContentBlock();
    }
    
    // Make the grid overlay view fade in
    if (self.cropView.gridOverlayHidden) {
        [self.cropView setGridOverlayHidden:NO animated:animated];
    }
    
    // Fade in the background view content
    if (self.navigationController == nil) {
        [self.cropView setBackgroundImageViewHidden:NO animated:animated];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Set the transition flag again so we can defer the status bar
    self.inTransition = YES;
    [UIView animateWithDuration:0.5f animations:^{
        [self setNeedsStatusBarAppearanceUpdate];
    }];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Reset the state once the view has gone offscreen
    self.inTransition = NO;
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark - Status Bar -

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden
{
    // Disregard the transition animation if we're not actively overriding it
    if (!self.overrideStatusBar) {
        return self.statusBarHidden;
    }

    // Work out whether the status bar needs to be visible
    // during a transition animation or not
    BOOL hidden = YES; // Default is yes
    hidden = hidden && !(self.inTransition); // Not currently in a presentation animation (Where removing the status bar would break the layout)
    hidden = hidden && !(self.view.superview == nil); // Not currently waiting to be added to a super view
    return hidden;
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures
{
    return UIRectEdgeAll;
}

- (CGRect)frameForToolbarWithVerticalLayout:(BOOL)verticalLayout
{
    UIEdgeInsets insets = self.statusBarSafeInsets;

    CGRect frame = CGRectZero;
    if (!verticalLayout) { // In landscape laying out toolbar to the left
        frame.origin.x = insets.left;
        frame.origin.y = 0.0f;
        frame.size.width = kTOCropViewControllerToolbarHeight;
        frame.size.height = CGRectGetHeight(self.view.frame);
    } else {
        frame.origin.x = 0.0f;
        frame.size.width = CGRectGetWidth(self.view.bounds);
        frame.size.height = kTOCropViewControllerToolbarHeight;

        if (self.toolbarPosition == TOCropViewControllerToolbarPositionBottom) {
            frame.origin.y = CGRectGetHeight(self.view.bounds) - (frame.size.height + insets.bottom);
        } else {
            frame.origin.y = insets.top;
        }

        if (self.showAdjustThumbnailOption) {
            frame.origin.y -= kTOCropViewControllerToolbarHeight;
        }
    }
    
    return frame;
}

- (CGRect)frameForButtonAdjustThumbnail
{
    UIEdgeInsets insets = self.statusBarSafeInsets;

    CGRect frame = CGRectZero;
    frame.origin.x = 0.0f;
    frame.size.height = kTOCropViewControllerToolbarHeight;
    frame.origin.y = CGRectGetHeight(self.view.bounds) - (frame.size.height + insets.bottom);
    frame.size.width = CGRectGetWidth(self.view.bounds);
    return frame;
}

- (CGRect)frameForCropViewWithVerticalLayout:(BOOL)verticalLayout
{
    //On an iPad, if being presented in a modal view controller by a UINavigationController,
    //at the time we need it, the size of our view will be incorrect.
    //If this is the case, derive our view size from our parent view controller instead
    UIView *view = nil;
    if (self.parentViewController == nil) {
        view = self.view;
    }
    else {
        view = self.parentViewController.view;
    }

    UIEdgeInsets insets = self.statusBarSafeInsets;

    CGRect bounds = view.bounds;
    CGRect frame = CGRectZero;

    // Horizontal layout (eg landscape)
    if (!verticalLayout) {
        frame.origin.x = kTOCropViewControllerToolbarHeight + insets.left;
        frame.size.width = CGRectGetWidth(bounds) - frame.origin.x;
		frame.size.height = CGRectGetHeight(bounds);
    }
    else { // Vertical layout
        frame.size.height = CGRectGetHeight(bounds);
        frame.size.width = CGRectGetWidth(bounds);

        // Set Y and adjust for height
        if (self.toolbarPosition == TOCropViewControllerToolbarPositionBottom) {
            frame.size.height -= (insets.bottom + kTOCropViewControllerToolbarHeight);
        } else {
			frame.origin.y = kTOCropViewControllerToolbarHeight + insets.top;
            frame.size.height -= frame.origin.y;
        }

        if (self.showAdjustThumbnailOption) {
            frame.size.height -= (insets.bottom + kTOCropViewControllerToolbarHeight);
        }
    }
    
    return frame;
}

- (void)adjustCropViewInsets
{
    UIEdgeInsets insets = self.statusBarSafeInsets;
    self.cropView.cropRegionInsets = UIEdgeInsetsMake(60.f, 0.0f, insets.bottom, 0.0f);
}

- (void)adjustToolbarInsets
{
    UIEdgeInsets insets = UIEdgeInsetsZero;

    if (@available(iOS 11.0, *)) {
        // Add padding to the left in landscape mode
        if (!self.verticalLayout) {
            insets.left = self.view.safeAreaInsets.left;
        }
        else {
            // Add padding on top if in vertical and tool bar is at the top
            if (self.toolbarPosition == TOCropViewControllerToolbarPositionTop) {
                insets.top = self.view.safeAreaInsets.top;
            }
            else { // Add padding to the bottom otherwise
                insets.bottom = self.view.safeAreaInsets.bottom;
            }
        }
    }
    else { // iOS <= 10
        if (!self.statusBarHidden && self.toolbarPosition == TOCropViewControllerToolbarPositionTop) {
            insets.top = self.statusBarHeight;
        }
    }

    // Update the toolbar with these properties
    self.toolbar.backgroundViewOutsets = insets;
    self.toolbar.statusBarHeightInset = self.statusBarHeight;
    [self.toolbar setNeedsLayout];
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self adjustCropViewInsets];
    [self adjustToolbarInsets];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.cropView.frame = [self frameForCropViewWithVerticalLayout:self.verticalLayout];
    [self adjustCropViewInsets];
    [self.cropView moveCroppedContentToCenterAnimated:NO];

    if (self.firstTime == NO) {
        [self.cropView performInitialSetup];
        self.firstTime = YES;
    }

    [UIView performWithoutAnimation:^{
        self.toolbar.frame = [self frameForToolbarWithVerticalLayout:self.verticalLayout];
        self.buttonAdjustThumbnail.frame = [self frameForButtonAdjustThumbnail];
        [self adjustToolbarInsets];
        [self.toolbar setNeedsLayout];
    }];

    [self.view bringSubviewToFront:self.toolbar];
    [self.view bringSubviewToFront:self.buttonAdjustThumbnail];
}

- (void)setAspectRatioPreset:(TOCropViewControllerAspectRatioPreset)aspectRatioPreset animated:(BOOL)animated
{
    CGSize aspectRatio = CGSizeZero;
    
    _aspectRatioPreset = aspectRatioPreset;
    
    switch (aspectRatioPreset) {
        case TOCropViewControllerAspectRatioPresetOriginal:
            aspectRatio = CGSizeZero;
            break;
        case TOCropViewControllerAspectRatioPresetSquare:
            aspectRatio = CGSizeMake(1.0f, 1.0f);
            break;
        case TOCropViewControllerAspectRatioPreset6x5:
            aspectRatio = CGSizeMake(6.0f, 5.0f);
            break;
        case TOCropViewControllerAspectRatioPresetCustom:
            aspectRatio = self.customAspectRatio;
            break;
    }

    [self.cropView setAspectRatio:aspectRatio animated:animated];
}

- (void)rotateCropViewClockwise
{
    [self.cropView rotateImageNinetyDegreesAnimated:YES clockwise:YES];
}

- (void)rotateCropViewCounterclockwise
{
    [self.cropView rotateImageNinetyDegreesAnimated:YES clockwise:NO];
}

#pragma mark - Presentation Handling -
- (void)presentAnimatedFromParentViewController:(UIViewController *)viewController
                                       fromView:(UIView *)fromView
                                      fromFrame:(CGRect)fromFrame
                                          setup:(void (^)(void))setup
                                     completion:(void (^)(void))completion
{
    [self presentAnimatedFromParentViewController:viewController fromImage:nil fromView:fromView fromFrame:fromFrame
                                            angle:0 toImageFrame:CGRectZero setup:setup completion:nil];
}

- (void)presentAnimatedFromParentViewController:(UIViewController *)viewController
                                      fromImage:(UIImage *)image
                                       fromView:(UIView *)fromView
                                      fromFrame:(CGRect)fromFrame
                                          angle:(NSInteger)angle
                                   toImageFrame:(CGRect)toFrame
                                          setup:(void (^)(void))setup
                                     completion:(void (^)(void))completion
{
    self.transitionController.image     = image ? image : self.image;
    self.transitionController.fromFrame = fromFrame;
    self.transitionController.fromView  = fromView;
    self.prepareForTransitionHandler    = setup;
    
    if (self.angle != 0 || !CGRectIsEmpty(toFrame)) {
        self.angle = angle;
        self.imageCropFrame = toFrame;
    }
    
    __weak typeof (self) weakSelf = self;
    [viewController presentViewController:self.parentViewController ? self.parentViewController : self
                                 animated:YES
                               completion:^
    {
        typeof (self) strongSelf = weakSelf;
        if (completion) {
            completion();
        }
        
        [strongSelf.cropView setCroppingViewsHidden:NO animated:YES];
        if (!CGRectIsEmpty(fromFrame)) {
            [strongSelf.cropView setGridOverlayHidden:NO animated:YES];
        }
    }];
}

- (void)dismissAnimatedFromParentViewController:(UIViewController *)viewController
                                         toView:(UIView *)toView
                                        toFrame:(CGRect)frame
                                          setup:(void (^)(void))setup
                                     completion:(void (^)(void))completion
{
    [self dismissAnimatedFromParentViewController:viewController withCroppedImage:nil toView:toView toFrame:frame setup:setup completion:completion];
}

- (void)dismissAnimatedFromParentViewController:(UIViewController *)viewController
                               withCroppedImage:(UIImage *)image
                                         toView:(UIView *)toView
                                        toFrame:(CGRect)frame
                                          setup:(void (^)(void))setup
                                     completion:(void (^)(void))completion
{
    // If a cropped image was supplied, use that, and only zoom out from the crop box
    if (image) {
        self.transitionController.image     = image ? image : self.image;
        self.transitionController.fromFrame = [self.cropView convertRect:self.cropView.cropBoxFrame toView:self.view];
    }
    else { // else use the main image, and zoom out from its entirety
        self.transitionController.image     = self.image;
        self.transitionController.fromFrame = [self.cropView convertRect:self.cropView.imageViewFrame toView:self.view];
    }
    
    self.transitionController.toView    = toView;
    self.transitionController.toFrame   = frame;
    self.prepareForTransitionHandler    = setup;

    [viewController dismissViewControllerAnimated:YES completion:^ {
        if (completion) { completion(); }
    }];
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    if (self.navigationController || self.modalTransitionStyle == UIModalTransitionStyleCoverVertical) {
        return nil;
    }
    
    self.cropView.simpleRenderMode = YES;
    
    __weak typeof (self) weakSelf = self;
    self.transitionController.prepareForTransitionHandler = ^{
        typeof (self) strongSelf = weakSelf;
        TOCropViewControllerTransitioning *transitioning = strongSelf.transitionController;

        transitioning.toFrame = [strongSelf.cropView convertRect:strongSelf.cropView.cropBoxFrame toView:strongSelf.view];
        if (!CGRectIsEmpty(transitioning.fromFrame) || transitioning.fromView) {
            strongSelf.cropView.croppingViewsHidden = YES;
        }

        if (strongSelf.prepareForTransitionHandler) {
            strongSelf.prepareForTransitionHandler();
        }
        
        strongSelf.prepareForTransitionHandler = nil;
    };
    
    self.transitionController.isDismissing = NO;
    return self.transitionController;
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    if (self.navigationController || self.modalTransitionStyle == UIModalTransitionStyleCoverVertical) {
        return nil;
    }
    
    __weak typeof (self) weakSelf = self;
    self.transitionController.prepareForTransitionHandler = ^{
        typeof (self) strongSelf = weakSelf;
        TOCropViewControllerTransitioning *transitioning = strongSelf.transitionController;
        
        if (!CGRectIsEmpty(transitioning.toFrame) || transitioning.toView) {
            strongSelf.cropView.croppingViewsHidden = YES;
        }
        else {
            strongSelf.cropView.simpleRenderMode = YES;
        }
        
        if (strongSelf.prepareForTransitionHandler) {
            strongSelf.prepareForTransitionHandler();
        }
    };
    
    self.transitionController.isDismissing = YES;
    return self.transitionController;
}

#pragma mark - Button Feedback -

- (void)buttonCloseDidPressed
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)cancelButtonTapped
{
    bool isDelegateOrCallbackHandled = NO;

    // Check if the delegate method was implemented and call if so
    if ([self.delegate respondsToSelector:@selector(cropViewController:didFinishCancelled:)]) {
        [self.delegate cropViewController:self didFinishCancelled:YES];
        isDelegateOrCallbackHandled = YES;
    }

    // Check if the block version was implemented and call if so
    if (self.onDidFinishCancelled != nil) {
        self.onDidFinishCancelled(YES);
        isDelegateOrCallbackHandled = YES;
    }

    // If neither callbacks were implemented, perform a default dismissing animation
    if (!isDelegateOrCallbackHandled) {
        if (self.navigationController) {
            [self.navigationController popViewControllerAnimated:YES];
        }
        else {
            self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
            [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

- (void)doneButtonTapped
{
    [self done:NO];
}

- (void)done:(BOOL)shouldAdjustThumbnailAfter
{
    CGRect cropFrame = self.cropView.imageCropFrame;
    NSInteger angle = self.cropView.angle;

    //If desired, when the user taps done, show an activity sheet
    if (self.showActivitySheetOnDone) {
        TOActivityCroppedImageProvider *imageItem = [[TOActivityCroppedImageProvider alloc] initWithImage:self.image cropFrame:cropFrame angle:angle circular:(self.croppingStyle == TOCropViewCroppingStyleCircular)];
        TOCroppedImageAttributes *attributes = [[TOCroppedImageAttributes alloc] initWithCroppedFrame:cropFrame angle:angle originalImageSize:self.image.size];

        NSMutableArray *activityItems = [@[imageItem, attributes] mutableCopy];
        if (self.activityItems) {
            [activityItems addObjectsFromArray:self.activityItems];
        }

        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:self.applicationActivities];
        activityController.excludedActivityTypes = self.excludedActivityTypes;

        if (NSClassFromString(@"UIPopoverPresentationController")) {
            activityController.modalPresentationStyle = UIModalPresentationPopover;
            activityController.popoverPresentationController.sourceView = self.toolbar;
            activityController.popoverPresentationController.sourceRect = self.toolbar.frame;
            [self presentViewController:activityController animated:YES completion:nil];
        }
        else {
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                [self presentViewController:activityController animated:YES completion:nil];
            }
            else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                [self.activityPopoverController dismissPopoverAnimated:NO];
                self.activityPopoverController = [[UIPopoverController alloc] initWithContentViewController:activityController];
                [self.activityPopoverController presentPopoverFromRect:self.toolbar.frame inView:self.toolbar permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
#pragma clang diagnostic pop
            }
        }
        __weak typeof(activityController) blockController = activityController;
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
        activityController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
            if (!completed) {
                return;
            }

            bool isCallbackOrDelegateHandled = NO;

            if (self.onDidFinishCancelled != nil) {
                self.onDidFinishCancelled(NO);
                isCallbackOrDelegateHandled = YES;
            }
            if ([self.delegate respondsToSelector:@selector(cropViewController:didFinishCancelled:)]) {
                [self.delegate cropViewController:self didFinishCancelled:NO];
                isCallbackOrDelegateHandled = YES;
            }

            if (!isCallbackOrDelegateHandled) {
                [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
                blockController.completionWithItemsHandler = nil;
            }
        };
#else
        activityController.completionHandler = ^(NSString *activityType, BOOL completed) {
            if (!completed) {
                return;
            }

            BOOL isCallbackOrDelegateHandled = NO;

            if (self.onDidFinishCancelled != nil) {
                self.onDidFinishCancelled(NO);
                isCallbackOrDelegateHandled = YES;
            }

            if ([self.delegate respondsToSelector:@selector(cropViewController:didFinishCancelled:)]) {
                [self.delegate cropViewController:self didFinishCancelled:NO];
                isCallbackOrDelegateHandled = YES;
            }

            if (!isCallbackOrDelegateHandled) {
                [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
                blockController.completionHandler = nil;
            }
        };
#endif

        return;
    }

    BOOL isCallbackOrDelegateHandled = NO;

    //If the delegate/block that only supplies crop data is provided, call it
    if ([self.delegate respondsToSelector:@selector(cropViewController:didCropImageToRect:angle:)]) {
        [self.delegate cropViewController:self didCropImageToRect:cropFrame angle:angle];
        isCallbackOrDelegateHandled = YES;
    }

    if (self.onDidCropImageToRect != nil) {
        self.onDidCropImageToRect(cropFrame, angle);
        isCallbackOrDelegateHandled = YES;
    }

    // Check if the circular APIs were implemented
    BOOL isCircularImageDelegateAvailable = [self.delegate respondsToSelector:@selector(cropViewController:didCropToCircularImage:withRect:angle:)];
    BOOL isCircularImageCallbackAvailable = self.onDidCropToCircleImage != nil;

    // Check if non-circular was implemented
    BOOL isDidCropToImageDelegateAvailable = [self.delegate respondsToSelector:@selector(cropViewController:didCropToImage:withRect:angle:)];
    BOOL isDidCropToImageCallbackAvailable = self.onDidCropToRect != nil;

    //If cropping circular and the circular generation delegate/block is implemented, call it
    if (self.croppingStyle == TOCropViewCroppingStyleCircular && (isCircularImageDelegateAvailable || isCircularImageCallbackAvailable)) {
        UIImage *image = [self.image croppedImageWithFrame:cropFrame angle:angle circularClip:YES scale:1];

        //Dispatch on the next run-loop so the animation isn't interuppted by the crop operation
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (isCircularImageDelegateAvailable) {
                [self.delegate cropViewController:self didCropToCircularImage:image withRect:cropFrame angle:angle];
            }
            if (isCircularImageCallbackAvailable) {
                self.onDidCropToCircleImage(image, cropFrame, angle);
            }
        });

        isCallbackOrDelegateHandled = YES;
    }
    //If the delegate/block that requires the specific cropped image is provided, call it
    else if (isDidCropToImageDelegateAvailable || isDidCropToImageCallbackAvailable) {
        UIImage *image = nil;
        if (angle == 0 && CGRectEqualToRect(cropFrame, (CGRect){CGPointZero, self.image.size})) {
            image = self.image;
        }
        else {
            image = [self.image croppedImageWithFrame:cropFrame angle:angle circularClip:NO scale:1];
        }

        //Dispatch on the next run-loop so the animation isn't interuppted by the crop operation
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (isDidCropToImageDelegateAvailable) {
                [self.delegate cropViewController:self didCropToImage:image withRect:cropFrame angle:angle];
            }

            if (isDidCropToImageCallbackAvailable) {
                self.onDidCropToRect(image, cropFrame, angle, shouldAdjustThumbnailAfter);
            }
        });

        isCallbackOrDelegateHandled = YES;
    }

    if (!isCallbackOrDelegateHandled) {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (TOCropView *)cropView
{
    // Lazily create the crop view in case we try and access it before presentation, but
    // don't add it until our parent view controller view has loaded at the right time
    if (!_cropView) {
        _cropView = [[TOCropView alloc] initWithCroppingStyle:self.croppingStyle image:self.image];
        _cropView.delegate = self;
        _cropView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        if (self.aspectRatioLockEnabled) {
            _cropView.gridOverlayView.gridHidden = YES;
        }

        [self.view addSubview:_cropView];
    }

    return _cropView;
}

- (TOCropToolbar *)toolbar
{
    if (!_toolbar) {
        _toolbar = [[TOCropToolbar alloc] initWithFrame:CGRectZero];

        if (!self.aspectRatioLockEnabled) {
            [self.view addSubview:_toolbar];
        }
    }

    return _toolbar;
}

- (UIButton *)buttonAdjustThumbnail
{
    if (!self.showAdjustThumbnailOption) {
        return nil;
    }

    if (!_buttonAdjustThumbnail) {
        _buttonAdjustThumbnail = [[UIButton alloc] initWithFrame:CGRectZero];
        [_buttonAdjustThumbnail setTitle:@"Adjust Thumbnail" forState:UIControlStateNormal];
        [_buttonAdjustThumbnail setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_buttonAdjustThumbnail.titleLabel setFont:[UIFont boldSystemFontOfSize:15.]];
        [_buttonAdjustThumbnail.titleLabel setTextAlignment:NSTextAlignmentCenter];

        [_buttonAdjustThumbnail addTarget:self
                                   action:@selector(buttonAdjustThumbnailDidPressed:)
                         forControlEvents:UIControlEventTouchUpInside];

        if (!self.aspectRatioLockEnabled) {
            [self.view addSubview:_buttonAdjustThumbnail];
        }
    }

    return _buttonAdjustThumbnail;
}

- (void)setAspectRatioLockEnabled:(BOOL)aspectRatioLockEnabled
{
    self.cropView.aspectRatioLockEnabled = aspectRatioLockEnabled;
    if (!self.aspectRatioPickerButtonHidden) {
        self.aspectRatioPickerButtonHidden = (aspectRatioLockEnabled && self.resetAspectRatioEnabled == NO);
    }
}

- (void)setAspectRatioLockDimensionSwapEnabled:(BOOL)aspectRatioLockDimensionSwapEnabled
{
    self.cropView.aspectRatioLockDimensionSwapEnabled = aspectRatioLockDimensionSwapEnabled;
}

- (BOOL)aspectRatioLockEnabled
{
    return self.cropView.aspectRatioLockEnabled;
}

- (void)setResetAspectRatioEnabled:(BOOL)resetAspectRatioEnabled
{
    self.cropView.resetAspectRatioEnabled = resetAspectRatioEnabled;
    if (!self.aspectRatioPickerButtonHidden) {
        self.aspectRatioPickerButtonHidden = (resetAspectRatioEnabled == NO && self.aspectRatioLockEnabled);
    }
}

- (void)setCustomAspectRatio:(CGSize)customAspectRatio
{
    _customAspectRatio = customAspectRatio;
    [self setAspectRatioPreset:TOCropViewControllerAspectRatioPresetCustom animated:NO];
}

- (BOOL)resetAspectRatioEnabled
{
    return self.cropView.resetAspectRatioEnabled;
}

- (void)setAngle:(NSInteger)angle
{
    self.cropView.angle = angle;
}

- (NSInteger)angle
{
    return self.cropView.angle;
}

- (void)setImageCropFrame:(CGRect)imageCropFrame
{
    self.cropView.imageCropFrame = imageCropFrame;
}

- (CGRect)imageCropFrame
{
    return self.cropView.imageCropFrame;
}

- (BOOL)verticalLayout
{
    return CGRectGetWidth(self.view.bounds) < CGRectGetHeight(self.view.bounds);
}

- (BOOL)statusBarHidden
{
    return NO;
}

- (CGFloat)statusBarHeight
{
    if (self.statusBarHidden) {
        return 0.0f;
    }

    CGFloat statusBarHeight = 0.0f;
    if (@available(iOS 11.0, *)) {
        statusBarHeight = self.view.safeAreaInsets.top;
    }
    else {
        statusBarHeight = self.topLayoutGuide.length;
    }
    
    return statusBarHeight;
}

- (UIEdgeInsets)statusBarSafeInsets
{
    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        insets = self.view.safeAreaInsets;

        // Since iPhone X insets are always 44, check if this is merely
        // accounting for a non-X status bar and cancel it
        if (insets.top <= 20.0f + FLT_EPSILON) {
            insets.top = self.statusBarHeight;
        }
    }
    else {
        insets.top = self.statusBarHeight;
    }

    return insets;
}

- (void)setMinimumAspectRatio:(CGFloat)minimumAspectRatio
{
    self.cropView.minimumAspectRatio = minimumAspectRatio;
}

- (CGFloat)minimumAspectRatio
{
    return self.cropView.minimumAspectRatio;
}

- (void)buttonAdjustThumbnailDidPressed:(id)sender
{
    [self done:YES];
}

@end
