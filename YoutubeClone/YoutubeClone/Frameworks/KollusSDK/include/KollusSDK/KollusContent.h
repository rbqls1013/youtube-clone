//
//  KollusContent.h
//  KollusSDK
//
//  Created by Franky.Jung on 2014. 11. 28..
//  Copyright (c) 2014년 Catenoid. All rights reserved.
//

#import "KollusSDK.h"

@interface KollusContent : NSObject

/// 회사이름
@property (nonatomic, copy, readonly) NSString *company;
/// 컨텐트 타이틀
@property (nonatomic, copy, readonly) NSString *title;
/// 코스명
@property (nonatomic, copy, readonly) NSString *course;
/// 강사명
@property (nonatomic, copy, readonly) NSString *teacher;
/// 스냅샷 파일 경로
@property (nonatomic, copy, readonly) NSString *snapshot;
/// 썸네일 파일 경로
@property (nonatomic, copy, readonly) NSString *thumbnail;
/// 미디어 컨텐트 키
@property (nonatomic, copy, readonly) NSString *mediaContentKey;
/// 시놉시스
@property (nonatomic, copy, readonly) NSString *synopsis;
/// 상세정보 URL
@property (nonatomic, copy, readonly) NSString *descriptionURL;
/// 영상 원본 사이즈
@property (nonatomic, unsafe_unretained, readonly) CGSize naturalSize;
/// 플레이어 타입 : hw, sw, native
@property (nonatomic, copy, readonly) NSString *iosPlayerType;

/// 컨텐트 타입
@property (nonatomic, unsafe_unretained, readonly) KollusContentType contentType;
/// DRM 체크일시
@property (nonatomic, strong, readonly) NSDate *DRMCheckDate;
/// DRM 만료일시
@property (nonatomic, strong, readonly) NSDate *DRMExpireDate;
/// DRM 최대 카운트
@property (nonatomic, unsafe_unretained, readonly) long DRMExpireCountMax;
/// DRM 재생 카운트
@property (nonatomic, unsafe_unretained, readonly) long DRMExpireCount;
/// DRM 전체 재생가능 시간
@property (nonatomic, unsafe_unretained, readonly) NSTimeInterval DRMTotalExpirePlayTime;
/// DRM 재생가능 시간
@property (nonatomic, unsafe_unretained, readonly) NSTimeInterval DRMExpirePlayTime;
/// DRM 만료여부
@property (nonatomic, unsafe_unretained, readonly) BOOL DRMExpired;
/// DRM 유효기간 갱신 팝업 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL DRMExpireRefreshPopup;
/// 컨텐트 duration
@property (nonatomic, unsafe_unretained, readonly) NSTimeInterval duration;
/// 이어보기 시간
@property (nonatomic, unsafe_unretained, readonly) NSTimeInterval position;
/// 컨텐트 인덱스: 다운로드 컨텐트 재생시 사용
@property (nonatomic, unsafe_unretained, readonly) NSUInteger contentIndex;
/// 컨텐트 파일 사이즈
@property (nonatomic, unsafe_unretained, readonly) long long fileSize;
/// 다운로드 된 파일 사이즈
@property (nonatomic, unsafe_unretained, readonly) long long downloadSize;
/// 다운로드 백분율
@property (nonatomic, unsafe_unretained, readonly) NSUInteger downloadProgress;
/// 다운로드 완료여부
@property (nonatomic, unsafe_unretained, readonly) BOOL downloaded;
/// 다운로드 정지된 파일 사이즈
@property (nonatomic, unsafe_unretained, readonly) long long downloadStopSize;
/// 파일 다운로드 일시
@property (nonatomic, unsafe_unretained, readonly) int downloadedTime;

@end
