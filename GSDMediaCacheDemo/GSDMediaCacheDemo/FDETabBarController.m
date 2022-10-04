//
//  FDETabBarController.m
//  Demon
//
//  Created by xuequan on 2020/1/29.
//  Copyright © 2020 xuequan. All rights reserved.
//

#import "FDETabBarController.h"
#import "FDENavigationController.h"
#import "FDEHomeViewController.h"
#import "FDEMessageViewController.h"
#import "FDEMineViewController.h"

@interface FDETabBarController ()

@end

@implementation FDETabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.whiteColor;
    
    [self setupControllers];
}

- (void)setupControllers {
    FDEHomeViewController *homeVC = FDEHomeViewController.new;
    FDENavigationController *homeNav = [[FDENavigationController alloc] initWithRootViewController:homeVC];
    homeNav.tabBarItem.title = @"首页";
    
    FDEMessageViewController *msgVC = FDEMessageViewController.new;
    FDENavigationController *msgNav = [[FDENavigationController alloc] initWithRootViewController:msgVC];
    msgNav.tabBarItem.title = @"消息";
    
    FDEMineViewController *mineVC = FDEMineViewController.new;
    FDENavigationController *mineNav = [[FDENavigationController alloc] initWithRootViewController:mineVC];
    mineNav.tabBarItem.title = @"我";
    
    NSArray *controllers = @[homeNav, msgNav, mineNav];
    [self setViewControllers:controllers];
}

@end
