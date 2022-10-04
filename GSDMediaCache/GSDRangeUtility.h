//
//  GSDRangeUtility.h
//  GSDMediaCache
//
//  Created by xq on 2022/1/5.
//  Copyright (c) 2022 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "GSDRangeItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface GSDRangeUtility : NSObject

+ (NSArray<GSDRangeItem *> *)rangeItems:(nullable NSArray<GSDRangeItem *> *)rangeItems addRangeItem:(GSDRangeItem *)rangeItem;

+ (NSArray<GSDRangeItem *> *)separateLocalRangeItems:(nullable NSArray<GSDRangeItem *> *)rangeItems withReqeustRangeItem:(GSDRangeItem *)rangeItem;

@end

NS_ASSUME_NONNULL_END
