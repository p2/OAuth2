#
#  p2.OAuth2
#
#  Versions reflect the Swift version they support.
#  Enjoy!
#

Pod::Spec.new do |s|
  s.name         = "p2.OAuth2"
  s.version      = "2.2.1"
  s.summary      = "OAuth2 framework for OS X and iOS, written in Swift."
  s.description  = <<-DESC
                   OAuth2 frameworks for OS X and iOS written in Swift.
                   
                   A flexible framework supporting standards-compliant _implicit_ and _code_ grant flows. Some
                   websites like Facebook may use slightly differring OAuth2 implementations, for those the
                   framework aims to provide specific subclasses handling these differences.
                   
                   Start with `import p2_OAuth2` in your source files. Code documentation is available from within
                   Xcode (ALT + click on symbols) and on [p2.github.io/OAuth2/](http://p2.github.io/OAuth2/).
                   DESC
  s.homepage     = "https://github.com/p2/OAuth2"
  s.license      = "Apache 2"
  s.author       = { "Pascal Pfiffner" => "phase.of.matter@gmail.com" }
  s.source       = { :git => "https://github.com/p2/OAuth2.git", :tag => "#{s.version}", :submodules => true  }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"
  s.requires_arc = true
  s.pod_target_xcconfig = { 'OTHER_SWIFT_FLAGS' => '-DNO_KEYCHAIN_IMPORT' }
  s.ios.pod_target_xcconfig = { 'OTHER_SWIFT_FLAGS' => '-DIMPORT_SWIFT_KEYCHAIN' }
  s.ios.dependency 'SwiftKeychain', '~> 0.1.5'
  
  s.source_files = "Sources/Base/*.swift"
  s.ios.source_files = "Sources/iOS/*.swift"
  s.osx.source_files = "Sources/OSX/*.swift", "SwiftKeychain/SwiftKeychain/Keychain/*.swift"
end
