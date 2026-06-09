//
//  KollusChat.h
//  KollusSDK
//
//  Created by 김용기 on 2021/01/20.
//  Copyright © 2021 Franky.Jung. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KollusChat : NSObject

/// 채팅 화면 보여줄지 체크
@property (nonatomic, unsafe_unretained) BOOL isChatVisible;
/// 채팅 정보 있는지 체크
@property (nonatomic, unsafe_unretained) BOOL isChatInfo;
/// 채팅 Url
@property (nonatomic, copy) NSString *chatUrl;
/// 관리자 여부
@property (nonatomic, unsafe_unretained) BOOL isAdmin;
/// 익명 여부
@property (nonatomic, unsafe_unretained) BOOL isAnonymous;
/// 룸 ID
@property (nonatomic, copy) NSString *roomId;
/// 채팅 서버
@property (nonatomic, copy) NSString *chattingServer;
/// 사용자 ID
@property (nonatomic, copy) NSString *userId;
/// 닉네임
@property (nonatomic, copy) NSString *nickName;
/// 포토 Url
@property (nonatomic, copy) NSString *photoUrl;

@end

NS_ASSUME_NONNULL_END
