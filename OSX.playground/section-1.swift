// OAuth2 Playground for OS X
//
// It seems it's not currently possible to perform asynchronous web requests in
// Playgrounds, so this one here uses a fake callback URL which will fail
// validation because of incorrect state. You might still get the idea of how to
// use the library.

import Foundation
import OAuth2


let settings = [
	"client_id": "my_mobile_app",
	"client_secret": "ignored_in_this_example",
	"authorize_uri": "https://authorize.smartplatforms.org/authorize",
	"token_uri": "https://authorize.smartplatforms.org/token",
]

let oauth = OAuth2CodeGrant(settings: settings)
oauth.onAuthorize = { parameters in
	println("Did authorize with parameters: \(parameters)")
}
oauth.onFailure = { error in
	println("Authorization went wrong: \(error.localizedDescription)")
}

// construct the authorize URL
let redir = "smartapp://callback"
let scope = "openid profile"
let authURL = oauth.authorizeURLWithRedirect(redir, scope: scope, params: nil)

// you will now need to open `authURL` in a browser or web view, login and you
// WOULD then need to call `handleRedirectURL()` (intercepting the callback from
// browser, it's done automatically in the embedded web view for iOS), which would
// look something like this:
let callbackURL: NSURL? = NSURL(string: "smartapp://callback?code=UvLwwy&state=18B87F5A-11A4-411F-891C-16F7010AE5C4")
oauth.handleRedirectURL(callbackURL!)

/*/ now you can go on and request data from the server
let resourceURL: NSURL? = NSURL(string: "https://api.smartplatforms.org/something")
let req = oauth.request(forURL: resourceURL!)
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
*/

