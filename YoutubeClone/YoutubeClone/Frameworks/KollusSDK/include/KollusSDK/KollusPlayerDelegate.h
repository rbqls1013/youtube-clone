//
//  KollusPlayerDelegate.h
//  KollusSDK
//
//  Created by Franky.Jung on 2014. 12. 4..
//  Copyright (c) 2014년 Catenoid. All rights reserved.
//

@class KollusPlayerView;
@class KollusCaption;

@protocol KollusPlayerDelegate <NSObject>

/**
 prepareToPlay 호출 후 컨텐트 재생준비 완료여부를 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param error 에러상세
 @remark error가 nil이 아닌 경우 재생준비 실패
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView prepareToPlayWithError:(NSError *)error;

/**
 재생이 시작된 경우에 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param userInteraction YES 사용자가 시작
 @param userInteraction NO 전제 반복을 통해서 시작, 시스템이 시작
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView play:(BOOL)userInteraction error:(NSError *)error;

/**
 일시정지 된 경우에 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param userInteraction YES 사용자가 일시정지
 @param userInteraction NO 시스템이 일시정지
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView pause:(BOOL)userInteraction error:(NSError *)error;

/**
 시스템의 데이터 버퍼링이 정체되거나 정체가 해소된 경우에 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param buffering YES 버퍼링 시작
 @param buffering NO 버퍼링 완료
 @param prepared NO 재생 준비전
 @param prepared YES 재생 준비후
@param error 에러상세
 @remark buffering 값이 YES로 변경되기 전에 시스템에 의한 일시정지 델리게이트가 호출된 경우 buffering 값이 NO로 변경된 경우에 UI에서 PlayWithError: 메서드 호출이 필요함.
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView buffering:(BOOL)buffering prepared:(BOOL)prepared error:(NSError *)error;

/**
 재생이 정지된 경우에 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param userInteraction YES 사용자가 종료
 @param userInteraction NO 끝까지 재생되어 종료, 시스템이 종료
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView stop:(BOOL)userInteraction error:(NSError *)error;

/**
 재생위치가 변경되기 전후에 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param position 변경되는 재생시간 값
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView position:(NSTimeInterval)position error:(NSError *)error;
// position 설정 전: kollusPlayerView.isSeeking = YES
// position 설정 후: kollusPlayerView.isSeeking = NO: media_event_type.MEDIA_SEEK_COMPLETE
// 두번 호출

/**
 영상화면 이동 동작 전후에 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param distance 영상 이동 거리
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView scroll:(CGPoint)distance error:(NSError *)error;
// scroll 설정 전: kollusPlayerView.isScrolling = YES
// scroll 설정 후: kollusPlayerView.isScrolling = NO 두번 호출.

/**
 비디오 출력화면 확대/축소 전후에 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param recognizer pinch줌을 적용할 UIPinchGestureRecognizer 포인터
 @param error 에러상세
 @return YES 성공
 @return NO 실패
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView zoom:(UIPinchGestureRecognizer*)recognizer error:(NSError **)error;

/**
 컨텐츠의 원본 영상사이즈 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param contentResolution 영상사이즈
 */
- (void)kollusPlayerView:(KollusPlayerView*)kollusPlayerView naturalSize:(CGSize)naturalSize;

/**
 재생화면 모드가 변경되었음
 @param kollusPlayerView KollusPlayerView 아이디
 @param playerContentMode 변경된 재생화면 모드
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView playerContentMode:(KollusPlayerContentMode)playerContentMode error:(NSError *)error;

/**
 재생화면 사이즈가 변경되었음
 @param kollusPlayerView KollusPlayerView 아이디
 @param contentFrame 변경된 화면 사이즈 정보
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView playerContentFrame:(CGRect)contentFrame error:(NSError *)error;

/**
 재생속도가 변경되었음
 @param kollusPlayerView KollusPlayerView 아이디
 @param playbackRate 변경된 재생속도
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView playbackRate:(float)playbackRate error:(NSError *)error;

/**
 반복재생모드가 변경되었음
 @param kollusPlayerView KollusPlayerView 아이디
 @param repeat YES 반복재생 설정모드로 변경
 @param repeat NO 반복재생 해제모드로 변경
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView repeat:(BOOL)repeat error:(NSError *)error;

/**
 TV출력 허용 컨텐트 속성 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param enabledOutput YES TV출력 허용
 @param enabledOutput NO TV출력 허용안함
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView enabledOutput:(BOOL)enabledOutput error:(NSError *)error;

/**
 기타에러 발생시 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView unknownError:(NSError *)error;

/**
 컨텐츠의 프레임레이트 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param framerate 영상 프레임레이트
 */
- (void)kollusPlayerView:(KollusPlayerView*)kollusPlayerView framerate:(int)framerate;

/**
 디바이스 락 발생시 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param lockedPlayer 실행중인 player type
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView lockedPlayer:(KollusPlayerType)playerType;

/**
 컨텐츠의 자막 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param charset 캐릭터셋
 @param caption 출력될 자막 데이터
 */
- (void)kollusPlayerView:(KollusPlayerView*)kollusPlayerView charset:(char*)charset caption:(char* )caption;

/**
 컨텐츠의 서브자막 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param charsetSub 캐릭터셋
 @param captionSub 출력될 자막 데이터
 */
- (void)kollusPlayerView:(KollusPlayerView*)kollusPlayerView charsetSub:(char*)charsetSub captionSub:(char* )captionSub;

/**
 썸네일 비동기 다운로드 완료를 전송
 @param kollusPlayerView KollusPlayerView 아이디
 @param 썸네일 유무
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView thumbnail:(BOOL)isThumbnail error:(NSError *)error;

/**
미디어 컨텐츠 키를 전송
@param kollusPlayerView KollusPlayerView 아이디
@param 미디어 컨텐츠 키
*/
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView mck:(NSString *)mck;

/**
 HLS 컨텐츠 재생중인 resolution 전송
@param kollusPlayerView KollusPlayerView 아이디
@param video height 정보
*/
- (void)kollusPlayerView:(KollusPlayerView *)view height:(int)height;

/**
 HLS 컨텐츠 bitrate 값 전송
@param kollusPlayerView KollusPlayerView 아이디
@param bitragte 정보
*/
- (void)kollusPlayerView:(KollusPlayerView *)view bitrate:(int)bitrate;


@end
