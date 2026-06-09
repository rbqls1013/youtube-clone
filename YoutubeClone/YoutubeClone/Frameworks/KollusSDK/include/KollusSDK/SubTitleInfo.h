//
//  SubTitleInfo.h
//  KollusPlayer
//
//  Created by Song on 2015. 1. 13..
//  Copyright (c) 2015년 Franky.Jung. All rights reserved.
//

#import <Foundation/Foundation.h>

/// 자막 정보
@interface SubTitleInfo : NSObject
/// 자막 이름
@property (nonatomic, retain) NSString* strName;
/// 자막 경로
@property (nonatomic, retain) NSString* strUrl;
/// 자막 언어
@property (nonatomic, retain) NSString* strLanguage;
/// AI 자막 여부
@property (nonatomic, unsafe_unretained) BOOL isAISubtitles;
@end
