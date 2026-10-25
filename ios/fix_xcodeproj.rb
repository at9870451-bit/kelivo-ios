#!/usr/bin/env ruby
# 向 Runner 工程注入 Rust 静态库链接设置（绕过 pods/xcconfig 配置链的不确定性）
# kelivo_core 符号通过 -force_load 保证链入（防 dead-code-strip 掉 FFI 符号）
require 'xcodeproj'

project_path = File.expand_path('Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

lib_flags = '$(inherited) -force_load "$(SRCROOT)/sandbox/build/iphoneos/libkelivo_core.a"'

target = project.targets.find { |t| t.name == 'Runner' }
abort('Runner target not found') unless target

target.build_configurations.each do |cfg|
  cfg.build_settings['OTHER_LDFLAGS'] = lib_flags
  cfg.build_settings['DEAD_CODE_STRIPPING'] = 'NO'
  cfg.build_settings['STRIP_INSTALLED_PRODUCT'] = 'NO'
  cfg.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  cfg.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  cfg.build_settings['CODE_SIGN_IDENTITY'] = ''
  puts "#{cfg.name}: ldflags + strip 禁用 已注入"
end

project.save
puts 'Runner.xcodeproj 注入完成'
