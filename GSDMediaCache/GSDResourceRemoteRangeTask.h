//
//  GSDResourceRemoteFetchOperation.h
//  GSDMediaCache
//
//  Created by xq on 2021/7/23.
//  Copyright (c) 2021 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "GSDRangeItem.h"
#import "GSDResourceRangeTask.h"

NS_ASSUME_NONNULL_BEGIN

@class GSDResourceRemoteRangeTask;

@protocol GSDResourceRemoteRangeTaskDelegate <NSObject>

@optional

- (void)remoteRangeTask:(GSDResourceRemoteRangeTask *)remoteRangeTask didReceiveResponse:(NSURLResponse *)response;

- (void)remoteRangeTask:(GSDResourceRemoteRangeTask *)remoteRangeTask didReceiveData:(NSData *)data;

- (void)remoteRangeTask:(GSDResourceRemoteRangeTask *)remoteRangeTask didReceiveData:(NSData *)data offset:(long long)offset;

- (void)remoteRangeTask:(GSDResourceRemoteRangeTask *)remoteRangeTask didCompleteWithError:(nullable NSError *)error;

@end

@interface GSDResourceRemoteRangeTask : NSObject <NSURLSessionTaskDelegate, NSURLSessionDataDelegate, GSDResourceRangeTask>

- (instancetype)initWithResourceURL:(NSURL *)resourceURL rangeItem:(GSDRangeItem *)rangeItem inSession:(nullable NSURLSession *)session;

//从属的fetch。debug用
@property (nonatomic, copy) NSString *fetchOperationID;

@property (nonatomic, weak) id<GSDResourceRemoteRangeTaskDelegate> delegate;

@property (strong, nonatomic, readonly, nullable) NSURLRequest *request;

@property (strong, nonatomic, readonly, nullable) NSURLResponse *response;

@property (strong, nonatomic, readonly, nullable) NSURLSessionTask *dataTask;

- (void)start;

- (void)cancel;


@end

NS_ASSUME_NONNULL_END
