//
//  FDEVideoPlayViewController.m
//  AudioDemo
//
//  Created by xq on 2020/12/11.
//

#import "FDEVideoPlayViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "GSDResourceLoaderManager.h"
#import "FDEPlayerView.h"
#import "FDEAudioPlayView.h"
#import "GSDMediaCache.h"

// 测试视频链接
#define kUrl0 @"https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4" //302

#define kUrl1 @"http://vt1.doubanio.com/202001021917/01b91ce2e71fd7f671e226ffe8ea0cda/view/movie/M/301120229.mp4"

#define kUrl3 @"http://www.w3school.com.cn/example/html5/mov_bbb.mp4"

#define kUrl4 @"http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"
 

@interface FDEVideoPlayViewController ()<FDESliderDelegate>

@property (nonatomic, strong) FDEPlayerView *playerView;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) id timeObserver;
@property (nonatomic, strong) GSDResourceLoaderManager *loaderManager;
@property (nonatomic, strong) FDEAudioPlayView *audioPlayView;
@property (nonatomic, assign) BOOL isSeeking;
@property (nonatomic, assign) BOOL isPausedByUser;
@property (nonatomic, assign) BOOL isDelegated;
/** 获取当前播放时间，单位：秒 */
@property (nonatomic, assign, readwrite) NSTimeInterval duration;
@property (nonatomic, assign, readwrite) NSTimeInterval currentTime;
@property (nonatomic, assign, readwrite) NSTimeInterval bufferTime;
@property (nonatomic, strong) NSMutableArray *playerUrls;
@property (nonatomic, strong) UIButton *lastBtn;
@property (nonatomic, strong) UIButton *nextBtn;
@property (nonatomic, strong) UIButton *testBtn;
@property (nonatomic, strong) UIButton *delegateBtn;
@property (nonatomic, assign) NSInteger currentIndex;
/** 播放的网址 */
@property (nonatomic, strong) NSURL *assetURL;
@end

@implementation FDEVideoPlayViewController

// MARK: - lifeCycle

- (void)dealloc {
    [self stop];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.playerUrls addObject:[NSURL URLWithString:kUrl0]];
    [self.playerUrls addObject:[NSURL URLWithString:kUrl1]];
    [self.playerUrls addObject:[NSURL URLWithString:kUrl3]];
    [self.playerUrls addObject:[NSURL URLWithString:kUrl4]];
    
    self.audioPlayView = [[FDEAudioPlayView alloc] initWithFrame:CGRectMake(20, 100, 270, 64)];
    [self.view addSubview:self.audioPlayView];
    
    [self.view addSubview:self.nextBtn];
    [self.view addSubview:self.lastBtn];
    [self.view addSubview:self.testBtn];
    [self.view addSubview:self.delegateBtn];
    
    self.lastBtn.frame = CGRectMake(20, 180, 80, 40);
    self.nextBtn.frame = CGRectMake(120, 180, 80, 40);
    self.testBtn.frame = CGRectMake(220, 180, 120, 40);
    
    [self.audioPlayView.playBtn addTarget:self action:@selector(playerBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    self.audioPlayView.playProgressView.delegate = self;
    
    self.playerView.frame = CGRectMake(0, 240, self.view.frame.size.width, 300);
    self.playerView.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view addSubview:self.playerView];
    
    self.delegateBtn.frame = CGRectMake(220, CGRectGetMaxY(self.playerView.frame) + 10, 80, 40);
    
    self.isDelegated = YES;
    
    [self playWithUrl:self.playerUrls[self.currentIndex]];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(removePlayerOnPlayerLayer)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(resetPlayerToPlayerLayer)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];
    
    [[GSDMediaCache sharedMediaCache] setEnableLog: YES];
}

- (void)removePlayerOnPlayerLayer {
    
    [self.playerView setPlayer:nil];
}

- (void)resetPlayerToPlayerLayer {
    
    [self.playerView setPlayer:self.player];
}

