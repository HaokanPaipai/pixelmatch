# PixelMatch Podfile
#
# 用途：引入广告 SDK（GoogleMobileAds + UMP + HKAdvertising 国内网盟全套），
# 与 HKAdKit（本地 SPM）配合完成"开屏 / 激励 / 插屏"三类广告位。
# 心智模型：HKAdKit 是纯策略引擎（零三方依赖），广告 SDK 都从这里引入，
# 通过 PixelMatch/Meta/Ad/*Adapter.swift 桥接到 HKAdKit 协议。
#
# pod install 后必须打开 `pixelmatch.xcworkspace`，不再用 `.xcodeproj`。

platform :ios, '15.6'
install! 'cocoapods', :deterministic_uuids => false

target 'pixelmatch' do
  use_frameworks!

  hk_advertising_source = {
    :git => 'git@github.com:HaokanPaipai/HKAds.git',
    :branch => 'main'
  }

  # ---- 海外 ----
  pod 'Google-Mobile-Ads-SDK', '11.10.0'
  pod 'GoogleUserMessagingPlatform'

  # ---- 国内网盟（HKAdvertising 聚合 subspec，一次性带齐 CSJ/GDT/KS/BD 4 家适配层 + SDK 依赖）----
  # HKAdvertising/CN（abb8cb1+ 引入）= CSJ + GDT + KS + BD 全套，替代原先单列 4 个 subspec。
  pod 'HKAdvertising/CN', hk_advertising_source

  # podspec 内部对 Ads-CN 做了版本固定（6.8.0.7），但 GDT/KS/BD 未 pin，会自动取最新。
  # PixelMatch 沿用与 goodlook 同版本，避免 SDK 浮版本带来回归风险。
  pod 'GDTMobSDK',     '4.15.10'
  pod 'KSAdSDK',       '3.3.76.5.0'
  pod 'BaiduMobAdSDK', '5.101'

  target 'pixelmatchTests' do
    inherit! :search_paths
  end

  target 'pixelmatchUITests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  # 统一 Team / Deployment Target，避免每个 pod 子工程要手动调。
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['DEVELOPMENT_TEAM'] = 'X43383F6CJ'
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.6'
        config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      end
    end
  end

  # CocoaPods 的 Embed Frameworks 脚本会通过 rsync 复制三方 XCFramework。
  # Xcode 的 User Script Sandboxing 开启后会拦截 DerivedData 读写，导致 TTSDKCore 等框架嵌入失败。
  app_project_path = File.join(__dir__, 'pixelmatch.xcodeproj')
  app_project = Xcodeproj::Project.open(app_project_path)
  app_project.targets.each do |target|
    next unless ['pixelmatch', 'pixelmatchTests', 'pixelmatchUITests'].include?(target.name)

    target.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
  app_project.save

  # Xcode 15+ 的 DT_TOOLCHAIN_DIR 兼容修复（CocoaPods/CocoaPods#12065）。
  installer.aggregate_targets.each do |target|
    target.xcconfigs.each do |variant, xcconfig|
      xcconfig_path = target.client_root + target.xcconfig_relative_path(variant)
      IO.write(xcconfig_path, IO.read(xcconfig_path).gsub('DT_TOOLCHAIN_DIR', 'TOOLCHAIN_DIR'))
    end
  end

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.base_configuration_reference.is_a? Xcodeproj::Project::Object::PBXFileReference
        xcconfig_path = config.base_configuration_reference.real_path
        IO.write(xcconfig_path, IO.read(xcconfig_path).gsub('DT_TOOLCHAIN_DIR', 'TOOLCHAIN_DIR'))
      end
    end
  end
end
