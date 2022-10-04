//
//  FDEBaseViewController.m
//  Demon
//
//  Created by xuequan on 2020/1/29.
//  Copyright © 2020 xuequan. All rights reserved.
//

#import "FDEBaseViewController.h"
#import <MBProgressHUD.h>

@interface FDEBaseViewController ()

@end

@implementation FDEBaseViewController

- (void)dealloc
{
    NSLog(@"%@销毁", self);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.whiteColor;
}

- (void)showToastWithMessage:(NSString *)message
{
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.view];
    hud.mode = MBProgressHUDModeText;
    hud.detailsLabel.text = message;
    hud.detailsLabel.textColor = [UIColor blackColor];
    hud.removeFromSuperViewOnHide = YES;
    [self.view addSubview:hud];
    [hud showAnimated:YES];
    [hud hideAnimated:YES afterDelay:2];
}

- (void)showProgress {
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
}

- (void)hiddenProgress {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

@end
