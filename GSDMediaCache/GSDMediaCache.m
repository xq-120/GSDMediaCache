//
//  GSDMediaCache.m
//  GSDMediaCache
//
//  Created by xq on 2020/12/6.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "GSDMediaCache.h"
#import <CommonCrypto/CommonDigest.h>
#import "NSError+GSDHelper.h"
#import <pthread.h> //pthread_mutex
#import "GSDMediaCacheLogDefine.h"


/**
 缓存路径：
 path/
     /data/
          /xxx.rif
          /xxx.mp4
 */

static const NSInteger kMaxLocalDataPerPage = 1 * 1024 * 1024; //1MiB
static const NSInteger kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7; // 1 week
static const NSInteger kDefaultCacheMaxCacheSize = 1 * 1024 * 1024 * 1024; //1GiB

@interface GSDMediaCache ()

@property (copy, nonatomic) NSString *path;
@property (copy, nonatomic) NSString *dataPath;
@property (strong, nonatomic) NSFileManager *fileManager;
@property (strong, nonatomic) dispatch_queue_t ioQueue;
@property (nonatomic, assign) pthread_rwlock_t rwlock;

@end

@implementation GSDMediaCache

+ (nonnull instancetype)sharedMediaCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        cachePath = [cachePath stringByAppendingPathComponent:@"com.xq.GSDMediaCache"];
        instance = [[self alloc] initWithPath:cachePath];
    });
    return instance;
}

- (nonnull instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _ioQueue = dispatch_queue_create("com.xq.GSDMediaCache", DISPATCH_QUEUE_CONCURRENT);
        
        pthread_rwlock_init(&self->_rwlock, NULL);
        
        _path = path.copy;
        _dataPath = [path stringByAppendingPathComponent:@"data"];
        _fileManager = [NSFileManager new];
        
        _maxCacheAge = kDefaultCacheMaxCacheAge;
        _maxCacheSize = kDefaultCacheMaxCacheSize;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundDeleteOldFiles)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }

    return self;
}

- (void)storeResourceInfo:(GSDResourceInfoModel *)resourceInfo
                   forKey:(NSString *)key
               completion:(void (^)(void))completionBlock {
    if (!resourceInfo || !key) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    
    dispatch_async(self.ioQueue, ^{
        pthread_rwlock_wrlock(&self->_rwlock);
        [self _storeResourceInfoToDisk:resourceInfo forKey:key];
        pthread_rwlock_unlock(&self->_rwlock);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock();
            }
        });
    });
}

- (void)storeMediaDataWithContentLength:(long long)contentLength
                        currentOffset:(long long)currentOffset
                                 data:(NSData *)data
                               forKey:(NSString *)key
                           completion:(void (^)(void))completionBlock {
    if (!data || !key) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    
    dispatch_async(self.ioQueue, ^{
        pthread_rwlock_wrlock(&self->_rwlock);
        
        //将数据写入文件
        NSError *error = nil;
        [self _storeMediaDataToDiskWithContentLength:contentLength currentOffset:currentOffset data:data forKey:key error:&error];
        if (!error) {
            GSDResourceRangeTable *resourceRangeTable = [self diskResourceRangeTableForKey:key];
            if (resourceRangeTable == nil) { //第一次存储时肯定没有
                resourceRangeTable = [GSDResourceRangeTable new];
                resourceRangeTable.contentLength = contentLength;
            }
            GSDRangeItem *rangeItem = [[GSDRangeItem alloc] initWithStart:currentOffset end:currentOffset + data.length - 1 type:GSDRangeItemTypeLocal];
            //更新区间表
            [resourceRangeTable addRangeItem:rangeItem];
            [self _storeResourceRangeTableToDisk:resourceRangeTable forKey:key];
        }
        
        pthread_rwlock_unlock(&self->_rwlock);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock();
            }
        });
    });
}

