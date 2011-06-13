//
//  KGPagedDocControlImplementation.m
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

#import "KGPagedDocControlImplementation.h"
#import "KGInMemoryImageStore.h"
#import "KGCappedScrollView.h"
#import "KGStartupView.h"
#import "UIWebView+KGAdditions.h"

//==============================================================================
// MARK: - Private interface

@interface KGPagedDocControlImplementation()

@property (nonatomic, retain) KGStartupView *startupView;
@property (nonatomic, retain) KGCappedScrollView *scrollView;
@property (nonatomic, retain) UIWebView *mainWebView, *backgroundWebView;
@property (nonatomic, retain) UIImageView *leftImageView, *rightImageView, *centreImageView;
@property (nonatomic, retain) UIActivityIndicatorView *leftBusyView, *rightBusyView, *centreBusyView;

- (void)initControl;
- (void)calculateDefaultSizes;
- (KGOrientation)orientationForSize:(CGSize)size;
- (BOOL)interfaceOrientationMatchesOrientation:(KGOrientation)orientation;
- (CGRect)frameForPageNumber:(NSUInteger)pageNumber;
- (void)createScrollView;
- (void)positionScrollViewContent;
- (UIImageView*)createImageView;
- (UIActivityIndicatorView*)createBusyView;
- (void)positionImageViewsCentredOnPage:(NSInteger)page;
- (void)positionImageView:(UIImageView*)imageView andBusyView:(UIActivityIndicatorView*)busyView forPage:(NSInteger)pageNumber;
- (UIWebView*)createWebViewWithSize:(CGSize)size;
- (void)stopWebView:(UIWebView*)webView;
- (void)webView:(UIWebView*)webView didFinish:(KGPagedDocFinishedMask)finished;
- (BOOL)webViewHasJavascriptDelay:(UIWebView*)webView;
- (void)takeSnapshotForWebView:(UIWebView*)webView;
- (void)loadMainWebView;
- (void)showMainWebView;
- (void)startBackgroundLoadAfterDelay:(CGFloat)delay;
- (void)cancelBackgroundLoad;
- (void)loadBackgroundWebViews;
- (BOOL)loadBackgroundWebViewsWithOrientation:(KGOrientation)orientation size:(CGSize)size;
- (BOOL)loadBackgroundWebViewsForPageNumber:(NSInteger)page withOrientation:(KGOrientation)orientation size:(CGSize)size;
- (void)toggleNavigator:(UITapGestureRecognizer *)recognizer;
- (void)updateNavigatorOrientation;
- (void)updateNavigatorDataSource;
- (void)navigatorPageChanged;
- (void)preloadImagesForPageNumber:(NSUInteger)pageNumber;
- (void)preloadImageForPageNumber:(NSInteger)pageNumber orientation:(KGOrientation)orientation;
- (void)startupUpdateProgress:(BOOL)afterSnapshot;
- (NSUInteger)startupPagesIntialised;
- (NSUInteger)numberOfPages;
- (NSURL*)urlForPageNumber:(NSUInteger)pageNumber;
- (NSInteger)pageNumberForURL:(NSURL*)url;

@end

//==============================================================================
// MARK: - Main implementation

@implementation KGPagedDocControlImplementation

@synthesize delegate;
@synthesize imageStore;
@synthesize dataSource;
@synthesize navigator;
@synthesize pageNumber;
@dynamic fractionalPageNumber;
@synthesize portraitSize, landscapeSize;
@synthesize scale;
@synthesize scrollEnabled;
@synthesize mediaPlaybackRequiresUserAction;
@dynamic bounces;

@synthesize startupView;
@synthesize scrollView;
@synthesize mainWebView, backgroundWebView;
@synthesize leftImageView, rightImageView, centreImageView;
@synthesize leftBusyView, rightBusyView, centreBusyView;

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
  [dataSource release];
  [navigator release];
  
  [startupView release];
  [scrollView release];
  [mainWebView release];
  [backgroundWebView release];
  [leftImageView release];
  [rightImageView release];
  [centreImageView release];
  [leftBusyView release];
  [rightBusyView release];
  [centreBusyView release];
  
  [super dealloc];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  if (!CGSizeEqualToSize(lastLayoutSize, self.bounds.size)) {
    lastLayoutSize = self.bounds.size;
    
    leftImageView.tag = rightImageView.tag = centreImageView.tag = -1;
    
    [self positionImageViewsCentredOnPage:pageNumber];
    [self positionScrollViewContent];
    [self preloadImagesForPageNumber:pageNumber];
    [self updateNavigatorOrientation];     

    // If we start the background load immediately it sometimes doesn't
    // snapshot properly for the first page.
    [self startBackgroundLoadAfterDelay:0.5];
    
    if (mainFinishedMask == KGPDFinishedEverything)
      [self showMainWebView];
  }
}

