//
//  GSDResourceLocalFetchOperation.m
//  GSDMediaCache
//
//  Created by xq on 2021/7/23.
//  Copyright (c) 2021 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "GSDResourceLocalRangeTask.h"
#import "NSError+GSDHelper.h"
#import "GSDMediaCache.h"
#import "GSDMediaCacheLogDefine.h"

@interface GSDResourceLocalRangeTask()

@property (nonatomic, strong, readonly) NSURL *resourceURL;

@property (nonatomic, strong, readonly) GSDRangeItem *rangeItem;

@property (nonatomic, strong) GSDMediaCache *mediaCache;

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;

@property (nonatomic, strong) NSOperation *localDataTask;

@property (assign, nonatomic) NSUInteger receivedSize;
@property (assign, nonatomic) NSUInteger nextOffset;

@end

@implementation GSDResourceLocalRangeTask

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@:%p, fetchOperationID:%@, range:%lld-%lld, length:%lld>", self.class, self, _fetchOperationID, _rangeItem.start, _rangeItem.end, _rangeItem.length];
}

- (void)dealloc {
    LogDebug(@"%@销毁, nextOffset:%ld, isCancelled:%d", self, self.nextOffset, self.isCancelled);
}

- (instancetype)initWithResourceURL:(NSURL *)resourceURL rangeItem:(GSDRangeItem *)rangeItem {
    self = [super init];
    if (self) {
        _resourceURL = resourceURL;
        _rangeItem = rangeItem;
        _mediaCache = [GSDMediaCache sharedMediaCache];
        _nextOffset = rangeItem.start;
    }
    return self;
}

// MARK: - Operation

- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            //通知外部已经取消。
            if (self.delegate && [self.delegate respondsToSelector:@selector(localRangeTask:didCompleteWithError:)]) {
                [self.delegate localRangeTask:self didCompleteWithError:[NSError gsd_errorWithCode:GSDAudioCacheErrorCancelled msg:@"取消请求"]];
            }
            [self reset];
            return;
        }
    }
    
    //这里不能写在锁里面，在某种情况下会造成死锁
    GSDResourceInfoModel *resourceInfo = [self.mediaCache resourceInfoFromCacheForKey:self.resourceURL.absoluteString];
    if (self.delegate && [self.delegate respondsToSelector:@selector(localRangeTask:didLoadResourceInfo:)]) {
        [self.delegate localRangeTask:self didLoadResourceInfo:resourceInfo];
    }
    
    __weak typeof(self) weakSelf = self;
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    GSDRangeItem *rangeItem = self.rangeItem;
    self.localDataTask = [self.mediaCache mediaDataWithStartOffset:rangeItem.start length:rangeItem.length forKey:self.resourceURL.absoluteString didLoadData:^(NSInteger sliceIndex, NSData * _Nonnull data) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return ;
        
        strongSelf.receivedSize += data.length;
        if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(localRangeTask:didReceiveData:offset:)]) {
            [strongSelf.delegate localRangeTask:strongSelf didReceiveData:data offset:strongSelf.nextOffset];
        }
        strongSelf.nextOffset += data.length;
    } completion:^(long long numberOfBytesResponded, NSError * _Nullable error) {
        
        CFAbsoluteTime endTime = (CFAbsoluteTimeGetCurrent() - startTime);
        LogInfo(@"本地请求完成:%@, error:%@, 返回数据长度:%llu, 耗时:%fms", weakSelf, error, numberOfBytesResponded, endTime * 1000.0);
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return ;
        
        @synchronized (strongSelf) {
            if (strongSelf.isCancelled) {
                return;
            }
            strongSelf.localDataTask = nil;
        }
        
        if (error && error.code != GSDAudioCacheErrorCancelled) {
            //其他本地读取失败情况，则转为远程请求。不太可能出现。
            long long start = rangeItem.start + numberOfBytesResponded;
            long long end = start + (rangeItem.length - numberOfBytesResponded) - 1;
            GSDRangeItem *retryRangeItem = [[GSDRangeItem alloc] initWithStart:start end:end type:GSDRangeItemTypeRemote];
            LogInfo(@"本地请求读取失败转为远程请求!!!,range:：%lld-%lld，请求总长度：%lld，op:%@", start, end, end - start + 1, strongSelf);
            
            if (![strongSelf.mediaCache isMediaFileExistWithKey:strongSelf.resourceURL.absoluteString] || retryRangeItem == nil) {
                [strongSelf.mediaCache deleteCacheWithKey:strongSelf.resourceURL.absoluteString];
                LogInfo(@"删除遗留无用缓存");
            }
        }
        if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(localRangeTask:didCompleteWithError:)]) {
            [strongSelf.delegate localRangeTask:strongSelf didCompleteWithError:error];
        }
        
        [strongSelf done];
    }];
    LogInfo(@"本地请求开始:%@, dataTask:%@", self, self.localDataTask);
}

- (void)cancel {
    @synchronized (self) {
        [self cancelInternal];
    }
}

- (void)cancelInternal {
    if (self.isCancelled) return;
    
    self.cancelled = YES;
    
    if (self.localDataTask) {
        [self.localDataTask cancel];
        self.localDataTask = nil;
    }
    
    //通知外部已经取消。
    if (self.delegate && [self.delegate respondsToSelector:@selector(localRangeTask:didCompleteWithError:)]) {
        [self.delegate localRangeTask:self didCompleteWithError:[NSError gsd_errorWithCode:GSDAudioCacheErrorCancelled msg:@"取消请求"]];
    }

    [self reset];
}

- (void)done {
    [self reset];
}

- (void)reset {
    @synchronized (self) {
        self.localDataTask = nil;
    }
}


@end
