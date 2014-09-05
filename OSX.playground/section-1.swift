// OAuth2 Playground for OS X
//
// It seems it's not currently possible to perform asynchronous web requests in
// Playgrounds, so this one here uses a fake callback URL which will fail
// validation because of incorrect state. You might still get the idea of how to
// use the library.

import Foundation
import XCPlayground
import OAuth2

XCPSetExecutionShouldContinueIndefinitely()


let settings = [
	"client_id": "my_mobile_app",
//	"client_secret": "ignored_in_this_example",
	"authorize_uri": "https://authorize.smartplatforms.org/authorize",
	"token_uri": "https://authorize.smartplatforms.org/token",
]

// instantiate an OAuth2 instance and set the `onAuthorize` and `onFailure` closures
let oauth = OAuth2CodeGrant(settings: settings)
oauth.verbose = true

oauth.onAuthorize = { parameters in
	println("Did authorize with parameters: \(parameters)")
	
	// you can now request data with signed requests, like so:
	let resource: NSURL? = NSURL(string: "https://fhir-api.smartplatforms.org/Patient/_search?_id=1288992")
	let request = oauth.request(forURL: resource!)
	let session = NSURLSession.sharedSession()
	let task = session.dataTaskWithRequest(request) { data, response, error in
		println("Got response \(response) or error \(error)")
	}
	task.resume()
}
oauth.onFailure = { error in
	println("Authorization failed: \(error.localizedDescription)")
}

// construct the authorize URL which you would then load in a browser or web view
let redir = "smartapp://callback"
let scope = "openid profile"
let authURL = oauth.authorizeURLWithRedirect(redir, scope: scope, params: nil)

// after the user logs in and goes through the flow, your redirect will be called, which
// you feed to `oauth.handleRedirectURL()`, which will end up calling your `onAuthorize`
// or 'onFailure` closures.
/*/
let redirect: NSURL? = NSURL(string: "smartapp://callback?code=jNskdO&state=MANUAL")
oauth.handleRedirectURL(redirect!)
//	*/
