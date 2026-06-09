//
//  KollusPlayerView.h
//  KollusSDK
//
//  Created by Franky.Jung on 2014. 12. 4..
//  Copyright (c) 2014년 Catenoid. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "KollusSDK.h"
#import "KollusPlayerDelegate.h"
#import "KollusPlayerDRMDelegate.h"
#import "KollusPlayerLMSDelegate.h"
#import "KollusPlayerBookmarkDelegate.h"
#import "KPSection.h"
#import "KollusChat.h"

@class KollusContent;
@class KollusStorage;
@class KollusBookmark;

@interface KollusPlayerView : UIView

/// 플레이어 관련 델리게이트
@property (nonatomic, weak) id<KollusPlayerDelegate> delegate;
/// DRM 정보 관련 델리게이트
@property (nonatomic, weak) id<KollusPlayerDRMDelegate> DRMDelegate;
/// LMS정보 관련 델리게이트
@property (nonatomic, weak) id<KollusPlayerLMSDelegate> LMSDelegate;
/// Bookmark 관련 델리게이트
@property (nonatomic, weak) id<KollusPlayerBookmarkDelegate> bookmarkDelegate;

/// KollusStorage 포인터
@property (nonatomic, weak) KollusStorage *storage;
/// 재생할 컨텐트 URL(Stream Play)
@property (nonatomic, copy) NSString *contentURL;
/// 재생할 컨텐트 Media Content Key (Local Play)
@property (nonatomic) NSString *mediaContentKey;
/// 사용중인 컨텐츠 정보
@property (nonatomic, weak, readonly) KollusContent *content;
/// AI 배속 지원 여부
@property (nonatomic, unsafe_unretained) BOOL AIRateEnable;
/// 컨텐트 현재시간
@property (nonatomic, unsafe_unretained) NSTimeInterval currentPlaybackTime;
/// 라이브 타임쉬프트 Duration
@property (nonatomic, unsafe_unretained, readonly) NSTimeInterval liveDuration;
/// 컨텐트 재생속도
/// 10배속까지 지원. 경고 : 2배속 초과시 품질 저하 및 오디오, 비디오 싱크가 맞지 않을 수 있음
@property (nonatomic, unsafe_unretained) float currentPlaybackRate;
/// 북마크 정보 배열
@property (nonatomic, strong) NSArray *bookmarks;
/// 컨텐트 출력 모드
@property (nonatomic, unsafe_unretained) KollusPlayerContentMode scalingMode;
/// 플레이어 화면 영역
@property (nonatomic, unsafe_unretained) CGRect playerContentFrame;
/// 전체반복 모드
@property (nonatomic, unsafe_unretained) KollusPlayerRepeatMode repeatMode;
/// 화면출력 허용여부
@property (nonatomic, unsafe_unretained, readonly) BOOL screenConnectEnabled;
/// 북마크 수정권한 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL bookmarkModifyEnabled;
/// 디버그 로그 출력여부
@property (nonatomic, unsafe_unretained) BOOL debug;
/// 재생준비 완료여부
@property (nonatomic, unsafe_unretained, readonly) BOOL isPreparedToPlay;
/// 재생중 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL isPlaying;
/// 버퍼링 진행여부
@property (nonatomic, unsafe_unretained, readonly) BOOL isBuffering;
/// 탐색중 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL isSeeking;
/// 화면이동중 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL isScrolling;
/// 오디오 컨텐트 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL isAudioOnly;
/// 시작시 mute 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL muteOnStart;
/// 원본컨텐츠 영상사이즈
@property (nonatomic, unsafe_unretained, readonly) CGSize naturalSize;
/// Zoom in 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL isZoomedIn;
/// 플레이어 타입
@property (nonatomic, readonly) KollusPlayerType playerType;
/// 플레이어 스킨정보 JSON Data
@property (nonatomic, copy) NSString *customSkin;
/// 미리보기 정보
@property (nonatomic) KPSection *playSection;
/// Repeat Start Time
@property (nonatomic, unsafe_unretained, readonly) NSInteger nRepeatStartTime;
/// Repeat End Time
@property (nonatomic, unsafe_unretained, readonly) NSInteger nRepeatEndTime;
/// Playback Limit Duration
@property (nonatomic, unsafe_unretained, readonly) NSInteger nPlaybackLimitDuration;
/// Playback Limit Message
@property (nonatomic, copy) NSString *strPlaybackLimitMessage;
/// 백그라운드 오디오파일 재생
@property (nonatomic, unsafe_unretained) BOOL audioBackgroundPlay;
/// 다운로드 컨텐츠 lms off
@property (nonatomic, unsafe_unretained) BOOL lmsOffDownloadContent;
/// Proxy Server Port 지정
@property (nonatomic, unsafe_unretained) NSUInteger proxyPort;

