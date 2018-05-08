//
//  TOCropToolbar.h
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

#import "TOCropToolbar.h"

#define TOCROPTOOLBAR_DEBUG_SHOWING_BUTTONS_CONTAINER_RECT     0   // convenience debug toggle

@interface TOCropToolbar()

@property (nonatomic, strong) UIView *backgroundView;

@property (nonatomic, strong, readwrite) UIButton *originalButton;
@property (nonatomic, strong, readwrite) UIButton *squareButton;
@property (nonatomic, strong, readwrite) UIButton *horizontalButton;

@property (nonatomic, assign) BOOL reverseContentLayout; // For languages like Arabic where they natively present content flipped from English

@end

@implementation TOCropToolbar

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    
    return self;
}

- (void)setup {
    self.backgroundView = [[UIView alloc] initWithFrame:self.bounds];
    self.backgroundView.backgroundColor = [UIColor colorWithWhite:0.12f alpha:1.0f];
    [self addSubview:self.backgroundView];
    
    // On iOS 9, we can use the new layout features to determine whether we're in an 'Arabic' style language mode
    if (@available(iOS 9.0, *)) {
        self.reverseContentLayout = ([UIView userInterfaceLayoutDirectionForSemanticContentAttribute:self.semanticContentAttribute] == UIUserInterfaceLayoutDirectionRightToLeft);
    } else {
        self.reverseContentLayout = [[[NSLocale preferredLanguages] objectAtIndex:0] hasPrefix:@"ar"];
    }
    
    // In CocoaPods, strings are stored in a separate bundle from the main one
    NSBundle *resourceBundle = nil;
    NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
    NSURL *resourceBundleURL = [classBundle URLForResource:@"TOCropViewControllerBundle" withExtension:@"bundle"];
    if (resourceBundleURL) {
        resourceBundle = [[NSBundle alloc] initWithURL:resourceBundleURL];
    } else {
        resourceBundle = classBundle;
    }

    _originalButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_originalButton setTitle:@"ORIGINAL" forState:UIControlStateNormal];
    [_originalButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_originalButton.titleLabel setFont:[UIFont boldSystemFontOfSize:15.]];
    [_originalButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [_originalButton addTarget:self action:@selector(buttonOriginalDidPressed:) forControlEvents:UIControlEventTouchUpInside];
    [_originalButton sizeToFit];
    [self addSubview:_originalButton];

    _squareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_squareButton setTitle:@"SQUARE" forState:UIControlStateNormal];
    [_squareButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_squareButton.titleLabel setFont:[UIFont boldSystemFontOfSize:15.]];
    [_squareButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [_squareButton addTarget:self action:@selector(buttonSquarelDidPressed:) forControlEvents:UIControlEventTouchUpInside];
    [_squareButton sizeToFit];
    [self addSubview:_squareButton];

    _horizontalButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_horizontalButton setTitle:@"6:5" forState:UIControlStateNormal];
    [_horizontalButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_horizontalButton.titleLabel setFont:[UIFont boldSystemFontOfSize:15.]];
    [_horizontalButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [_horizontalButton addTarget:self action:@selector(buttonHorizontalDidPressed:) forControlEvents:UIControlEventTouchUpInside];
    [_horizontalButton sizeToFit];
    [self addSubview:_horizontalButton];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect frame = self.bounds;
    frame.origin.x -= self.backgroundViewOutsets.left;
    frame.size.width += self.backgroundViewOutsets.left;
    frame.size.width += self.backgroundViewOutsets.right;
    frame.origin.y -= self.backgroundViewOutsets.top;
    frame.size.height += self.backgroundViewOutsets.top;
    frame.size.height += self.backgroundViewOutsets.bottom;
    self.backgroundView.frame = frame;
    
    #if TOCROPTOOLBAR_DEBUG_SHOWING_BUTTONS_CONTAINER_RECT
    static UIView *containerView = nil;
    if (!containerView) {
        containerView = [[UIView alloc] initWithFrame:CGRectZero];
        containerView.backgroundColor = [UIColor redColor];
        containerView.alpha = 0.1;
        [self addSubview:containerView];
    }
    #endif

    CGSize boundsSize = self.bounds.size;
    CGFloat fullWidth = boundsSize.width;
    CGFloat buttonWidth = (fullWidth - 16.) / 3.;
    CGFloat buttonHeight = 44.;

    _originalButton.frame = CGRectMake(8., 0., buttonWidth, buttonHeight);
    _squareButton.frame = CGRectMake(buttonWidth + 8., 0., buttonWidth, buttonHeight);
    _horizontalButton.frame = CGRectMake(buttonWidth + buttonWidth + 8., 0., buttonWidth, buttonHeight);
}

// The convenience method for calculating button's frame inside of the container rect
- (void)layoutToolbarButtons:(NSArray *)buttons withSameButtonSize:(CGSize)size inContainerRect:(CGRect)containerRect horizontally:(BOOL)horizontally
{
    NSInteger count = buttons.count;
    CGFloat fixedSize = horizontally ? size.width : size.height;
    CGFloat maxLength = horizontally ? CGRectGetWidth(containerRect) : CGRectGetHeight(containerRect);
    CGFloat padding = (maxLength - fixedSize * count) / (count + 1);
    
    for (NSInteger i = 0; i < count; i++) {
        UIView *button = buttons[i];
        CGFloat sameOffset = horizontally ? fabs(CGRectGetHeight(containerRect)-CGRectGetHeight(button.bounds)) : fabs(CGRectGetWidth(containerRect)-CGRectGetWidth(button.bounds));
        CGFloat diffOffset = padding + i * (fixedSize + padding);
        CGPoint origin = horizontally ? CGPointMake(diffOffset, sameOffset) : CGPointMake(sameOffset, diffOffset);
        if (horizontally) {
            origin.x += CGRectGetMinX(containerRect);
        } else {
            origin.y += CGRectGetMinY(containerRect);
        }
        button.frame = (CGRect){origin, size};
    }
}

- (void)buttonOriginalDidPressed:(id)sender
{
    if (self.originalButtonTapped) {
        self.originalButtonTapped();
    }
}

- (void)buttonSquarelDidPressed:(id)sender
{
    if (self.squareButtonTapped) {
        self.squareButtonTapped();
    }
}

- (void)buttonHorizontalDidPressed:(id)sender
{
    if (self.horizontalButtonTapped) {
        self.horizontalButtonTapped();
    }
}

#pragma mark - Accessors -

- (void)setStatusBarHeightInset:(CGFloat)statusBarHeightInset
{
    _statusBarHeightInset = statusBarHeightInset;
    [self setNeedsLayout];
}

@end