//------------------------------------------------------------------------------
// MARK: Public messages and properties

- (void)hideUntilInitialised {
  [self hideUntilInitialised:INT_MAX];
}

- (void)hideUntilInitialised:(NSUInteger)requiredPages {
  startupRequiredPages = MIN(requiredPages, [self numberOfPages]);
  if ([self startupPagesIntialised] < startupRequiredPages)
    self.startupView = [[[KGStartupView alloc] init] autorelease];
}

- (void)setImageStore:(id<KGPagedDocControlImageStore>)newImageStore {
  if (imageStore != newImageStore) {
    [imageStore release];
    imageStore = [newImageStore retain];
    
    [self updateNavigatorDataSource];
    // TODO: rebuild cache if datasource already set?
  }
}

- (void)setDataSource:(id<KGPagedDocControlDataSource>)newDataSource {
  if (dataSource != newDataSource) {
    [dataSource release];
    dataSource = [newDataSource retain];
    
    [imageStore removeAllImages];
    
    [self updateNavigatorDataSource];
    [self positionScrollViewContent];
    [self setPageNumber:pageNumber];
    [self startBackgroundLoadAfterDelay:0];
  }
}

- (void)setNavigator:(UIControl<KGPagedDocControlNavigator>*)newNavigator {
  if (navigator != newNavigator) {
    [navigator removeTarget:self action:@selector(navigatorPageChanged) forControlEvents:UIControlEventValueChanged];
    [navigator release];
    navigator = [newNavigator retain];
    [navigator addTarget:self action:@selector(navigatorPageChanged) forControlEvents:UIControlEventValueChanged];
    
    [self updateNavigatorDataSource];
    [self updateNavigatorOrientation];     
  }
}

- (void)setPageNumber:(NSUInteger)newPageNumber {
  [self setPageNumber:newPageNumber animated:NO];
}

- (void)setPageNumber:(NSUInteger)newPageNumber animated:(BOOL)animated {
  if (animated) {
    // If the main web view is offscreen (i.e. it's still loading), we stop
    // it and delete it so that it doesn't slow down the animation.
    if (mainWebView.frame.origin.y > 1024) {
      [self stopWebView:mainWebView];
      [mainWebView removeFromSuperview];
      self.mainWebView = nil;
    }
    // Also cancel any background loads temporarily.
    [self cancelBackgroundLoad];
  }
  else {
    [self preloadImagesForPageNumber:newPageNumber];
    
    pageNumber = newPageNumber;
    navigator.pageNumber = newPageNumber;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    
    [self positionImageViewsCentredOnPage:pageNumber];    
    [self loadMainWebView];
  }
  
  CGRect rect = [self frameForPageNumber:newPageNumber];
  [scrollView scrollRectToVisible:rect animated:animated];
}

- (CGFloat)fractionalPageNumber {
  if (scrollView.contentSize.width == 0 || dataSource == nil) return 0;
  return scrollView.contentOffset.x / scrollView.contentSize.width * [self numberOfPages];
}

- (void)setScrollEnabled:(BOOL)newScrollEnabled {
  if (scrollEnabled != newScrollEnabled) {
    scrollEnabled = newScrollEnabled;
    mainWebView.scrollEnabled = newScrollEnabled;
  }
}

- (void)setMediaPlaybackRequiresUserAction:(BOOL)newValue {
  if (mediaPlaybackRequiresUserAction != newValue) {
    mediaPlaybackRequiresUserAction = newValue;
    mainWebView.mediaPlaybackRequiresUserAction = mediaPlaybackRequiresUserAction;
  }
}

- (BOOL)bounces {
  return [scrollView bounces];
}

- (void)setBounces:(BOOL)bounces {
  [scrollView setBounces:bounces];
}

