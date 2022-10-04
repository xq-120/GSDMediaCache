//
//  GSDRangeItem.h
//  GSDMediaCache
//
//  Created by xq on 2021/7/26.
//  Copyright (c) 2021 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <YYModel.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GSDRangeItemType) {
    GSDRangeItemTypeRemote,
    GSDRangeItemTypeLocal,
};

@interface GSDRangeItem : NSObject <YYModel, NSCoding, NSCopying>

/// 偏移量从0开始.
@property (nonatomic, assign) long long start;

/// end必须>=start.
@property (nonatomic, assign) long long end;
@property (nonatomic, assign) GSDRangeItemType type;
@property (nonatomic, assign, readonly) long long length;

- (nullable instancetype)initWithStart:(long long)start end:(long long)end type:(GSDRangeItemType)type;

@end

NS_ASSUME_NONNULL_END
