//
//  GSDResourceInfoModel.h
//  GSDMediaCache
//
//  Created by xq on 2022/1/5.
//  Copyright (c) 2022 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "GSDRangeItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface GSDResourceInfoModel : NSObject <NSCoding, NSCopying>

@property (nonatomic, copy) NSURL *resourceURL;

/// 2^64≈1.8x10^19,10^12=1TB,足以满足目前所有的音视频大小。
@property (nonatomic, assign) long long contentLength;

@property (nonatomic, copy) NSString *mimeType;

@property (nonatomic, copy) NSString *UTIType;

@property (nonatomic, assign, getter=isByteRangeAccessSupported) BOOL byteRangeAccessSupported;

@property (nonatomic, copy) NSString *ETag;

@property (nonatomic, copy) NSString *lastModified;

@end

NS_ASSUME_NONNULL_END
