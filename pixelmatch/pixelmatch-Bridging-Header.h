//
//  pixelmatch-Bridging-Header.h
//  pixelmatch
//
//  暴露 HKAdvertising（ObjC pod）给 Swift。pod install 后才能编译这些 import。
//  PixelMatch 的国内广告网络适配器（PixelMatchOpenAdAdapter/Rewarded/Interstitial）
//  通过本头文件桥接 HKAdSplash / EasyAdRewardVideo / EasyAdInterstitial。
//

#if __has_include(<HKAdvertising/HKAdSplash.h>)
#import <HKAdvertising/HKAdSplash.h>
#import <HKAdvertising/EasyAdRewardVideo.h>
#import <HKAdvertising/EasyAdInterstitial.h>
#endif