- (void)setOpaque:(BOOL)opaque {
  [super setOpaque:opaque];
  [scrollView setOpaque:opaque];
  [mainWebView setOpaque:opaque];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
  [super setBackgroundColor:backgroundColor];
  [scrollView setBackgroundColor:backgroundColor];
  [mainWebView setBackgroundColor:backgroundColor];
}

//------------------------------------------------------------------------------
// MARK: UIScrollViewDelegate messages

- (void)scrollViewWillBeginDragging:(UIScrollView *)sender {
  [scrollView setMaxDelta:100.0];
  // Cancel any background loads temporarily so we have smoother dragging.
  [self cancelBackgroundLoad];
}

- (void)scrollViewDidScroll:(UIScrollView *)sender {
  navigator.fractionalPageNumber = self.fractionalPageNumber;
  
  CGFloat w = scrollView.bounds.size.width;
  NSInteger newPageNumber = floor((scrollView.contentOffset.x + w/2)/w);
  
  [self positionImageViewsCentredOnPage:newPageNumber];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)sender {
  [scrollView setMaxDelta:0.0];
  navigator.fractionalPageNumber = self.fractionalPageNumber;
  NSInteger destPageNum = floor(scrollView.contentOffset.x / scrollView.frame.size.width);    
  [self setPageNumber:destPageNum];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)sender {
  [scrollView setMaxDelta:0.0];
  navigator.fractionalPageNumber = self.fractionalPageNumber;
  NSInteger destPageNum = floor(scrollView.contentOffset.x / scrollView.frame.size.width);    
  [self setPageNumber:destPageNum];
}

//------------------------------------------------------------------------------
// MARK: UIWebViewDelegate messages

- (BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType {
  NSURL *URL = [request URL];
  BOOL shouldStart = YES;
  BOOL isPlumbSchema = [[URL scheme] isEqualToString:@"pugpig"];
  if (isPlumbSchema) {
    NSString *plumbCommand = [URL host];
    if ([plumbCommand isEqualToString:@"onPageReady"])
      [self webView:webView didFinish:KGPDFinishedJS];
    else
      [delegate document:(KGPagedDocControl*)self didExecuteCommand:URL];
    shouldStart = NO;
  }
  else if (webView == mainWebView && mainFinishedMask != KGPDFinishedNothing) {
    NSInteger page = [self pageNumberForURL:URL];
    if (page != -1)
      [self setPageNumber:page animated:YES];
    else
      [[UIApplication sharedApplication] openURL:URL];
    shouldStart = NO;
  }
  return shouldStart;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
  [self webView:webView didFinish:KGPDFinishedLoad];
  if (![self webViewHasJavascriptDelay:webView])
    [self webView:webView didFinish:KGPDFinishedJS];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
  [self webView:webView didFinish:KGPDFinishedLoad];
  if (![self webViewHasJavascriptDelay:webView])
    [self webView:webView didFinish:KGPDFinishedJS];
}

//------------------------------------------------------------------------------
// MARK: UIGestureRecognizerDelegate messages

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
  return YES;
}

//------------------------------------------------------------------------------
// MARK: Private messages

- (void)initControl {
  [self calculateDefaultSizes];
  [self createScrollView];
  
  mainFinishedMask = KGPDFinishedEverything;
  backgroundFinishedMask = KGPDFinishedEverything;
  
  scale = 1.0;
  
  self.imageStore = [[[KGInMemoryImageStore alloc] init] autorelease];
  
  self.leftImageView = [self createImageView];
  self.rightImageView = [self createImageView];
  self.centreImageView = [self createImageView];
  self.leftBusyView = [self createBusyView];
  self.rightBusyView = [self createBusyView];
  self.centreBusyView = [self createBusyView];
  
  UITapGestureRecognizer *doubleTap = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleNavigator:)] autorelease];
  doubleTap.delegate = self;
	doubleTap.numberOfTapsRequired = 2;
	[self addGestureRecognizer:doubleTap];
}

- (void)calculateDefaultSizes {
  // TODO: make this take into account autosizing information
  CGSize size = self.bounds.size;
  if ([self orientationForSize:size] == KGLandscapeOrientation) {
    landscapeSize = size;
    portraitSize = CGSizeMake(size.height, size.width);
  }
  else {
    portraitSize = size;
    landscapeSize = CGSizeMake(size.height, size.width);
  }
}

- (KGOrientation)orientationForSize:(CGSize)size {
  return (size.width > size.height ? KGLandscapeOrientation : KGPortraitOrientation);
}

