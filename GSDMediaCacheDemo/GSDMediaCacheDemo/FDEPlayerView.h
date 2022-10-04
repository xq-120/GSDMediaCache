//
//  FDEPlayerView.h
//  Demon
//
//  Created by xuequan on 2020/1/29.
//  Copyright © 2020 xuequan. All rights reserved.
//

#import <UIKit/UIKit.h>

@import AVFoundation;

NS_ASSUME_NONNULL_BEGIN

@interface FDEPlayerView : UIView

- (AVPlayerLayer *)playerLayer;

- (void)setPlayer:(AVPlayer *)player;

@end

NS_ASSUME_NONNULL_END
