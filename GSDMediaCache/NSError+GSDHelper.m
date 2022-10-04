//
//  NSError+GSDHelper.h
//  GSDMediaCache
//
//  Created by xq on 2020/12/3.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "NSError+GSDHelper.h"

@implementation NSError (GSDHelper)

+ (instancetype)gsd_errorWithDomain:(NSString *)domain code:(NSInteger)code msg:(NSString *)msg
{
    NSMutableDictionary *errReasonDict = [NSMutableDictionary dictionary];
    if (msg != nil) {
        [errReasonDict setObject:msg forKey:NSLocalizedDescriptionKey];
    }
    return [[self class] errorWithDomain:domain code:code userInfo:errReasonDict];
}

+ (instancetype)gsd_errorWithCode:(NSInteger)code msg:(NSString *)msg
{
    return [[self class] gsd_errorWithDomain:@"com.xq.GSDMediaCache" code:code msg:msg];
}


@end
