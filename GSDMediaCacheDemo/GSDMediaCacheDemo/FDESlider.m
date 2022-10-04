//
//  FDESlider.h
//  Demon
//
//  Created by xuequan on 2020/1/29.
//  Copyright © 2020 xuequan. All rights reserved.
//

#import "FDESlider.h"

@interface FDESlider ()
@property (nonatomic, strong) UITapGestureRecognizer *sliderTap;
@end

@implementation FDESlider

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        //滑动中
        [self addTarget:self action:@selector(progressSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        [self addTarget:self action:@selector(progressSliderTouchDown:) forControlEvents:UIControlEventTouchDown];
        //滑动结束
        [self addTarget:self action:@selector(progressSliderTouchEnded:) forControlEvents: UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchUpOutside];
        //点击slider
        _sliderTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapSliderAction:)];
        [self addGestureRecognizer:_sliderTap];
    }
    
    return self;
}

//更改进度条的跟踪view高度
- (CGRect)trackRectForBounds:(CGRect)bounds {
    CGRect rect = CGRectMake(0, (bounds.size.height - 5)/2.0, bounds.size.width, 5);
    return rect;
}

- (void)tapSliderAction:(UITapGestureRecognizer *)tap
{
    if ([tap.view isKindOfClass:[UISlider class]]) {
        UISlider *slider = (UISlider *)tap.view;
        CGPoint point    = [tap locationInView:slider];
        CGFloat length   = slider.frame.size.width;
        CGFloat tapValue = point.x / length;
        
        slider.value = tapValue;
//        NSLog(@"点击:%.3f", self.value);
        if (self.delegate && [self.delegate respondsToSelector:@selector(slider:valueDidEndChanged:)]) {
            [self.delegate slider:self valueDidEndChanged:self.value];
        }
    }
}

- (void)progressSliderTouchDown:(UISlider *)sender {
//    NSLog(@"touch down:%f", sender.value);
    _sliderTap.enabled = NO;
    if (self.delegate && [self.delegate respondsToSelector:@selector(sliderThumbDidTouchDown:)]) {
        [self.delegate sliderThumbDidTouchDown:self];
    }
}

- (void)progressSliderValueChanged:(UISlider *)sender {
//    NSLog(@"ValueChanged:%.3f", self.value);
    if (self.delegate && [self.delegate respondsToSelector:@selector(slider:valueChanging:)]) {
        [self.delegate slider:self valueChanging:self.value];
    }
}

- (void)progressSliderTouchEnded:(UISlider *)sender {
    _sliderTap.enabled = YES;
    //seek
    if (self.delegate && [self.delegate respondsToSelector:@selector(slider:valueDidEndChanged:)]) {
        [self.delegate slider:self valueDidEndChanged:self.value];
    }
}

@end