- (void)_storeResourceInfoToDisk:(nullable GSDResourceInfoModel *)resourceInfo forKey:(nullable NSString *)key {
    if (!resourceInfo || !key) {
        return;
    }
    
    if (![self.fileManager fileExistsAtPath:self.dataPath]) {
        [self.fileManager createDirectoryAtPath:self.dataPath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    NSString *rifFilePath = [self resourceInfoFilePathForKey:key];
    [NSKeyedArchiver archiveRootObject:resourceInfo toFile:rifFilePath];
}

- (void)_storeResourceRangeTableToDisk:(nullable GSDResourceRangeTable *)resourceRangeTable forKey:(nullable NSString *)key {
    if (!resourceRangeTable || !key) {
        return;
    }
    
    if (![self.fileManager fileExistsAtPath:self.dataPath]) {
        [self.fileManager createDirectoryAtPath:self.dataPath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    NSString *rtaFilePath = [self resourceRangeTableFilePathForKey:key];
    [NSKeyedArchiver archiveRootObject:resourceRangeTable toFile:rtaFilePath];
}

- (void)_storeMediaDataToDiskWithContentLength:(long long)contentLength currentOffset:(long long)currentOffset data:(NSData *)data forKey:(NSString *)key error:(NSError **)error {
    if (!data || !key || contentLength == 0) {
        return;
    }
    
    if (![self.fileManager fileExistsAtPath:self.dataPath]) { //创建目录
        [self.fileManager createDirectoryAtPath:self.dataPath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    NSString *mediaFilePath = [self mediaFilePathForKey:key];
    
    NSFileHandle *writingFileHandle = nil;
    BOOL isNeedTruncateFile = NO;
    if (![self.fileManager fileExistsAtPath:mediaFilePath]) { //创建文件
        [self.fileManager createFileAtPath:mediaFilePath contents:nil attributes:nil];
        isNeedTruncateFile = YES;
    }
    writingFileHandle = [NSFileHandle fileHandleForWritingAtPath:mediaFilePath];
    
    @try {
        if (isNeedTruncateFile) {
            [writingFileHandle truncateFileAtOffset:contentLength];
        }
        [writingFileHandle seekToFileOffset:currentOffset];
        [writingFileHandle writeData:data];
        [writingFileHandle synchronizeFile];
        [writingFileHandle closeFile];
    }
    @catch (NSException *exception) {
        LogError(@"write to file error");
        *error = [NSError gsd_errorWithCode:GSDAudioCacheErrorWriteToFileError msg:@"write to file error"];
    }
}

- (NSData *)mediaDataWithStartOffset:(long long)startOffset length:(long long)numberOfBytesToRespondWith forKey:(NSString *)key {
    pthread_rwlock_rdlock(&self->_rwlock);
    
    NSData *retData = nil;
    NSString *mediaFilePath = [self mediaFilePathForKey:key];
    NSFileHandle *readingFileHandle = [NSFileHandle fileHandleForReadingAtPath:mediaFilePath];
    @try {
        [readingFileHandle seekToFileOffset:startOffset];
        retData = [readingFileHandle readDataOfLength:numberOfBytesToRespondWith];
        [readingFileHandle closeFile];
    }
    @catch (NSException *exception) {
        LogError(@"read cached data error %@",exception);
    }
    
    pthread_rwlock_unlock(&self->_rwlock);
    return retData;
}

- (void)mediaDataWithStartOffset:(long long)startOffset
                          length:(long long)numberOfBytesToRespondWith
                          forKey:(NSString *)key
                      completion:(nullable void (^)(NSData * _Nullable, NSError * _Nullable))completionBlock {
    dispatch_async(self.ioQueue, ^{
        pthread_rwlock_rdlock(&self->_rwlock);
        
        NSString *mediaFilePath = [self mediaFilePathForKey:key];
        NSFileHandle *readingFileHandle = [NSFileHandle fileHandleForReadingAtPath:mediaFilePath];
        
        @autoreleasepool {
            NSError *error = nil;
            NSData *retData = [self mediaDataWithStartOffset:startOffset length:numberOfBytesToRespondWith readingFileHandle:readingFileHandle error:&error];
            [readingFileHandle closeFile];
            
            if (completionBlock) {
                completionBlock(retData, error);
            }
        }
        
        pthread_rwlock_unlock(&self->_rwlock);
    });
}

- (NSOperation *)mediaDataWithStartOffset:(long long)startOffset length:(long long)numberOfBytesToRespondWith forKey:(nonnull NSString *)key didLoadData:(nullable void (^)(NSInteger, NSData * _Nonnull))didLoadDataBlock completion:(nullable void (^)(long long, NSError * _Nullable))completionBlock {
    if (didLoadDataBlock == nil) {
        if (completionBlock) {
            completionBlock(numberOfBytesToRespondWith, nil);
        }
        return [NSOperation new];
    }

    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();

    NSOperation *operation = [NSOperation new];
    dispatch_async(self.ioQueue, ^{

        pthread_rwlock_rdlock(&self->_rwlock);

        long long off = startOffset;
        long long total = numberOfBytesToRespondWith;
        long long numberOfBytesResponded = 0;
        NSInteger sliceIndex = 0;
        NSError *error = nil;

        NSString *mediaFilePath = [self mediaFilePathForKey:key];
        NSFileHandle *readingFileHandle = [NSFileHandle fileHandleForReadingAtPath:mediaFilePath];
        if (readingFileHandle == nil) {
            error = [NSError gsd_errorWithCode:GSDAudioCacheErrorReadingFileHandleNilError msg:@"reading file handle nil error"];

            CFAbsoluteTime elapsed = (CFAbsoluteTimeGetCurrent() - startTime);
            LogInfo(@"读取%lld-%lld数据完成!!!,请求长度：%lld,实际返回：%lld,是否取消：%d，总耗时:%fms", startOffset, startOffset + numberOfBytesToRespondWith - 1, numberOfBytesToRespondWith, numberOfBytesResponded, operation.isCancelled, elapsed * 1000.0);

            pthread_rwlock_unlock(&self->_rwlock);

            if (completionBlock) {
                completionBlock(numberOfBytesResponded, error);
            }

            return;
        }
        
        while (total > 0) {
            if (operation.isCancelled) {
                error = [NSError gsd_errorWithCode:GSDAudioCacheErrorCancelled msg:@"取消操作"];
                break;
            }

            long long currReadLength = total;
            if (currReadLength > kMaxLocalDataPerPage) {
                currReadLength = kMaxLocalDataPerPage;
            }

            @autoreleasepool { //没啥影响，加不加无所谓
                NSData *mediaData = [self mediaDataWithStartOffset:off length:currReadLength readingFileHandle:readingFileHandle error:&error];
                if (error) {
                    break;
                }
                if (didLoadDataBlock) {
                    didLoadDataBlock(sliceIndex, mediaData);
                }
            }

            off += currReadLength;
            total -= currReadLength;
            sliceIndex += 1;
            numberOfBytesResponded += currReadLength;
        }

        [readingFileHandle closeFile];

        if (operation.isCancelled && error == nil) {
            error = [NSError gsd_errorWithCode:GSDAudioCacheErrorCancelled msg:@"取消操作"];
        }

        CFAbsoluteTime elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000;
        LogInfo(@"线程：%@，读取%lld-%lld数据完成!!!,请求长度：%lld,实际返回：%lld,是否取消：%d，总耗时:%fms", [NSThread currentThread], startOffset, startOffset + numberOfBytesToRespondWith - 1, numberOfBytesToRespondWith, numberOfBytesResponded, operation.isCancelled, elapsed);
        if (elapsed > 1000) {
            LogWarn(@"warning!!!读数据时间过长：%fms", elapsed);
        }
        pthread_rwlock_unlock(&self->_rwlock);

        if (completionBlock) {
            completionBlock(numberOfBytesResponded, error);
        }
    });
    return operation;
}

- (NSData *)mediaDataWithStartOffset:(long long)startOffset length:(long long)numberOfBytesToRespondWith readingFileHandle:(NSFileHandle *)readingFileHandle error:(NSError **)error {
    if (readingFileHandle == nil) {
        *error = [NSError gsd_errorWithCode:GSDAudioCacheErrorReadingFileHandleNilError msg:@"reading file handle nil error"];
        return nil;
    }
    
    @try {
        [readingFileHandle seekToFileOffset:startOffset];
        
        NSData *retData = nil;
        @autoreleasepool {
            retData = [readingFileHandle readDataOfLength:numberOfBytesToRespondWith];
        }
        //TODO:这里有待讨论，如果剩余数据<请求数据，那么返回全部剩余数据也未尝不可。
        if (retData == nil || retData.length != numberOfBytesToRespondWith) {
            *error = [NSError gsd_errorWithCode:GSDAudioCacheErrorReadCachedDataLengthError msg:@"read cached data length error"];
            return nil;
        }
        return retData;
    }
    @catch (NSException *exception) {
        LogError(@"read cached data error %@",exception);
        *error = [NSError gsd_errorWithCode:GSDAudioCacheErrorReadCachedDataError msg:@"read cached data error"];
        return nil;
    }
}

#pragma mark - cacheQuery

- (GSDResourceInfoModel *)resourceInfoFromCacheForKey:(NSString *)key {
    if (key.length <= 0) {
        return nil;
    }
    pthread_rwlock_rdlock(&self->_rwlock);
    GSDResourceInfoModel *resourceInfo = [self diskResourceInfoForKey:key];
    pthread_rwlock_unlock(&self->_rwlock);
    return resourceInfo;
}

- (nullable GSDResourceInfoModel *)diskResourceInfoForKey:(NSString *)key {
    if (key.length <= 0) {
        return nil;
    }
    NSString *rifFilePath = [self resourceInfoFilePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:rifFilePath options:0 error:nil];
    if (data) {
        GSDResourceInfoModel *resourceInfo = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        return resourceInfo;
    }
    return nil;
}

- (GSDResourceRangeTable *)resourceRangeTableFromCacheForKey:(NSString *)key {
    if (key.length <= 0) {
        return nil;
    }
    pthread_rwlock_rdlock(&self->_rwlock);
    GSDResourceRangeTable *resourceRangeTable = [self diskResourceRangeTableForKey:key];
    pthread_rwlock_unlock(&self->_rwlock);
    return resourceRangeTable;
}

- (nullable GSDResourceRangeTable *)diskResourceRangeTableForKey:(NSString *)key {
    if (key.length <= 0) {
        return nil;
    }
    NSString *rtaFilePath = [self resourceRangeTableFilePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:rtaFilePath options:0 error:nil];
    if (data) {
        GSDResourceRangeTable *resourceRangeTable = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        return resourceRangeTable;
    }
    return nil;
}

- (BOOL)isMediaFileExistWithKey:(NSString *)key {
    pthread_rwlock_rdlock(&self->_rwlock);
    BOOL isMediaFileExist = [self.fileManager fileExistsAtPath:[self mediaFilePathForKey:key]];
    pthread_rwlock_unlock(&self->_rwlock);
    return isMediaFileExist;
}

- (BOOL)isMediaCompleteCachedWithKey:(NSString *)key {
    pthread_rwlock_rdlock(&self->_rwlock);
    BOOL isMediaFileExist = [self.fileManager fileExistsAtPath:[self mediaFilePathForKey:key]];
    GSDResourceInfoModel *resourceInfo = [self diskResourceInfoForKey:key];
    GSDResourceRangeTable *resourceRangeTable = [self diskResourceRangeTableForKey:key];
    BOOL ret = isMediaFileExist && resourceInfo && resourceRangeTable && [resourceRangeTable isRangeComplete];
    pthread_rwlock_unlock(&self->_rwlock);
    return ret;
}

#pragma mark - cacheDelete

- (void)deleteCacheWithKey:(NSString *)key {
    pthread_rwlock_wrlock(&self->_rwlock);
    NSString *rifFilePath = [self resourceInfoFilePathForKey:key] ?: @"";
    NSString *rtaFilePath = [self resourceRangeTableFilePathForKey:key] ?: @"";
    NSString *mediaFilePath = [self mediaFilePathForKey:key] ?: @"";
    NSArray *filesPath = @[mediaFilePath, rifFilePath, rtaFilePath];
    for (NSString *path in filesPath) {
        NSURL *fileURL = [NSURL fileURLWithPath:path];
        [self.fileManager removeItemAtURL:fileURL error:nil];
    }
    pthread_rwlock_unlock(&self->_rwlock);
}

- (void)calculateSizeWithCompletion:(void (^)(NSUInteger))completionBlock {
    NSURL *dataCacheURL = [NSURL fileURLWithPath:self.dataPath isDirectory:YES];

    dispatch_async(self.ioQueue, ^{
        
        pthread_rwlock_rdlock(&self->_rwlock);
        
        NSUInteger totalSize = 0;
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:dataCacheURL
                                                   includingPropertiesForKeys:@[NSFileSize]
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];
        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
        }
        
        pthread_rwlock_unlock(&self->_rwlock);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock(totalSize);
            }
        });
    });
}

- (void)clearDiskWithCompletion:(nullable void(^)(void))completionBlock {
    dispatch_async(self.ioQueue, ^{
        pthread_rwlock_wrlock(&self->_rwlock);
        [self.fileManager removeItemAtPath:self.dataPath error:nil];
        [self.fileManager createDirectoryAtPath:self.dataPath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL];
        pthread_rwlock_unlock(&self->_rwlock);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock();
            }
        });
    });
}

