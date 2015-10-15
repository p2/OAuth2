//
//  OAuth2PasswordGrant.swift
//  OAuth2
//
//  Created by Tim Sneed on 6/5/15.
//  Copyright (c) 2015 Pascal Pfiffner. All rights reserved.
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
    A class to handle authorization for clients via password grant.
 */
public class OAuth2PasswordGrant: OAuth2
{
	/// Username to use during authentication.
	public var username: String
	
	/// The user's password.
	public var password: String
	
	/**
	Adds support for the "password" & "username" setting.
	*/
	public override init(settings: OAuth2JSON) {
		username = settings["username"] as? String ?? ""
		password = settings["password"] as? String ?? ""
		super.init(settings: settings)
	}
	
	public override func authorize(params params: [String : String]? = nil, autoDismiss: Bool = true) {
        tryToObtainAccessTokenIfNeeded() { success in
            if success {
                self.didAuthorize(OAuth2JSON())
            }
            else {
                self.logIfVerbose("No access token, requesting a new one")
                self.obtainAccessToken() { error in
                    if let error = error {
                        self.didFail(error)
                    }
                    else {
                        self.didAuthorize([String: String]())
                    }
                }
            }
        }
	}
	
	/**
	If there is a refresh token, use it to receive a fresh access token.
	
	- parameter callback: The callback to call after the refresh token exchange has finished
	*/
	func obtainAccessToken(callback: ((error: NSError?) -> Void)) {
		do {
			let post = try tokenRequest()
			logIfVerbose("Requesting new access token from \(post.URL?.description)")
			
			performRequest(post) { data, status, error in
				if let data = data {
					do {
						let json = try self.parseAccessTokenResponse(data)
						if status < 400 && nil == json["error"] {
							self.logIfVerbose("Did get access token [\(nil != self.accessToken)]")
							callback(error: nil)
						}
						else {
							callback(error: self.errorForErrorResponse(json, fallback: "The username or password is incorrect"))
						}
					}
					catch let err {
						self.logIfVerbose("Error parsing response: \((err as NSError).localizedDescription)")
						callback(error: err as NSError)
					}
				}
				else {
					callback(error: error ?? genOAuth2Error("Error checking username and password: no data received"))
				}
			}
		}
		catch let err {
			callback(error: err as NSError)
		}
	}
	
	/**
	Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
	*/
	func tokenRequest() throws -> NSMutableURLRequest {
		if username.isEmpty{
			throw OAuth2IncompleteSetup.NoUsername
		}
		if password.isEmpty{
			throw OAuth2IncompleteSetup.NoPassword
		}
		if clientId.isEmpty {
			throw OAuth2IncompleteSetup.NoClientId
		}
		if nil == clientSecret {
			throw OAuth2IncompleteSetup.NoClientSecret
		}
		
		let req = NSMutableURLRequest(URL: tokenURL ?? authURL)
		req.HTTPMethod = "POST"
		req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		req.setValue("application/json", forHTTPHeaderField: "Accept")
		
		// create body string
		var body = "grant_type=password&username=\(username.wwwFormURLEncodedString)&password=\(password.wwwFormURLEncodedString)"
		if let scope = scope {
			body += "&scope=\(scope.wwwFormURLEncodedString)"
		}
		req.HTTPBody = body.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
		
		// add Authorization header
		logIfVerbose("Adding “Authorization” header as “Basic client-key:client-secret”")
		let pw = "\(clientId.wwwFormURLEncodedString):\(clientSecret!.wwwFormURLEncodedString)"
		if let utf8 = pw.dataUsingEncoding(NSUTF8StringEncoding) {
			req.setValue("Basic \(utf8.base64EncodedStringWithOptions([]))", forHTTPHeaderField: "Authorization")
		}
		else {
			logIfVerbose("ERROR: for some reason failed to base-64 encode the client-key:client-secret combo")
		}
		
		return req
	}
	
	override func parseAccessTokenResponse(data: NSData) throws -> OAuth2JSON {
		let json = try super.parseAccessTokenResponse(data)
		if let type = json["token_type"] as? String where "bearer" != type {
			logIfVerbose("WARNING: expecting “bearer” token type but got “\(type)”")
		}
		return json
	}
}