- (BOOL)interfaceOrientationMatchesOrientation:(KGOrientation)orientation {
  UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
  return (
    UIInterfaceOrientationIsLandscape(interfaceOrientation) && orientation == KGLandscapeOrientation ||
    UIInterfaceOrientationIsPortrait(interfaceOrientation) && orientation == KGPortraitOrientation
  );
}

- (CGRect)frameForPageNumber:(NSUInteger)page {
  CGSize size = self.bounds.size;
  return CGRectMake(page*size.width, 0, size.width, size.height);
}

- (void)createScrollView {
  self.scrollView = [[[KGCappedScrollView alloc] initWithFrame:self.bounds] autorelease];
  scrollView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
  
  scrollView.delegate = self;
  scrollView.pagingEnabled = YES;
  scrollView.scrollEnabled = YES;
  scrollView.showsVerticalScrollIndicator = NO;
  scrollView.showsHorizontalScrollIndicator = NO;
  scrollView.bounces = NO;
  scrollView.delaysContentTouches = NO;
  scrollView.clipsToBounds = YES;
  scrollView.backgroundColor = [self backgroundColor];
  scrollView.opaque = [self isOpaque];
  
  [self addSubview:scrollView];
  
  [self positionScrollViewContent];
}

- (void)positionScrollViewContent {
  if (dataSource) {
    CGSize size = self.bounds.size;
    NSUInteger pages = [self numberOfPages];
    [scrollView setContentOffset:CGPointMake(pageNumber * size.width, 0) animated:NO];
    [scrollView setContentSize:CGSizeMake(pages * size.width, size.height)];
  }
}

- (UIImageView*)createImageView {
  UIImageView *imageView = [[UIImageView alloc] init];
  imageView.tag = -1;
  [scrollView addSubview:imageView];
  return [imageView autorelease];
}

- (UIActivityIndicatorView*)createBusyView {
  UIActivityIndicatorView *busyView = [[UIActivityIndicatorView alloc] init];
  busyView.tag = -1;
  busyView.opaque = NO;
  busyView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
  [scrollView addSubview:busyView];
  return [busyView autorelease];
}

- (void)positionImageViewsCentredOnPage:(NSInteger)page {
  [self positionImageView:centreImageView andBusyView:centreBusyView forPage:page];
  [self positionImageView:leftImageView andBusyView:leftBusyView forPage:page - 1];
  [self positionImageView:rightImageView andBusyView:rightBusyView forPage:page + 1];       
}

- (void)positionImageView:(UIImageView*)imageView andBusyView:(UIActivityIndicatorView*)busyView forPage:(NSInteger)page {
  if (page < 0 || page >= [self numberOfPages]) {
    imageView.hidden = YES;
    busyView.hidden = YES;
  }
  else {
    // TODO: optimize this when imageView.tag == page
    KGOrientation orientation = [self orientationForSize:self.bounds.size];
    UIImage *pageImage = [imageStore imageForPageNumber:page orientation:orientation];
    CGRect pageFrame = [self frameForPageNumber:page];
    
    if (pageImage) {
      imageView.image = pageImage;
      imageView.frame = pageFrame;
      imageView.tag = page;
      imageView.hidden = NO;
      busyView.hidden = YES;
      [busyView stopAnimating];
    }    
    else {
      // image isn't available yet - show a placeholder
      CGPoint pageOrigin = pageFrame.origin;
      CGSize pageSize = pageFrame.size;
      CGSize busySize = CGSizeMake(40, 40);
      CGRect busyFrame = CGRectMake(
        pageOrigin.x + (pageSize.width-busySize.width)/2, 
        pageOrigin.y + (pageSize.height-busySize.height)/2, 
        busySize.width, busySize.height
      );
      busyView.frame = busyFrame;
      busyView.hidden = NO;
      [busyView startAnimating];
      imageView.hidden = YES;
    }
  }
}