/// 인트로 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL intro;
/// seek 할 수 있는지
@property (nonatomic, unsafe_unretained, readonly) BOOL seekable;
/// 주어진 n초후에 skip
@property (nonatomic, unsafe_unretained, readonly) NSInteger nSecSkip;
/// Live 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL isLive;
/// 배속 컨트롤 가능 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL disablePlayRate;
/// 주어진 n초까지 또는 현재 재생 초까지 Seek 할 수 있음. seekable이 false일 때만 적용
/// -1 : seek 할 수 없음
@property (nonatomic, unsafe_unretained, readonly) NSInteger nSeekableEnd;
/// Partner portal 설정 값 : 자막 스타일 "bg" : 자막 배경 적용, "bg"가 아니면 사용자 설정
@property (nonatomic, copy, readonly) NSString *strCaptionStyle;
/// 강제 이어보기
@property (nonatomic, unsafe_unretained, readonly) BOOL forceNScreen;
/// 이어보기 시간값이 작을 때에도 이어보기 유효
@property (nonatomic, unsafe_unretained, readonly) BOOL ignoreZero;
/// 썸네일 사용 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL isThumbnailEnable;
/// 썸네일 다운로드 방식(sync, async)
@property (nonatomic, unsafe_unretained, readonly) BOOL isThumbnailSync;
/// FairPlay 인증 URL
@property (nonatomic, copy) NSString *fpsCertURL;
/// FairPlay DRM URL
@property (nonatomic, copy) NSString *fpsDrmURL;
/// Action Stats URL ( KollusPlayer only )
@property (nonatomic, copy, readonly) NSString *actionStatsUrl;
/// Action Stats Secret Key ( KollusPlayer only )
@property (nonatomic, copy, readonly) NSString *actionStatsSecretKey;
/// 오프라인 북마크는 다운로드 컨텐츠만 사용
/// 0: 사용 안함, 1: 사용함
@property (nonatomic, unsafe_unretained, readonly) NSInteger nOfflineBookmarkUse;
/// 1: 인덱스만 다운로드, 2: 인덱스/북마크 모두 다운로드
@property (nonatomic, unsafe_unretained, readonly) NSInteger nOfflineBookmarkDownload;
/// 추가/삭제 사용 여부( 0:사용(기본값), 1: 사용 안함)
@property (nonatomic, unsafe_unretained, readonly) NSInteger nOfflineBookmarkReadOnly;
/// Chapter 정보 리스트
@property (nonatomic, readonly) NSMutableDictionary* chapterInfo;

/// 비디오 워터마크
/// 비디오 워터마크 문자
@property (nonatomic, copy, readonly) NSString *strVideoWaterMark;
/// 비디오 워터마크 알파 값
@property (nonatomic, unsafe_unretained, readonly) NSInteger nVideoWaterMarkAlpha;
/// 비디오 워터마크 폰트 크기
@property (nonatomic, unsafe_unretained, readonly) NSInteger nVideoWaterMarkFontSize;
/// 비디오 워터마크 칼라
@property (nonatomic, copy, readonly) NSString *strVideoWaterMarkFontColor;
/// 비디오 워터마크 보이는 시간
@property (nonatomic, unsafe_unretained, readonly) NSInteger nVideoWaterMarkShowTime;
/// 비디오 워터마크 보이지 않는 시간
@property (nonatomic, unsafe_unretained, readonly) NSInteger nVideoWaterMarkHideTime;
/// 동적 drm 파라메터
@property (nonatomic, copy) NSString *extraDrmParam;
/// HLS ABR Information
@property (nonatomic, readonly) NSMutableArray *streamInfoList;

/// 라이브 채팅
@property (nonatomic) KollusChat *kollusChat;

/// 다음 회차 재생 Show Time
@property (nonatomic, unsafe_unretained, readonly) NSInteger nextEpisodeShowTime;
/// 다음 회차 재생 URL
@property (nonatomic, copy, readonly) NSString *nextEpisodeCallbackURL;
/// 다음 회차 재생 Params
@property (nonatomic, readonly) NSMutableDictionary *nextEpisodeCallbackParams;
/// 다음 회차 재생 Show Button
@property (nonatomic, unsafe_unretained, readonly) BOOL nextEpisodeShowButton;

/// Content Provider Key
@property (nonatomic, copy, readonly) NSString *contentProviderKey;
/// Content Provider Name
@property (nonatomic, copy, readonly) NSString *contentProviderName;
/// 백그라운드 재생 가능 여부
@property (nonatomic, unsafe_unretained, readonly) BOOL disableBackgroundAudio;
/// Max playback Rate
@property (nonatomic, unsafe_unretained, readonly) NSInteger maxPlaybackRate;

/**
 컨텐트URL을 사용하여 플레이어를 생성
 @param url 재생할 컨텐트 URL
 @return 생성된 플레이어 아이디
 */
- (id)initWithContentURL:(NSString*)url;

/**
 컨텐트 인덱스를 사용하여 플레이어를 생성(다운로드 받은 컨텐트의 경우에 사용)
 @param mck 재생할 컨텐트의 mediaContentKey
 @return 생성된 플레이어 아이디
 */
- (id)initWithMediaContentKey:(NSString*)mck;

/**
 컨텐츠 재생준비 (KollusPlayer or Native)
 @param type 플레이어 타입
 @param error 에러상세
 @return YES 성공
 @return NO 실패
 */
