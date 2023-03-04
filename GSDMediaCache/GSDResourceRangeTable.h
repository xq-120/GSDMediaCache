//
//  GSDResourceRangeTable.h
//  GSDMediaCache
//
//  Created by xq on 2022/1/7.
//  Copyright (c) 2022 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "GSDRangeItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface GSDResourceRangeTable : NSObject <NSCoding, NSCopying>

@property (nonatomic, assign) long long contentLength;

/// 区间记录表。记录当前下载的数据区间.
/// 当资源下载完成时，该数组只会存在一个元素([0, contentLength-1])
@property (nonatomic, copy, nullable) NSArray<GSDRangeItem *> *rangeItems;

/// 添加一个local类型的rangeItem。添加后可能会合并区间，rangeItems会发生变化。
/// @param rangeItem 数据区间,必须是local类型。
- (void)addRangeItem:(GSDRangeItem *)rangeItem;

/// 根据请求的数据区间将rangeItems拆分为[...remote,local,remote,local...]的区间列表
/// @param rangeItem 数据区间。
- (NSArray<GSDRangeItem *> *)separateLocalRangeItemsWithReqeustRangeItem:(GSDRangeItem *)rangeItem;

- (BOOL)isRangeComplete;

@end

NS_ASSUME_NONNULL_END
