//
//  GSDResourceLocalFetchOperation.h
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
#import "GSDResourceInfoModel.h"

NS_ASSUME_NONNULL_BEGIN

@class GSDResourceLocalRangeTask;

@protocol GSDResourceLocalRangeTaskDelegate <NSObject>

@optional

- (void)localRangeTask:(GSDResourceLocalRangeTask *)localRangeTask didLoadResourceInfo:(GSDResourceInfoModel *)resourceInfo;

- (void)localRangeTask:(GSDResourceLocalRangeTask *)localRangeTask didReceiveData:(NSData *)data offset:(long long)offset;

- (void)localRangeTask:(GSDResourceLocalRangeTask *)localRangeTask didCompleteWithError:(nullable NSError *)error;

@end

@interface GSDResourceLocalRangeTask : NSObject <GSDResourceRangeTask>

- (instancetype)initWithResourceURL:(NSURL *)resourceURL rangeItem:(GSDRangeItem *)rangeItem;

@property (nonatomic, weak) id<GSDResourceLocalRangeTaskDelegate> delegate;

//从属的fetch。debug用
@property (nonatomic, copy) NSString *fetchOperationID;

- (void)start;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
