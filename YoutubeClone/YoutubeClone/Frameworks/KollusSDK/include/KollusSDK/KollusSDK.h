//
//  KollusSDK.h
//  KollusSDK
//
//  Created by Franky.Jung on 2014. 11. 28..
//  Copyright (c) 2014년 Catenoid. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// 플레이어 타입
typedef NS_ENUM(NSInteger, KollusPlayerType) {
    /// Kollus Player 사용
    PlayerTypeKollus = 0,
    /// Native player 사용
    PlayerTypeNative,
    /// HLS player 사용
    PlayerTypeHLS
};

/// 컨텐트 타입
typedef NS_ENUM(NSInteger, KollusContentType) {
    /// 스트리밍 컨텐트
    KollusContentTypeStreaming = 0,
    /// 다운로드 컨텐트
    KollusContentTypeDownloading,
    // 샘플 컨텐트 (do not use)
    KollusContentTypeSample,
    // HLS 스트리밍
    KollusContentTypeAdaptiveStreaming,
    // HLS 다운로드
    KollusContentTypeAdaptiveDownload
};

/// 플레이어 화면 출력 모드
typedef NS_ENUM(NSInteger, KollusPlayerContentMode) {
    /// 화면사이즈에 맞춤
    KollusPlayerContentModeScaleAspectFit = 0,
    /// 화면사이즈에 채움
    KollusPlayerContentModeScaleAspectFill,
    /// 컨텐트 원본사이즈(화면사이즈보다 작은경우 KollusPlayerContentModeScaleAspectFit 적용)
    KollusPlayerContentModeScaleCenter,
    /// 화면 비율 관계없이 화면사이즈에 채움
    KollusPlayerContentModeScaleFill
};

/// 반복재생 모드
typedef NS_ENUM(NSInteger, KollusPlayerRepeatMode) {
    /// 반복재생 안함
    KollusPlayerRepeatModeNone = 0,
    /// 반복재생
    KollusPlayerRepeatModeOne
};
