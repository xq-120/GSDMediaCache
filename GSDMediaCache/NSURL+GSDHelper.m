//
//  NSURL+GSDHelper.m
//  GSDMediaCache
//
//  Created by xq on 2020/12/1.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "NSURL+GSDHelper.h"

@implementation NSURL (GSDHelper)

- (NSURL *)gsd_URLByReplacingScheme:(NSString *)scheme {
    NSURL *resultURL = nil;
    @try {
        NSURLComponents *component = [[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:NO];
        component.scheme = scheme;
        resultURL = component.URL;
    } @catch (NSException *exception) {
        NSLog(@"replace scheme异常：%@", exception);
    } @finally {
        return resultURL;
    }
}

- (BOOL)gsd_isCustomSchemeURLByContainningSuffix:(NSString *)suffix {
    BOOL isCustomScheme = [self.scheme hasSuffix:suffix];
    return isCustomScheme;
}

- (NSURL *)gsd_customSchemeURLByAppendingSuffix:(NSString *)suffix {
    NSString *customScheme = [self.scheme stringByAppendingString:suffix];
    NSURL *newUrl = [self gsd_URLByReplacingScheme:customScheme];
    return newUrl;
}

- (NSURL *)gsd_recoverCustomSchemeURLByRemovingSuffix:(NSString *)suffix {
    NSString *originScheme = [self.scheme stringByReplacingOccurrencesOfString:suffix withString:@""];
    NSURL *newUrl = [self gsd_URLByReplacingScheme:originScheme];
    return newUrl;
}

@end
