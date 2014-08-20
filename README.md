OAuth2
======

OAuth2 frameworks for **OS X** and **iOS** written in Swift.
Still very much WiP and not feature complete.

The code in this repo requires Xcode 6, currently deployment targets have to be OS X 10.9+ or iOS 8+.
The iOS 8 requirement stems from us using frameworks which are not compatible with iOS 7.
When building static libraries from Swift code becomes possible it should be possible to lower the deployment target to iOS 7.

Usage
-----

For a typical code grant flow you want to perform the following steps.
The steps for other flows are mostly the same short of instantiating a different subclass and using different client settings.

1. Create a settings dictionary.
    
    ```swift
    settings = [
        "client_id" = "my_swift_app",
        "client_secret" = "C7447242-A0CF-47C5-BAC7-B38BA91970A9",
        "authorize_uri" = "https://authorize.smartplatforms.org/authorize",
        "token_uri" = "https://authorize.smartplatforms.org/token",
    ]
    ```

2. Create an `OAuth2CodeGrant` instance, setting the `onAuthorize` and `onFailure` closures to keep informed about the status.
    
    ```swift
    let oauth = OAuth2CodeGrant(settings: settings)
    oauth.onAuthorize = { parameters in
        println("Did authorize with parameters: \(parameters)")
    }
    oauth.onFailure = { error in
        println("Authorization went wrong: \(error.localizedDescription)")
    }
    ```

3. Now either use the built-in web view controller or manually open the _authorize URL_ in the browser:
    
    ```swift
    let redir = "myapp://callback"        // don't forget to register this scheme
    let scope = "profile email"
    ```
    
    **Embedded**:
    
    ```swift
    let web = oauth.authorizeEmbedded(redir, scope: scope, params: nil, from: <# view controller #>)
    oauth.afterAuthorizeOrFailure = { wasFailure in
        web.dismissViewControllerAnimated(true, completion: nil)
    }
    ```
    
    **OS browser**:
    
    ```swift
    let url = oauth.authorizeURLWithRedirect(redir, scope: scope, params: nil)
    UIApplication.sharedApplication().openURL(url)
    ```
    
    1. Since you opened the authorize URL in the browser you will need to intercept the callback.
        When doing so (intercept in your app delegate), let the OAuth2 instance handle the full URL.
        
        ```swift
        func application(application: UIApplication!,
                         openURL url: NSURL!,
                   sourceApplication: String!,
                          annotation: AnyObject!) -> Bool {
            // you should probably first check if this is your URL being opened
            if <# check #> { 
                oauth.handleRedirectURL(url)
            }
        }
        ```

4. After everything completes either the `onAuthorize` or the `onFailure` closure will be called.

5. You can now obtain an `OAuth2Request`, which is an already signed `NSMutableURLRequest`, to retrieve data from your server.
    
    ```swift
    let req = oauth.request(forURL: <# resource URL #>)
    let session = NSURLSession()
    let task = session.dataTaskWithRequest(req) { data, response, error in
        if nil != error {
            // something went wrong
        }
        else {
            // check the response and the data
            // you have just received data with an OAuth2-signed request!
        }
    }
    task.resume()
    ``` 

Flows
-----

Based on which OAuth2 flow that you need to use you will want to use the correct subclass.
For a very nice explanation of OAuth's basics: [The OAuth Bible](http://oauthbible.com/#oauth-2-three-legged).

#### Code Grant

For a full OAuth 2 code grant flow you want to use the `OAuth2CodeGrant` class.
This flow is typically used by applications that can guard their secrets, like server-side apps, and not in distributed binaries.
In case an application cannot guard its secret, such as a distributed iOS app, you would use the _implicit grant_ or, in some cases, still a _code grant_ but omitting the client secret.

#### Implicit Grant

An implicit grant is suitable for apps that are not capable of guarding their secret, such as distributed binaries or client-side web apps.
Use the `OAuth2ImplicitGrant` class to receive a token and perform requests.

Would be nice to add another code example here, but it's pretty much the same as for the _code grant_.


Playground
----------

The idea is to add a Playground to see OAuth2 in use (instead of a sample app).
However, it's not currently possible to import custom code into playgrounds, so currently there is no Playground.
