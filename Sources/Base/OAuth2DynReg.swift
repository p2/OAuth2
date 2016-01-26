//
//  OAuth2DynReg.swift
//  c3-pro
//
//  Created by Pascal Pfiffner on 6/1/15.
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


public enum OAuth2EndpointAuthMethod: String {
	case None = "none"
	case ClientSecretPost = "client_secret_post"
	case ClientSecretBasic = "client_secret_basic"
}


/**
    Class to handle OAuth2 Dynamic Client Registration.

    This is a lightweight class that uses a OAuth2 instance's settings when registering, only few settings are held by instances of this
    class. Hence it's highly portable and can be instantiated when needed with ease.

	For the full OAuth2 Dynamic Client Registration spec see https://tools.ietf.org/html/rfc7591
 */
public class OAuth2DynReg {
	
	/// Additional HTTP headers to supply during registration.
	public var extraHeaders: OAuth2StringDict?
	
	/// Whether registration should also allow refresh tokens. Defaults to true, making sure "refresh_token" grant type is being registered.
	public var allowRefreshTokens = true
	
	public init() {  }
	
	
	// MARK: - Registration
	
	/**
	Register the given client.
	
	- parameter client: The client to register and update with client credentials, when successful
	- parameter callback: The callback to call when done with the registration response (JSON) and/or an error
	*/
	public func registerClient(client: OAuth2, callback: ((json: OAuth2JSON?, error: ErrorType?) -> Void)) {
		do {
			let req = try registrationRequest(client)
			client.logIfVerbose("Registering client at \(req.URL!) with scopes “\(client.scope ?? "(none)")”")
			client.performRequest(req) { data, status, error in
				do {
					guard let data = data else {
						throw error ?? OAuth2Error.NoDataInResponse
					}
					
					let dict = try self.parseRegistrationResponse(data, client: client)
					try client.assureNoErrorInResponse(dict)
					if status >= 400 {
						client.logIfVerbose("Registration failed with \(status)")
					}
					else {
						self.didRegisterWith(dict, client: client)
					}
					callback(json: dict, error: nil)
				}
				catch let error {
					callback(json: nil, error: error)
				}
			}
		}
		catch let error {
			callback(json: nil, error: error)
		}
	}
	
	
	// MARK: - Registration Request
	
	/** Returns a mutable URL request, set up to be used for registration: POST method, JSON body data. */
	public func registrationRequest(client: OAuth2) throws -> NSMutableURLRequest {
		guard let registrationURL = client.clientConfig.registrationURL else {
			throw OAuth2Error.NoRegistrationURL
		}
		
		let req = NSMutableURLRequest(URL: registrationURL)
		req.HTTPMethod = "POST"
		req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
		req.setValue("application/json", forHTTPHeaderField: "Accept")
		if let headers = extraHeaders {
			for (key, val) in headers {
				req.setValue(val, forHTTPHeaderField: key)
			}
		}
		let body = registrationBody(client)
		client.logIfVerbose("Registration parameters: \(body)")
		req.HTTPBody = try NSJSONSerialization.dataWithJSONObject(body, options: [])
		
		return req
	}
	
	/** The body data to use for registration. */
	public func registrationBody(client: OAuth2) -> OAuth2JSON {
		var dict = OAuth2JSON()
		if let client = client.clientConfig.clientName {
			dict["client_name"] = client
		}
		if let redirect = client.clientConfig.redirectURLs {
			dict["redirect_uris"] = redirect
		}
		if let logoURL = client.clientConfig.logoURL?.absoluteString {
			dict["logo_uri"] = logoURL
		}
		if let scope = client.scope {
			dict["scope"] = scope
		}
		
		// grant types, response types and auth method
		var grant_types = [client.dynamicType.grantType]
		if allowRefreshTokens {
			grant_types.append("refresh_token")
		}
		dict["grant_types"] = grant_types
		if let responseType = client.dynamicType.responseType {
			dict["response_types"] = [responseType]
		}
		dict["token_endpoint_auth_method"] = client.clientConfig.endpointAuthMethod.rawValue
		return dict
	}
	
	public func parseRegistrationResponse(data: NSData, client: OAuth2) throws -> OAuth2JSON {
		return try client.parseJSON(data)
	}
	
	public func didRegisterWith(json: OAuth2JSON, client: OAuth2) {
		if let id = json["client_id"] as? String {
			client.clientId = id
			client.logIfVerbose("Did register with client-id “\(id)”, params: \(json)")
		}
		else {
			client.logIfVerbose("Did register but did not get a client-id. Params: \(json)")
		}
		if let secret = json["client_secret"] as? String {
			client.clientSecret = secret
			if let expires = json["client_secret_expires_at"] as? Double where 0 != expires {
				client.logIfVerbose("Client secret will expire on \(NSDate(timeIntervalSince1970: expires))")
			}
		}
		if let methodName = json["token_endpoint_auth_method"] as? String, let method = OAuth2EndpointAuthMethod(rawValue: methodName) {
			client.clientConfig.endpointAuthMethod = method
		}
		
		if client.useKeychain {
			client.storeClientToKeychain()
		}
	}
}

