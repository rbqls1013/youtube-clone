//
//  KollusBookmark.h
//  KollusSDK
//
//  Created by Franky.Jung on 2014. 12. 12..
//  Copyright (c) 2014년 Catenoid. All rights reserved.
//

#import "KollusSDK.h"

typedef NS_ENUM(NSInteger, KollusBookmarkKind) {
    KollusBookmarkKindUser,     /// 사용자 북마크
    KollusBookmarkKindIndex     /// 인덱스 북마크
};

@interface KollusBookmark : NSObject

/// 북마크 시간
@property (nonatomic, unsafe_unretained, readonly) NSTimeInterval position;
/// 북마크 생성된 일시
@property (nonatomic, unsafe_unretained, readonly) NSDate *time;
/// 북마크 타이틀(인덱스:강사용)
@property (nonatomic, copy, readonly) NSString *title;
/// 북마크 타이틀(사용자)
@property (nonatomic, copy, readonly) NSString *value;
/// 북마크 종류
@property (nonatomic, readonly) KollusBookmarkKind kind;

@end