- (UIWebView*)createWebViewWithSize:(CGSize)size {
  // make sure web view is off-screen to prevent any flicker.
  // 0x0 seems to force the webview to redraw; without it there can be flicker as the webview briefly
  // shows the previously loaded view.
  // width > 0 but set to the minimum dimension (width or height) desired makes reflow work on rotation but
  // causes the previous-webview-visible flicker problem.
  //
  // TODO: update this comment to reflect reality
  
  CGRect frame = CGRectMake(0, 9999, size.width/2, size.height/2);
  //  CGRect frame = CGRectMake(0, 9999, size.width, size.height);
  //  CGRect frame = CGRectMake(0, 9999, 1, 1);
  //  CGRect frame = CGRectMake(0, 9999, size.width, size.height+1);
  UIWebView *webView = [[[UIWebView alloc] initWithFrame:frame] autorelease];
  
  webView.tag = -1;
  webView.autoresizesSubviews = YES;
  webView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
  webView.delegate = self;
  webView.scrollEnabled = NO;
  if (scale != 1.0 && scale != 0.0) webView.transform = CGAffineTransformMakeScale(scale, scale);
  
  [scrollView addSubview:webView];
  return webView;
}

- (void)stopWebView:(UIWebView*)webView {
  [webView setDelegate:nil];
  [webView stopLoading];
  webView.tag = -1;
}

- (void)webView:(UIWebView*)webView didFinish:(KGPagedDocFinishedMask)finished {
  if (webView == mainWebView) {
    if (mainFinishedMask == KGPDFinishedEverything) return;
    mainFinishedMask |= finished;
    if (mainFinishedMask == KGPDFinishedEverything) {
      mainWebView.tag = mainPageNumber;
      [self showMainWebView];
      
      KGOrientation orientation = [self orientationForSize:mainSize];
      if (![imageStore hasImageForPageNumber:mainPageNumber orientation:orientation]) {
        [self startupUpdateProgress:NO];
        [self performSelector:@selector(takeSnapshotForWebView:) withObject:webView afterDelay:0.0];
      }
    }
  }
  
  if (webView == backgroundWebView) {
    if (backgroundFinishedMask == KGPDFinishedEverything) return;
    backgroundFinishedMask |= finished;
    if (backgroundFinishedMask == KGPDFinishedEverything) {
      backgroundWebView.tag = backgroundPageNumber;
      backgroundWebView.frame = CGRectMake(9999, 9999, backgroundSize.width, backgroundSize.height);
      
      KGOrientation orientation = [self orientationForSize:backgroundSize];
      if (![imageStore hasImageForPageNumber:backgroundPageNumber orientation:orientation]) {
        [self startupUpdateProgress:NO];
        [self performSelector:@selector(takeSnapshotForWebView:) withObject:webView afterDelay:0.0];
      }
      else {
        backgroundBusyLoading = NO;
        [self startBackgroundLoadAfterDelay:0];
      }
    }
  }
}

- (BOOL)webViewHasJavascriptDelay:(UIWebView*)webView {
  NSString *delayCheckJS =
  @"function getDelayMeta() {"
  @"  var m = document.getElementsByTagName('meta');"
  @"  for(var i in m) { "
  @"    if(m[i].name == 'delaySnapshotUntilReady') {"
  @"      return m[i].content;"
  @"    }"
  @"  }"
  @"  return '';"
  @"}"
  @"getDelayMeta();";
  NSString *mustDelayTag = [webView stringByEvaluatingJavaScriptFromString:delayCheckJS];
  return (mustDelayTag && [mustDelayTag localizedCaseInsensitiveCompare:@"yes"] == NSOrderedSame);    
}

- (void)takeSnapshotForWebView:(UIWebView*)webView {
  CGSize size;
  NSUInteger page;
  
  if (webView == mainWebView) {
    size = mainSize;
    page = mainPageNumber;  
  }
  else if (webView == backgroundWebView) {
    size = backgroundSize;
    page = backgroundPageNumber;
  }
  else
    return;

  // Check that the current interfaceOrientation still matches the 
  // orientation at which the page was rendered otherwise the rendering 
  // won't be completely correct and the snapshot image won't match the 
  // final rendering.
  KGOrientation orientation = [self orientationForSize:size];
  if ([self interfaceOrientationMatchesOrientation:orientation]) {
    UIImage *snapShot = [webView getImageFromView];
    [imageStore saveImage:snapShot forPageNumber:page orientation:orientation];
    [navigator newImageForPageNumber:page orientation:orientation];
    [self startupUpdateProgress:YES];
  }
  
  if (webView == backgroundWebView) {
    backgroundBusyLoading = NO;
    [self startBackgroundLoadAfterDelay:0];
  }
}

