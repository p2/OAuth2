OAuth2
======

OAuth2 frameworks for **OS X** and **iOS** written in Swift 2.0.

Technical documentation is available at [p2.github.io/OAuth2](https://p2.github.io/OAuth2).
Take a look at the [OS X sample app][sample] for basic usage of this framework.

The code in this repo requires Xcode 7, the built framework can be used on **OS X 10.9** or **iOS 8** and later.
To use on **iOS 7** you'll have to include the source files in your main project.

#### Swift Version

Since the Swift language is constantly evolving I have adopted a versioning scheme mirroring Swift versions:
the framework version's **first two digits are always the Swift version** the library is compatible with, see [releases](https://github.com/p2/OAuth2/releases).
Code compatible with brand new Swift versions are to be found on a separate feature branch named after their swift version.


Usage
-----

To use OAuth2 in your own code, start with `import OAuth2` (use `p2_OAuth2` if you installed _p2.OAuth2_ via CocoaPods) in your source files.

For a typical code grant flow you want to perform the following steps.
The steps for other flows are mostly the same short of instantiating a different subclass and using different client settings.
If you need to provide additional parameters to the authorize URL take a look at `authorizeURLWithRedirect(redirect:scope:params:)`.

### 1. Create a Settings Dictionary.

```swift
let settings = [
    "client_id": "my_swift_app",
    "client_secret": "C7447242-A0CF-47C5-BAC7-B38BA91970A9",
    "authorize_uri": "https://authorize.smarthealthit.org/authorize",
    "token_uri": "https://authorize.smarthealthit.org/token",   // code grant only!
    "scope": "profile email",
    "redirect_uris": ["myapp://oauth/callback"],   // don't forget to register this scheme
    "keychain": false,     // if you DON'T want keychain integration
    "title": "My Service"  // optional title to show in views
] as OAuth2JSON            // the "as" part may or may not be needed
```

### 2. Instantiate OAuth2

Create an `OAuth2CodeGrant` Instance.
Optionally, set the `onAuthorize` and `onFailure` closures **or** the `afterAuthorizeOrFailure` closure to keep informed about the status.

```swift
let oauth2 = OAuth2CodeGrant(settings: settings)
oauth2.onAuthorize = { parameters in
    print("Did authorize with parameters: \(parameters)")
}
oauth2.onFailure = { error in        // `error` is nil on cancel
    if nil != error {
        print("Authorization went wrong: \(error!.localizedDescription)")
    }
}
```

### 3. Authorize the User

By default the OS browser will be used for authorization if there is no access token present in the keychain.
To start authorization call **`authorize()`** or the convenience method `authorizeEmbeddedFrom(<# UIViewController or NSWindow #>)`.

The latter configures `authConfig` like so: changes `authorizeEmbedded` to `true` and sets a root view controller/window, from which to present the login screen, as `authorizeContext`.
See [_Advanced Settings_](#advanced-settings) for other options.

**Starting with iOS 9**, `SFSafariViewController` will be used when enabling embedded authorization.

```swift
oauth2.authConfig.authorizeEmbedded = true
oauth2.authConfig.authorizeContext = <# presenting view controller / window #>
oauth2.authorize()

// for embedded authorization you can just use:
oauth2.authorizeEmbeddedFrom(<# presenting view controller / window #>)
```

When using the OS browser or the iOS 9 Safari view controller, you will need to **intercept the callback** in your app delegate.
Let the OAuth2 instance handle the full URL:

```swift
func application(application: UIApplication,
                 openURL url: NSURL,
           sourceApplication: String?,
                  annotation: AnyObject) -> Bool {
    // you should probably first check if this is your URL being opened
    if <# check #> {
        oauth2.handleRedirectURL(url)
    }
}
```

See [_Manually Performing Authentication_](#manually-performing-authentication) below for details on how to do this on the Mac.

### 4. Receive Callback

After everything completes either the `onAuthorize` or the `onFailure` closure will be called, and after that the `afterAuthorizeOrFailure` closure if it has been set.
Hence, unless you have a reason to, you don't need to set all three callbacks, you can use any of those.

### 5. Make Requests

You can now obtain an `OAuth2Request`, which is an already signed `NSMutableURLRequest`, to retrieve data from your server.
If you use _Alamofire_ there's a [class extension](#usage-with-alamofire) below that you can use.

```swift
let req = oauth2.request(forURL: <# resource URL #>)
let session = NSURLSession.sharedSession()
let task = session.dataTaskWithRequest(req) { data, response, error in
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

### 6. Cancel Authorization

You can cancel an ongoing authorization any time by calling `oauth2.abortAuthorization()`.
This will cancel ongoing requests (like a code exchange request) or call the callback while you're waiting for a user to login on a webpage.
The latter will dismiss embedded login screens or redirect the user back to the app.

### 7. Re-Authorize

It is safe to always call `oauth2.authorize()` before performing a request.
You can also perform the authorization before the first request after your app became active again.
Or you can always intercept 401s in your requests and call authorize again before re-attempting the request.

### 8. Logout

If you're storing tokens to the keychain, you can call `forgetTokens()` to throw them away.

**However** your user is likely still logged in to the website, so on the next `authorize()` call, the web view may appear and immediately disappear.
When using the built-in web view on iOS 8, one can use the following snippet to throw away any cookies the app created.
With the newer `SFSafariViewController`, or logins performed in the browser, it's probably best to directly **open the logout page** so the user sees the logout happen.

```swift
let storage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
storage.cookies?.forEach() { storage.deleteCookie($0) }
```


Manually Performing Authentication
----------------------------------

The `authorize()` method will:

1. Check if an access token that has not yet expired is in the keychain, if not
2. Check if a refresh token is in the keychain, if found
3. Try to use the refresh token to get a new access token, if it fails
4. Start the OAuth2 dance by using the `authConfig` settings to determine how to display an authorize screen to the user

If you do **not wish this kind of automation**, the manual steps to show the authorize screens are:

**Embedded iOS**:

```swift
let vc = <# presenting view controller #>
let web = oauth2.authorizeEmbeddedFrom(vc)
oauth2.afterAuthorizeOrFailure = { wasFailure, error in
    web.dismissViewControllerAnimated(true, completion: nil)
}
```

**Modal Sheet on OS X**:

```swift
let win = <# window to present from #>
// if `win` is nil, will open a new window
oauth2.authorizeEmbeddedFrom(win)
```

**Present yourself on OS X**:

```swift
let vc = <# view controller #>
let web = oauth2.presentableAuthorizeViewController()
oauth2.afterAuthorizeOrFailure = { wasFailure, error in
    vc.dismissViewController(web)
}
vc.presentViewController(web, animator: <# animator #>)
```

**iOS/OS X browser**:

```swift
try! oauth2.openAuthorizeURLInBrowser()
```

In case you're using the OS browser or the new Safari view controller, you will need to **intercept the callback** in your app delegate.

**iOS**

```swift
func application(application: UIApplication!,
                 openURL url: NSURL!,
           sourceApplication: String!,
                  annotation: AnyObject!) -> Bool {
    // you should probably first check if this is your URL being opened
    if <# check #> {
        oauth2.handleRedirectURL(url)
    }
}
```

**OS X**

See the [OAuth2 Sample App][sample]'s AppDelegate class on how to receive the callback URL in your Mac app.
If the authentication displays the code to the user, e.g. with Google's `urn:ietf:wg:oauth:2.0:oob` callback URL, you can retrieve the code from the user's pasteboard and continue authorization with:

```swift
let pboard = NSPasteboard.generalPasteboard()
if let pasted = pboard.stringForType(NSPasteboardTypeString) {
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
This class fully supports those flows, it automatically creates a “Basic” Authorization header if the client has a client secret.
If the site requires client credentials in the request body, set `secretInBody` to true, as explained below.

#### Implicit Grant

An implicit grant (`response_type=token`) is suitable for apps that are not capable of guarding their secret, such as distributed binaries or client-side web apps.
Use the `OAuth2ImplicitGrant` class to receive a token and perform requests.

Would be nice to add another code example here, but it's pretty much the same as for the _code grant_.

#### Client Credentials

A 2-legged flow that lets an app authenticate itself via its client id and secret.
Instantiate `OAuth2ClientCredentials`, as usual supplying `client_id` but also a `client_secret` – plus your other configurations – in the settings dict, and you should be good to go.

#### Username and Password

The _Resource Owner Password Credentials Grant_ is supported with the `OAuth2PasswordGrant` subclass.
Create an instance as shown above, set its `username` and `password` properties, then call `authorize()`.


### Site-Specific Peculiarities

Some sites might not strictly adhere to the OAuth2 flow.
The framework deals with those deviations by creating site-specific subclasses.

#### Facebook

Use `OAuth2CodeGrantFacebook` to deal with the [URL-query-style response](https://developers.facebook.com/docs/facebook-login/manually-build-a-login-flow/v2.2) instead of the expected JSON dictionary.

#### GitHub

`OAuth2CodeGrant` automatically puts the client-key/client-secret into an “Authorization: Basic” header.
GitHub however needs those two in the POSTed body; you need to set the `authConfig.secretInBody` setting to true, either directly in code or via the `secret_in_body` key in the settings dictionary.

#### Reddit

`OAuth2CodeGrant` automatically adds a _Basic_ authorization header when a client secret is set.
This means that you **must** specify a client_secret; if there is none (like for [Reddit](https://github.com/reddit/reddit/wiki/OAuth2#token-retrieval-code-flow)) specify the empty string.
There is a [RedditLoader](https://github.com/p2/OAuth2App/blob/master/OAuth2App/RedditLoader.swift) example in the [OAuth2App sample app][sample] for a basic usage example.

#### Google

If you authorize against Google with a `OAuth2CodeGrant`, the built-in iOS web view will intercept the `http://localhost` as well as the `urn:ietf:wg:oauth:2.0:oob` (with or without `:auto`) callbacks.
This means you must disable the Safari view controller and – for now – this only works on iOS.

```swift
oauth2.authConfig.authorizeEmbedded = true
oauth2.authConfig.ui.useSafariView = false
```

#### LinkedIn

There are a couple of peculiarities with LinkedIn's OAuth2 implementation.
You can use `OAuth2CodeGrantLinkedIn` which deals with those, but since it needs the custom embedded web view this will only work on iOS for now.
To receive _JSON_ you will also need to use their special header `x-li-format` and set it to `json`:

```swift
urlRequest.setValue("json", forHTTPHeaderField: "x-li-format")
```

#### Instagram, Bitly, ...

Some sites don't return the required `token_type` parameter in their token response.
LinkedIn does the same, see above.
You can tell if you're getting the error _“No token type received, will not use the token”_.
There is a subclass for code grant flows that ignores the missing token type that you can use: [`OAuth2CodeGrantNoTokenType`](Sources/Base/OAuth2CodeGrantNoTokenType.swift).

For _Instagram_ you also need to set `oauth2.authConfig.secretInBody = true` (or use `secret_in_body` in your settings dict) because it expects the client secret in the request body, not the _Authorization_ header.


Usage with Alamofire
--------------------

Here's an extension that can be used with Alamofire:

```swift
import Alamofire

extension OAuth2 {
    public func request(
        method: Alamofire.Method,
        _ URLString: URLStringConvertible,
        parameters: [String: AnyObject]? = nil,
        encoding: Alamofire.ParameterEncoding = .URL,
        headers: [String: String]? = nil)
        -> Alamofire.Request
    {
        
        var hdrs = headers ?? [:]
        if let token = accessToken {
            hdrs["Authorization"] = "Bearer \(token)"
        }
        return Alamofire.request(
            method,
            URLString,
            parameters: parameters,
            encoding: encoding,
            headers: hdrs)
    }
}
```

You can now use the handle to your `OAuth2` instance instead of using _Alamofire_ directly to make requests that are signed.
Of course this will only work once you have an access token.
You can use `hasUnexpiredAccessToken()` to check for one or just always call `authorize()` first; it will call your callback immediately if you have a token.

```swift
oauth2.request(.GET, "http://httpbin.org/get")
```


Dynamic Client Registration
---------------------------

There is support for [dynamic client registration](https://tools.ietf.org/html/rfc7591).
If during setup `registration_url` is set but `client_id` is not, the `authorize()` call automatically attempts to register the client before continuing to the actual authorization.
Client credentials returned from registration are stored to the keychain.

The `OAuth2DynReg` class is responsible for handling client registration.
You can use its `registerClient(client:callback:)` method manually if you need to.
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
dynreg.registerClient(oauth2) { params, error in
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

This framework can transparently use the iOS and OS X keychain.
It is controlled by the `useKeychain` property, which can be disabled during initialization with the "keychain" setting.
Since this is **enabled by default**, if you do _not_ turn it off during initialization, the keychain will be queried for tokens and client credentials related to the authorization URL.
If you turn it off _after_ initialization, the keychain will be queried for existing tokens, but new tokens will not be written to the keychain.

If you want to delete the tokens from keychain, i.e. **log the user out** completely, call `forgetTokens()`.
If you have dynamically registered your client and want to start anew, you can call `forgetClient()`.

Ideally, access tokens get delivered with an "expires_in" parameter that tells you how long the token is valid.
If it is missing the framework will still use those tokens if one is found in the keychain and not re-perform the OAuth dance.
You will need to intercept 401s and re-authenticate if an access token has expired but the framework has still pulled it from the keychain.
This behavior can be turned off by supplying "token_assume_unexpired": false in settings or setting `clientConfig.accessTokenAssumeUnexpired` to false.


Advanced Settings
-----------------

The main configuration you'll use with `oauth2.authConfig` is whether or not to use an embedded login:

    oauth2.authConfig.authorizeEmbedded = true


Starting with version 2.0.1 on iOS 9, `SFSafariViewController` will be used for embedded authorization.
To revert to the old custom `OAuth2WebViewController`:

    oauth2.authConfig.ui.useSafariView = false


To customize the _go back_ button when using `OAuth2WebViewController`:

    oauth2.authConfig.ui.backButton = <# UIBarButtonItem(...) #>


Some sites also want the client-id/secret combination in the request _body_, not in the _Authorization_ header:

    oauth2.authConfig.secretInBody = true


Installation
------------

You can use git or CocoaPods to install the framework.

#### CocoaPods

Add a `Podfile` that contains at least the following information to the root of your app project, then do `pod install`.
If you're unfamiliar with CocoaPods, read [using CocoaPods](http://guides.cocoapods.org/using/using-cocoapods.html).

```ruby
platform :ios, '8.0'      # or platform :osx, '10.9'
pod 'p2.OAuth2'
use_frameworks!
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

> NOTE that as of Xcode 6.2, the "embed" step happens in the "General" tab.
> You may want to perform step 2 and 3 from the "General" tab.
> Also make sure you select the framework for the platform, as of Xcode 7 this is visible behind _OAuth2.framework_.


License
-------

This code is released under the [_Apache 2.0 license_](LICENSE.txt), which means that you can use it in open as well as closed source projects.
Since there is no `NOTICE` file there is nothing that you have to include in your product.


[sample]: https://github.com/p2/OAuth2App

