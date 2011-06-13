//
//  KGPagedDocThumbnailControlImplementation.m
//  Pugpig
//
//  Copyright (c) 2011, Kaldor Holdings Ltd.
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are
//  permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this list of
//  conditions and the following disclaimer. Redistributions in binary form must reproduce
//  the above copyright notice, this list of conditions and the following disclaimer in
//  the documentation and/or other materials provided with the distribution.
//  Neither the name of pugpig nor the names of its contributors may be
//  used to endorse or promote products derived from this software without specific prior
//  written permission.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
//  SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
//  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
//  BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
//  IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//  SUCH DAMAGE.
//

#import "KGPagedDocThumbnailControlImplementation.h"
#import "KGPagedDocThumbnailContentView.h"
#import "KGInMemoryImageStore.h"

//==============================================================================
// MARK: - Private interface

@interface KGPagedDocThumbnailControlImplementation()

@property (nonatomic, retain) UIScrollView *scrollView;
@property (nonatomic, retain) KGPagedDocThumbnailContentView *contentView;

- (void)initControl;
- (void)redrawContent;
- (void)redrawContentIfNeeded;
- (void)repositionContent;
- (void)selectPage:(UIGestureRecognizer*)gesture;
- (void)preloadImagesForPageNumber:(NSUInteger)page;
- (void)preloadImageForPageNumber:(NSInteger)page;

@end

//==============================================================================
// MARK: - Main implementation

@implementation KGPagedDocThumbnailControlImplementation

@dynamic active;
@synthesize numberOfPages;
@synthesize pageNumber;
@synthesize fractionalPageNumber;
@synthesize pageOrientation;
@synthesize dataSource;

@synthesize portraitSize, landscapeSize;
@synthesize pageSeparation;
@synthesize imageStore;
@synthesize portraitPlaceholderImage;
@synthesize landscapePlaceholderImage;

@synthesize pageSize;
@synthesize placeholderImage;
@dynamic horizontalPadding;

@synthesize scrollView;
@synthesize contentView;

//------------------------------------------------------------------------------
// MARK: NSObject/UIView messages

- (id)initWithFrame:(CGRect)aRect {
  self = [super initWithFrame:aRect];
  if (self) {
    [self initControl];
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self initControl];
  }
  return self;
}

- (void)dealloc {
  [imageStore release];
  [portraitPlaceholderImage release];
  [landscapePlaceholderImage release];
  [scrollView release];
  [contentView release];
  [super dealloc];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  if (!CGSizeEqualToSize(lastLayoutSize, self.bounds.size)) {
    lastLayoutSize = self.bounds.size;
    [self redrawContent];
  }
}

//------------------------------------------------------------------------------
// MARK: Public properties

- (BOOL)isActive {
  return self.alpha > 0.0;
}

