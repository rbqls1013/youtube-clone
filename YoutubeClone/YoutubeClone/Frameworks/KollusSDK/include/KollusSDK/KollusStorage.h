//
//  KollusStorage.h
//  KollusSDK
//
//  Created by Franky.Jung on 2014. 11. 28..
//  Copyright (c) 2014년 Catenoid. All rights reserved.
//
#import <AVKit/AVKit.h>
#import "KollusSDK.h"
#import "KollusStorageDelegate.h"

@class KollusContent;

@interface KollusStorage : NSObject

/// 다운로드 상태정보 델리게이트
@property (nonatomic, weak) id<KollusStorageDelegate> delegate;
/// KollusSDK 버전
@property (nonatomic, copy, readonly) NSString *applicationVersion;
/// KollusPlayer Device ID
@property (nonatomic, copy, readonly) NSString *applicationDeviceID;

/// KollusSDK 인증 키(카테노이드에서 발급)
@property (nonatomic, copy) NSString *applicationKey;
/// 어플리케이션 Bundle ID(ex:com.yourcompany.applicationname)
@property (nonatomic, copy) NSString *applicationBundleID;
/// keychain 그룹(ex:com.yourcompany.shared)
@property (nonatomic, copy) NSString *keychainGroup;
/// KollusSDK 유효날짜(카테노이드에서 발급)
@property (nonatomic, copy) NSDate *applicationExpireDate;
/// Kollus SDK 폴더
@property (nonatomic, copy, readonly) NSString *storagePath;

/// 다운로드 컨텐츠 총 사이즈(bytes)
@property (nonatomic, unsafe_unretained, readonly) long long storageSize;
/// 캐시데이터 총 사이즈(bytes)
@property (nonatomic, unsafe_unretained, readonly) long long cacheDataSize;

/// Hybrid App에서 사용되는 port 번호
@property (nonatomic) NSInteger serverPort;

/// 동적 drm 파라메터
@property (nonatomic, copy) NSString *extraDrmParam;

/// UserAgent
@property (nonatomic, copy, readonly) NSString *appUserAgent;
/// 디바이스 Type(kp-mobile, kp-tablet)
@property (nonatomic, copy, readonly) NSString *deviceType;


/**
 스토리지 폴더 설정
 @param path kollus sdk에서 사용하는 폴더
 @return YES 성공
 @return NO 실패
 @warning 이 메서드는 신규 앱에서만 사용해야 됨. 그렇지 않으면 기존 download된 컨텐츠는 볼 수 없음
        startStorage 함수를 호출 전에 사용해야 됨. default path로 Documnet 폴더를 사용
 */
- (BOOL)setKollusPath:(NSString *)path;
/**
 KollusStorage 시작
 @param error 에러
 @return YES 성공
 @return NO 실패
 @warning 이 메서드를 호출하지 않은 경우 컨텐츠 정보 배열(contents)이 nil로 반환됨
 */
- (BOOL)startStorage:(NSError**)error;

/**
 KollusStorage 시작
 @param first 설치후 최초 실행
 @param error 에러
 @return 성공시 YES, 실패 시 NO를 반환
 @warning 이 메서드를 호출하지 않은 경우 컨텐츠 개수(contentsCount)가 0으로 반환됨
 */
- (BOOL)startStorageWithFirst:(BOOL)first error:(NSError**)error;

/**
 KollusStorage 시작
 @param error 에러
 @return 성공시 YES, 실패 시 NO를 반환
 @warning 이 메서드를 호출하지 않은 경우 컨텐츠 개수(contentsCount)가 0으로 반환됨
 @warning 이 메서드는 키체인으로부터 playerID 획득 실패시
   최초 실행이면 새로 생성후 처리,  최초 실행이 아니면 세번 요청 모두 실패시 에러 처리
 */
- (BOOL)startStorageWithCheck:(NSError**)error;

/**
 KollusStorage 시작
 @param error 에러
 @return 성공시 YES, 실패 시 NO를 반환
 @warning 이 메서드를 호출하지 않은 경우 컨텐츠 개수(contentsCount)가 0으로 반환됨
 @warning 이 메서드는 playerID를 새로 생성하여 키체인에 등록하고 사용
*/
- (BOOL)startStorageWithNewPlayerID:(NSError**)error;

/**
 컨텐트 다운로드 초기화
 @param URL 다운로드 초기화 할 컨텐트 URL
 @param error 에러상세
 @return 초기화 완료된 컨텐트 키 (mediaContentKey)
 */
- (NSString *)loadContentURL:(NSString *)URL error:(NSError**)error;

/**
 컨텐트 다운로드 체크: 전달된 URL에 해당하는 컨텐츠의 다운로드 유무 및 MCK를 확인하기 위해 사용
 @param URL 컨텐트 URL
 @param error 에러상세
 @return 다운로드 완료된 컨텐트 media content key
 */
- (NSString*)checkContentURL:(NSString *)URL error:(NSError **)error;

/**
 컨텐트 다운로드 (컨텐트 인덱스로 다운로드)
 @param mediaContentKey 다운로드 할 컨텐트 키
 @return YES 성공
 @return NO 실패
 */
- (BOOL)downloadContent:(NSString *)mediaContentKey error:(NSError **)error;


/**
 특정 컨텐트 삭제
 @param mediaContentKey 삭제할 컨텐트 키
 @param error 에러상세
 @return YES 성공
 @return NO 실패
 */
- (BOOL)removeContent:(NSString *)mediaContentKey error:(NSError **)error;


/**
 스트리밍 컨텐트 캐시데이터 삭제
 @param error 에러상세
 @return YES 성공
 @return NO 실패
 */
- (BOOL)removeCacheWithError:(NSError **)error;


/**
 컨텐츠 다운로드를 중지
 @param mediaContentKey 다운로드를 중지할 컨텐트 키
 @param error 에러상세
 @return YES 성공
 @return NO 실패
 */
- (BOOL)downloadCancelContent:(NSString *)mediaContentKey error:(NSError **)error;


/**
 스토리지 네트워크 타임아웃 설정
 @param timeOut 타임아웃 값(초)
 @param retryCount 재시도 횟수
 */
- (void)setNetworkTimeOut:(NSInteger)timeOut retry:(NSInteger)retryCount;

/**
 Drm 컨텐츠 리스트 갱신
 @param expired 모든 컨텐츠 YES, 만기된 컨텐츠 NO
 */
- (void)updateDownloadDRMInfo:(BOOL)bAll;


/**
 스토리지 캐쉬 사이즈 설정
 @param cacheSizeMB 스트리밍 컨텐츠 캐쉬 사이즈(Mega Bytes)
 */
- (void)setCacheSize:(NSInteger)cacheSizeMB;

/**
 스토리지 컨텐츠 백그라운드 다운로드 여부
  */
- (void)setBackgroundDownload:(BOOL)bBackground;

/**
 다운로드 컨텐츠 정보 배열
 */
- (NSMutableArray*)contents;

/**
 미전송된 LMS data 전송
 */
- (void)sendStoredLms;


@end
