//
//  FDEMessageViewController.m
//  GSDMediaCacheDemo
//
//  Created by xq on 2022/1/13.
//

#import "FDEMessageViewController.h"
#import "GSDMediaCache.h"

@interface FDEMessageViewController ()

@property (strong, nonatomic) UIButton *btn;
@end

@implementation FDEMessageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupSubview];
}


- (void)setupSubview {
    self.navigationItem.title = @"消息";
    self.btn.center = self.view.center;
    [self.view addSubview:self.btn];
}


- (void)btnDidClicked:(UIButton *)sender {
    NSLog(@"btnDidClicked");
    
    [self clearMediaCache];
}

- (void)clearMediaCache
{
    __weak typeof(self) weakSelf = self;
    [self showProgress];
    [[GSDMediaCache sharedMediaCache] clearDiskWithCompletion:^{
        [weakSelf hiddenProgress];
        [weakSelf showToastWithMessage:@"清除成功"];
    }];
}

- (void)clearAllCache
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString * cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSLog(@"%@",cachePath);
    NSDirectoryEnumerator *fileEnumerator = [fileManager enumeratorAtPath:cachePath];
    for (NSString *fileName in fileEnumerator) {
        NSString *filePath = [cachePath stringByAppendingPathComponent:fileName];
        [fileManager removeItemAtPath:filePath error:nil];
    }
    [self showToastWithMessage:@"清除成功"];
}

- (UIButton *)btn {
    if (_btn == nil) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(0, 0, 100, 44);
        btn.backgroundColor = [UIColor redColor];
        [btn setTitle:@"button" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(btnDidClicked:) forControlEvents:UIControlEventTouchUpInside];
        _btn = btn;
    }
    return _btn;
}


@end
