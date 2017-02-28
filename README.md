OAuth2
======

[![Build Status](https://travis-ci.org/p2/OAuth2.svg?branch=master)](https://travis-ci.org/p2/OAuth2)
[![License](https://img.shields.io/:license-apache-blue.svg)](LICENSE.txt)

OAuth2 frameworks for **macOS**, **iOS** and **tvOS** written in Swift 3.0.

- [⤵️ Installation](#installation)
- [🛠 Usage](#usage)
- [🖥 Sample macOS app][sample] (with data loader examples)
- [📱 Sample iOS app](https://github.com/p2/OAuth2PodApp) (using CocoaPods)
- [📖 Technical Documentation](https://p2.github.io/OAuth2)

OAuth2 requires Xcode 8, the built framework can be used on **OS X 10.9** or **iOS 8** and later.
Happy to accept pull requests, please see [CONTRIBUTING.md](./CONTRIBUTING.md)

### Swift Version

Since the Swift language is constantly evolving I have adopted a versioning scheme mirroring Swift versions:
the framework version's **first two digits are always the Swift version** the library is compatible with, see [releases](https://github.com/p2/OAuth2/releases).
Code compatible with brand new Swift versions are to be found on a separate feature branch named appropriately.


Usage
-----

To use OAuth2 in your own code, start with `import OAuth2` (use `p2_OAuth2` if you installed _p2.OAuth2_ via CocoaPods) in your source files.

In OAuth2 there are [**different kinds of _flows_**](https://tools.ietf.org/html/rfc6749#page-2).
This library supports all of them, make sure you're using the correct one for your use-case and authorization server.
A typical **code grant flow** is used for demo purposes below.
The steps for other flows are mostly the same short of instantiating a different subclass and using different client settings.

Still not working?
See [site-specific peculiarities](#site-specific-peculiarities).

### 1. Instantiate OAuth2 with a Settings Dictionary

In this example you'll be building an iOS client to Github, so the code below will be somewhere in a view controller of yours, _maybe_ the app delegate.

```swift
let oauth2 = OAuth2CodeGrant(settings: [
    "client_id": "my_swift_app",
    "client_secret": "C7447242",
    "authorize_uri": "https://github.com/login/oauth/authorize",
    "token_uri": "https://github.com/login/oauth/access_token",   // code grant only
    "redirect_uris": ["myapp://oauth/callback"],   // register your own "myapp" scheme in Info.plist
    "scope": "user repo:status",
    "secret_in_body": true,    // Github needs this
    "keychain": false,         // if you DON'T want keychain integration
] as OAuth2JSON)
```

See those `redirect_uris`?
You can use the scheme you want, but you must **a)** declare the scheme you use in your `Info.plist` and **b)** register the very same URI on the authorization server you connect to.

Note that **as of iOS 9**, you _should_ use [Universal Links](https://developer.apple.com/library/content/documentation/General/Conceptual/AppSearch/UniversalLinks.html) as your redirect URL, rather than a custom app scheme.
This prevents others from re-using your URI scheme and intercept the authorization flow.

Want to avoid switching to Safari and pop up a SafariViewController or NSPanel?
Set this:

```swift
oauth2.authConfig.authorizeEmbedded = true
oauth2.authConfig.authorizeContext = <# your UIViewController / NSWindow #>
```

Need to debug? Use a `.debug` or even a `.trace` logger:

```swift
oauth2.logger = OAuth2DebugLogger(.trace)
```

For more see [advanced settings](#advanced-settings) below.


### 2. Let the Data Loader or Alamofire Take Over

Starting with version 3.0, there is an `OAuth2DataLoader` class that you can use to retrieve data from an API.
It will automatically start authorization if needed and will ensure that this works even if you have multiple calls going on.
For details on how to configure authorization see step 4 below, in this example we'll use "embedded" authorization, meaning we'll show a SFSafariViewController on iOS if the user needs to log in.

[This wiki page has all you need](https://github.com/p2/OAuth2/wiki/Alamofire-4) to easily use OAuth2 with Alamofire instead.

```swift
let base = URL(string: "https://api.github.com")!
let url = base.appendingPathComponent("user")

var req = oauth2.request(forURL: url)
req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

self.loader = OAuth2DataLoader(oauth2: oauth2)
loader.perform(request: req) { response in
    do {
        let dict = try response.responseJSON()
        DispatchQueue.main.async {
            // you have received `dict` JSON data!
        }
    }
    catch let error {
        DispatchQueue.main.async {
            // an error occurred
        }
    }
}
```

### 3. Make Sure You Intercept the Callback

When using the OS browser or the iOS 9+ Safari view controller, you will need to **intercept the callback** in your app delegate and let the OAuth2 instance handle the full URL:

```swift
func application(_ app: UIApplication,
              open url: URL,
               options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
    // you should probably first check if this is the callback being opened
    if <# check #> {
        // if your oauth2 instance lives somewhere else, adapt accordingly
        oauth2.handleRedirectURL(url)
    }
}
```

You’re all set!

---

If you want to dig deeper or do authorization yourself, here it goes:

### 4. Manually Authorize the User

By default the OS browser will be used for authorization if there is no access token present or in the keychain.
**Starting with iOS 9**, `SFSafariViewController` will be used when enabling embedded authorization on iOS.

To start authorization call **`authorize(params:callback:)`** or, to use embedded authorization, the convenience method `authorizeEmbedded(from:callback:)`.

The login screen will only be **presented if needed** (see [_Manually Performing Authorization](#manually-performing-authorization) below for details) and will automatically **dismiss** the login screen on success.
See [_Advanced Settings_](#advanced-settings) for other options.


```swift
oauth2.authorize() { authParameters, error in
    if let params = authParameters {
        print("Authorized! Access token is in `oauth2.accessToken`")
        print("Authorized! Additional parameters: \(params)")
    }
    else {
        print("Authorization was cancelled or went wrong: \(error)")   // error will not be nil
    }
}

// for embedded authorization you can simply use:
oauth2.authorizeEmbedded(from: <# presenting view controller / window #>) { ... }

// which is equivalent to:
oauth2.authConfig.authorizeEmbedded = true
oauth2.authConfig.authorizeContext = <# presenting view controller / window #>
oauth2.authorize() { ... }
```

Don't forget, when using the OS browser or the iOS 9+ Safari view controller, you will need to **intercept the callback** in your app delegate.
This is shown under step 2 above.

See [_Manually Performing Authorization_](#manually-performing-authorization) below for details on how to do this on the Mac.

### 5. Receive Callback

After everything completes the callback will be called, **either** with a non-nil _authParameters_ dictionary (which may be empty!), **or** an error.
The access and refresh tokens and its expiration dates will already have been extracted and are available as `oauth2.accessToken` and `oauth2.refreshToken` parameters.
You only need to inspect the _authParameters_ dictionary if you wish to extract additional information.

For advanced use outlined below, there is the `afterAuthorizeOrFail` block that you can use on your OAuth2 instance.
The `internalAfterAuthorizeOrFail` closure is, as its name suggests, provided for internal purposes – it is exposed for subclassing and compilation reasons and you should not mess with it.
As of version 3.0.2, you can no longer use the `onAuthorize` and `onFailure` callback properties, they have been removed entirely.

### 6. Make Requests

You can now obtain an `OAuth2Request`, which is an already signed `MutableURLRequest`, to retrieve data from your server.
This request sets the _Authorization_ header using the access token like so: `Authorization: Bearer {your access token}`.

```swift
let req = oauth2.request(forURL: <# resource URL #>)
// set up your request, e.g. `req.HTTPMethod = "POST"`
let task = oauth2.session.dataTaskWithRequest(req) { data, response, error in
    if let error = error {
        // something went wrong, check the error
    }
    else {
        // check the response and the data
        // you have just received data with an OAuth2-signed request!
    }
}
task.resume()
```

Of course you can use your own `URLSession` with these requests, you don't have to use `oauth2.session`; use [OAuth2DataLoader](https://github.com/p2/OAuth2/blob/master/Sources/Base/OAuth2DataLoader.swift), as shown in step 2, or hand it over to _Alamofire_.
[Here's all you need](https://github.com/p2/OAuth2/wiki/Alamofire-4) to easily use OAuth2 with Alamofire.

### 7. Cancel Authorization

You can cancel an ongoing authorization any time by calling `oauth2.abortAuthorization()`.
This will cancel ongoing requests (like a code exchange request) or call the callback while you're waiting for a user to login on a webpage.
The latter will dismiss embedded login screens or redirect the user back to the app.

### 8. Re-Authorize

It is safe to always call `oauth2.authorize()` before performing a request.
You can also perform the authorization before the first request after your app became active again.
Or you can always intercept 401s in your requests and call authorize again before re-attempting the request.

### 9. Logout

If you're storing tokens to the keychain, you can call `forgetTokens()` to throw them away.

**However** your user is likely still logged in to the website, so on the next `authorize()` call, the web view may appear and immediately disappear.
When using the built-in web view on iOS 8, one can use the following snippet to throw away any cookies the app created.
With the newer `SFSafariViewController`, or logins performed in the browser, it's probably best to directly **open the logout page** so the user sees the logout happen.

```swift
let storage = HTTPCookieStorage.shared
storage.cookies?.forEach() { storage.deleteCookie($0) }
```


Manually Performing Authorization
---------------------------------

The `authorize(params:callback:)` method will:

1. Check if an authorize call is already running, if yes it will abort with an `OAuth2Error.alreadyAuthorizing` error
2. Check if an access token that has not yet expired is already present (or in the keychain), if not
3. Check if a refresh token is available, if found
4. Try to use the refresh token to get a new access token, if it fails
5. Start the OAuth2 dance by using the `authConfig` settings to determine how to display an authorize screen to the user

Your `oauth2` instance will use an automatically created `URLSession` using an `ephemeralSessionConfiguration()` configuration for its requests, exposed on `oauth2.session`.
You can set `oauth2.sessionConfiguration` to your own configuration, for example if you'd like to change timeout values.
You can also set `oauth2.sessionDelegate` to your own session delegate if you like.

The wiki has [the complete call graph](https://github.com/p2/OAuth2/wiki/Call-Graph) of the _authorize()_ method.
If you do **not wish this kind of automation**, the manual steps to show and hide the authorize screens are:

**Embedded iOS**:

```swift
let url = try oauth2.authorizeURL(params: <# custom parameters or nil #>)
oauth2.authConfig.authorizeEmbeddedAutoDismiss = false
let web = try oauth2.authorizer.authorizeSafariEmbedded(from: <# view controller #>, at: url)
oauth2.afterAuthorizeOrFail = { authParameters, error in
    // inspect error or oauth2.accessToken / authParameters or do something else
    web.dismissViewControllerAnimated(true, completion: nil)
}
```

**Modal Sheet on macOS**:

```swift
let window = <# window to present from #>
let url = try oauth2.authorizeURL(params: <# custom parameters or nil #>)
let sheet = try oauth2.authorizer.authorizeEmbedded(from: window, at: url)
oauth2.afterAuthorizeOrFail = { authParameters, error in
    // inspect error or oauth2.accessToken / authParameters or do something else
    window.endSheet(sheet)
}
```

**New window on macOS**:

```swift
let url = try oauth2.authorizeURL(params: <# custom parameters or nil #>)
let windowController = try oauth2.authorizer.authorizeInNewWindow(at: url)
oauth2.afterAuthorizeOrFail = { authParameters, error in
    // inspect error or oauth2.accessToken / authParameters or do something else
    windowController.window?.close()
}
```

**iOS/macOS browser**:

```swift
let url = try oauth2.authorizeURL(params: <# custom parameters or nil #>)
try oauth2.authorizer.openAuthorizeURLInBrowser(url)
oauth2.afterAuthorizeOrFail = { authParameters, error in
    // inspect error or oauth2.accessToken / authParameters or do something else
}
```


**macOS**

See the [OAuth2 Sample App][sample]'s AppDelegate class on how to receive the callback URL in your Mac app.
If the authorization displays the code to the user, e.g. with Google's `urn:ietf:wg:oauth:2.0:oob` callback URL, you can retrieve the code from the user's pasteboard and continue authorization with:

```swift
let pboard = NSPasteboard.general()
if let pasted = pboard.string(forType: NSPasteboardTypeString) {
    oauth2.exchangeCodeForToken(pasted)
}
```


Flows
-----

Based on which OAuth2 flow that you need you will want to use the correct subclass.
For a very nice explanation of OAuth's basics: [The OAuth Bible](http://oauthbible.com/#oauth-2-three-legged).

#### Code Grant

For a full OAuth 2 code grant flow (`response_type=code`) you want to use the `OAuth2CodeGrant` class.
This flow is typically used by applications that can guard their secrets, like server-side apps, and not in distributed binaries.
In case an application cannot guard its secret, such as a distributed iOS app, you would use the _implicit grant_ or, in some cases, still a _code grant_ but omitting the client secret.
It has however become common practice to still use code grants from mobile devices, including a client secret.

This class fully supports those flows, it automatically creates a “Basic” Authorization header if the client has a non-nil client secret.
This means that you likely **must** specify `client_secret` in your settings; if there is none (like for [Reddit](https://github.com/reddit/reddit/wiki/OAuth2#token-retrieval-code-flow)) specify the empty string.
If the site requires client credentials in the request body, set `clientConfig.secretInBody` to true, as explained below.

#### Implicit Grant

An implicit grant (`response_type=token`) is suitable for apps that are not capable of guarding their secret, such as distributed binaries or client-side web apps.
Use the `OAuth2ImplicitGrant` class to receive a token and perform requests.

Would be nice to add another code example here, but it's pretty much the same as for the _code grant_.

#### Client Credentials

A 2-legged flow that lets an app authorize itself via its client id and secret.
Instantiate `OAuth2ClientCredentials`, as usual supplying `client_id` but also a `client_secret` – plus your other configurations – in the settings dict, and you should be good to go.

#### Username and Password

The _Resource Owner Password Credentials Grant_ is supported with the `OAuth2PasswordGrant` subclass.
Create an instance as shown above, set its `username` and `password` properties, then call `authorize()`.


Site-Specific Peculiarities
---------------------------

Some sites might not strictly adhere to the OAuth2 flow, from returning data differently like Facebook to omitting mandatory return parameters like Instagram & co.
The framework deals with those deviations by creating site-specific subclasses and/or configuration details.
If you need to pass additional **headers** or **parameters**, you can supply these in the settings dict like so:

```swift
let oauth2 = OAuth2CodeGrant(settings: [
    "client_id": "...",
    ...
    "headers": ["Accept": "application/vnd.github.v3+json"],
    "parameters": ["duration": "permanent"],
] as OAuth2JSON)
```

- [GitHub](https://github.com/p2/OAuth2/wiki/GitHub)
- [Facebook](https://github.com/p2/OAuth2/wiki/Facebook)
- [Reddit](https://github.com/p2/OAuth2/wiki/Reddit)
- [Google](https://github.com/p2/OAuth2/wiki/Google)
- [LinkedIn](https://github.com/p2/OAuth2/wiki/LinkedIn)
- [Instagram, Bitly, Pinterest, ...](https://github.com/p2/OAuth2/wiki/Instagram,-Bitly,-Pinterest-and-others)
- [Uber](https://github.com/p2/OAuth2/wiki/Uber)
- [BitBucket](https://github.com/p2/OAuth2/wiki/BitBucket)


Advanced Settings
-----------------

The main configuration you'll use with `oauth2.authConfig` is whether or not to use an embedded login:

    oauth2.authConfig.authorizeEmbedded = true

Similarly, if you want to take care of dismissing the login screen yourself:

    oauth2.authConfig.authorizeEmbeddedAutoDismiss = false

Some sites also want the client-id/secret combination in the request _body_, not in the _Authorization_ header:

    oauth2.clientConfig.secretInBody = true
    // or in your settings:
    "secret_in_body": true

Sometimes you also need to provide additional authorization parameters.
This can be done in 3 ways:

    oauth2.authParameters = ["duration": "permanent"]
    // or in your settings:
    "parameters": ["duration": "permanent"]
    // or when you authorize manually:
    oauth2.authorize(params: ["duration": "permanent"]) { ... }

Similar is how you specify custom HTTP headers:

    oauth2.clientConfig.authHeaders = ["Accept": "application/json, text/plain"]
    // or in your settings:
    "headers": ["Accept": "application/json, text/plain"]

Starting with version 2.0.1 on iOS 9, `SFSafariViewController` will be used for embedded authorization.
To revert to the old custom `OAuth2WebViewController`:

    oauth2.authConfig.ui.useSafariView = false

To customize the _go back_ button when using `OAuth2WebViewController` on iOS 8 and older:

    oauth2.authConfig.ui.backButton = <# UIBarButtonItem(...) #>


Usage with Alamofire
--------------------

You'll get the best experience when using Alamofire v4 or newer and OAuth2 v3 and newer:

- How to use Alamofire [version 4 and newer](https://github.com/p2/OAuth2/wiki/Alamofire-4)
- How to use [version 3 and older](https://github.com/p2/OAuth2/wiki/Alamofire-3)


Dynamic Client Registration
---------------------------

There is support for [dynamic client registration](https://tools.ietf.org/html/rfc7591).
If during setup `registration_url` is set but `client_id` is not, the `authorize()` call automatically attempts to register the client before continuing to the actual authorization.
Client credentials returned from registration are stored to the keychain.

The `OAuth2DynReg` class is responsible for handling client registration.
You can use its `register(client:callback:)` method manually if you need to.
Registration parameters are taken from the client's configuration.

```swift
let oauth2 = OAuth2...()
oauth2.registerClientIfNeeded() { error in
    if let error = error {
        // registration failed
    }
    else {
        // client was registered
    }
}
```

```swift
let oauth2 = OAuth2...()
let dynreg = OAuth2DynReg()
dynreg.register(client: oauth2) { params, error in
    if let error = error {
        // registration failed
    }
    else {
        // client was registered with `params`
    }
}
```


Keychain
--------

This framework can transparently use the iOS and macOS keychain.
It is controlled by the `useKeychain` property, which can be disabled during initialization with the "keychain" setting.
Since this is **enabled by default**, if you do _not_ turn it off during initialization, the keychain will be queried for tokens and client credentials related to the authorization URL.
If you turn it off _after_ initialization, the keychain will be queried for existing tokens, but new tokens will not be written to the keychain.

If you want to delete the tokens from keychain, i.e. **log the user out** completely, call `forgetTokens()`.
If you have dynamically registered your client and want to start anew, you can call `forgetClient()`.

Ideally, access tokens get delivered with an "expires_in" parameter that tells you how long the token is valid.
If it is missing the framework will still use those tokens if one is found in the keychain and not re-perform the OAuth dance.
You will need to intercept 401s and re-authorize if an access token has expired but the framework has still pulled it from the keychain.
This behavior can be turned off by supplying "token_assume_unexpired": false in settings or setting `clientConfig.accessTokenAssumeUnexpired` to false.


Installation
------------

You can use _git_, _Carthage_ and even _CocoaPods_ to install the framework.
The preferred way is to use _git_ directly or _Carthage_.

#### Carthage

Installation via Carthage is easy enough:

```ruby
github "p2/OAuth2" ~> 3.0
```

#### git

Using Terminal.app, clone the OAuth2 repository, best into a subdirectory of your app project:  

    $ cd path/to/your/app
    $ git clone --recursive https://github.com/p2/OAuth2.git

If you're using git you'll want to add it as a submodule.
Once cloning completes, open your app project in Xcode and add `OAuth2.xcodeproj` to your app:

![Adding to Xcode](assets/step-adding.png)

Now link the framework to your app:

![Linking](assets/step-linking.png)

These three steps are needed to:

1. Make your App also build the framework
2. Link the framework into your app
3. Embed the framework in your app when distributing

#### CocoaPods

CocoaPods was nice back in the days for Obj-C and static libraries, but is overkill in the modern days of Swift and iOS frameworks.
You can however still use OAuth2 with Cocoapods.

Add a `Podfile` that contains at least the following information to the root of your app project, then do `pod install`.
If you're unfamiliar with CocoaPods, read [using CocoaPods](http://guides.cocoapods.org/using/using-cocoapods.html).

```ruby
platform :ios, '8.0'          # or platform :osx, '10.9'
use_frameworks!
target `YourApp` do
  pod 'p2.OAuth2', '~> 3.0'
end
```

If you want the bleeding edge, use this command for CocoaPods instead – note the `submodules` flag: without it the library will not compile.

```ruby
pod 'p2.OAuth2', :git => 'https://github.com/p2/OAuth2', :submodules => true
```


License
-------

This code is released under the [_Apache 2.0 license_](LICENSE.txt), which means that you can use it in open as well as closed source projects.
Since there is no `NOTICE` file there is nothing that you have to include in your product.


[sample]: https://github.com/p2/OAuth2App

