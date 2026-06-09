//
//  KollusStorageDelegate.h
//  KollusSDK
//
//  Created by Franky.Jung on 2014. 11. 28..
//  Copyright (c) 2014년 Catenoid. All rights reserved.
//

@class KollusStorage;
@class KollusContent;

@protocol KollusStorageDelegate <NSObject>

/**
 컨텐트 다운로드 중 상태변화가 있는 경우 호출
 @param KollusStorage KollusStorage 아이디
 @param cotent 상태변화가 있는 컨텐트 정보
 @param error 에러정보: nil이 아닌 경우 에러발생
 */
- (void)kollusStorage:(KollusStorage *)kollusStorage downloadContent:(KollusContent *)content error:(NSError *)error;

/**
 DRM Callback 처리후 호출
 @param KollusStorage KollusStorage 아이디
 @param request request 정보
 @param json response 받은 json
 @param error 에러정보: nil이 아닌 경우 에러발생
 */
- (void)kollusStorage:(KollusStorage *)kollusStorage request:(NSDictionary *)request json:(NSDictionary *)json error:(NSError *)error;

/**
 DRM 컨텐츠 리스트를 일괄 갱신중 각 컨텐츠 갱신이 끝난 경우 호출
 @param KollusStorage KollusStorage 아이디
 @param cur 현재 항목
 @param count 전체 컨텐츠 갯수
 @param error 에러정보: nil이 아닌 경우 에러발생
 */
- (void)kollusStorage:(KollusStorage *)kollusStorage cur:(int)cur count:(int)count error:(NSError *)error;


/**
 LMS Callback 처리후 호출
 @param KollusStorage KollusStorage 아이디
 @param lmsData  lms data 정보
 @param lmsResult  lms result 정보
 */
- (void)kollusStorage:(KollusStorage *)kollusStorage lmsData:(NSString *)lmsData resultJson:(NSDictionary *)resultJson;

/**
 미전송 LMS Callback 완료후 호출
 @param successCount  lms 전송 성공 횟수
 @param failCount  lms 전송 실패 횟수
 */
- (void)onSendCompleteStoredLms:(int)successCount failCount:(int)failCount;

@end
