Changelog
=========

Version numbering represents the Swift version, plus a running number representing updates, fixes and new features at the same time.
You can also refer to commit logs to get details on what was implemented, fixed and improved.


### 3.0.3

- Allow more UI customization via `authConfig.UI` and making `OAuth2Authorizer` friendlier to subclassing
- Implement custom authorization UIs for password grants (thanks @amaurydavid !)
- Optionally allow `DataLoader` to follow 302 redirects automatically (on same host)
- Fix a bug with data loader not using refresh tokens (#184)


### 3.0.2

- Move `secretInBody` and `customParameters` from `authConfig` to `clientConfig`, where they belong
- Allow to override default UTF-8 encoding of the _Basic_ authorization header
- Improvements to embedded authorization
- Remove `onAuthorize` and `onFailure` callbacks, which have been deprecated with 3.0 (now handled in the callback to `authorize()`)


### 3.0.1

- Add Azure flow (thanks @everlof)
- Add `keychain_account_*` settings (thanks @aidzz)
- Workaround for Safari issue (thanks @everlof)


### 3.0.0

- Rewrite in Swift 3
- New DataLoader, meaning you don't have to do authorization yourself (and helps with Alamofire use)
- Broad API redesign, you should now use `authorize(params:callback:)` if you still authorize manually
- All errors returned by OAuth2 are now `OAuth2Error` types
- Add `Package.swift` for the Swift package manager
- Expose `keychainAccessGroup` (`keychain_access_group` in settings; thanks @damienrambout !)
- Some new errors (like `.forbidden` and `.missingState`)


### 2.3.0

- Use Swift 2.3


### 2.2.9

- Allow to add custom authorization headers (thanks @SpectralDragon)
- Fix: add `client_id` to password grant even if there is no secret (thanks Criss!)


### 2.2.8

- Make keychain store name programmer-settable (fixes #111 and #119)
- More public methods to support subclassing
- Allow resource owner password grant without client_id


### 2.2.7

- Use a simple logger for logging purposes (inspired by @tompson and @ChrisInIssaquah)
- Make `parseAccessTokenResponseData()` public for non-conformant OAuth2 providers (like Facebook)
- Add overrideable `normalizeAccessTokenResponseKeys()` and `normalizeRefreshTokenResponseKeys()` (inspired by @ChrisTitos)


### 2.2.6

- Make sure extra params are passed to refresh token requests (fixes #105)
- The convenience `request(forURL:)` method by default no longer uses locally cached data


### 2.2.5

- Use ephemeral NSURLSession by default; fixes #96
- Build fix to enable Carthage builds (thanks @davidpeckham !)


### 2.2.4

- Fix: add optional auth parameters to the authorize URL


### 2.2.3

- Refactor authorization request creation
- Add `OAuth2ClientCredentialsReddit` to deal with Reddit installed apps special flow
- Rename clashing method definitions to fix #99


### 2.2.2

- Add tvOS build (thanks @davidkraus and @ddengler !)
- Update SwiftKeychain integration (thanks @davidkraus and @ddengler !)
- Expose `keychainAccessMode` (`keychain_access_mode` in settings; thanks @tompson !)


### 2.2.1

- Better error parsing when handling redirect URL in code grants
- Remove implicit web view unwrapping to fix issue #88


### 2.2

- Add capability to abort ongoing authorization with `abortAuthorization()`
- Implement embedded auth for OS X 10.10 and newer (thanks @insidegui !)
- Move `autoDismiss` param from `authorize()` into the `authConfig` struct
- Change `openAuthorizeURLInBrowser()` to throw instead of returning a Bool (throwing `UnableToOpenAuthorizeURL` instead of returning false)
- Add `RequestCancelled` Error
- Add `OAuth2CodeGrantLinkedIn` to deal with LinkedIn
- Add `OAuth2CodeGrantNoTokenType` to deal with Instagram, Bitly and all others not returning `token_type`
- Add `UTF8DecodeError`


### 2.1.3

- Fix issue #76 (dismissing built-in web view controller in a more robust way)


### 2.1.2

- Fix issue #75 (refresh tokens not saved to keychain)


### 2.1.1

- Fix issue #72 (refresh token SNAFU from 2.1)


### 2.1

- Refresh tokens now work for all grants
- Rewrite most parts of the code to use `OAuth2Error` instead of `NSError`
- Improvements to password grant
- Properly implement dynamic client registration
- Fix issues #47, #59, #61, #66 and improve behavior in several scenarios


### 2.0.2

- Fix issue #53, not detecting canceling the `SFSafariViewController` by the user


### 2.0.1

- Use `SFSafariViewController` for embedded authorization if used on iOS 9+


### 2.0.0

- Uses Swift 2.0


### 1.2.9

- Add flag to force client registration
- Last planned release for Swift 1.2


### 1.2.8

- Allow to customize the _Back_ button in iOS' login web view.
- Fix _“wrong password”_ detection in password grant, thanks Tim!


### 1.2.7

- Add `accessTokenAssumeUnexpired` variable to allow storing of access tokens even if "expires_in" is not supplied. You may need to intercept 401s and re-authorize when performing REST requests.
- Add `OAuth2DynReg` class to help with dynamic client registration (preliminary/incomplete).
- Code refactoring


### 1.2.6

- Add `OAuth2PasswordGrant` for password grant flow, courtesy of Tim Sneed.


### 1.2.5

- Add `OAuth2ClientCredentials` for client_credentials flow.
- Fix bug where custom authorize parameters would not appear in the embedded iOS view controller (thanks Nate!).


### 1.2.4

- Make `OAuth2CodeGrant` auto-decide whether to use an “Authorization: Basic ...” header (if the client has a _clientSecret_) or omit it. The option `secretInBody` (called `secret_in_body` in the settings dict) allows to force putting the secret into the request body.


### 1.2.3

- Client uses refresh-tokens automatically, if available. Use the new `authorize()` method to take advantage of this.
- System keychain integration for token storage. Use `keychain` = false to turn this off.


### 1.2.2

- Support detecting Google's `urn:ietf:wg:oauth:2.0:oob` callback URLs
- Improvements when detecting and intercepting callback URLs


### 1.2.1

- Swift compiler improvements (via use of `final` keyword)


### 1.2

- Swift 1.2 support
- Improve embedded web view controller (iOS only)


### 1.1.2

- Correctly use www-form-urlencoded parameter strings


### 1.1.0

- Initial release supporting Swift 1.1
