//
//  GSDMediaCache.h
//  GSDMediaCache
//
//  Created by xq on 2020/12/6.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "GSDResourceInfoModel.h"
#import "GSDResourceRangeTable.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GSDMediaCacheErrorCode)
{
    GSDAudioCacheErrorUnknown = 0,
    GSDAudioCacheErrorCancelled = -999,
    GSDAudioCacheErrorReadCachedDataError = -1000,
    GSDAudioCacheErrorReadCachedDataLengthError = -1001,
    GSDAudioCacheErrorReadingFileHandleNilError = -1002,
    GSDAudioCacheErrorWriteToFileError = -1003,
};

@interface GSDMediaCache : NSObject

+ (nonnull instancetype)sharedMediaCache;

/// 最大磁盘缓存时间,单位:seconds.默认1周=7*24*3600.
@property (assign, nonatomic) NSInteger maxCacheAge;

/// 最大磁盘缓存size,单位:bytes.默认1GiB.
@property (assign, nonatomic) NSUInteger maxCacheSize;

/// 异步存储音视频元信息
/// @param resourceInfo 音视频元信息
/// @param key 关联的键值,一般为URL.
/// @param completionBlock 完成回调
- (void)storeResourceInfo:(GSDResourceInfoModel *)resourceInfo
                   forKey:(NSString *)key
               completion:(nullable void(^)(void))completionBlock;

/// 异步存储音视频数据到磁盘.
///
/// note:数据存储成功后，内部会同时更新resourceInfo的区间记录表，全部缓存时区间记录表中将只有一个区间。
/// @param contentLength 音视频内容总长度(byte)
/// @param currentOffset 当前存储数据的偏移量。偏移量从0开始
/// @param data 将要存储的音视频数据
/// @param key 关联的键值,一般为URL.
/// @param completionBlock 完成回调(子线程)
- (void)storeMediaDataWithContentLength:(long long)contentLength
                          currentOffset:(long long)currentOffset
                                   data:(NSData *)data
                                 forKey:(NSString *)key
                             completion:(nullable void (^)(void))completionBlock;

/// 同步读取数据
/// @param startOffset 读取的起始偏移量
/// @param numberOfBytesToRespondWith 读取的长度
/// @param key 关联的键值,一般为URL.
- (nullable NSData *)mediaDataWithStartOffset:(long long)startOffset
                                       length:(long long)numberOfBytesToRespondWith
                                       forKey:(NSString *)key;
/// 异步读取数据
/// @param startOffset 读取的起始偏移量
/// @param numberOfBytesToRespondWith 读取的长度
/// @param key 关联的键值,一般为URL.
/// @param completionBlock 完成回调(子线程)
- (void)mediaDataWithStartOffset:(long long)startOffset
                          length:(long long)numberOfBytesToRespondWith
                          forKey:(NSString *)key
                      completion:(nullable void (^)(NSData * _Nullable data, NSError * _Nullable error))completionBlock;

/// 渐进式异步读取数据
/// @param startOffset 读取的起始偏移量
/// @param numberOfBytesToRespondWith 读取的长度
/// @param key 关联的键值,一般为URL.
/// @param didLoadDataBlock 进度回调(子线程).sliceIndex:第几块数据,data:读取的数据。
/// @param completionBlock 完成回调(子线程).numberOfBytesResponded:实际读取的数据长度,error:读取时是否出错，比如外部取消或读错误。
- (NSOperation *)mediaDataWithStartOffset:(long long)startOffset
                                   length:(long long)numberOfBytesToRespondWith
                                   forKey:(NSString *)key
                              didLoadData:(nullable void(^)(NSInteger sliceIndex, NSData *data))didLoadDataBlock
                               completion:(nullable void (^)(long long numberOfBytesResponded, NSError * _Nullable error))completionBlock;

/// 同步获取resourceInfo信息
/// @param key 关联的键值,一般为URL.
- (nullable GSDResourceInfoModel *)resourceInfoFromCacheForKey:(NSString *)key;

/// 同步获取resourceRangeTable信息
/// @param key 关联的键值,一般为URL.
- (nullable GSDResourceRangeTable *)resourceRangeTableFromCacheForKey:(NSString *)key;

/// 同步查询音视频缓存文件是否存在
///
/// note:存在不一定代表已经完全缓存
/// @param key 关联的键值,一般为URL.
- (BOOL)isMediaFileExistWithKey:(NSString *)key;

/// 同步查询音视频是否完全缓存
/// @param key 关联的键值,一般为URL.
/// @return YES:缓存完成,NO:部分缓存或没有缓存
- (BOOL)isMediaCompleteCachedWithKey:(NSString *)key;

/// 获取音视频文件的磁盘缓存路径
/// @param key 关联的键值,一般为URL.
- (NSString *)mediaFilePathForKey:(NSString *)key;

/// 删除指定key的缓存.
/// @param key 关联的键值,一般为URL.
- (void)deleteCacheWithKey:(NSString *)key;

/// 计算磁盘缓存文件大小，单位byte
/// @param completionBlock 完成回调
- (void)calculateSizeWithCompletion:(nullable void (^)(NSUInteger size))completionBlock;

/// 清除磁盘缓存。
/// @param completionBlock 完成回调
- (void)clearDiskWithCompletion:(nullable void(^)(void))completionBlock;

/// 删除旧缓存文件
/// @param completionBlock 完成回调
- (void)deleteOldFilesWithCompletionBlock:(nullable void(^)(void))completionBlock;

@end

NS_ASSUME_NONNULL_END
