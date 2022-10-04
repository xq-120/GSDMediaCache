//
//  NSURL+GSDHelper.h
//  GSDMediaCache
//
//  Created by xq on 2020/12/1.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (GSDHelper)

/**
 替换URL的scheme
 
 @param scheme 必须为一个有效字符串。（比如：不能为空）
 @return 替换后的URL
 */
- (nullable NSURL *)gsd_URLByReplacingScheme:(NSString *)scheme;

- (BOOL)gsd_isCustomSchemeURLByContainningSuffix:(NSString *)suffix;

- (NSURL *)gsd_customSchemeURLByAppendingSuffix:(NSString *)suffix;

- (NSURL *)gsd_recoverCustomSchemeURLByRemovingSuffix:(NSString *)suffix;

@end

NS_ASSUME_NONNULL_END
