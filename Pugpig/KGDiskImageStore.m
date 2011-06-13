//
//  KGDiskImageStore.m
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

#import "KGDiskImageStore.h"

@interface KGDiskImageStore()

@property (nonatomic, retain) NSString *cacheDir;
@property (nonatomic, retain) NSMutableDictionary *store;
@property (nonatomic, retain) NSMutableArray *queue;

- (id)keyForPageNumber:(NSUInteger)pageNumber orientation:(KGOrientation)orientation;
- (NSString*)fileNameForKey:(id)key;
- (BOOL)imageWrittenForKey:(id)key;
- (UIImage*)readImageForKey:(id)key;
- (void)writeImage:(UIImage*)image forKey:(id)key;
- (void)enqueueImage:(UIImage*)image forKey:(id)key;

@end


@interface KGDiskImageStoreObject : NSObject {
}
@property (nonatomic,assign) BOOL onDisk;
@property (nonatomic,retain) UIImage *image;
@end

@implementation KGDiskImageStoreObject
@synthesize onDisk;
@synthesize image;
@end


@implementation KGDiskImageStore

@synthesize cacheSize;
@synthesize cacheDir;
@synthesize store;
@synthesize queue;

- (id)init {
  self = [super init];
  if (self) {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    self.cacheSize = 7;   // default cache size
    self.cacheDir = ([cachePaths count] > 0) ? [cachePaths objectAtIndex:0] : nil;
    self.store = [[[NSMutableDictionary alloc] init] autorelease];
    self.queue = [[[NSMutableArray alloc] init] autorelease];
  }
  return self;
}

- (void)dealloc {
  [queue release];
  [store release];
  [cacheDir release];
  [super dealloc];
}

- (void)removeAllImages {
  for (id key in store) {
    KGDiskImageStoreObject *obj = [store objectForKey:key];
    obj.image = nil;
  }
}

- (void)saveImage:(UIImage*)image forPageNumber:(NSUInteger)pageNumber orientation:(KGOrientation)orientation {
  if (![self hasImageForPageNumber:pageNumber orientation:orientation]) {
    id key = [self keyForPageNumber:pageNumber orientation:orientation];
    KGDiskImageStoreObject *obj = [store objectForKey:key];
    obj.onDisk = YES;
    obj.image = image;
    [self writeImage:image forKey:key];
    [self enqueueImage:image forKey:key];
  }
}

- (UIImage*)imageForPageNumber:(NSUInteger)pageNumber orientation:(KGOrientation)orientation {
  return [self imageForPageNumber:pageNumber orientation:orientation withOptions:KGImageStoreFetch];
}

- (UIImage*)imageForPageNumber:(NSUInteger)pageNumber orientation:(KGOrientation)orientation withOptions:(KGImageStoreOptions)options {
  UIImage *image = nil;
  if ([self hasImageForPageNumber:pageNumber orientation:orientation]) {
    id key = [self keyForPageNumber:pageNumber orientation:orientation];
    KGDiskImageStoreObject *obj = [store objectForKey:key];

    image = (obj.image ? obj.image : [self readImageForKey:key]);
    
    if (image && !(options & KGImageStoreTemporary)) {
      // if not temporary, add to in-memory store and queue
      obj.image = image;
      [self enqueueImage:image forKey:key];
    }
  }
  return image; 
}

- (BOOL)hasImageForPageNumber:(NSUInteger)pageNumber orientation:(KGOrientation)orientation {
  id key = [self keyForPageNumber:pageNumber orientation:orientation];
  KGDiskImageStoreObject *obj = [store objectForKey:key];
  if ([store objectForKey:key] == nil) { 
    obj = [[[KGDiskImageStoreObject alloc] init] autorelease];
    obj.onDisk = [self imageWrittenForKey:key];
    [store setObject:obj forKey:key];
  }
  return [obj onDisk];
}

- (id)keyForPageNumber:(NSUInteger)pageNumber orientation:(KGOrientation)orientation {
  return [NSNumber numberWithInt:(pageNumber*2 + (int)orientation)];
}

- (NSString*)fileNameForKey:(id)key {
  return  [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"snap-%d.jpg", [key unsignedIntegerValue]]];
}

- (BOOL)imageWrittenForKey:(id)key {
  NSString *cacheFile = [self fileNameForKey:key];
  return [[NSFileManager defaultManager] fileExistsAtPath:cacheFile];    
}

- (UIImage*)readImageForKey:(id)key {
  NSString *cacheFile = [self fileNameForKey:key];
  return [[NSFileManager defaultManager] fileExistsAtPath:cacheFile] ? [UIImage imageWithContentsOfFile:cacheFile] : nil;
}

- (void)writeImage:(UIImage*)image forKey:(id)key {
  NSString *cacheFile = [self fileNameForKey:key];
  [UIImageJPEGRepresentation(image, 0.5) writeToFile:cacheFile atomically:YES];
}

- (void)enqueueImage:(UIImage *)image forKey:(id)key {
  NSUInteger keyIdx = [queue indexOfObject:key];
  if (keyIdx != NSNotFound) {
    // image in recent use queue; move it to the back so it's the most recently used.
    id moveKey = [queue objectAtIndex:keyIdx];
    [queue addObject:moveKey];
    [queue removeObjectAtIndex:keyIdx];
  }
  else {
    // image not in queue - add it and drop the oldest if necessary
    [queue addObject:key];
    if ([queue count] > cacheSize) {
      id lastKey = [queue objectAtIndex:0];
      [[store objectForKey:lastKey] setImage:nil];
      [queue removeObjectAtIndex:0];
    }
  }
}

@end
