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
	public var refreshToken: String?
	
	
	/**
		Adds support for the "token_uri" setting.
	 */
	public override init(settings: OAuth2JSON) {
		if let token = settings["token_uri"] as? String {
			tokenURL = NSURL(string: token)
		}
		else {
			tokenURL = nil
		}
		
		super.init(settings: settings)
	}
	
	public override func authorizeURLWithRedirect(redirect: String?, scope: String?, params: [String: String]?) -> NSURL {
		return authorizeURLWithBase(authURL, redirect: redirect, scope: scope, responseType: "code", params: params)
	}
	
	/**
		Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
	 */
	func tokenRequestWithURL(url: NSURL) -> NSMutableURLRequest {
		let comp = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
		assert(comp != nil, "It seems NSURLComponents cannot parse \(url)");
		let body = comp!.percentEncodedQuery
		comp!.query = nil
		
		let req = NSMutableURLRequest(URL: comp!.URL!)
		req.HTTPMethod = "POST"
		req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		req.setValue("application/json", forHTTPHeaderField: "Accept")
		req.HTTPBody = body?.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
		
		return req
	}
	
	
	// MARK: - Token Request
	
	/**
		Generate the URL to be used for the token request from known instance variables and supplied parameters.
	
		This will set "grant_type" to "authorization_code", add the "code" provided and forward to `authorizeURL()` to
		fill the remaining parameters.
	 */
	func tokenURLWithRedirect(redirect: String?, code: String, params: [String: String]? = nil) -> NSURL {
		var urlParams = params ?? [String: String]()
		urlParams["code"] = code
		urlParams["grant_type"] = "authorization_code"
		if nil != clientSecret {
			urlParams["client_secret"] = clientSecret!
		}
		
		return authorizeURLWithBase(tokenURL ?? authURL, redirect: redirect, scope: nil, responseType: nil, params: urlParams)
	}
	
	/**
		Create a request for token exchange.
		
		This method is public to enable unit testing.
	 */
	public func tokenRequestWithCode(code: String) -> NSMutableURLRequest {
		let url = tokenURLWithRedirect(redirect, code: code)
		return tokenRequestWithURL(url)
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
	func exchangeCodeForToken(code: String) {
		
		// do we have a code?
		if (code.isEmpty) {
			didFail(genOAuth2Error("I don't have a code to exchange, let the user authorize first", .PrerequisiteFailed))
			logIfVerbose("No code to exchange for a token, cannot continue")
			return;
		}
		
		let post = tokenRequestWithCode(code)
		logIfVerbose("Exchanging code \(code) with redirect \(redirect!) for access token from \(post.URL?.description)")
		
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
	
		:returns: A OAuth2JSON, which is usually returned upon token exchange and may contain additional information
	 */
	func parseTokenExchangeResponse(data: NSData, error: NSErrorPointer) -> OAuth2JSON? {
		if let json = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: error) as? OAuth2JSON {
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
	
	
	// MARK: - Refresh Token
	
	/**
		Generate the URL to be used for the token request when we have a refresh token.
	
		This will set "grant_type" to "refresh_token", add the "code" provided and forward to `authorizeURL()` to
		fill the remaining parameters.
	 */
	func tokenURLWithRefreshToken(redirect: String?, refreshToken: String, params: [String: String]? = nil) -> NSURL {
		var urlParams = params ?? [String: String]()
		urlParams["grant_type"] = "refresh_token"
		urlParams["refresh_token"] = refreshToken
		if nil != clientSecret {
			urlParams["client_secret"] = clientSecret!
		}
		
		return authorizeURLWithBase(tokenURL ?? authURL, redirect: redirect, scope: nil, responseType: nil, params: urlParams)
	}
	
	/**
		Create a request for token refresh.
	
		This method is public to enable unit testing.
	 */
	public func tokenRequestWithRefreshToken(refreshToken: String) -> NSMutableURLRequest {
		let url = tokenURLWithRefreshToken(redirect, refreshToken: refreshToken)
		return tokenRequestWithURL(url)
	}
	
	/**
		Use the refresh token to receive a fresh access token.
	 */
	public func refreshTokenWithRefreshToken(refreshToken: String) {
		if (refreshToken.isEmpty) {
			didFail(genOAuth2Error("I don't have a refresh token", .PrerequisiteFailed))
			logIfVerbose("No refresh token, cannot continue")
			return;
		}
		
		let post = tokenRequestWithRefreshToken(refreshToken)
		logIfVerbose("Using refresh token with redirect \(redirect!) to receive access token from \(post.URL?.description)")
		
		// perform the request
		let session = NSURLSession.sharedSession()
		let task = session.dataTaskWithRequest(post) { sessData, sessResponse, error in
			var finalError: NSError?
			
			if nil != error {
				finalError = error
			}
			else if let data = sessData, let http = sessResponse as? NSHTTPURLResponse {
				if let json = self.parseRefreshTokenResponse(data, error: &finalError) {
					if 200 == http.statusCode {
						self.logIfVerbose("Did receive access token: \(self.accessToken)")
						self.didAuthorize(json)
						return
					}
					
					finalError = self.errorForAccessTokenErrorResponse(json, fallback: http.statusString)
				}
			}
			
			// if we're still here an error must have happened
			if nil == finalError {
				finalError = genOAuth2Error("Unknown refresh token error for response \(sessResponse) with data \(sessData)", .NetworkError)
			}
			self.didFail(finalError)
		}
		task.resume()
	}
	
	/**
		Parse the NSData object returned when using our refresh token.
	
		:returns: A OAuth2JSON, which is usually returned upon token exchange and may contain additional information
	 */
	func parseRefreshTokenResponse(data: NSData, error: NSErrorPointer) -> OAuth2JSON? {
		if let json = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: error) as? OAuth2JSON {
			println("2 Got \(json)")
			if let access = json["access_token"] as? String {
				accessToken = access
			}
			accessTokenExpiry = nil
			if let expires = json["expires_in"] as? NSTimeInterval {
				accessTokenExpiry = NSDate(timeIntervalSinceNow: expires)
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
			let query = OAuth2CodeGrant.paramsFromQuery(comp!.percentEncodedQuery!)
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
				error = errorForAccessTokenErrorResponse(query)
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

