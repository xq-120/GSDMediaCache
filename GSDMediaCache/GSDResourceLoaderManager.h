//
//  GSDPlayerResourceLoaderManager.h
//  GSDMediaCache
//
//  Created by xq on 2020/12/1.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GSDResourceLoaderManager : NSObject <AVAssetResourceLoaderDelegate>

+ (instancetype)sharedManager;

- (AVURLAsset *)customSchemeAssetWithURL:(NSURL *)URL options:(nullable NSDictionary<NSString *, id> *)options;

- (void)cancelAllLoaders;

- (void)cancelLoaderWithURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
