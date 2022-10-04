//
//  GSDResourceRequestOperation.h
//  GSDMediaCache
//
//  Created by xq on 2021/7/28.
//  Copyright (c) 2021 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol GSDResourceRangeTask <NSObject>

//从属的fetch。debug用
@property (nonatomic, copy) NSString *fetchOperationID;

- (void)start;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
