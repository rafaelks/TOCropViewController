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

#import <UIKit/UIKit.h>

@interface TOCropToolbar : UIView

/* In horizontal mode, offsets all of the buttons vertically by height of status bar. */
@property (nonatomic, assign) CGFloat statusBarHeightInset;

/* Set an inset that will expand the background view beyond the bounds. */
@property (nonatomic, assign) UIEdgeInsets backgroundViewOutsets;

/* Cutting style buttons. */
@property (nonnull, nonatomic, strong, readonly) UIButton *originalButton;
@property (nonnull, nonatomic, strong, readonly) UIButton *squareButton;
@property (nonnull, nonatomic, strong, readonly) UIButton *horizontalButton;

/* Button feedback handler blocks */
@property (nullable, nonatomic, copy) void (^originalButtonTapped)(void);
@property (nullable, nonatomic, copy) void (^squareButtonTapped)(void);
@property (nullable, nonatomic, copy) void (^horizontalButtonTapped)(void);

@end
