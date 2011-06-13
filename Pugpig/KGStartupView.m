//
//  KGStartupView.m
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

#import "KGStartupView.h"

//==============================================================================
// MARK: - Private interface

@interface KGStartupView()

@property (nonatomic,retain) UIViewController *rootViewController;
@property (nonatomic,retain) UIImageView *background;
@property (nonatomic,retain) UIProgressView *progressBar;

@end

//==============================================================================
// MARK: - Main implementation

@implementation KGStartupView

@dynamic progress;

@synthesize rootViewController;
@synthesize background;
@synthesize progressBar;

//------------------------------------------------------------------------------
// MARK: NSObject/UIView messages

- (id)init {
  UIWindow *window = [[UIApplication sharedApplication] keyWindow];
  CGRect frame = window.frame;
  
  self = [super initWithFrame:frame];
  if (self) {
    self.rootViewController = window.rootViewController;
    [self setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
    [self setBackgroundColor:[UIColor blackColor]];
    
    self.background = [[[UIImageView alloc] initWithFrame:frame] autorelease];
    [self addSubview:background];
    
    self.progressBar = [[[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar] autorelease];
    CGSize isize = frame.size;
    CGSize psize = progressBar.bounds.size;
    [progressBar setFrame:CGRectMake((isize.width-psize.width)/2,(isize.height-psize.height)/2,psize.width,psize.height)];
    [progressBar setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin];
    [background addSubview:progressBar];
  
    [rootViewController.view addSubview:self];
  }
  return self;
}

- (void)dealloc {
  [rootViewController release];
  [background release];
  [progressBar release];
  [super dealloc];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  
  CGSize size = self.bounds.size;
  
  UIImage *image;
  CGSize isize, isizedef;
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
    image = [UIImage imageNamed:@"Default.png"];
    isize = [image size];  
    isizedef = CGSizeMake(320, 480);
    if (size.width < size.height)
      [background setTransform:CGAffineTransformIdentity];
    else {
      // On the iPhone we only have a protrait loading screen, so if the 
      // orientation is landscape we need to rotate the image 90 degrees
      // to the left or right in order to display something meaningful.
      if (rootViewController.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
        [background setTransform:CGAffineTransformMakeRotation(M_PI/2)];
      else  
        [background setTransform:CGAffineTransformMakeRotation(-M_PI/2)];
      CGFloat tmp = isize.width;
      isize.width = isize.height;
      isize.height = tmp;
    }  
  }
  else {
    if (size.width < size.height) {
      image = [UIImage imageNamed:@"Default-Portrait~ipad.png"];
      isizedef = CGSizeMake(768, 1004);
    }
    else {
      image = [UIImage imageNamed:@"Default-Landscape~ipad.png"];
      isizedef = CGSizeMake(1024, 748);
    }
    isize = [image size]; 
  }    
  
  if (!image) isize = isizedef;
    
  CGRect frame = CGRectMake((size.width-isize.width)/2, size.height-isize.height, isize.width, isize.height);
  [background setFrame:frame];
  [background setImage:image];
}

//------------------------------------------------------------------------------
// MARK: Public methods

- (void)setProgress:(CGFloat)progress {
  [progressBar setProgress:progress];
}

- (CGFloat)progress {
  return [progressBar progress];
}

@end