- (void)viewWillAppear:(BOOL)animated {
    [self play];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [self pause];
}

// MARK: - privateMethod

- (NSString *)formatterTime:(float)time
{
    NSString *durationString;
    
    int seconds = MAX(0, time);
    
    int s = seconds;
    int m = s / 60;
    int h = m / 60;
    
    s = s % 60;
    m = m % 60;
    
    durationString = [NSString stringWithFormat:@"%02d:%02d:%02d",h,m,s];
    return durationString;
}

- (void)updatePlayBtnSelectedStatus:(BOOL)isSelected {
    self.audioPlayView.playBtn.selected = isSelected;
}

// MARK: - event response

- (void)playerBtnClicked:(UIButton *)sender
{
    [self updatePlayBtnSelectedStatus:!sender.selected];
    
    if (sender.selected) {
        NSLog(@"用户点击播放");
        if (self.player == nil) {
            [self playVideo:self.currentIndex];
        } else {
            if (self.currentTime == [self duration]) {
                [self seekToTime:0 completionHandler:nil];
            }
            [self play];
        }
    } else {
        NSLog(@"用户点击暂停");
        [self pause];
    }
}

- (void)nextBtnDidClicked:(UIButton *)sender
{
    self.currentIndex ++;
    if (self.currentIndex >= self.playerUrls.count) {
        self.currentIndex = 0;
    }
    [self playVideo:self.currentIndex];
}

- (void)lastBtnDidClicked:(UIButton *)sender
{
    self.currentIndex --;
    if (self.currentIndex < 0) {
        self.currentIndex = self.playerUrls.count - 1;
    }
    [self playVideo:self.currentIndex];
}

- (void)playVideo:(NSInteger)index {
    NSURL *url = self.playerUrls[index];
    [self playWithUrl:url];
    [self updatePlayBtnSelectedStatus:YES];
}

// MARK: - FDESliderDelegate

- (void)slider:(FDESlider *)slider valueChanging:(float)value
{
    if (self.duration > 0) {
        NSTimeInterval currentTime = self.duration * value;
        self.audioPlayView.playedTimeLabel.text = [self formatterTime:currentTime];
    }
}

- (void)slider:(FDESlider *)slider valueDidEndChanged:(float)value
{
    if (self.duration > 0) {
        NSTimeInterval seekTime = self.duration * value;
        self.audioPlayView.playedTimeLabel.text = [self formatterTime:seekTime];
        NSLog(@"TouchUpOutside:%f,  seekToTime:%f", value, seekTime);
        [self seekToTime:seekTime completionHandler:^{
            
        }];
    }
}

- (void)sliderThumbDidTouchDown:(FDESlider *)slider {
    
}

// MARK: - Player

- (void)playWithUrl:(NSURL *)assetURL
{
    self.assetURL = assetURL;
    [self prepareToPlay];
}

- (void)play {
    [self.player play];
    [self updatePlayBtnSelectedStatus:YES];
    self.isPausedByUser = NO;
}

- (void)_internalPlay {
    [self.player play];
}

- (void)pause {
    [self.player pause];
    [self updatePlayBtnSelectedStatus:NO];
    self.isPausedByUser = YES;
}

- (void)_internalPause {
    [self.player pause];
}

- (void)stop {
    [self resetStatus];
    [self resetAudio];
}

- (void)seekToTime:(NSTimeInterval)time completionHandler:(void (^)(void))completionHandler
{
    if (self.playerItem.status != AVPlayerItemStatusReadyToPlay) {
        NSAssert(NO, @"seekToTime ERROR! 非AVPlayerItemStatusReadyToPlay");
        return;
    }
    
    [self.player.currentItem cancelPendingSeeks];
    
    self.isSeeking = YES;
    self.currentTime = time;
    
    [self _internalPause];
    
    //NSLog(@"将要开始seek:%f", time);
    int32_t currentAssetTimeScale = self.playerItem.asset.duration.timescale;
    if (currentAssetTimeScale < 600) {
        currentAssetTimeScale = 600;
    }
    CMTime cmTime = CMTimeMakeWithSeconds(time, currentAssetTimeScale);
    NSLog(@"seek cmTime");
    CMTimeShow(cmTime);
    __weak typeof(self) weakSelf = self;
    [self.player seekToTime:cmTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        NSLog(@"seekToTime:%f,是否完成:%d", time, finished);
        weakSelf.bufferTime = time;
        weakSelf.isSeeking = NO;
        if (finished) {
            if (!weakSelf.isPausedByUser) {
                [weakSelf play];
            }
        }
        
        if (completionHandler) {
            completionHandler();
        }
    }];
}

