//
//  GSDRangeItem.m
//  GSDMediaCache
//
//  Created by xq on 2021/7/26.
//  Copyright (c) 2021 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "GSDRangeItem.h"
#import <YYModel/YYModel.h>

@interface GSDRangeItem() <YYModel>

@end

@implementation GSDRangeItem

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@:%p, type:%ld, range:%lld-%lld, length:%lld>", self.class, self, (long)_type, _start, _end, [self length]];
}

- (instancetype)initWithStart:(long long)start end:(long long)end type:(GSDRangeItemType)type {
    if (end < start) { //非法区间
        NSLog(@"非法区间:start:%lld,end:%lld", start, end);
        return nil;
    }
    self = [super init];
    if (self) {
        _start = start;
        _end = end;
        _type = type;
    }
    return self;
}

- (long long)length {
    return self.end - self.start + 1;
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