- (void)deleteOldFilesWithCompletionBlock:(nullable void(^)(void))completionBlock {
    dispatch_async(self.ioQueue, ^{
        pthread_rwlock_wrlock(&self->_rwlock);
        
        NSURL *dataCacheURL = [NSURL fileURLWithPath:self.dataPath isDirectory:YES];
        NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];

        // This enumerator prefetches useful properties for our cache files.
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:dataCacheURL
                                                   includingPropertiesForKeys:resourceKeys
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];

        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.maxCacheAge];
        NSMutableDictionary<NSURL *, NSDictionary<NSString *, id> *> *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;

        // Enumerate all of the files in the cache directory.  This loop has two purposes:
        //
        //  1. Removing files that are older than the expiration date.
        //  2. Storing file attributes for the size-based cleanup pass.
        NSMutableArray<NSURL *> *urlsToDelete = [[NSMutableArray alloc] init];
        for (NSURL *fileURL in fileEnumerator) {
            NSError *error;
            NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];

            // Skip directories and errors.
            if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }

            // Remove files that are older than the expiration date;
            NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
            if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                [urlsToDelete addObject:fileURL];
                continue;
            }

            // Store a reference to this file and account for its total size.
            NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            LogError(@"文件：%@，totalFileAllocatedSize：%@", fileURL, totalAllocatedSize);
            currentCacheSize += totalAllocatedSize.unsignedIntegerValue;
            cacheFiles[fileURL] = resourceValues;
        }
        
        for (NSURL *fileURL in urlsToDelete) {
            [self.fileManager removeItemAtURL:fileURL error:nil];
        }
        
        LogError(@"已经清理过期缓存：%@", urlsToDelete);
        LogError(@"当前缓存大小：%lu", currentCacheSize);
        
        // If our remaining disk cache exceeds a configured maximum size, perform a second
        // size-based cleanup pass.  We delete the oldest files first.
        if (self.maxCacheSize > 0 && currentCacheSize > self.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.maxCacheSize / 2;
            
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                                     }];

            // Delete files until we fall below our desired cache size.
            NSMutableArray *deletedArr = [NSMutableArray array];
            NSMutableSet *deletedFileSet = [NSMutableSet set];
            NSMutableArray *remain = sortedFiles.mutableCopy;
            for (NSURL *fileURL in sortedFiles) {
                if ([self.fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                    
                    [deletedArr addObject:fileURL];
                    NSString *fileMainName = [fileURL.lastPathComponent componentsSeparatedByString:@"."].firstObject;
                    if (![deletedFileSet containsObject:fileMainName]) {
                        [deletedFileSet addObject:fileMainName];
                    }
                    [remain removeObject:fileURL];
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
            
            //获取未删干净的缓存
            NSMutableArray *fragment = [NSMutableArray array];
            for (NSURL *fileURL in remain) {
                NSString *fileMainName = [fileURL.lastPathComponent componentsSeparatedByString:@"."].firstObject;
                if ([deletedFileSet containsObject:fileMainName]) {
                    [fragment addObject:fileURL];
                }
            }

            //删除fragment
            for (NSURL *fileURL in fragment) {
                if ([self.fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;

                    [deletedArr addObject:fileURL];
                    [remain removeObject:fileURL];
                }
            }
            LogError(@"超出maxCacheSize，sortedFiles：%@", sortedFiles);
            LogError(@"超出maxCacheSize，deletedFileSet：%@", deletedFileSet);
            LogError(@"超出maxCacheSize，remain：%@", remain);
            LogError(@"超出maxCacheSize，fragment：%@", fragment);
            LogError(@"超出maxCacheSize，清理缓存：%@", deletedArr);
            LogError(@"当前缓存大小：%lu", currentCacheSize);
        }
        
        pthread_rwlock_unlock(&self->_rwlock);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock();
            }
        });
    });
}

