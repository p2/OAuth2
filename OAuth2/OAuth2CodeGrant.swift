//
//  OAuth2CodeGrant.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/16/14.
//  Copyright (c) 2014 Pascal Pfiffner. All rights reserved.
//

import Foundation


/*!
 *  A class to handle authorization for confidential clients via the authorization code grant method.
 *
 *  This auth flow is designed for clients that are capable of protecting their client secret, which a distributed Mac/iOS App **is not**!
 */
class OAuth2CodeGrant: OAuth2 {
	
	/*! The client secret */
	let clientSecret: String
	
	/*! The URL string where we can exchange a code for a token; if nil `authURL` will be used. */
	let tokenURL: NSURL?
	
	/*! The receiver's long-time refresh token. */
	var refreshToken = ""
	
	init(settings: NSDictionary) {
		if let secret = settings["client_secret"] as? String {
			clientSecret = secret
		}
		else {
			fatalError("Must supply `client_secret` upon initialization; it may be an empty string")
		}
		
		if let token = settings["token_uri"] as? String {
			tokenURL = NSURL(string: token)
		}
		
		super.init(settings: settings)
	}
	
	
	func authorizeURLWithRedirect(redirect: String?, scope: String?, params: Dictionary<String, String>?) -> NSURL {
		return authorizeURL(authURL!, redirect: redirect, scope: scope, responseType: "code", params: params)
	}
	
	func tokenURLWithRedirect(redirect: String?, params: Dictionary<String, String>?) -> NSURL {
		let base = tokenURL ? tokenURL! : authURL!
		return authorizeURL(base, redirect: redirect, scope: nil, responseType: nil, params: params)
	}
	
	func tokenRequest(code: String) -> NSURLRequest {
		
		// create a request for token exchange
		let url = tokenURLWithRedirect(redirect, params: [
			"grant_type": "authorization_code",
			"code": code,
		])
		let comp = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
		let body = comp.query
		comp.query = nil
		
		let post = NSMutableURLRequest(URL: comp.URL)
		post.HTTPMethod = "POST"
		post.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		post.HTTPBody = body.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
		
		return post
	}
	
	/*!
	 *  Call this when we receive a code.
	 */
	func exchangeCodeForToken(code: String, callback: (didCancel: Bool, error: NSError?) -> ()) {
		
		// do we have a code?
		if (code.isEmpty) {
			let error = NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "I don't have a code to exchange, let the user authorize first"])
			callback(didCancel: false, error: error)
			return;
		}
		
		let post = tokenRequest(code)
		
		// perform the exchange
		NSURLConnection.sendAsynchronousRequest(post, queue: NSOperationQueue.mainQueue(), completionHandler: { response, data, error in
			var finalError: NSError?
			
			if error {
				finalError = error
			}
			else if response {
				if data {				// Swift compiler bug, cannot test two implicitly unwrapped optionals with `&&`
				if let http = response as? NSHTTPURLResponse {
					if 200 == http.statusCode {
						if let json = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &finalError) as? NSDictionary {
							if let access = json["access_token"] as? String {
								self.accessToken = access
							}
							if let refresh = json["refresh_token"] as? String {
								self.refreshToken = refresh
							}
							
							callback(didCancel: false, error: nil)
							return
						}
					}
				}
				}
			}

			// if we're still here an error must have happened
			if !finalError {
				finalError = NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown connection error"])
			}
			
			callback(didCancel: false, error: finalError)
		})
	}
}
