//
//  AVAssetResourceLoadingRequest+AddressID.m
//  GSDMediaCache
//
//  Created by xq on 2021/7/23.
//  Copyright (c) 2021 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "AVAssetResourceLoadingRequest+AddressID.h"

@implementation AVAssetResourceLoadingRequest (AddressID)

- (NSString *)addressID {
    NSString *addr = [NSString stringWithFormat:@"%p", self];
    return addr;
}

@end
