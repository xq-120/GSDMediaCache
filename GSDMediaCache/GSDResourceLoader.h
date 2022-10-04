//
//  GSDPlayerResourceLoader.h
//  GSDMediaCache
//
//  Created by xq on 2020/12/1.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GSDResourceLoader : NSObject <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

- (instancetype)initWithResourceURL:(NSURL *)resourceURL inSession:(nullable NSURLSession *)session;

@property (nonatomic, strong, readonly) NSURL *resourceURL;

@property (nonatomic, assign, readonly, getter=isCancelled) BOOL cancelled;

- (void)addLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest;

- (void)cancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