- (BOOL)prepareToPlayWithMode:(KollusPlayerType)type error:(NSError**)error;

/**
 재생시작
 @param error 에러상세
 @return YES 성공
 @return NO 실패
 @warning prepareToPlayerWithError 메서드 호출 및 성공한 경우에 사용
 */
- (BOOL)playWithError:(NSError **)error;

/**
 일시정지
 @param error 에러상세
 @return YES 성공
 @return NO 실패
 @warning prepareToPlayerWithError 메서드 호출 및 성공한 경우에 사용
 */
- (BOOL)pauseWithError:(NSError **)error;

/**
 재생중지
 @param error 에러상세
 @return YES 성공
 @return NO 실패
 @warning prepareToPlayerWithError 메서드 호출 및 성공한 경우에 사용
 */
- (BOOL)stopWithError:(NSError **)error;

/**
 비디오 출력화면을 이동
 @param distance 이동할 거리
 @param error 에러상세
 @return YES 성공
 @return NO 실패
 */
- (BOOL)scroll:(CGPoint)distance error:(NSError **)error;

/**
 비디오 출력화면 이동 중지(화면위치 고정)
 @param error 에러상세
 @return YES 성공
 @return NO 실패
 */
- (BOOL)scrollStopWithError:(NSError **)error;

/**
 비디오 출력화면 확대/축소
 @param recognizer pinch줌을 적용할 UIPinchGestureRecognizer 포인터
 @param error 에러상세
 @return YES 성공
 @return NO 실패
 */
- (BOOL)zoom:(UIPinchGestureRecognizer*)recognizer error:(NSError **)error;

/**
 북마크 추가
 @param position 추가할 시간
 @param value 북마크 타이틀
 @param error 에러 상세정보
 @return YES 추가 가능
 @return NO 추가 불가능
 @warning 이미 동일한 position의 북마크가 존재할 경우 입력된 북마크로 대체됨
 */
- (BOOL)addBookmark:(NSTimeInterval)position value:(NSString*)value error:(NSError **)error;

/**
 북마크 삭제
 @param position 삭제할 북마크 시간
 @param error 에러 상세정보
 @return YES 삭제 가능
 @return NO 삭제 불가능
 @warning 북마크 kind가 KollusBookmarkKindIndex인 북마크는 삭제되지 않음
 */
- (BOOL)removeBookmark:(NSTimeInterval)position error:(NSError **)error;

/**
 플레이어 네트워크 타임아웃 설정
 @param timeOut 타임아웃 값(초)
 @param retryCount 재시도 횟수
 */
- (void)setNetworkTimeOut:(NSInteger)timeOut;

/**
 버퍼링 배수 설정
 @param bufferingRatio 설정할 버퍼링 배수
 @warning prepareToPlayerWithError 메서드 호출 및 성공한 경우에 사용
 @warning PlayerTypeKollus인 경우에만 적용됩니다.
 */
- (void)setBufferingRatio:(NSInteger)bufferingRatio;


/**
 플레이어 생성여부 확인
 @return YES 생성됨
 @return NO 생성안됨
 */
- (BOOL)isOpened;


/**
 play list중에 현재 재생중인 동영상을 skip
 */
- (BOOL) setSkipPlay;

/**
 HLS 재생중 bandwidth 변경
 */
- (void) changeBandWidth:(int)bandWidth;

/**
 자막파일 선택
 @param path 사용할 자막파일 경로
 @return bool true:성공 false:실패
 */
- (bool)setSubTitlePath:(char*)path;

/**
 서브자막파일 선택
 @param path 사용할 자막파일 경로
 @return bool true:성공 false:실패
 */
- (bool)setSubTitleSubPath:(char*)path;

/// 자막 파일 리스트
@property (nonatomic, readonly) NSMutableArray* listSubTitle;
/// 서브자막 파일 리스트
@property (nonatomic, readonly) NSMutableArray* listSubTitleSub;


/**
 비디오 영역
 @return CGRect 비디오 재생 위치
 */
- (CGRect)getVideoPosition;

/**
 비디오 출력화면 확대/축소 값
 @return CGFloat 출력화면 확대/축소 비율 값
 */
- (CGFloat)getZoomValue;

/**
 Foreground 상태로 변경시 Player 재생상태를 Pause로 유지하기 위한 API
 @param NO(default): 포그라운드 진입시 자동재생(기존과 동일)
 @param YES: 포그라운드 진입시 pause 상태로 유지됨. APP에서 필요한 경우 Play 처리 필요
 */
- (void)setPauseOnForeground:(BOOL)bPause;

/**
 Zoom 기능에서 zoom out 기능을 막는 API
 @param NO(default): zoom out(축소)기능 Enable
 @param YES: zoom out 기능 Disable
 */
- (void)setDisableZoomOut:(BOOL)bDisable;

/**
 코덱 설정
 @param YES(default): YES : 하드웨어 코덱, NO : 소프트웨어 코덱
 */
- (void)setDecoder:(bool)bHW;

/**
 AI 배속 사용 설정
 @param YES(default): YES : AI 배속, NO : 일반 배속
 */
- (void) setAIRate:(bool)bAIRate;

@end
