//
//  FDESlider.h
//  Demon
//
//  Created by xuequan on 2020/1/29.
//  Copyright © 2020 xuequan. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FDESlider;
@protocol FDESliderDelegate <NSObject>

@optional
- (void)sliderThumbDidTouchDown:(FDESlider *)slider;
- (void)slider:(FDESlider *)slider valueChanging:(float)value;
- (void)slider:(FDESlider *)slider valueDidEndChanged:(float)value;

@end

@interface FDESlider : UISlider

@property (nonatomic, weak) id<FDESliderDelegate>delegate;

@end
