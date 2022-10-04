//
//  GSDResourceRequestOperation.m
//  GSDMediaCache
//
//  Created by xq on 2020/12/6.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "GSDResourceFetchOperation.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "GSDMediaCache.h"
#import "GSDMediaCacheLogDefine.h"
#import "GSDResourceRemoteRangeTask.h"
#import "GSDResourceLocalRangeTask.h"
#import "NSError+GSDHelper.h"
#import "GSDResourceRangeTask.h"
#import "AVAssetResourceLoadingRequest+AddressID.h"


@interface GSDResourceFetchOperation () <GSDResourceRemoteRangeTaskDelegate, GSDResourceLocalRangeTaskDelegate>

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
@property (nonatomic, strong) GSDResourceInfoModel *resourceInfo;
@property (nonatomic, strong) GSDMediaCache *mediaCache;
@property (nonatomic, weak) NSURLSession *session;
@property (nonatomic, strong) NSMutableArray *rangeTasks;
@property (nonatomic, strong) id<GSDResourceRangeTask> currentRangeTask;

@end

@implementation GSDResourceFetchOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@:%p, fetchOperationID:%@, requestedOffset:%lld, requestedLength:%ld>", self.class, self, _fetchOperationID, self.loadingRequest.dataRequest.requestedOffset, self.loadingRequest.dataRequest.requestedLength];
}

- (void)dealloc {
    [self cancel];
    LogError(@"%@销毁", self);
}

- (instancetype)initWithResourceURL:(NSURL *)resourceURL loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest inSession:(NSURLSession *)session {
    self = [super init];
    if (self) {
        _loadingRequest = loadingRequest;
        _resourceURL = resourceURL;
        _session = session;
        _rangeTasks = [NSMutableArray array];
        _currentRangeTask = nil;
        _mediaCache = [GSDMediaCache sharedMediaCache];
        _fetchOperationID = loadingRequest.addressID;
    }
    return self;
}

// MARK: - publicMethod

- (BOOL)containDataTask:(NSURLSessionTask *)task {
    BOOL ret = NO;
    NSArray *rangeTasks;
    @synchronized (self) {
        rangeTasks = [self.rangeTasks copy];
    }
    for (id<GSDResourceRangeTask>op in rangeTasks) {
        if ([op isKindOfClass:GSDResourceRemoteRangeTask.class] && [(GSDResourceRemoteRangeTask *)op dataTask].taskIdentifier == task.taskIdentifier) {
            ret = YES;
            break;
        }
    }
    return ret;
}

// MARK: - Operation

- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            if (!self.isFinished) self.finished = YES;
            
            //通知外部已经取消。
            if (self.delegate && [self.delegate respondsToSelector:@selector(fetchOperation:didCompleteWithError:)]) {
                [self.delegate fetchOperation:self didCompleteWithError:[NSError gsd_errorWithCode:-999 msg:@"取消请求"]];
            }
            
            [self reset];
            
            return;
        }
        self.executing = YES;
    }
    
    //contentInfo改为异步存储后，这里也要加锁读取了，否则这里有一定几率读取为空导致下面range错误。
    self.resourceInfo = [self.mediaCache resourceInfoFromCacheForKey:self.resourceURL.absoluteString];
    
    long long requestedOffset = self.loadingRequest.dataRequest.requestedOffset;
    NSInteger requestedLength = self.loadingRequest.dataRequest.requestedLength;
    GSDRangeItem *requestRangeItem = nil;
    if (self.loadingRequest.dataRequest.requestsAllDataToEndOfResource && self.resourceInfo) {
        requestedLength = self.resourceInfo.contentLength;
        requestRangeItem = [[GSDRangeItem alloc] initWithStart:requestedOffset end:requestedLength - 1 type:GSDRangeItemTypeRemote];
    } else {
        requestRangeItem = [[GSDRangeItem alloc] initWithStart:requestedOffset end:requestedOffset + requestedLength - 1 type:GSDRangeItemTypeRemote];
    }
    
    GSDResourceRangeTable *resourceRangeTable = [self.mediaCache resourceRangeTableFromCacheForKey:self.resourceURL.absoluteString];
    NSArray *requestRanges = @[requestRangeItem];
    if (resourceRangeTable != nil) {
        requestRanges = [resourceRangeTable separateLocalRangeItemsWithReqeustRangeItem:requestRangeItem];
    }
    
    LogError(@"已缓存区间列表:\n%@", resourceRangeTable.rangeItems);
    LogError(@"start fetchOp:%@, 原始请求:%lld-%lld,长度:%lld\n拆分请求列表:总计range个数:%ld\n%@", self, requestRangeItem.start, requestRangeItem.end, requestRangeItem.length, requestRanges.count, requestRanges);
    
    NSMutableArray *rangeTasks = [NSMutableArray array];
    for (GSDRangeItem *rangeItem in requestRanges) {
        id<GSDResourceRangeTask> rangeTask = nil;
        if (rangeItem.type == GSDRangeItemTypeRemote) {
            rangeTask = [[GSDResourceRemoteRangeTask alloc] initWithResourceURL:self.resourceURL rangeItem:rangeItem inSession:self.session];
            rangeTask.fetchOperationID = self.fetchOperationID;
            [(GSDResourceRemoteRangeTask *)rangeTask setDelegate:self];
        } else {
            rangeTask = [[GSDResourceLocalRangeTask alloc] initWithResourceURL:self.resourceURL rangeItem:rangeItem];
            rangeTask.fetchOperationID = self.fetchOperationID;
            [(GSDResourceLocalRangeTask *)rangeTask setDelegate:self];
        }
        [rangeTasks addObject:rangeTask];
    }
    @synchronized (self) {
        self.rangeTasks = rangeTasks;
    }
    [self dequeueRangeTask];
}

- (void)dequeueRangeTask {
    @synchronized (self) {
        if (self.isCancelled) {
            if (!self.isFinished) self.finished = YES;
            
            //通知外部已经取消。
            if (self.delegate && [self.delegate respondsToSelector:@selector(fetchOperation:didCompleteWithError:)]) {
                [self.delegate fetchOperation:self didCompleteWithError:[NSError gsd_errorWithCode:-999 msg:@"取消请求"]];
            }
            
            [self reset];
            return;
        }
    }
    
    if ([self requestOperationCounts] == 0) {
        //通知外部执行完成
        if (self.delegate && [self.delegate respondsToSelector:@selector(fetchOperation:didCompleteWithError:)]) {
            [self.delegate fetchOperation:self didCompleteWithError:nil];
        }
        [self done];
        return;
    }
    
    @synchronized (self) {
        self.currentRangeTask = self.rangeTasks.firstObject;
    }
    
    [self.currentRangeTask start];
}

- (NSInteger)requestOperationCounts {
    @synchronized (self) {
        return self.rangeTasks.count;
    }
}

- (void)cancel {
    @synchronized (self) {
        [self cancelInternal];
    }
}

- (void)cancelInternal {
    if (self.isFinished || self.isCancelled) return;
    
    self.cancelled = YES;
    
    if (self.currentRangeTask) {
        [self.currentRangeTask cancel];
        self.currentRangeTask = nil;
    }

    // NSOperation disallow setFinished=YES **before** operation's start method been called
    // We check for the initialized status, which is isExecuting == NO && isFinished = NO
    // Ony update for non-intialized status, which is !(isExecuting == NO && isFinished = NO), or if (self.isExecuting || self.isFinished) {...}
    if (self.isExecuting || self.isFinished) {
        if (self.isExecuting) self.executing = NO;
        if (!self.isFinished) self.finished = YES;
    }
    
    //通知外部已经取消。
    if (self.delegate && [self.delegate respondsToSelector:@selector(fetchOperation:didCompleteWithError:)]) {
        [self.delegate fetchOperation:self didCompleteWithError:[NSError gsd_errorWithCode:-999 msg:@"取消请求"]];
    }

    [self reset];
}

- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void)reset {
    @synchronized (self) {
        self.currentRangeTask = nil;
        [self.rangeTasks removeAllObjects];
    }
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

#pragma mark NSURLSessionDataDelegate

- (GSDResourceRemoteRangeTask *)remoteRangeTaskWithTask:(NSURLSessionTask *)task {
    GSDResourceRemoteRangeTask *returnRangeTask = nil;
    NSArray *rangeTasks;
    @synchronized (self) {
        rangeTasks = [self.rangeTasks copy];
    }
    for (id<GSDResourceRangeTask> rangeTask in rangeTasks) {
        if ([rangeTask isKindOfClass:GSDResourceRemoteRangeTask.class]) {
            // So we lock the operation here, and in `SDWebImageDownloaderOperation`, we use `@synchonzied (self)`, to ensure the thread safe between these two classes.
            NSURLSessionTask *dataTask;
            @synchronized (rangeTask) {
                dataTask = [(GSDResourceRemoteRangeTask *)rangeTask dataTask];
            }
            if (dataTask.taskIdentifier == task.taskIdentifier) {
                returnRangeTask = (GSDResourceRemoteRangeTask *)rangeTask;
                break;
            }
        }
    }
    return returnRangeTask;
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {

    GSDResourceRemoteRangeTask *operation = [self remoteRangeTaskWithTask:dataTask];
    if ([operation respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [operation URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(NSURLSessionResponseAllow);
        }
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {

    GSDResourceRemoteRangeTask *operation = [self remoteRangeTaskWithTask:dataTask];
    if ([operation respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [operation URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
    GSDResourceRemoteRangeTask *operation = [self remoteRangeTaskWithTask:task];
    if ([operation respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [operation URLSession:session task:task didCompleteWithError:error];
    }
}

// MARK: - GSDResourceRemoteRequestOperationDelegate

- (void)remoteRangeTask:(GSDResourceRemoteRangeTask *)remoteRangeTask didReceiveResponse:(NSURLResponse *)response {
    if (self.resourceInfo == nil) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSDictionary *headers = [httpResponse allHeaderFields];
        NSDictionary *caseInsensitiveHeaders = [self caseInsensitiveKeyWithDict:headers];
        if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 400) {
            self.resourceInfo = [self resourceInfoModelWithHeaderFields:caseInsensitiveHeaders];
            if (!self.resourceInfo.isByteRangeAccessSupported && httpResponse.statusCode == 206) {
                self.resourceInfo.byteRangeAccessSupported = YES;
            }
            [self.mediaCache storeResourceInfo:self.resourceInfo forKey:self.resourceURL.absoluteString completion:nil];
        }
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(fetchOperation:didLoadResourceInfo:)]) {
        [self.delegate fetchOperation:self didLoadResourceInfo:self.resourceInfo];
    }
}

- (void)remoteRangeTask:(GSDResourceRemoteRangeTask *)remoteRangeTask didReceiveData:(NSData *)data {
    if (self.delegate && [self.delegate respondsToSelector:@selector(fetchOperation:didReceiveData:)]) {
        [self.delegate fetchOperation:self didReceiveData:data];
    }
}

- (void)remoteRangeTask:(GSDResourceRemoteRangeTask *)remoteRangeTask didReceiveData:(NSData *)data offset:(long long)offset {
    [self.mediaCache storeMediaDataWithContentLength:self.resourceInfo.contentLength
                                     currentOffset:offset
                                              data:data
                                            forKey:self.resourceURL.absoluteString
                                        completion:nil];
}

- (void)remoteRangeTask:(GSDResourceRemoteRangeTask *)remoteRangeTask didCompleteWithError:(NSError *)error {
    if (error && error.code == NSURLErrorCancelled) {
        return;
    }
    
    if (!error) {
        @synchronized (self) {
            [self.rangeTasks removeObject:remoteRangeTask];
        }
        [self dequeueRangeTask];
    } else {
        //数据获取失败，通知外部执行完成
        if (self.delegate && [self.delegate respondsToSelector:@selector(fetchOperation:didCompleteWithError:)]) {
            [self.delegate fetchOperation:self didCompleteWithError:error];
        }
        [self done];
    }
}

// MARK: - GSDResourceLocalRequestOperationDelegate

- (void)localRangeTask:(GSDResourceLocalRangeTask *)localRangeTask didLoadResourceInfo:(nonnull GSDResourceInfoModel *)resourceInfo {
    if (self.resourceInfo == nil) {
        self.resourceInfo = resourceInfo;
        NSAssert(NO, @"不可能，因为本地如果存在缓存，那么fetchOp初始化的时候肯定能取到contentInfo");
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(fetchOperation:didLoadResourceInfo:)]) {
        [self.delegate fetchOperation:self didLoadResourceInfo:self.resourceInfo];
    }
}

- (void)localRangeTask:(GSDResourceRemoteRangeTask *)localRangeTask didReceiveData:(NSData *)data offset:(long long)offset {
    if (self.delegate && [self.delegate respondsToSelector:@selector(fetchOperation:didReceiveData:)]) {
        [self.delegate fetchOperation:self didReceiveData:data];
    }
}

- (void)localRangeTask:(GSDResourceRemoteRangeTask *)localRangeTask didCompleteWithError:(NSError *)error {
    if (error && error.code == GSDAudioCacheErrorCancelled) {
        return;
    }
    
    if (!error) {
        @synchronized (self) {
            [self.rangeTasks removeObject:localRangeTask];
        }
        [self dequeueRangeTask];
    } else {
        //数据获取失败，通知外部执行完成
        if (self.delegate && [self.delegate respondsToSelector:@selector(fetchOperation:didCompleteWithError:)]) {
            [self.delegate fetchOperation:self didCompleteWithError:error];
        }
        [self done];
    }
}


// MARK: - PrivateMethod

- (NSDictionary *)caseInsensitiveKeyWithDict:(NSDictionary *)dict {
    NSMutableDictionary *caseInsensitiveDict = [NSMutableDictionary dictionary];
    for (NSString *key in dict.allKeys) {
        id value = [dict objectForKey:key];
        NSString *caseInsensitiveKey = [key lowercaseString];
        [caseInsensitiveDict setObject:value forKey:caseInsensitiveKey];
    }
    return caseInsensitiveDict;
}

- (NSString *)getUTITypeWithHeaderFields:(NSDictionary *)headerFields {
    NSString *mimeType = [headerFields valueForKey:@"content-type"];
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    NSString *contentTypeStr = CFBridgingRelease(contentType);
    return contentTypeStr;
}

- (long long)getContentLengthWithHeaderFields:(NSDictionary *)headerFields {
    NSString *contentRange = [headerFields valueForKey:@"content-range"];
    NSString *contentLength = [contentRange componentsSeparatedByString:@"/"].lastObject;
    return contentLength.longLongValue;
}

- (GSDResourceInfoModel *)resourceInfoModelWithHeaderFields:(NSDictionary *)headerFields {
    GSDResourceInfoModel *resourceInfo = [GSDResourceInfoModel new];
    resourceInfo.resourceURL = self.resourceURL;
    resourceInfo.contentLength = [self getContentLengthWithHeaderFields:headerFields];
    resourceInfo.mimeType = [headerFields valueForKey:@"content-type"];
    resourceInfo.UTIType = [self getUTITypeWithHeaderFields:headerFields];
    resourceInfo.byteRangeAccessSupported = [[headerFields valueForKey:@"accept-ranges"] isEqualToString:@"bytes"] ? YES : NO;
    return resourceInfo;
}

@end
