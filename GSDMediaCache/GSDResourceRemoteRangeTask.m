//
//  GSDResourceRemoteFetchOperation.m
//  GSDMediaCache
//
//  Created by xq on 2021/7/23.
//  Copyright (c) 2021 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "GSDResourceRemoteRangeTask.h"
#import "NSError+GSDHelper.h"
#import "GSDMediaCacheLogDefine.h"

@interface GSDResourceRemoteRangeTask()

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
@property (nonatomic, weak) NSURLSession *session;
@property (nonatomic, strong, readonly) GSDRangeItem *rangeItem;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSURLResponse *response;
@property (strong, nonatomic, readwrite, nullable) NSURLSessionTask *dataTask;
@property (strong, nonatomic, nullable) NSMutableData *assetData;
@property (assign, nonatomic) NSUInteger expectedSize;
@property (assign, nonatomic) NSUInteger receivedSize;
/// 数据缓存门槛，用于控制数据缓存回调频率。默认10MiB。
@property (assign, nonatomic) NSUInteger cacheCallbackThreshold;
@property (assign, nonatomic) NSUInteger nextOffset;
@property (nonatomic, assign) BOOL hasBuffer;

@end

@implementation GSDResourceRemoteRangeTask

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@:%p, fetchOperationID:%@, range:%lld-%lld, length:%lld>", self.class, self, _fetchOperationID, _rangeItem.start, _rangeItem.end, _rangeItem.length];
}

- (void)dealloc {
    LogDebug(@"%@销毁, nextOffset:%ld, isCancelled:%d", self, self.nextOffset, self.isCancelled);
}

- (instancetype)initWithResourceURL:(NSURL *)resourceURL rangeItem:(GSDRangeItem *)rangeItem inSession:(NSURLSession *)session {
    self = [super init];
    if (self) {
        _session = session;
        _rangeItem = rangeItem;
        NSURLRequestCachePolicy cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:resourceURL cachePolicy:cachePolicy timeoutInterval:60];
        [mutableRequest setValue:[NSString stringWithFormat:@"bytes=%lld-%lld", rangeItem.start, rangeItem.end] forHTTPHeaderField:@"range"];
        _request = mutableRequest;
        _cacheCallbackThreshold = 10 * 1024 * 1024;
        _nextOffset = rangeItem.start;
    }
    return self;
}

// MARK: - Operation

- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            //通知外部已经取消。
            if (self.delegate && [self.delegate respondsToSelector:@selector(remoteRangeTask:didCompleteWithError:)]) {
                [self.delegate remoteRangeTask:self didCompleteWithError:[NSError gsd_errorWithCode:NSURLErrorCancelled msg:@"取消请求"]];
            }
            [self reset];
            return;
        }
        
        self.dataTask = [self.session dataTaskWithRequest:self.request];
    }
    LogError(@"远程请求开始：%@, dataTask:%@", self, self.dataTask);
    [self.dataTask resume];
}

- (void)cancel {
    @synchronized (self) {
        [self cancelInternal];
    }
}

- (void)cancelInternal {
    if (self.isCancelled) return;
    
    self.cancelled = YES;
    
    if (self.dataTask) {
        // Cancel the URLSession, `URLSession:task:didCompleteWithError:` delegate callback will be ignored
        [self.dataTask cancel];
        self.dataTask = nil;
    }
    
    if (self.hasBuffer) {
        if (self.assetData == nil) {
            NSAssert(NO, @"case1,怎么回事没数据也有buffer???");
        }
        self.hasBuffer = NO;
        if (self.assetData.length > 0 && self.delegate && [self.delegate respondsToSelector:@selector(remoteRangeTask:didReceiveData:offset:)]) {
            [self.delegate remoteRangeTask:self didReceiveData:self.assetData offset:self.nextOffset];
            LogError(@"远程请求取消,开始flush:loc:%lu, length:%lu", self.nextOffset, self.assetData.length);
            self.nextOffset += self.assetData.length;
        }
        self.assetData = nil;
    }
    
    //通知外部已经取消。
    if (self.delegate && [self.delegate respondsToSelector:@selector(remoteRangeTask:didCompleteWithError:)]) {
        [self.delegate remoteRangeTask:self didCompleteWithError:[NSError gsd_errorWithCode:NSURLErrorCancelled msg:@"取消请求"]];
    }

    [self reset];
}