- (void)loadMainWebView {
  // page already loaded don't reload
  if (mainWebView && mainWebView.tag == pageNumber) return;
  
  // Cancel any background loads since we want the main load to take priority
  [self cancelBackgroundLoad];
  
  [self stopWebView:mainWebView];
  [mainWebView removeFromSuperview];
  
  mainPageNumber = pageNumber;
  mainSize = self.bounds.size;
  
  self.mainWebView = [self createWebViewWithSize:mainSize];
  mainWebView.backgroundColor = [self backgroundColor];
  mainWebView.opaque = [self isOpaque];
  mainWebView.scrollEnabled = scrollEnabled;
  mainWebView.mediaPlaybackRequiresUserAction = mediaPlaybackRequiresUserAction;
  
  mainFinishedMask = KGPDFinishedNothing;
  
  if ([self numberOfPages] == 0) {
    NSString *blank = 
      @"<html><head>"
      @"<style>body {width:60%;font-family:Helvetica;font-size:300%;padding:25% 20%;} .small {font-size:50%;margin-top:2em;}</style>"
      @"<body><center><p>This page intentionally left blank.</p></center>"
      @"<center><p class='small'>Your data source did not return any data.</p></center></body></html>";
    [mainWebView loadHTMLString:blank baseURL:nil];
  }
  else
    [mainWebView loadRequest:[NSURLRequest requestWithURL:[self urlForPageNumber:mainPageNumber]]];
}

- (void)showMainWebView {
  mainWebView.frame = [self frameForPageNumber:pageNumber];
  // When scrolling is enabled, we need to make sure the scroll width of the
  // web view is no wider than its view width. If not, the web view's scroller
  // will intercept gestures that were intended for the containing scroll view.
  if (scrollEnabled) [mainWebView setScrollWidth:mainWebView.bounds.size.width];
  centreImageView.hidden = YES;
  centreBusyView.hidden = YES;
}

- (void)startBackgroundLoadAfterDelay:(CGFloat)delay {
  // Check whether we have already started a background load so that we don't
  // get a whole bunch of these queued up.
  if (!backgroundBusyLoading) {
    backgroundBusyLoading = YES;
    [self performSelector:@selector(loadBackgroundWebViews) withObject:nil afterDelay:delay];
  }
}

- (void)cancelBackgroundLoad {
  if (backgroundBusyLoading) {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(loadBackgroundWebViews) object:nil];
    
    [self stopWebView:backgroundWebView];
    [backgroundWebView removeFromSuperview];
    self.backgroundWebView = nil;
    
    backgroundBusyLoading = NO;
    [self startBackgroundLoadAfterDelay:1.0];
  }
}

- (void)loadBackgroundWebViews {
  // Don't load while the main view is loading since that has a tendency to
  // cause rendering problems which show up in the snapshot.
  if (mainFinishedMask != KGPDFinishedEverything) {
    backgroundBusyLoading = NO;
    [self startBackgroundLoadAfterDelay:0.5];
    return;
  }
  
  BOOL loaded = NO;
  
  KGOrientation orientation = [self orientationForSize:self.bounds.size];
  if (orientation == KGLandscapeOrientation)
    loaded = [self loadBackgroundWebViewsWithOrientation:orientation size:landscapeSize];
  if (orientation == KGPortraitOrientation)
    loaded = [self loadBackgroundWebViewsWithOrientation:orientation size:portraitSize];
  
  backgroundBusyLoading = loaded;
}

- (BOOL)loadBackgroundWebViewsWithOrientation:(KGOrientation)orientation size:(CGSize)size {
  // Only render orientations that match the current interface orientation
  // otherwise the rendering won't be completely correct and the snapshot
  // image won't match the final rendering.
  if ([self interfaceOrientationMatchesOrientation:orientation])
    for (NSInteger i = 0; i < [self numberOfPages]; i++) {
      // load pages that are closest to the current page first
      if ([self loadBackgroundWebViewsForPageNumber:pageNumber+i withOrientation:orientation size:size]) return YES;
      if ([self loadBackgroundWebViewsForPageNumber:pageNumber-i withOrientation:orientation size:size]) return YES;
    }
  return NO;
}

