//
//  OAuth2ClientCredentials.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 5/27/15.
//  Copyright 2015 Pascal Pfiffner
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
    Class to handle two-legged OAuth2 requests of the "client_credentials" type.
 */
public class OAuth2ClientCredentials: OAuth2
{
	public override func authorize(# params: [String : String]?, autoDismiss: Bool) {
		if hasUnexpiredAccessToken() {
			self.didAuthorize([String: String]())
		}
		else {
			logIfVerbose("No access token, requesting a new one")
			obtainAccessToken() { error in
				if let error = error {
					self.didFail(error)
				}
				else {
					self.didAuthorize([String: String]())
				}
			}
		}
	}
	
	/**
	    If there is a refresh token, use it to receive a fresh access token.
	
	    :param: callback The callback to call after the refresh token exchange has finished
	 */
	func obtainAccessToken(callback: ((error: NSError?) -> Void)) {
		let post = tokenRequest()
		logIfVerbose("Requesting new access token from \(post.URL?.description)")
		
		performRequest(post) { (data, status, error) -> Void in
			var myError = error
			if let data = data, let json = self.parseAccessTokenResponse(data, error: &myError) {
				self.logIfVerbose("Did get access token [\(nil != self.accessToken)]")
				callback(error: nil)
			}
			else {
				callback(error: myError ?? genOAuth2Error("Unknown error when requesting access token"))
			}
		}
	}
	
	/**
	    Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
	
	    Made public to enable unit testing.
	 */
	public func tokenRequest() -> NSMutableURLRequest {
		if clientId.isEmpty {
			NSException(name: "OAuth2IncompleteSetup", reason: "I do not yet have a client id, cannot request a token", userInfo: nil).raise()
		}
		if nil == clientSecret {
			NSException(name: "OAuth2IncompleteSetup", reason: "I do not yet have a client secret, cannot request a token", userInfo: nil).raise()
		}
		
		let req = NSMutableURLRequest(URL: authURL)
		req.HTTPMethod = "POST"
		req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		req.setValue("application/json", forHTTPHeaderField: "Accept")
        
		// check if scope is set
		if let scope = scope {
			req.HTTPBody = "grant_type=client_credentials&scope=\(scope.wwwFormURLEncodedString)".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
		}
		else {
			req.HTTPBody = "grant_type=client_credentials".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
		}
		// add Authorization header
		logIfVerbose("Adding “Authorization” header as “Basic client-key:client-secret”")
		let pw = "\(clientId.wwwFormURLEncodedString):\(clientSecret!.wwwFormURLEncodedString)"
		if let utf8 = pw.dataUsingEncoding(NSUTF8StringEncoding) {
			req.setValue("Basic \(utf8.base64EncodedStringWithOptions(nil))", forHTTPHeaderField: "Authorization")
		}
		else {
			logIfVerbose("ERROR: for some reason failed to base-64 encode the client-key:client-secret combo")
		}
		
		return req
	}
	
	override func parseAccessTokenResponse(data: NSData, error: NSErrorPointer) -> OAuth2JSON? {
		if let json = super.parseAccessTokenResponse(data, error: error) {
			if let type = json["token_type"] as? String where "bearer" != type {
				logIfVerbose("WARNING: expecting “bearer” token type but got “\(type)”")
			}
			return json
		}
		return nil
	}
}

