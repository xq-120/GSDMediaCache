//
//  GSDResourceRequestOperation.h
//  GSDMediaCache
//
//  Created by xq on 2020/12/6.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "GSDResourceInfoModel.h"

NS_ASSUME_NONNULL_BEGIN
@class GSDResourceFetchOperation;

@protocol GSDResourceFetchOperationDelegate <NSObject>

@optional

- (void)fetchOperation:(GSDResourceFetchOperation *)fetchOperation didLoadResourceInfo:(GSDResourceInfoModel *)resourceInfo;

- (void)fetchOperation:(GSDResourceFetchOperation *)fetchOperation didReceiveData:(NSData *)data;

- (void)fetchOperation:(GSDResourceFetchOperation *)fetchOperation didCompleteWithError:(nullable NSError *)error;

@end

@interface GSDResourceFetchOperation : NSObject <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

- (instancetype)initWithResourceURL:(NSURL *)resourceURL loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest inSession:(nullable NSURLSession *)session;

@property (nonatomic, weak) id<GSDResourceFetchOperationDelegate>delegate;

@property (nonatomic, strong, readonly) AVAssetResourceLoadingRequest *loadingRequest;

@property (nonatomic, strong, readonly) NSURL *resourceURL;

@property (nonatomic, copy, readonly) NSString *fetchOperationID;

@property (assign, nonatomic, readonly, getter = isCancelled) BOOL cancelled;

@property (assign, nonatomic, readonly, getter = isExecuting) BOOL executing;

@property (assign, nonatomic, readonly, getter = isFinished) BOOL finished;

- (BOOL)containDataTask:(NSURLSessionTask *)task;

- (void)start;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
