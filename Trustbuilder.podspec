require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "Trustbuilder"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "13.4" }
  s.source       = { :git => "https://github.com/skanderhk/react-native-mfa-trustbuilder.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}"
  s.public_header_files = "ios/RNTrustbuilder.h"

  s.vendored_frameworks = "ios/libs/libmaccess.xcframework"

  s.preserve_paths = "ios/iw.h"

  s.pod_target_xcconfig = {
    "HEADER_SEARCH_PATHS" => '"$(PODS_TARGET_SRCROOT)/ios"',
    "OTHER_LDFLAGS" => "-lsqlite3 -lz",
  }

  install_modules_dependencies(s)
end
