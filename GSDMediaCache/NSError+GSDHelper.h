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

#import <Foundation/Foundation.h>

@interface NSError (GSDHelper)

+ (instancetype)gsd_errorWithDomain:(NSString *)domain code:(NSInteger)code msg:(NSString *)msg;

+ (instancetype)gsd_errorWithCode:(NSInteger)code msg:(NSString *)msg;

@end
