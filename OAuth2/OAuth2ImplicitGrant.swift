//
//  OAuth2ImplicitGrant.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/9/14.
//  Copyright (c) 2014 Pascal Pfiffner. All rights reserved.
//

import Foundation


/*!
 *  Class to handle OAuth2 requests for public clients, such as distributed Mac/iOS Apps.
 */
class OAuth2ImplicitGrant: OAuth2 {
	
	func authorizeURLWithRedirect(redirect: String?, scope: String?, params: [String: String]?) -> NSURL {
		return authorizeURL(authURL!, redirect: redirect, scope: scope, responseType: "token", params: params)
	}
	
	override func handleRedirectURL(redirect: NSURL, callback: (error: NSError?) -> ()) {
		logIfVerbose("Handling redirect URL \(redirect.description)")
		
		var error: NSError?
		var comp = NSURLComponents(URL: redirect, resolvingAgainstBaseURL: true)
		
		// token should be in the URL fragment
		if comp.fragment.utf16count > 0 {
			let params = OAuth2ImplicitGrant.paramsFromQuery(comp.fragment)
			let token: String? = params["access_token"]
			if token?.utf16count > 0 {
				if let tokType = params["token_type"] {
					if "bearer" == tokType.lowercaseString {
						
						// got a "bearer" token, use it if state checks out
						if let tokState = params["state"] {
							if tokState == state {
								accessToken = token!
								logIfVerbose("Successfully extracted access token \(token!)")
								didAuthorize(params)
							}
							else {
								error = genOAuth2Error("Invalid state \(tokState), will not use the token", .InvalidState)
							}
						}
						else {
							error = genOAuth2Error("No state returned, will not use the token", .InvalidState)
						}
					}
					else {
						error = genOAuth2Error("Only \"bearer\" token is supported, but received \"\(tokType)\"", .Unsupported)
					}
				}
				else {
					error = genOAuth2Error("No token type received, will not use the token", .PrerequisiteFailed)
				}
			}
			else {
				error = OAuth2ImplicitGrant.errorForAccessTokenErrorResponse(params)
			}
		}
		else {
			error = genOAuth2Error("Invalid redirect URL: \(redirect)", .PrerequisiteFailed)
		}
		
		// log, if needed, then call the callback
		if error {
			logIfVerbose("Error handling redirect URL: \(error!.localizedDescription)")
		}
		callback(error: error)
	}
}

