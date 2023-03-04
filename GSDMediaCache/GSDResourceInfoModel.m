//
//  GSDResourceInfoModel.m
//  GSDMediaCache
//
//  Created by xq on 2022/1/5.
//  Copyright (c) 2022 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "GSDResourceInfoModel.h"
#import <YYModel/YYModel.h>

@interface GSDResourceInfoModel () <YYModel>

@end

@implementation GSDResourceInfoModel

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
