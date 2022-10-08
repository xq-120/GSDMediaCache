//
//  GSDPlayerResourceLoader.m
//  GSDMediaCache
//
//  Created by xq on 2020/12/1.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "GSDResourceLoader.h"
#import "NSURL+GSDHelper.h"
#import "NSError+GSDHelper.h"
#import "GSDMediaCacheLogDefine.h"
#import "GSDResourceFetchOperation.h"
#import "GSDResourceRemoteRangeTask.h"
#import "GSDResourceLocalRangeTask.h"
#import "AVAssetResourceLoadingRequest+AddressID.h"
#import <os/lock.h>

@interface GSDResourceLoader ()<GSDResourceFetchOperationDelegate>

@property (nonatomic, assign, readwrite, getter=isCancelled) BOOL cancelled;
@property (nonatomic, weak) NSURLSession *session;
@property (nonatomic, assign) NSInteger maxConcurrentOperationCount;
@property (nonatomic, strong) NSMutableArray<GSDResourceFetchOperation *> *fetchOperations;

@end

@implementation GSDResourceLoader

- (void)dealloc {
    [self cancel];
    LogDebug(@"%@销毁", self);
}

- (instancetype)initWithResourceURL:(NSURL *)resourceURL inSession:(nullable NSURLSession *)session {
    self = [super init];
    if (self) {
        _resourceURL = resourceURL;
        _session = session;
        _maxConcurrentOperationCount = 3;
        _fetchOperations = [NSMutableArray array];
    }
    return self;
}

// MARK: - publicMethod

- (void)addLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    @synchronized (self) {
        if (!self.isCancelled) {
            
            [self cancelFetchOperationIfNeededWithNewLoadingRequest:loadingRequest];
            
            GSDResourceFetchOperation *operation = [self fetchOperationForKey:loadingRequest.addressID];
            if (!operation || operation.isFinished || operation.isCancelled) { //isFinished和isCancelled的fetch后续会被移除,这里就不重复移除了。
                operation = [[GSDResourceFetchOperation alloc] initWithResourceURL:self.resourceURL loadingRequest:loadingRequest inSession:self.session];
                operation.delegate = self;
                [self.fetchOperations addObject:operation];
                
                LogInfo(@"添加loading Request：%p, fetchOp：%@，fetchOpDict：%@", loadingRequest, operation, self.fetchOperations);

                [operation start];
            } else {
                NSAssert(NO, @"添加了一个已有的loadingRequest");
            }
        } else {
            NSAssert(NO, @"loader 已经取消");
            if (!loadingRequest.isFinished) {
                [loadingRequest finishLoadingWithError:[NSError gsd_errorWithCode:-999 msg:@"取消下载"]];
            }
        }
    }
}

- (GSDResourceFetchOperation *)fetchOperationForKey:(NSString *)key {
    if (key == nil) {
        return nil;
    }
    GSDResourceFetchOperation *op = nil;
    for (GSDResourceFetchOperation *fetchOperation in self.fetchOperations) {
        if ([fetchOperation.fetchOperationID isEqualToString:key]) {
            op = fetchOperation;
            break;
        }
    }
    return op;
}

- (void)cancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    GSDResourceFetchOperation *fetchOp = nil;
    @synchronized (self) {
        fetchOp = [self fetchOperationForKey:loadingRequest.addressID];
        LogInfo(@"取消指定Loading Request：%p, fetchOp：%@，fetchOperations：%@", loadingRequest, fetchOp, self.fetchOperations);
        [fetchOp cancel];
        [self.fetchOperations removeObject:fetchOp];
    }
}

- (void)cancel {
    @synchronized (self) {
        if (self.isCancelled) {
            return;
        }
        self.cancelled = YES;
        LogInfo(@"取消all Loading Request，fetchOpDict：%@", self.fetchOperations);
        
        for (GSDResourceFetchOperation *fetchOperation in self.fetchOperations.copy) {
            [fetchOperation cancel];
        }
        
        [self.fetchOperations removeAllObjects];
    }
}

// MARK: - privateMethod

