//
//  KGPagedDocThumbnailContentView.m
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

#import "KGPagedDocThumbnailContentView.h"

@implementation KGPagedDocThumbnailContentView

@synthesize control;

- (void)drawRect:(CGRect)rect {
  CGRect frame = self.frame;
  CGSize pageSize = control.pageSize;
  CGFloat x = frame.origin.x - control.horizontalPadding;
  CGFloat y = (frame.size.height - pageSize.height)/2;
  CGFloat fullWidth = pageSize.width + control.pageSeparation;
  KGOrientation orientation = control.pageOrientation;
  NSInteger first = floor(x / fullWidth);
  NSInteger last = ceil((x+frame.size.width) / fullWidth);
  CGRect dest = CGRectMake(0, y, pageSize.width, pageSize.height);
  CGContextRef context = NULL;
  for (NSInteger page = first; page < last; page++) {
    if (page < 0 || page >= control.numberOfPages) continue;
    dest.origin.x = page*fullWidth - x;
    UIImage *image = [control imageForPageNumber:page orientation:orientation];
    if (image)
      [image drawInRect:dest];
    else {
      if (context == NULL) {
        context = UIGraphicsGetCurrentContext();
        CGContextSetRGBFillColor (context, 0, 0, 0, 1);
      }
      CGContextFillRect (context, dest);        
    }
  }
}

@end



