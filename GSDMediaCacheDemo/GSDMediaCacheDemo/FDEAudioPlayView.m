//
//  FDEAudioPlayView.m
//  Demon
//
//  Created by xuequan on 2020/1/29.
//  Copyright © 2020 xuequan. All rights reserved.
//

#import "FDEAudioPlayView.h"

@implementation FDEAudioPlayView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    //这个时候的view的frame还是XIB上的,是不正确的.
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (void)commonInit
{
    _playBtn = [FDEAudioPlayButton buttonWithType:UIButtonTypeCustom];
    _playBtn.frame = CGRectMake(0, 0, 44, 44);
    [_playBtn setImage:[UIImage imageNamed:@"pause_icon"] forState:UIControlStateNormal];
    [_playBtn setImage:[UIImage imageNamed:@"playing_icon"] forState:UIControlStateSelected];
    _playBtn.adjustsImageWhenHighlighted = NO;
    
    [_playBtn addTarget:self action:@selector(playBtnDidClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_playBtn];
    
    _playStatusLabel = [[UILabel alloc] init];
    _playStatusLabel.font = [UIFont systemFontOfSize:10];
    _playStatusLabel.textAlignment = NSTextAlignmentCenter;
    _playStatusLabel.textColor = [UIColor blackColor];
    [self addSubview:_playStatusLabel];
    
    _bufferProgressView = [[YLProgressBar alloc] init];
    _bufferProgressView.type = YLProgressBarTypeRounded;
    _bufferProgressView.progress = 0;
    _bufferProgressView.hideStripes = YES;
    _bufferProgressView.hideGloss = YES;
    _bufferProgressView.progressTintColor = [UIColor greenColor];
    _bufferProgressView.trackTintColor = [UIColor lightGrayColor];
    _bufferProgressView.progressStretch = NO;
    _bufferProgressView.uniformTintColor = YES;
    _bufferProgressView.progressBarInset = 0;
    [self addSubview:_bufferProgressView];
    
    _playProgressView = [[FDESlider alloc] init];
    [_playProgressView setThumbImage:[UIImage imageNamed:@"progress_thumb"] forState:UIControlStateNormal];
    _playProgressView.maximumValue = 1;
    _playProgressView.minimumValue = 0;
    _playProgressView.value = 0;
    _playProgressView.minimumTrackTintColor = [UIColor cyanColor];
    _playProgressView.maximumTrackTintColor = [UIColor clearColor];
    [self addSubview:_playProgressView];
    
    _playedTimeLabel = [[UILabel alloc] init];
    _playedTimeLabel.font = [UIFont systemFontOfSize:10];
    _playedTimeLabel.textAlignment = NSTextAlignmentLeft;
    _playedTimeLabel.textColor = [UIColor blackColor];
    [self addSubview:_playedTimeLabel];
    
    _totalTimeLabel = [[UILabel alloc] init];
    _totalTimeLabel.font = [UIFont systemFontOfSize:10];
    _totalTimeLabel.textAlignment = NSTextAlignmentRight;
    _totalTimeLabel.textColor = [UIColor blackColor];
    [self addSubview:_totalTimeLabel];
    
    self.playedTimeLabel.text = @"--:--:--";
    self.totalTimeLabel.text = @"--:--:--";
    self.playStatusLabel.text = @"继续收听";
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    //这个时候的view的frame还是XIB上的,是不正确的.
    
    self.playedTimeLabel.text = @"--:--:--";
    self.totalTimeLabel.text = @"--:--:--";
    self.playStatusLabel.text = @"继续收听";
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _playStatusLabel.frame = CGRectMake(0, CGRectGetMaxY(_playBtn.frame) + 4, 44, 14);
    
    CGFloat bufferProgressViewX = CGRectGetMaxX(_playBtn.frame) + 11;
    _bufferProgressView.frame = CGRectMake(bufferProgressViewX, (44 - 5)/2.0, self.frame.size.width - bufferProgressViewX, 5);
    
    _playProgressView.frame = CGRectMake(bufferProgressViewX, (44 - 19)/2.0, self.frame.size.width - bufferProgressViewX, 19);
    
    _playedTimeLabel.frame = CGRectMake(bufferProgressViewX, CGRectGetMaxY(_bufferProgressView.frame) + 10, 100, 14);
    
    _totalTimeLabel.frame = CGRectMake(CGRectGetMaxX(_bufferProgressView.frame) - 100, CGRectGetMaxY(_bufferProgressView.frame) + 10, 100, 14);
}

- (void)playBtnDidClicked:(UIButton *)sender
{
    
}

@end