//兼容iOS10，iOS10系统bug:didCancelLoadingRequest代理方法只在手机重启后的第一次才会回调，后续都不会回调。
- (void)cancelFetchOperationIfNeededWithNewLoadingRequest:(AVAssetResourceLoadingRequest *)newLoadingRequest {
    if (self.fetchOperations.count < self.maxConcurrentOperationCount) {
        return;
    }
    
    GSDResourceFetchOperation *oldFullFetchOperation = nil;
    for (GSDResourceFetchOperation *op in self.fetchOperations) {
        if (op.loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
            oldFullFetchOperation = op;
            break;
        }
    }
    
    //有新的满请求和旧的满请求，则取消旧的满请求
    if (oldFullFetchOperation != nil && newLoadingRequest.dataRequest.requestsAllDataToEndOfResource) {
        [oldFullFetchOperation cancel];
        [self.fetchOperations removeObject:oldFullFetchOperation];
        LogInfo(@"SDK取消旧的满请求：%@", oldFullFetchOperation);
        return;
    }
    
    //优先取消短请求。
    NSArray *fetchOperations = self.fetchOperations.copy;
    for (GSDResourceFetchOperation *op in fetchOperations) {
        if (op.loadingRequest.dataRequest.requestsAllDataToEndOfResource) {
            continue;
        }
        if (self.fetchOperations.count < self.maxConcurrentOperationCount) {
            return;
        } else {
            [op cancel];
            [self.fetchOperations removeObject:op];
            LogInfo(@"SDK优先取消短请求：%@", op);
        }
    }
    
    NSInteger cancelCount = self.fetchOperations.count + 1 - self.maxConcurrentOperationCount;
    if (cancelCount > 0) { //继续移除
        for (int i = 0; i < cancelCount; i++) {
            GSDResourceFetchOperation *op = self.fetchOperations[i];
            [op cancel];
            [self.fetchOperations removeObject:op];
            LogInfo(@"SDK继续移除请求：%@", op);
        }
    }
}

// MARK: - GSDResourceRequestOperationDelegate

- (void)fetchOperation:(GSDResourceFetchOperation *)fetchOperation didLoadResourceInfo:(nonnull GSDResourceInfoModel *)resourceInfo {
    AVAssetResourceLoadingRequest *loadingRequest = fetchOperation.loadingRequest;
    if (loadingRequest.contentInformationRequest != nil) {
        loadingRequest.contentInformationRequest.contentType = resourceInfo.UTIType;
        loadingRequest.contentInformationRequest.byteRangeAccessSupported = resourceInfo.byteRangeAccessSupported;
        loadingRequest.contentInformationRequest.contentLength = resourceInfo.contentLength;
    }
}

- (void)fetchOperation:(GSDResourceFetchOperation *)fetchOperation didReceiveData:(NSData *)data {
    AVAssetResourceLoadingRequest *loadingRequest = fetchOperation.loadingRequest;
    [loadingRequest.dataRequest respondWithData:data];
}

- (void)fetchOperation:(GSDResourceFetchOperation *)fetchOperation didCompleteWithError:(NSError *)error {
    AVAssetResourceLoadingRequest *loadingRequest = fetchOperation.loadingRequest;
    if (!loadingRequest.isFinished) {
        if (!error) {
            [loadingRequest finishLoading];
        } else {
            [loadingRequest finishLoadingWithError:error];
        }
    }
    
    @synchronized (self) {
        [self.fetchOperations removeObject:fetchOperation];
    }
    LogInfo(@"本次下载完成fetchOp：%@，error:%@，移除Loading Request：%p", fetchOperation, error.localizedDescription, loadingRequest);
}

#pragma mark NSURLSessionDataDelegate

- (GSDResourceFetchOperation *)fetchOperationWithTask:(NSURLSessionTask *)task {
    GSDResourceFetchOperation *returnOperation = nil;
    NSArray *fetchOperations = nil;
    @synchronized (self) {
        fetchOperations = [self.fetchOperations copy];
    }
    for (GSDResourceFetchOperation *operation in fetchOperations) {
        @synchronized (operation) {
            if ([operation containDataTask:task]) {
                returnOperation = operation;
                break;
            }
        }
    }
    return returnOperation;
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {

    GSDResourceFetchOperation *operation = [self fetchOperationWithTask:dataTask];
    if ([operation respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [operation URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(NSURLSessionResponseAllow);
        }
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {

    GSDResourceFetchOperation *operation = [self fetchOperationWithTask:dataTask];
    if ([operation respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [operation URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {

    GSDResourceFetchOperation *operation = [self fetchOperationWithTask:task];
    if ([operation respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [operation URLSession:session task:task didCompleteWithError:error];
    }
}

@end
