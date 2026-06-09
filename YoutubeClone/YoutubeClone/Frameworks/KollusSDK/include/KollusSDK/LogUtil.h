//
//  LogUtil.h
//  KollusSDK
//
//  Created by 김용기 on 2020/06/05.
//  Copyright © 2020 Franky.Jung. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol UtilDelegate;

@interface LogUtil : NSObject

@property (nonatomic, weak) id<UtilDelegate> utilDelegate;

+ (instancetype)sharedUtil;
+ (void)utilLog:(NSString *)logContent, ...;
@end

@protocol UtilDelegate<NSObject>
@required

- (void)onLogUtil:(NSString*)logData;

@end

NS_ASSUME_NONNULL_END
