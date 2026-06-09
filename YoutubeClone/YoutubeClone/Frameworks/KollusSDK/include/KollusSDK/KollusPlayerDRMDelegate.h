//
//  KollusPlayerDRMDelegate.h
//  KollusSDK
//
//  Created by Franky.Jung on 2014. 12. 4..
//  Copyright (c) 2014년 Catenoid. All rights reserved.
//

#import "KollusSDK.h"

@protocol KollusPlayerDRMDelegate <NSObject>

/**
 DRM Callback 전송 후 호출
 @param kollusPlayerView KollusPlayerView 아이디
 @param json 레스폰스 받은 JSON 객체
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView request:(NSDictionary *)request json:(NSDictionary *)json error:(NSError *)error;

@end