- (void)prepareToPlay
{
    [self resetStatus];
    
    [self resetAudio];
    
    [self loadAudio];
}

- (void)resetStatus
{
    self.isPausedByUser = NO;
    self.duration = 0;
    self.currentTime = 0;
    self.bufferTime = 0;
    self.isSeeking = NO;
}

- (void)resetAudio
{
    //暂停
    [self.player pause];
    
    //取消下载
    [self.playerItem cancelPendingSeeks];
    [self.loaderManager cancelLoaderWithURL:self.assetURL];
    self.loaderManager = nil;
    
    //移除观察者
    [self removeObserverWithPlayerItem:self.playerItem];
    [self removeObserverWithPlayer:self.player];
    self.player = nil;
    self.playerItem = nil;
}

- (void)loadAudio
{
    BOOL isCached = [[GSDMediaCache sharedMediaCache] isMediaCompleteCachedWithKey:self.assetURL.absoluteString];
    isCached = NO;
    if (isCached) {   //播放本地音频
        NSString *localPathStr = [[GSDMediaCache sharedMediaCache] mediaFilePathForKey:self.assetURL.absoluteString];
        NSLog(@"将要播放本地文件:原url:%@\n fileUrl:%@",self.assetURL, localPathStr);
        NSURL *localPathUrl = [NSURL fileURLWithPath:localPathStr];
        [self loadPlayerWithItemUrl:localPathUrl];
    } else {    //播放网络音频
        [self sd_loadPlayerWithItemUrl:self.assetURL];
    }
}

- (void)loadPlayerWithItemUrl:(NSURL *)url{
    self.playerItem = [AVPlayerItem playerItemWithURL:url];
    [self loadPlayer];
}

- (void)sd_loadPlayerWithItemUrl:(NSURL *)url {
    AVURLAsset *urlAsset = nil;
    if ([url.pathExtension containsString:@"m3u8"] || [url.pathExtension containsString:@"ts"] || !self.isDelegated) {
        urlAsset = [[AVURLAsset alloc] initWithURL:url options:nil];
    } else {
        self.loaderManager = [GSDResourceLoaderManager sharedManager];
        urlAsset = [self.loaderManager customSchemeAssetWithURL:url options:nil];
    }
    self.playerItem = [AVPlayerItem playerItemWithAsset:urlAsset];
    [self loadPlayer];
}

- (void)loadPlayer {
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
    [self addObserverWithPlayer:self.player];
    
    [self addObserverWithPlayerItem:self.playerItem];
    
    [self playerWillAddAudioToPlayQueue:self.player];
    
    [self.playerView setPlayer:self.player];
    
    [self.player play];
}

