//
//  GSDResourceRangeTable.m
//  GSDMediaCache
//
//  Created by xq on 2022/1/7.
//  Copyright (c) 2022 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "GSDResourceRangeTable.h"
#import "GSDRangeUtility.h"
#import <YYModel/YYModel.h>

@interface GSDResourceRangeTable () <YYModel>

@end

@implementation GSDResourceRangeTable

- (void)addRangeItem:(GSDRangeItem *)rangeItem {
    NSArray *rangeItems = [GSDRangeUtility rangeItems:self.rangeItems addRangeItem:rangeItem];
    self.rangeItems = rangeItems;
}

- (NSArray<GSDRangeItem *> *)separateLocalRangeItemsWithReqeustRangeItem:(GSDRangeItem *)rangeItem {
    NSArray *rangeItems = [GSDRangeUtility separateLocalRangeItems:self.rangeItems withReqeustRangeItem:rangeItem];
    return rangeItems;
}

- (BOOL)isRangeComplete {
    if (self.rangeItems.count == 1 && self.contentLength > 0) {
        GSDRangeItem *item = self.rangeItems.firstObject;
        return item.end - item.start + 1 == self.contentLength ? YES : NO;
    }
    return NO;
}

//重写以下几个方法
- (void)encodeWithCoder:(NSCoder*)aCoder {
    [self yy_modelEncodeWithCoder:aCoder];
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    self = [super init];
    return [self yy_modelInitWithCoder:aDecoder];
}

- (id)copyWithZone:(NSZone*)zone {
    return [self yy_modelCopy];
}

- (NSUInteger)hash {
    return [self yy_modelHash];
}

- (BOOL)isEqual:(id)object {
    return [self yy_modelIsEqual:object];
}

@end
