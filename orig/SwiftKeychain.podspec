Pod::Spec.new do |s|
  s.name         = "SwiftKeychain"
  s.version      = "1.0.0"
  s.summary      = "Swift wrapper for working with the Keychain API implemented with Protocol Oriented Programming."

  s.description  = <<-DESC
                   Swift wrapper for working with the Keychain API implemented with Protocol Oriented Programming with support for iOS, OSX, watchOS and tvOS.
                   DESC

  s.homepage     = "https://github.com/yankodimitrov/SwiftKeychain"
  s.license      = { :type => "MIT", :file => "LICENSE.txt" }
  s.author       = { "Yanko Dimitrov" => "yanko@yankodimitrov.com" }
  s.social_media_url   = "https://twitter.com/_yankodimitrov"

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/yankodimitrov/SwiftKeychain.git", :tag => "v#{s.version}" }
  s.source_files  = "Keychain/Keychain.swift"

  s.framework  = "Security"

  s.requires_arc = true
end
