//
//  KollusPlayerLMSDelegate.h
//  KollusSDK
//
//  Created by Franky.Jung on 2014. 12. 4..
//  Copyright (c) 2014년 Catenoid. All rights reserved.
//

#import "KollusSDK.h"

@protocol KollusPlayerLMSDelegate <NSObject>

/**
 LMS정보를 서버로 전송후 호출
 @param kollusPlayerView KollusPlayerView 아이디
 @param lmsData  lms data 정보
 @param resultJson  lms result 정보
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView lmsData:(NSString *)lmsData resultJson:(NSDictionary *)resultJson;

@end
