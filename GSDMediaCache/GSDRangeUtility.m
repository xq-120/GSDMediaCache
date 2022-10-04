//
//  GSDRangeUtility.m
//  GSDMediaCache
//
//  Created by xq on 2022/1/5.
//  Copyright (c) 2022 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "GSDRangeUtility.h"

@implementation GSDRangeUtility

+ (NSArray<GSDRangeItem *> *)rangeItems:(NSArray<GSDRangeItem *> *)rangeItems addRangeItem:(GSDRangeItem *)rangeItem {
    if (rangeItem == nil) {
        return rangeItems;
    }
    NSMutableArray *mArr = [NSMutableArray arrayWithArray:rangeItems];
    [mArr addObject:rangeItem];
    NSArray *ret = [self mergeRangeItems:mArr];
    return ret;
}

+ (NSArray<GSDRangeItem *> *)mergeRangeItems:(NSMutableArray<GSDRangeItem *> *)rangeItems {
    if (rangeItems.count == 0) {
        return @[];
    }
    [rangeItems sortUsingComparator:^NSComparisonResult(GSDRangeItem *  _Nonnull obj1, GSDRangeItem *  _Nonnull obj2) {
        return obj1.start <= obj2.start ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSMutableArray *ret = [NSMutableArray array];
    [ret addObject:rangeItems.firstObject];
    for (int i = 1; i < rangeItems.count; i++) {
        GSDRangeItem *bItem = rangeItems[i];
        GSDRangeItem *aItem = ret[ret.count - 1];
        if (aItem.end < bItem.start - 1) {
            [ret addObject:bItem];
        } else {
            aItem.end = MAX(aItem.end, bItem.end);
        }
    }
    return ret;
}

+ (NSArray<GSDRangeItem *> *)separateLocalRangeItems:(NSArray<GSDRangeItem *> *)rangeItems withReqeustRangeItem:(GSDRangeItem *)rangeItem {
    if (rangeItems == nil) {
        return rangeItem == nil ? @[] : @[rangeItem];
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    
    long long start = rangeItem.start;
    long long end = rangeItem.end;
    
    for (int i = 0; i < rangeItems.count; i++) {
        GSDRangeItem *aItem = rangeItems[i];
        if (start < aItem.start) {
            if (end < aItem.start) {
                GSDRangeItem *item = [[GSDRangeItem alloc] initWithStart:start end:end type:GSDRangeItemTypeRemote];
                [ret addObject:item];
                break;
            } else if (end >= aItem.start && end <= aItem.end) {
                GSDRangeItem *item0 = [[GSDRangeItem alloc] initWithStart:start end:aItem.start-1 type:GSDRangeItemTypeRemote];
                [ret addObject:item0];
                GSDRangeItem *item1 = [[GSDRangeItem alloc] initWithStart:aItem.start end:end type:GSDRangeItemTypeLocal];
                [ret addObject:item1];
                break;
            } else {
                GSDRangeItem *item0 = [[GSDRangeItem alloc] initWithStart:start end:aItem.start-1 type:GSDRangeItemTypeRemote];
                [ret addObject:item0];
                GSDRangeItem *item1 = [[GSDRangeItem alloc] initWithStart:aItem.start end:aItem.end type:GSDRangeItemTypeLocal];
                [ret addObject:item1];
                start = aItem.end + 1;
            }
        } else if (start >= aItem.start && start <= aItem.end) {
            if (end < aItem.start) { //不可能
                
            } else if (end >= aItem.start && end <= aItem.end) {
                GSDRangeItem *item0 = [[GSDRangeItem alloc] initWithStart:start end:end type:GSDRangeItemTypeLocal];
                [ret addObject:item0];
                break;
            } else {
                GSDRangeItem *item1 = [[GSDRangeItem alloc] initWithStart:start end:aItem.end type:GSDRangeItemTypeLocal];
                [ret addObject:item1];
                start = aItem.end + 1;
            }
        } else {
            continue;
        }
        if (start > end) {
            break;
        }
    }
    GSDRangeItem *lastItem = ret.lastObject;
    if (lastItem == nil) {
        [ret addObject:rangeItem];
    } else if (lastItem.end < end) {
        GSDRangeItem *item0 = [[GSDRangeItem alloc] initWithStart:lastItem.end + 1 end:end type:GSDRangeItemTypeRemote];
        [ret addObject:item0];
    }
    return ret.copy;
}


@end
