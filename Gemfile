
source "https://gems.ruby-china.com/"

# gem "rails"
gem 'fastlane', '2.226.0'
gem 'cocoapods', '1.16.2'
# gem 'xcodeproj', '1.27.0'
gem 'xcodeproj', '~> 1.27'
# 本地 CocoaPods 插件：给 xcodeproj 补 objectVersion 70（Xcode 16），
# 彻底解决 "[Xcodeproj] Unable to find compatibility version string for object version `70`"。
# bundle exec pod install 时自动加载，无需手改 pbxproj。
# gem 'cocoapods-xcodeproj-objectversion70', path: 'CocoapodsPlugins/cocoapods-xcodeproj-objectversion70'
# google库更新升级 pod >- 1.12.0， 需要指定activesupport https://github.com/fastlane/fastlane/issues/21585
gem 'activesupport','7.1.0'
# gem 'cocoapods-project-hmap'

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)