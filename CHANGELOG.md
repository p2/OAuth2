Changelog
=========

Version numbering represents the Swift version, plus a running number representing updates, fixes and new features at the same time.
You can also refer to commit logs to get details on what was implemented, fixed and improved.


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