- (void)addObserverWithPlayerItem:(AVPlayerItem *)playerItem
{
    [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"playbackBufferFull" options:NSKeyValueObservingOptionNew context:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
}

- (void)removeObserverWithPlayerItem:(AVPlayerItem *)playerItem
{
    [playerItem removeObserver:self forKeyPath:@"status"];
    [playerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [playerItem removeObserver:self forKeyPath:@"playbackBufferFull"];
}

- (void)addObserverWithPlayer:(AVPlayer *)player
{
    __weak typeof(self)weakSelf = self;
    self.timeObserver =
    [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, NSEC_PER_SEC) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        if (weakSelf.duration <= 0) {
            return;
        }
        
        if (weakSelf.player.rate == 0) {
            return;
        }
        
        if (weakSelf.player.currentItem.isPlaybackBufferEmpty) {
            return;
        }
        
        if (weakSelf.isSeeking) {
            return;
        }
        
        NSTimeInterval currentTime = CMTimeGetSeconds(time);
        if (currentTime > weakSelf.duration) {
            currentTime = weakSelf.duration;
        }
        if (currentTime < weakSelf.currentTime) {
            return;
        }
        
        weakSelf.currentTime = currentTime;
        
        //播放进度
        NSTimeInterval progress = weakSelf.currentTime / weakSelf.duration;
        
        if (!weakSelf.audioPlayView.playProgressView.isTracking) {
            [weakSelf.audioPlayView.playProgressView setValue:progress animated:YES];
            weakSelf.audioPlayView.playedTimeLabel.text = [weakSelf formatterTime:currentTime];
        }
    }];
    [player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)removeObserverWithPlayer:(AVPlayer *)player
{
    [player removeTimeObserver:self.timeObserver];
    [player removeObserver:self forKeyPath:@"rate"];
    self.timeObserver = nil;
}

- (NSTimeInterval)duration {
    return CMTimeGetSeconds(self.playerItem.duration);
}

- (void)playerItemDidPlayToEnd:(NSNotification *)notify
{
    NSLog(@"音频播放完成通知!!!");
    [self pause];
//    [self nextBtnDidClicked:self.nextBtn];
}

- (void)playerWillAddAudioToPlayQueue:(AVPlayer *)player
{
    self.audioPlayView.playedTimeLabel.text = @"--:--";
    self.audioPlayView.totalTimeLabel.text = @"--:--";
    self.audioPlayView.playProgressView.value = 0;
    self.audioPlayView.bufferProgressView.progress = 0;
}

- (void)bufferTimeChanged:(NSTimeInterval)bufferTime duration:(NSTimeInterval)duration progress:(NSTimeInterval)progress
{
    [self.audioPlayView.bufferProgressView setProgress:progress animated:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        NSLog(@"player status %@, rate %@, error: %@", @(self.playerItem.status), @(self.player.rate), self.playerItem.error);
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status) {
            case AVPlayerStatusUnknown:
            {
                NSLog(@"KVO：未知状态，此时不能播放，%@", self.player.currentItem.error);
                break;
            }
            case AVPlayerStatusReadyToPlay:
            {
                NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.asset.duration);
                if (!isnan(duration)) {
                    self.duration = duration;
                    self.audioPlayView.playedTimeLabel.text = [self formatterTime:0];
                    self.audioPlayView.totalTimeLabel.text = [self formatterTime:duration];
                } else {
                    NSLog(@"总时长NAN!!!");
                }
                NSLog(@"KVO：准备播放：%f", self.duration);
                break;
            }
            case AVPlayerStatusFailed:
            {
                NSError *currentItemError = self.player.currentItem.error;
                NSLog(@"KVO：播放失败，原因:%@", currentItemError);
                [self showToastWithMessage:currentItemError.localizedDescription];
                [self stop];
                break;
            }
            default:
                break;
        }
    } else if ([keyPath isEqualToString:@"timeControlStatus"]) {
        
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        if (self.duration == 0) {
            return;
        }
        NSTimeInterval totalBuffer = [self availableDuration];// 计算缓冲进度
        self.bufferTime = totalBuffer;
//        NSLog(@"已缓存时长 : %f", totalBuffer);
        NSTimeInterval bufferProgress = 0;
        bufferProgress = totalBuffer / self.duration;
        [self bufferTimeChanged:totalBuffer duration:self.duration progress:bufferProgress];
        
        if (totalBuffer > self.getCurrentPlayingTime + 5) { // 缓存 大于 播放 当前时长+5
            if (!self.isPausedByUser) {
                [self play];
            }
        } else {
            NSLog(@"等待播放，网络出现问题"); //虽然如此但是有时候还是能播放
            if (self.player.currentItem.playbackLikelyToKeepUp) {
                if (!self.isPausedByUser) {
                    [self play];
                }
            }
        }
    }

    if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        if (self.duration == 0) {
            return;
        }
        if (self.player.currentItem.playbackLikelyToKeepUp) {
            if (!self.isPausedByUser) {
                [self play];
            }
        }
    }
    
    if ([keyPath isEqualToString:@"playbackBufferFull"]) {
        if (self.duration == 0) {
            return;
        }
        if (self.player.currentItem.playbackBufferFull) {
            if (!self.isPausedByUser) {
                [self play];
            }
        }
    }
}

