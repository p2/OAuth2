OAuth2
======

OAuth2 frameworks for **OS X** and **iOS** written in Swift.
This is currently more of an academic exercise and very much WiP.
Here is a very nice explanation of OAuth's basics: [The OAuth Bible](http://oauthbible.com/#oauth-2-three-legged).

The code in this repo requires Xcode 6 to compile and will run on OS X 10.9+ or iOS 7+.


Flows
-----

#### Code Grant

For a full OAuth 2 code grant flow you want to use the `OAuth2CodeGrant` class.
This flow is typically used by applications that can guard their secrets, like server-side apps, and not in distributed binaries.
In case an application cannot guard its secret, such as a distributed iOS app, you would use the _implicit grant_ or, in some cases, still a _code grant_ but omitting the client secret.

For a typical code grant flow you want to perform the following steps:

1. Create a settings dictionary.
    
    ```swift
    settings = [
        "client_id" = "my_swift_app",
        "client_secret" = "C7447242-A0CF-47C5-BAC7-B38BA91970A9",
        "authorize_uri" = "https://authorize.smartplatforms.org/authorize",
        "token_uri" = "https://authorize.smartplatforms.org/token",
    ]
    ```

2. Create an `OAuth2CodeGrant` instance, optionally setting the `onAuthorize` closure to call on successful authorization.
    
    ```swift
    let oauth = OAuth2CodeGrant(settings: settings)
    oauth.onAuthorize = { parameters in
        println("Did authorize with parameters: \(parameters)")
    }
    ```

3. Open the _authorize URL_ in the browser (or an embedded web view).
    
    ```swift
    let redir = "myapp://callback"        // don't forget to register this scheme
    let scope = "profile email"
    let url = oauth.authorizeURLWithRedirect(redir, scope: scope, params: nil)
    UIApplication.sharedApplication().openURL(url)
    ```

4. When the callback is called (intercept in your app delegate or in your web view), let the OAuth2 instance handle the full URL.
    
    ```swift
    oauth.handleRedirectURL(<redirectURL>) { error in
        if error {
            // something went wrong
        }
        else {
            // we now have `accessToken`!!
        }
    }
    ```

5. You can now obtain a `OAuth2Request`, which is an already signed `NSMutableURLRequest`, to retrieve data from your server.
    
    ```swift
    let req = oauth.request(forURL: <a resource URL>)
    let session = NSURLSession()
    let task = session.dataTaskWithRequest(req) { data, response, error in
        if error {
            // something went wrong
        }
        else {
            // check the response and the data
            // you have just received data with an OAuth2-signed request!
        }
    }
    task.resume()
    ``` 

#### Implicit Grant

An implicit grant is suitable for apps that are not capable of guarding their secret, such as distributed binaries or client-side web apps.
Use the `OAuth2ImplicitGrant` class to receive a token and perform requests.

Would be nice to add another code example here, but it's pretty much the same as for the _code grant_.


Playground
----------

The idea is to add a Playground to see OAuth2 in use (instead of a sample app).
However, it's not currently possible to import custom code into playgrounds, so currently there is no Playground.
