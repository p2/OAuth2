//
//  OAuth2CodeGrant.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/16/14.
//  Copyright 2014 Pascal Pfiffner
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation


/**
    A class to handle authorization for confidential clients via the authorization code grant method.

    This auth flow is designed for clients that are capable of protecting their client secret but can be used from installed apps. During
    code exchange and token refresh flows, **if** the client has a secret, a "Basic key:secret" Authorization header will be used. If not
    the client key will be embedded into the request body.
 */
public class OAuth2CodeGrant: OAuth2
{
	public override func authorizeURLWithRedirect(redirect: String?, scope: String?, params: OAuth2StringDict?) throws -> NSURL {
		var prms = params ?? OAuth2StringDict()
		prms["response_type"] = "code"
		return try super.authorizeURLWithRedirect(redirect, scope: scope, params: prms)
	}
	
	override func assureMatchesState(params: OAuth2JSON) throws {
		if nil == params["code"] {		// no state in the second step (exchange code)
			return
		}
		try super.assureMatchesState(params)
	}
	
	
	// MARK: - Token Request
	
	/**
	    Generate the URL to be used for the token request from known instance variables and supplied parameters.
	
	    This will set "grant_type" to "authorization_code", add the "code" provided and forward to `authorizeURLWithRedirect()` to fill the
	    remaining parameters.
	 */
	func tokenURLWithRedirect(redirect: String?, code: String, params: OAuth2StringDict? = nil) throws -> NSURL {
		var urlParams = params ?? OAuth2StringDict()
		urlParams["code"] = code
		urlParams["grant_type"] = "authorization_code"
		if let secret = clientConfig.clientSecret where authConfig.secretInBody {
			urlParams["client_secret"] = secret
		}
		
		return try authorizeURLWithRedirect(redirect, params: urlParams, asTokenURL: true)
	}
	
	/**
	    Create a request for token exchange.
	 */
	func tokenRequestWithCode(code: String) throws -> NSMutableURLRequest {
		let url = try tokenURLWithRedirect(clientConfig.redirect, code: code)
		return try tokenRequestWithURL(url)
	}
	
	/**
	    Extracts the code from the redirect URL and exchanges it for a token.
	 */
	public override func handleRedirectURL(redirect: NSURL) {
		logIfVerbose("Handling redirect URL \(redirect.description)")
		
		let (code, error) = validateRedirectURL(redirect)
		if nil != error {
			didFail(error)
		}
		else {
			exchangeCodeForToken(code!)
		}
	}
	
	/**
	    Takes the received code and exchanges it for a token.
	 */
	public func exchangeCodeForToken(code: String) {
		if (code.isEmpty) {
			didFail(OAuth2Error.PrerequisiteFailed("I don't have a code to exchange, let the user authorize first"))
			return;
		}
		
		do {
			let post = try tokenRequestWithCode(code)
			logIfVerbose("Exchanging code \(code) with redirect \(clientConfig.redirect!) for access token at \(post.URL!)")
			
			performRequest(post) { data, status, error in
				if let data = data {
					do {
						let params = try self.parseAccessTokenResponse(data)
						if status < 400 {
							self.logIfVerbose("Did exchange code for access [\(nil != self.clientConfig.accessToken)] and refresh [\(nil != self.clientConfig.refreshToken)] tokens")
							self.didAuthorize(params)
						}
						else {
							throw OAuth2Error.Generic("\(status)")
						}
					}
					catch let err {
						self.didFail(err)
					}
				}
				else {
					self.didFail(error ?? OAuth2Error.NoDataInResponse)
				}
			}
		}
		catch let err {
			didFail(err)
		}
	}
	
	
	// MARK: - Utilities
	
	/**
	    Validates the redirect URI: returns a tuple with the code and nil on success, nil and an error on failure.
	 */
	func validateRedirectURL(redirect: NSURL) -> (code: String?, error: OAuth2Error?) {
		var code: String?
		var error: OAuth2Error?
		
		let comp = NSURLComponents(URL: redirect, resolvingAgainstBaseURL: true)
		if let compQuery = comp?.query where compQuery.characters.count > 0 {
			let query = OAuth2CodeGrant.paramsFromQuery(comp!.percentEncodedQuery!)
			if let cd = query["code"] {
				
				// we got a code, use it if state is correct (and reset state)
				if context.matchesState(query["state"]) {
					code = cd
					context.resetState()
				}
				else {
					error = OAuth2Error.InvalidState
				}
			}
			else {
				error = OAuth2Error.ResponseError("No “code” received")
			}
		}
		else {
			error = OAuth2Error.PrerequisiteFailed("The redirect URL contains no query fragment")
		}
		
		return (code, error)
	}
}

