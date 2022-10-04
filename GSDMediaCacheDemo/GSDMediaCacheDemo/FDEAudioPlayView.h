//
//  FDEAudioPlayView.h
//  Demon
//
//  Created by xuequan on 2020/1/29.
//  Copyright © 2020 xuequan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FDEAudioPlayButton.h"
#import "FDESlider.h"
#import "YLProgressBar.h"

@interface FDEAudioPlayView : UIView

@property (nonatomic, strong) FDEAudioPlayButton *playBtn;
@property (nonatomic, strong) UILabel *playStatusLabel;
//UIProgressView高度改变不了.一直是系统的2pt.所以只能自定义了
@property (nonatomic, strong) YLProgressBar *bufferProgressView;
@property (nonatomic, strong) FDESlider *playProgressView;
@property (nonatomic, strong) UILabel *playedTimeLabel;
@property (nonatomic, strong) UILabel *totalTimeLabel;

@end