- (void)setActive:(BOOL)active {
  BOOL newAlpha;
  CGRect oldFrame, newFrame;
  CGSize size = self.bounds.size;
  CGSize parentSize = self.superview.bounds.size;
  
  if (active) {   
    newAlpha = 1.0;
    oldFrame = CGRectMake(0, parentSize.height, size.width, size.height);
    newFrame = CGRectOffset(oldFrame, 0.0, -size.height);    
  }
  else {
    newAlpha = 0.0;
    oldFrame = CGRectMake(0, parentSize.height - size.height, size.width, size.height);
    newFrame = CGRectOffset(oldFrame, 0.0, size.height);    
  }
  
  [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
  
  self.frame = oldFrame;
  [UIView beginAnimations:nil context:NULL];
  [UIView setAnimationDuration:0.5];
  self.alpha = newAlpha;
  self.frame = newFrame;
  [UIView commitAnimations];    
  
  [[UIApplication sharedApplication] endIgnoringInteractionEvents];
}

- (void)setNumberOfPages:(NSUInteger)newNumberOfPages {
  if (newNumberOfPages != numberOfPages) {
    numberOfPages = newNumberOfPages;
    pageNumber = 0;
    fractionalPageNumber = 0;
    [self repositionContent];
  }
}

- (void)setPageNumber:(NSUInteger)newPageNumber {
  [self preloadImagesForPageNumber:newPageNumber];
  pageNumber = newPageNumber;
  self.fractionalPageNumber = pageNumber;
}

- (void)setFractionalPageNumber:(CGFloat)newFractionalPageNumber {
  if (newFractionalPageNumber != fractionalPageNumber) {
    fractionalPageNumber = newFractionalPageNumber;
    [self repositionContent];
  }
}

- (void)setPageOrientation:(KGOrientation)newPageOrientation {
  pageOrientation = newPageOrientation;
  pageSize = (pageOrientation == KGPortraitOrientation ? portraitSize : landscapeSize);
  placeholderImage = (pageOrientation == KGPortraitOrientation ? portraitPlaceholderImage : landscapePlaceholderImage);
  [self preloadImagesForPageNumber:pageNumber];
  [self repositionContent];
}

- (void)setDataSource:(id<KGPagedDocControlImageStore>)newDataSource {
  if (newDataSource != dataSource) {
    dataSource = newDataSource;
    [imageStore removeAllImages];
    [self redrawContent];
  }
}

- (void)setPageSeparation:(CGFloat)newPageSeparation {
  if (newPageSeparation != pageSeparation) {
    pageSeparation = newPageSeparation;
    [self repositionContent];
  }
}

- (CGFloat)horizontalPadding {
  return self.bounds.size.width/2 - pageSize.width/2;
}

//------------------------------------------------------------------------------
// MARK: Public messages

- (void)newImageForPageNumber:(NSUInteger)page orientation:(KGOrientation)orientation {
  [self imageForPageNumber:page orientation:orientation];
  if (orientation == pageOrientation) {
    [self redrawContent]; // TODO: only redraw if page is in view
  }  
}

- (UIImage*)imageForPageNumber:(NSUInteger)page orientation:(KGOrientation)orientation {
  UIImage *image = [imageStore imageForPageNumber:page orientation:orientation];
  if (!image) {
    UIImage *fullImage;
    if ([dataSource respondsToSelector:@selector(imageForPageNumber:orientation:withOptions:)])
      fullImage = [dataSource imageForPageNumber:page orientation:orientation withOptions:KGImageStoreTemporary];
    else
      fullImage = [dataSource imageForPageNumber:page orientation:orientation];
    if (fullImage) {
      CGSize size = (orientation == KGPortraitOrientation ? portraitSize : landscapeSize);
      size.width *= retinaScale;
      size.height *= retinaScale; 
      UIGraphicsBeginImageContextWithOptions(size, YES, 1.0);
      [fullImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
      image = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();
      if (image) [imageStore saveImage:image forPageNumber:page orientation:orientation];
    }
  }
  return image ? image : placeholderImage;
}

//------------------------------------------------------------------------------
// MARK: UIScrollView delegate messages

- (void)scrollViewWillBeginDragging:(UIScrollView *)sender
{
  [self redrawContentIfNeeded];
}

- (void)scrollViewDidScroll:(UIScrollView *)sender {
  [self redrawContentIfNeeded];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)sender {
  [self redrawContentIfNeeded];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)sender {
  [self redrawContentIfNeeded];
}

//------------------------------------------------------------------------------
// MARK: Private messages

- (void)initControl {
  self.alpha = 0.0; // start inactive

  retinaScale = [UIScreen mainScreen].scale;

  self.imageStore = [[[KGInMemoryImageStore alloc] init] autorelease];
  
  self.scrollView = [[[UIScrollView alloc] initWithFrame:self.bounds] autorelease];
  scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  scrollView.backgroundColor = [UIColor clearColor];
  scrollView.delegate = self;
	scrollView.showsVerticalScrollIndicator = NO;
	scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
  
  [self addSubview:scrollView];
  
  self.contentView = [[[KGPagedDocThumbnailContentView alloc] initWithFrame:self.bounds] autorelease];
  contentView.control = self;
  contentView.backgroundColor = [UIColor clearColor];
  [scrollView addSubview:contentView];
  
  UITapGestureRecognizer *tapGesture = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectPage:)] autorelease];
  tapGesture.numberOfTapsRequired = 1;
  [contentView addGestureRecognizer:tapGesture];
}

- (void)redrawContent {
  CGSize size = self.bounds.size;
  CGFloat extra = pageSize.width+pageSeparation;
  CGRect crect = CGRectMake(scrollView.contentOffset.x - extra, 0, size.width+extra*2, size.height);
  [contentView setFrame:crect];
  [contentView setNeedsDisplay];
}

- (void)redrawContentIfNeeded {
  CGFloat cx1 = contentView.frame.origin.x;
  CGFloat cx2 = cx1 + contentView.frame.size.width;
  CGFloat sx1 = scrollView.contentOffset.x;
  CGFloat sx2 = sx1 + self.bounds.size.width;
  if (cx1 > sx1 || cx2 < sx2) [self redrawContent];
}

- (void)repositionContent {
  CGFloat mainWidth, x;
  if (numberOfPages == 0) {
    mainWidth = 0;
    x = 0;
  }
  else {
    mainWidth = pageSize.width*numberOfPages + pageSeparation*(numberOfPages-1);
    x = fractionalPageNumber / numberOfPages * mainWidth;
  }
  
  CGFloat padding = self.horizontalPadding;
  CGSize scrollSize = CGSizeMake(mainWidth + padding*2, pageSize.height);
  
  [scrollView setContentSize:scrollSize];
  [scrollView setContentOffset:CGPointMake(x,0) animated:NO];
}

- (void)selectPage:(UIGestureRecognizer*)gesture {
  CGPoint tapPoint = [gesture locationInView:scrollView];
  CGFloat padding = self.horizontalPadding;
  NSInteger page = floor((tapPoint.x - padding + pageSeparation/2) / (pageSize.width + pageSeparation));
  if (page >= 0 && page < numberOfPages) {
    pageNumber = page;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
  }
}

- (void)preloadImagesForPageNumber:(NSUInteger)page {
  for (NSInteger i = 5; i > 0; i--) {
    [self preloadImageForPageNumber:page+i];
    [self preloadImageForPageNumber:page-i];
  }
}

- (void)preloadImageForPageNumber:(NSInteger)page {
  if (page >= 0 && page < [self numberOfPages]) {
    if (![imageStore hasImageForPageNumber:page orientation:pageOrientation])
      [self imageForPageNumber:page orientation:pageOrientation];
  }
}

@end