- (void)backgroundDeleteOldFiles {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];

    // Start the long-running task and return immediately.
    [self deleteOldFilesWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}

#pragma mark - file

/// 音视频的数据文件路径
/// @param key key
- (NSString *)mediaFilePathForKey:(NSString *)key {
    if (key.length <= 0) {
        return nil;
    }
    NSString *filename = [self mediaFilenameForKey:key];
    return [self.dataPath stringByAppendingPathComponent:filename];
}

- (nullable NSString *)mediaFilenameForKey:(nullable NSString *)key {
    NSString *md5Key = [self md5String:key];
    NSURL *keyURL = [NSURL URLWithString:key];
    NSString *ext = keyURL ? keyURL.pathExtension : key.pathExtension;
    NSString *filename = [NSString stringWithFormat:@"%@%@", md5Key, ext.length == 0 ? @"" : [NSString stringWithFormat:@".%@", ext]];
    return filename;
}

/// 音视频的元数据文件路径
/// @param key key
- (nullable NSString *)resourceInfoFilePathForKey:(nullable NSString *)key {
    if (key.length <= 0) {
        return nil;
    }
    NSString *filename = [self resourceInfoFilenameForKey:key];
    return [self.dataPath stringByAppendingPathComponent:filename];
}

- (nullable NSString *)resourceInfoFilenameForKey:(NSString *)key {
    if (key.length <= 0) {
        return nil;
    }
    NSString *md5Key = [self md5String:key];
    NSString *ext = @".rif";
    NSString *filename = [NSString stringWithFormat:@"%@%@", md5Key, ext];
    return filename;
}

/// 音视频的区间记录表文件路径
/// @param key key
- (nullable NSString *)resourceRangeTableFilePathForKey:(nullable NSString *)key {
    if (key.length <= 0) {
        return nil;
    }
    NSString *filename = [self resourceRangeTableFilenameForKey:key];
    return [self.dataPath stringByAppendingPathComponent:filename];
}

- (nullable NSString *)resourceRangeTableFilenameForKey:(NSString *)key {
    if (key.length <= 0) {
        return nil;
    }
    NSString *md5Key = [self md5String:key];
    NSString *ext = @".rta";
    NSString *filename = [NSString stringWithFormat:@"%@%@", md5Key, ext];
    return filename;
}

- (NSString *)md5String:(NSString *)string {
    const char *str = string.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *ret = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15]];
    return ret;
}

@end

