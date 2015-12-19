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
public class OAuth2CodeGrant: OAuth2 {
	
	public override class var grantType: String {
		return "authorization_code"
	}
	
	override public class var responseType: String? {
		return "code"
	}
	
	
	// MARK: - Token Request
	
	/**
	Generate the URL to be used for the token request from known instance variables and supplied parameters.
	
	This will set "grant_type" to "authorization_code", add the "code" provided and forward to `authorizeURLWithBase()` to fill the
	remaining parameters. The "client_id" is only added if there is no secret (public client) or if the request body is used for id and
	secret.
	
	- parameter code: The code you want to exchange for an access token
	- parameter params: Optional additional params to add as URL parameters
	- returns: The URL you can use to exchange the code for an access token
	*/
	func tokenURLWithCode(code: String, params: OAuth2StringDict? = nil) throws -> NSURL {
		guard let redirect = context.redirectURL else {
			throw OAuth2Error.NoRedirectURL
		}
		var urlParams = params ?? OAuth2StringDict()
		urlParams["code"] = code
		urlParams["grant_type"] = self.dynamicType.grantType
		urlParams["redirect_uri"] = redirect
		if let secret = clientConfig.clientSecret {
			if authConfig.secretInBody {
				urlParams["client_secret"] = secret
				urlParams["client_id"] = clientConfig.clientId
			}
		}
		else {
			urlParams["client_id"] = clientConfig.clientId
		}
		return try authorizeURLWithParams(urlParams, asTokenURL: true)
	}
	
	/**
	Create a request for token exchange.
	*/
	func tokenRequestWithCode(code: String) throws -> NSMutableURLRequest {
		let url = try tokenURLWithCode(code)
		return try tokenRequestWithURL(url)
	}
	
	/**
	Extracts the code from the redirect URL and exchanges it for a token.
	*/
	override public func handleRedirectURL(redirect: NSURL) {
		logIfVerbose("Handling redirect URL \(redirect.description)")
		do {
			let code = try validateRedirectURL(redirect)
			exchangeCodeForToken(code)
		}
		catch let error {
			didFail(error)
		}
	}
	
	/**
	Takes the received code and exchanges it for a token.
	*/
	public func exchangeCodeForToken(code: String) {
		do {
			guard !code.isEmpty else {
				throw OAuth2Error.PrerequisiteFailed("I don't have a code to exchange, let the user authorize first")
			}
			
			let post = try tokenRequestWithCode(code)
			logIfVerbose("Exchanging code \(code) for access token at \(post.URL!)")
			
			performRequest(post) { data, status, error in
				do {
					guard let data = data else {
						throw error ?? OAuth2Error.NoDataInResponse
					}
					
					let params = try self.parseAccessTokenResponse(data)
					if status < 400 {
						self.logIfVerbose("Did exchange code for access [\(nil != self.clientConfig.accessToken)] and refresh [\(nil != self.clientConfig.refreshToken)] tokens")
						self.didAuthorize(params)
					}
					else {
						throw OAuth2Error.Generic("\(status)")
					}
				}
				catch let error {
					self.didFail(error)
				}
			}
		}
		catch let error {
			didFail(error)
		}
	}
	
	
	// MARK: - Utilities
	
	/**
	Validates the redirect URI: returns a tuple with the code and nil on success, nil and an error on failure.
	*/
	func validateRedirectURL(redirect: NSURL) throws -> String {
		let comp = NSURLComponents(URL: redirect, resolvingAgainstBaseURL: true)
		if let compQuery = comp?.query where compQuery.characters.count > 0 {
			let query = OAuth2CodeGrant.paramsFromQuery(comp!.percentEncodedQuery!)
			if let cd = query["code"] {
				
				// we got a code, use it if state is correct (and reset state)
				try assureMatchesState(query)
				return cd
			}
			throw OAuth2Error.ResponseError("No “code” received")
		}
		throw OAuth2Error.PrerequisiteFailed("The redirect URL contains no query fragment")
	}
}