/**
 *  返回 当前 视频 播放时长
 */
- (double)getCurrentPlayingTime {
    return self.player.currentTime.value/self.player.currentTime.timescale;
}

/**
 *  返回 当前 视频 缓存时长
 */
- (NSTimeInterval)availableDuration {
    NSArray *loadedTimeRanges = [[self.player currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}

// MARK: - getter/setter

- (FDEPlayerView *)playerView {
    if (_playerView == nil) {
        _playerView = [[FDEPlayerView alloc] initWithFrame:CGRectZero];
        _playerView.backgroundColor = [UIColor blackColor];
    }
    return _playerView;
}

- (NSMutableArray *)playerUrls
{
    if (!_playerUrls) {
        _playerUrls = [NSMutableArray array];
    }
    return _playerUrls;
}

- (UIButton *)nextBtn
{
    if (!_nextBtn) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.backgroundColor = [UIColor greenColor];
        [btn setTitle:@"下一首" forState:UIControlStateNormal];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:14]];
        [btn addTarget:self action:@selector(nextBtnDidClicked:) forControlEvents:UIControlEventTouchUpInside];
        _nextBtn = btn;
    }
    return _nextBtn;
}

- (UIButton *)lastBtn
{
    if (!_lastBtn) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.backgroundColor = [UIColor greenColor];
        [btn setTitle:@"上一首" forState:UIControlStateNormal];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:14]];
        [btn addTarget:self action:@selector(lastBtnDidClicked:) forControlEvents:UIControlEventTouchUpInside];
        _lastBtn = btn;
    }
    return _lastBtn;
}

- (UIButton *)testBtn
{
    if (!_testBtn) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.backgroundColor = [UIColor greenColor];
        [btn setTitle:@"test-mainThread" forState:UIControlStateNormal];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:14]];
        [btn addTarget:self action:@selector(testBtnDidClicked:) forControlEvents:UIControlEventTouchUpInside];
        _testBtn = btn;
    }
    return _testBtn;
}

- (UIButton *)delegateBtn
{
    if (!_delegateBtn) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.backgroundColor = [UIColor greenColor];
        [btn setTitle:@"delegate/o" forState:UIControlStateNormal];
        [btn setTitle:@"delegate/c" forState:UIControlStateSelected];
        [btn.titleLabel setFont:[UIFont systemFontOfSize:14]];
        [btn addTarget:self action:@selector(delegateBtnDidClicked:) forControlEvents:UIControlEventTouchUpInside];
        _delegateBtn = btn;
    }
    return _delegateBtn;
}

- (void)testBtnDidClicked:(id)sender {
    NSLog(@"test main thread");
    [self showToastWithMessage:@"test main thread"];

//    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
//        NSInteger s = arc4random() % 10;
//        if (s == 0) {
//            s = 1;
//        }
//        CGFloat val = s / 10.0;
//        [self.audioPlayView.playProgressView setValue:val];
//        [self slider:self.audioPlayView.playProgressView valueDidEndChanged:val];
//    }];
}

- (void)delegateBtnDidClicked:(UIButton *)sender {
    self.isDelegated = !self.isDelegated;
    sender.selected = !sender.selected;
    if (!self.isDelegated) {
        [self showToastWithMessage:@"已关闭"];
    } else {
        [self showToastWithMessage:@"已开启"];
    }
}

@end