- (void)done {
    [self reset];
}

- (void)reset {
    @synchronized (self) {
        self.dataTask = nil;
    }
}

#pragma mark NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    NSURLSessionResponseDisposition disposition = NSURLSessionResponseAllow;
    
    long long expected = response.expectedContentLength;
    expected = expected > 0 ? expected : self.rangeItem.length;
    self.expectedSize = expected;
    self.response = response;
    
    LogError(@"接收到响应,%@", self);
    
    NSInteger statusCode = [response respondsToSelector:@selector(statusCode)] ? ((NSHTTPURLResponse *)response).statusCode : 200;
    // Status code should between [200,400)
    BOOL statusCodeValid = statusCode >= 200 && statusCode < 400;
    if (!statusCodeValid) {
        disposition = NSURLSessionResponseCancel;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(remoteRangeTask:didReceiveResponse:)]) {
        [self.delegate remoteRangeTask:self didReceiveResponse:response];
    }
    
    if (completionHandler) {
        completionHandler(disposition);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    @synchronized (self) {
        if (self.isCancelled) {
            LogError(@"case1:didReceiveData回调,但已经取消了,几率很小,data丢弃length:%lu", (unsigned long)data.length);
            return;
        }
        if (self.delegate && [self.delegate respondsToSelector:@selector(remoteRangeTask:didReceiveData:)]) {
            [self.delegate remoteRangeTask:self didReceiveData:data];
        }
        
        if (!self.assetData) {
            self.assetData = [[NSMutableData alloc] init];
        }
        [self.assetData appendData:data];

        self.receivedSize += data.length;
        BOOL isFinished = self.receivedSize >= self.expectedSize ? YES : NO;
        BOOL needFlush = NO;
        if (isFinished) {
            needFlush = YES;
        } else {
            needFlush = self.assetData.length >= self.cacheCallbackThreshold ? YES : NO;
        }
        
        self.hasBuffer = YES;
        if (needFlush) {
            @autoreleasepool {
                if (self.isCancelled) {
                    LogError(@"case2:didReceiveData回调,但已经取消了,几率很小,data丢弃length:%lu", (unsigned long)data.length);
                    return;
                }
                if (self.delegate && [self.delegate respondsToSelector:@selector(remoteRangeTask:didReceiveData:offset:)]) {
                    [self.delegate remoteRangeTask:self didReceiveData:self.assetData offset:self.nextOffset];
                }
            }
            self.nextOffset += self.assetData.length;
            self.hasBuffer = NO;
            self.assetData = nil;
        }
    }
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    LogError(@"远程请求完成：%@，error:%@，dataTask:%@", self, error, self.dataTask);
    
    @synchronized (self) {
        if (self.isCancelled) { //这里有极小概率会进来
            LogError(@"这里有极小概率会进来，remoteRangeTask已经取消，但didCompleteDelegate代理方法还是调用了，self:%@,self.delegate:%@", self, self.delegate);
            return;
        }
        if (self.hasBuffer) {
            if (self.assetData == nil) {
                NSAssert(NO, @"case2,怎么回事没数据也有buffer???");
            }
            self.hasBuffer = NO;
            //理论上不会走到这里，因为didReceiveData里面已经处理过了。
            if (self.assetData.length > 0 && self.delegate && [self.delegate respondsToSelector:@selector(remoteRangeTask:didReceiveData:offset:)]) {
                [self.delegate remoteRangeTask:self didReceiveData:self.assetData offset:self.nextOffset];
                LogError(@"远程请求完成, 开始flush:loc:%lu, subdataLength:%lu", self.nextOffset, self.assetData.length);
                self.nextOffset += self.assetData.length;
            }
        }
        self.assetData = nil;
        self.dataTask = nil;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(remoteRangeTask:didCompleteWithError:)]) {
        [self.delegate remoteRangeTask:self didCompleteWithError:error];
    }
    
    [self done];
}

@end
