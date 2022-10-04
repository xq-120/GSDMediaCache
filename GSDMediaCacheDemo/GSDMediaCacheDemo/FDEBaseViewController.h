//
//  FDEBaseViewController.h
//  Demon
//
//  Created by xuequan on 2020/1/29.
//  Copyright © 2020 xuequan. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FDEBaseViewController : UIViewController

- (void)showToastWithMessage:(NSString *)message;

- (void)showProgress;

- (void)hiddenProgress;

@end

NS_ASSUME_NONNULL_END
