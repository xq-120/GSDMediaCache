//
//  GSDPlayerResourceLoaderManager.m
//  GSDMediaCache
//
//  Created by xq on 2020/12/1.
//  Copyright (c) 2020 xq.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "GSDResourceLoaderManager.h"
#import "GSDMediaCacheInternalDefine.h"
#import "GSDResourceLoader.h"
#import "NSURL+GSDHelper.h"
#import <os/lock.h>
#import "GSDMediaCacheLogDefine.h"

@interface GSDResourceLoaderManager () <NSURLSessionDelegate, NSURLSessionDataDelegate>

@property (nonatomic, strong) NSMutableDictionary<NSURL *, GSDResourceLoader *> *loaderDict;
@property (nonatomic, strong, readwrite) dispatch_queue_t assetDelegateQueue;
@property (nonatomic, assign) os_unfair_lock loaderLock;
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation GSDResourceLoaderManager

- (void)dealloc {
    [self cancelAllLoaders];
    [self.session invalidateAndCancel];
    self.session = nil;
}

+ (instancetype)sharedManager {
    static id obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[GSDResourceLoaderManager alloc] init];
    });
    return obj;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _assetDelegateQueue = dispatch_queue_create("com.GSDAudioCache.assetDelegate.concurrentQueue", DISPATCH_QUEUE_CONCURRENT);
        _loaderDict = [[NSMutableDictionary alloc] init];
        _loaderLock = OS_UNFAIR_LOCK_INIT;
        
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        sessionConfiguration.timeoutIntervalForRequest = 60;
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                 delegate:self
                                            delegateQueue:nil];
    }
    return self;
}

// MARK: - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSURL *resourceURL = loadingRequest.request.URL;
    if ([resourceURL gsd_isCustomSchemeURLByContainningSuffix:kCustomSchemeSuffix]) {
        NSURL *originalURL = [resourceURL gsd_recoverCustomSchemeURLByRemovingSuffix:kCustomSchemeSuffix];

        os_unfair_lock_lock(&_loaderLock);
        GSDResourceLoader *loader = self.loaderDict[originalURL];
        if (loader == nil) {
            loader = [[GSDResourceLoader alloc] initWithResourceURL:originalURL inSession:self.session];
            self.loaderDict[originalURL] = loader;
        }
        os_unfair_lock_unlock(&_loaderLock);
        
        [loader addLoadingRequest:loadingRequest];
        return YES;
    } else {
        return NO;
    }
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSURL *originalURL = [loadingRequest.request.URL gsd_recoverCustomSchemeURLByRemovingSuffix:kCustomSchemeSuffix];
    
    os_unfair_lock_lock(&_loaderLock);
    GSDResourceLoader *loader = self.loaderDict[originalURL];
    os_unfair_lock_unlock(&_loaderLock);
    
    [loader cancelLoadingRequest:loadingRequest];
}

// MARK: - publicMethod

- (AVURLAsset *)customSchemeAssetWithURL:(NSURL *)URL options:(NSDictionary<NSString *,id> *)options {
    NSURL *customURL = [URL gsd_customSchemeURLByAppendingSuffix:kCustomSchemeSuffix];
    AVURLAsset *urlAsset = [[AVURLAsset alloc] initWithURL:customURL options:options];
    [urlAsset.resourceLoader setDelegate:self queue:self.assetDelegateQueue];
    return urlAsset;
}

- (void)cancelAllLoaders {
    os_unfair_lock_lock(&_loaderLock);
    for (GSDResourceLoader *loader in self.loaderDict.allValues) {
        [loader cancel];
    }
    [self.loaderDict removeAllObjects];
    os_unfair_lock_unlock(&_loaderLock);
}

- (void)cancelLoaderWithURL:(NSURL *)url {
    os_unfair_lock_lock(&_loaderLock);
    GSDResourceLoader *loader = self.loaderDict[url];
    [self.loaderDict removeObjectForKey:url];
    os_unfair_lock_unlock(&_loaderLock);
    [loader cancel];
}

#pragma mark NSURLSessionDataDelegate

- (GSDResourceLoader *)resourceLoaderWithTask:(NSURLSessionTask *)task {
    NSURL *resourceURL = task.originalRequest.URL;
    
    os_unfair_lock_lock(&_loaderLock);
    GSDResourceLoader *loader = self.loaderDict[resourceURL];
    os_unfair_lock_unlock(&_loaderLock);
    
    return loader;
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {

    GSDResourceLoader *loader = [self resourceLoaderWithTask:dataTask];
    if ([loader respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [loader URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(NSURLSessionResponseAllow);
        }
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {

    GSDResourceLoader *loader = [self resourceLoaderWithTask:dataTask];
    if ([loader respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [loader URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
    GSDResourceLoader *loader = [self resourceLoaderWithTask:task];
    if ([loader respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [loader URLSession:session task:task didCompleteWithError:error];
    }
}


@end
