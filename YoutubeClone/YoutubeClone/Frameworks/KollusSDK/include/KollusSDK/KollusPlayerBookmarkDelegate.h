//
//  KollusPlayerBookmarkDelegate.h
//  KollusSDK
//
//  Created by Franky.Jung on 2014. 12. 4..
//  Copyright (c) 2014년 Catenoid. All rights reserved.
//

#import "KollusSDK.h"

@class KollusBookmark;

@protocol KollusPlayerBookmarkDelegate <NSObject>

/**
 재생 컨텐트의 북마크 유무를 호출
 @param kollusPlayerView KollusPlayerView 아이디
 @param bookmarks KollusBookmark 배열
 @param enabled YES: 북마크 있음 NO: 북마크 없음
 @param error 에러상세
 */
- (void)kollusPlayerView:(KollusPlayerView *)kollusPlayerView bookmark:(NSArray *)bookmarks enabled:(BOOL)enabled error:(NSError *)error;

@end