- (BOOL)loadBackgroundWebViewsForPageNumber:(NSInteger)page withOrientation:(KGOrientation)orientation size:(CGSize)size {
  if (page < 0 || page >= [self numberOfPages]) return NO;
  if ([imageStore hasImageForPageNumber:page orientation:orientation]) return NO;
    
  [self stopWebView:backgroundWebView];
  [backgroundWebView removeFromSuperview];
  
  backgroundPageNumber = page;
  backgroundSize = size;
  
  self.backgroundWebView = [self createWebViewWithSize:backgroundSize];
  
  backgroundFinishedMask = KGPDFinishedNothing;
  [backgroundWebView loadRequest:[NSURLRequest requestWithURL:[self urlForPageNumber:backgroundPageNumber]]];
  return YES;
}

- (void)toggleNavigator:(UITapGestureRecognizer *)recognizer {
  if (!navigator) return;
  
  BOOL isVisible = [navigator isActive];
  if (isVisible) {
    CGPoint posInNav = [recognizer locationInView:navigator];
    if (posInNav.y >= 0.0) {
      return;  // double-tap within the navigator shouldn't close it
    }
  }
  
  [navigator setActive:!isVisible];
}

- (void)updateNavigatorOrientation {
  navigator.pageOrientation = [self orientationForSize:self.bounds.size];
  navigator.fractionalPageNumber = self.fractionalPageNumber;
}

- (void)updateNavigatorDataSource {
  [navigator setDataSource:nil];
  [navigator setNumberOfPages:0];
  if (dataSource && imageStore) {
    [navigator setDataSource:imageStore];
    [navigator setNumberOfPages:[self numberOfPages]];
  }
}


- (void)navigatorPageChanged {
  [self setPageNumber:navigator.pageNumber animated:YES];
}

- (void)preloadImagesForPageNumber:(NSUInteger)page {
  // For a slow image cache, if we request an image while the view is scrolling,
  // it can cause the interface to jerk. By calling this function when a scroll
  // operation has just finished, we can give the cache a chance to preload
  // images that are soon likely to be needed, without having a negative impact
  // on the scrolling.
  KGOrientation orientation = [self orientationForSize:self.bounds.size];
  for (NSInteger i = 3; i >= 2; i--) {
    [self preloadImageForPageNumber:page+i orientation:orientation];
    [self preloadImageForPageNumber:page-i orientation:orientation];
  }
}

- (void)preloadImageForPageNumber:(NSInteger)page orientation:(KGOrientation)orientation {
  if (page >= 0 && page < [self numberOfPages]) {
    if ([imageStore respondsToSelector:@selector(imageForPageNumber:orientation:withOptions:)])
      [imageStore imageForPageNumber:page orientation:orientation withOptions:KGImageStorePrefetch];
    else
      [imageStore imageForPageNumber:page orientation:orientation];
  }
}

- (void)startupUpdateProgress:(BOOL)afterSnapshot {
  // This function is called twice for each page: once immediately after the
  // page has loaded (but before the snapshot has been taken), and a second
  // time after the snapshot has been taken for the page.
  //
  // In order that the final 100% state actually has a chance to be seen, we
  // count 100% as being 1 step shy of complete (i.e. the last page has been
  // loaded, but not yet snapshot). When the snapshot is eventually taken
  // the loading screen will close immediately.
  
  if (startupView) {
    NSUInteger gotPages = [self startupPagesIntialised];
    
    if (gotPages >= startupRequiredPages) {
      [startupView removeFromSuperview];
      self.startupView = nil;
    }
    else {
      CGFloat fractionalPages = (CGFloat)gotPages + (afterSnapshot ? 0 : 0.5);
      CGFloat maximumPages = (CGFloat)startupRequiredPages - 0.5;
      [startupView setProgress:(fractionalPages / maximumPages)];
    }  
  }
}

- (NSUInteger)startupPagesIntialised {
  NSUInteger gotPages = 0;
  KGOrientation orientation = [self orientationForSize:self.bounds.size];
  for (NSUInteger i = 0; i < startupRequiredPages; i++)
    if ([imageStore hasImageForPageNumber:i orientation:orientation])
      gotPages++;
  return gotPages;
}

//------------------------------------------------------------------------------
// MARK: Forwarding methods for the data source

- (NSUInteger)numberOfPages {
  return [dataSource numberOfPagesInDocument:(KGPagedDocControl*)self];
}

- (NSURL*)urlForPageNumber:(NSUInteger)page {
  return [dataSource document:(KGPagedDocControl*)self urlForPageNumber:page];
}

- (NSInteger)pageNumberForURL:(NSURL*)url {
  return [dataSource document:(KGPagedDocControl*)self pageNumberForURL:url];
}

@end

