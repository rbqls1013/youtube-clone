//
//  Chapter.h
//  KollusSDK
//
//  Created by 김용기 on 7/31/25.
//  Copyright © 2025 ykkim. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Chapter : NSObject

/// 챕터 위치
@property (nonatomic, unsafe_unretained) NSTimeInterval position;
/// 문자
@property (nonatomic, retain) NSString *value;

@end

@interface ChapterDict : NSObject

/// 챕터 언어
@property (nonatomic, retain) NSString* strLanguage;
/// 챕터 리스트
@property (nonatomic, retain) NSMutableArray* listChapter;

@end

NS_ASSUME_NONNULL_END
