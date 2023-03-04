# GSDMediaCache
iOS边下边播框架for AVPlayer。GSDMediaCache具有如下特点：

1. 支持边下边播，一遍的流量完成播放和缓存。
2. 极致的缓存利用，只有未缓存的区间才会从服务器获取。
3. 线程安全。
4. 高性能，低内存、低CPU消耗。
5. 最低支持iOS10。
6. 可选的详细的打印日志。

### 集成

`pod 'GSDMediaCache'`

### 使用

```objc
- (void)sd_loadPlayerWithItemUrl:(NSURL *)url {
    self.loaderManager = [GSDResourceLoaderManager sharedManager];
    AVURLAsset *urlAsset = [self.loaderManager customSchemeAssetWithURL:url options:nil];
    self.playerItem = [AVPlayerItem playerItemWithAsset:urlAsset];
    
    // 告诉app支持后台播放
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    
    self.player = [[AVPlayer alloc] initWithPlayerItem:self.playerItem];
    if (@available(iOS 10.0, *)) {
        [self.player setAutomaticallyWaitsToMinimizeStalling:NO];
    } else {
        // Fallback on earlier versions
    }
    
    [self.playerView setPlayer:self.player];
    
    [self.player play];
}
```

