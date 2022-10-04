//
//  FDEAudioPlayButton.m
//  Demon
//
//  Created by xuequan on 2020/1/29.
//  Copyright © 2020 xuequan. All rights reserved.
//

#import "FDEAudioPlayButton.h"

@interface FDEAudioPlayButton ()

@property (nonatomic, strong) CALayer *circularLayer;
@property (nonatomic, assign) BOOL isLoading;

@end

@implementation FDEAudioPlayButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _circularLayer = [CALayer layer];
        _circularLayer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
        [self drawCircularWithLayer:_circularLayer circularWidth:2];
        [self.layer addSublayer:_circularLayer];
        
        //默认隐藏
        _circularLayer.hidden = YES;
    }
    
    return self;
}

- (void)drawCircularWithLayer:(CALayer *)layer circularWidth:(CGFloat)circularWidth
{
    CGFloat minSide = MIN(layer.frame.size.width, layer.frame.size.height);
    if (minSide == 0) {
        return;
    }
    
    for (CALayer *subLayer in layer.sublayers) {
        [subLayer removeFromSuperlayer];
    }
    
    //创建圆环路径
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(minSide/2.0, minSide/2.0) radius:minSide/2.0 - 2 * circularWidth startAngle:0 endAngle:M_PI * 2 clockwise:YES];
    
    //圆环遮罩
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    shapeLayer.fillColor = [UIColor clearColor].CGColor;
    shapeLayer.strokeColor = [UIColor whiteColor].CGColor;
    shapeLayer.lineWidth = circularWidth;
    shapeLayer.strokeStart = 0;
    shapeLayer.strokeEnd = 1;
    shapeLayer.lineCap = kCALineCapRound;
    shapeLayer.lineDashPhase = 0.8;
    shapeLayer.path = bezierPath.CGPath;
    [layer setMask:shapeLayer];
    
    //颜色渐变
    NSMutableArray *colors = [NSMutableArray arrayWithObjects:(id)[UIColor colorWithRed:1 green:1 blue:1 alpha:1].CGColor, (id)[[UIColor colorWithRed:1 green:1 blue:1 alpha:0.5] CGColor], nil];
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.shadowPath = bezierPath.CGPath;
    gradientLayer.frame = CGRectMake(0, 0, layer.frame.size.width, layer.frame.size.height/2.0); //上半部分
    gradientLayer.startPoint = CGPointMake(1, 0);
    gradientLayer.endPoint = CGPointMake(0, 0);
    [gradientLayer setColors:[NSArray arrayWithArray:colors]];
    [layer addSublayer:gradientLayer]; //设置颜色渐变
    
    NSMutableArray *colors1 = [NSMutableArray arrayWithObjects:(id)[[UIColor colorWithRed:1 green:1 blue:1 alpha:0.5] CGColor], (id)[[UIColor colorWithRed:1 green:1 blue:1 alpha:0] CGColor], nil];
    CAGradientLayer *gradientLayer1 = [CAGradientLayer layer];
    gradientLayer1.shadowPath = bezierPath.CGPath;
    gradientLayer1.frame = CGRectMake(0, layer.frame.size.height/2.0, layer.frame.size.width, layer.frame.size.height/2.0); //下半部分
    gradientLayer1.startPoint = CGPointMake(0, 1);
    gradientLayer1.endPoint = CGPointMake(1, 1);
    [gradientLayer1 setColors:[NSArray arrayWithArray:colors1]];
    [layer addSublayer:gradientLayer1];
}

- (void)startLoading {
    //动画
    if (!self.isLoading) {
        self.isLoading = YES;
        
        _circularLayer.hidden = NO;
        CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnimation.fromValue = [NSNumber numberWithFloat:0];
        rotationAnimation.toValue = [NSNumber numberWithFloat:2.0*M_PI];
        rotationAnimation.repeatCount = MAXFLOAT;
        rotationAnimation.duration = 1;
        rotationAnimation.removedOnCompletion = NO;
        rotationAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        [_circularLayer addAnimation:rotationAnimation forKey:@"rotationAnnimation"];
    }
}

- (void)stopLoading
{
    if (self.isLoading) {
        self.isLoading = NO;
        [_circularLayer removeAnimationForKey:@"rotationAnnimation"];
        _circularLayer.hidden = YES;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (!CGSizeEqualToSize(self.frame.size, self.circularLayer.frame.size)) {
        self.circularLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
        [self drawCircularWithLayer:self.circularLayer circularWidth:2];
    }
}

@end
