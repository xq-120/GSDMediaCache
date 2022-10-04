//
//  FDEItemModel.h
//  ImageDemo
//
//  Created by 薛权 on 2021/9/25.
//  Copyright © 2021 xuequan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FDEItemModel : NSObject

@property (nonatomic, copy) NSString *title;

@property (nonatomic, copy) void (^actionBlk)(void);

@end

NS_ASSUME_NONNULL_END
