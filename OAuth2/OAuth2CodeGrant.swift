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
 *  A class to handle authorization for confidential clients via the authorization code grant method.
 *
 *  This auth flow is designed for clients that are capable of protecting their client secret, which a distributed Mac/iOS App **is not**!
 */
public class OAuth2CodeGrant: OAuth2
{
	/** The URL string where we can exchange a code for a token; if nil `authURL` will be used. */
	public let tokenURL: NSURL?
	
	/** The receiver's long-time refresh token. */
	public var refreshToken = ""
	
	public override init(settings: JSONDictionary) {
		if let token = settings["token_uri"] as? String {
			tokenURL = NSURL(string: token)
		}
		else {
			tokenURL = nil
		}
		
		super.init(settings: settings)
	}
	
	
	override public func authorizeURLWithRedirect(redirect: String?, scope: String?, params: [String: String]?) -> NSURL {
		return authorizeURL(authURL!, redirect: redirect, scope: scope, responseType: "code", params: params)
	}
	
	public func tokenURLWithRedirect(redirect: String?, code: String, params: [String: String]?) -> NSURL {
		let base = tokenURL ?? authURL!
		var urlParams = params ?? [String: String]()
		urlParams["code"] = code
		urlParams["grant_type"] = "authorization_code"
		if nil != clientSecret {
			urlParams["client_secret"] = clientSecret!
		}
		
		return authorizeURL(base, redirect: redirect, scope: nil, responseType: nil, params: urlParams)
	}
	
	/**
		Create a request for token exchange
	 */
	public func tokenRequest(code: String) -> NSURLRequest {
		let url = tokenURLWithRedirect(redirect, code: code, params: nil)
		let comp = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
		assert(comp != nil, "It seems NSURLComponents cannot parse \(url)");
		let body = comp!.query
		comp!.query = nil
		
		let post = NSMutableURLRequest(URL: comp!.URL!)
		post.HTTPMethod = "POST"
		post.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		post.setValue("application/json", forHTTPHeaderField: "Accept")
		post.HTTPBody = body?.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
		
		return post
	}
	
	/**
		Extracts the code from the redirect URL and exchanges it for a token.
	 */
	override public func handleRedirectURL(redirect: NSURL) {
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
	func exchangeCodeForToken(code: String) {
		
		// do we have a code?
		if (code.isEmpty) {
			didFail(genOAuth2Error("I don't have a code to exchange, let the user authorize first", .PrerequisiteFailed))
			logIfVerbose("No code to exchange for a token, cannot continue")
			return;
		}
		
		let post = tokenRequest(code)
		logIfVerbose("Exchanging code \(code) with redirect \(redirect!) for token at \(post.URL?.description)")
		
		// perform the exchange
		let session = NSURLSession.sharedSession()
		let task = session.dataTaskWithRequest(post) { sessData, sessResponse, error in
			var finalError: NSError?
			
			if nil != error {
				finalError = error
			}
			else if let data = sessData, let http = sessResponse as? NSHTTPURLResponse {
				if let json = self.parseTokenExchangeResponse(data, error: &finalError) {
					if 200 == http.statusCode {
						self.logIfVerbose("Did receive access token: \(self.accessToken), refresh token: \(self.refreshToken)")
						self.didAuthorize(json)
						return
					}
					
					let desc = (json["error_description"] ?? json["error"]) as? String
					finalError = genOAuth2Error(desc ?? http.statusString, .AuthorizationError)
				}
			}
			
			// if we're still here an error must have happened
			if nil == finalError {
				finalError = genOAuth2Error("Unknown connection error for response \(sessResponse) with data \(sessData)", .NetworkError)
			}
			
			self.didFail(finalError)
		}
		task.resume()
	}
	
	/**
		Parse the NSData object returned while exchanging the code for a token in `exchangeCodeForToken`.
	
		:returns: A JSONDictionary, which is usually returned upon token exchange and may contain additional information
	 */
	func parseTokenExchangeResponse(data: NSData, error: NSErrorPointer) -> JSONDictionary? {
		if let json = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: error) as? JSONDictionary {
			if let access = json["access_token"] as? String {
				accessToken = access
			}
			accessTokenExpiry = nil
			if let expires = json["expires_in"] as? NSTimeInterval {
				accessTokenExpiry = NSDate(timeIntervalSinceNow: expires)
			}
			if let refresh = json["refresh_token"] as? String {
				refreshToken = refresh
			}
			
			return json
		}
		return nil
	}
	
	
	// MARK: - Utilities
	
	/**
		Validates the redirect URI: returns a tuple with the code and nil on success, nil and an error on failure.
	 */
	func validateRedirectURL(redirect: NSURL) -> (code: String?, error: NSError?) {
		var code: String?
		var error: NSError?
		
		let comp = NSURLComponents(URL: redirect, resolvingAgainstBaseURL: true)
		if let compQuery = comp?.query where count(compQuery) > 0 {
			let query = OAuth2CodeGrant.paramsFromQuery(comp!.query!)
			if let cd = query["code"] {
				
				// we got a code, use it if state is correct (and reset state)
				if let st = query["state"] where st == state {
					code = cd
					state = ""
				}
				else {
					error = genOAuth2Error("Invalid state, will not use the code", .InvalidState)
				}
			}
			else {
				error = OAuth2CodeGrant.errorForAccessTokenErrorResponse(query)
			}
		}
		else {
			error = genOAuth2Error("The redirect URL contains no query fragment", .PrerequisiteFailed)
		}
		
		if nil != error {
			logIfVerbose("Invalid redirect URL: \(error!.localizedDescription)")
		}
		else {
			logIfVerbose("Successfully validated redirect URL")
		}
		return (code, error)
	}
}

