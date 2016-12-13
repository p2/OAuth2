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
#if !NO_MODULE_IMPORT
import Base
#endif


/**
Class to handle OAuth2 Dynamic Client Registration.

This is a lightweight class that uses a OAuth2 instance's settings when registering, only few settings are held by instances of this class.
Hence it's highly portable and can be instantiated when needed with ease.

For the full OAuth2 Dynamic Client Registration spec see https://tools.ietf.org/html/rfc7591
*/
open class OAuth2DynReg {
	
	/// Additional HTTP headers to supply during registration.
	open var extraHeaders: OAuth2StringDict?
	
	/// Whether registration should also allow refresh tokens. Defaults to true, making sure "refresh_token" grant type is being registered.
	open var allowRefreshTokens = true
	
	
	/** Designated initializer. */
	public init() {  }
	
	
	// MARK: - Registration
	
	/**
	Register the given client.
	
	- parameter client: The client to register and update with client credentials, when successful
	- parameter callback: The callback to call when done with the registration response (JSON) and/or an error
	*/
	open func register(client: OAuth2, callback: @escaping ((_ json: OAuth2JSON?, _ error: OAuth2Error?) -> Void)) {
		do {
			let req = try registrationRequest(for: client)
			client.logger?.debug("OAuth2", msg: "Registering client at \(req.url!) with scopes “\(client.scope ?? "(none)")”")
			client.perform(request: req) { response in
				do {
					let data = try response.responseData()
					let dict = try self.parseRegistrationResponse(data: data, client: client)
					try client.assureNoErrorInResponse(dict)
					if response.response.statusCode >= 400 {
						client.logger?.warn("OAuth2", msg: "Registration failed with \(response.response.statusCode)")
					}
					else {
						self.didRegisterWith(json: dict, client: client)
					}
					callback(dict, nil)
				}
				catch let error {
					callback(nil, error.asOAuth2Error)
				}
			}
		}
		catch let error {
			callback(nil, error.asOAuth2Error)
		}
	}
	
	
	// MARK: - Registration Request
	
	/**
	Returns a URL request, set up to be used for registration: POST method, JSON body data.
	
	- parameter for: The OAuth2 client the request is built for
	- returns:       A URL request to be used for registration
	*/
	open func registrationRequest(for client: OAuth2) throws -> URLRequest {
		guard let registrationURL = client.clientConfig.registrationURL else {
			throw OAuth2Error.noRegistrationURL
		}
		
		var req = URLRequest(url: registrationURL)
		req.httpMethod = "POST"
		req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
		req.setValue("application/json", forHTTPHeaderField: "Accept")
		if let headers = extraHeaders {
			for (key, val) in headers {
				req.setValue(val, forHTTPHeaderField: key)
			}
		}
		let body = registrationBody(for: client)
		client.logger?.debug("OAuth2", msg: "Registration parameters: \(body)")
		req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
		
		return req
	}
	
	/** The body data to use for registration. */
	open func registrationBody(for client: OAuth2) -> OAuth2JSON {
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
		var grant_types = [type(of: client).grantType]
		if allowRefreshTokens {
			grant_types.append("refresh_token")
		}
		dict["grant_types"] = grant_types
		if let responseType = type(of: client).responseType {
			dict["response_types"] = [responseType]
		}
		dict["token_endpoint_auth_method"] = client.clientConfig.endpointAuthMethod.rawValue
		return dict
	}
	
	/**
	Parse the registration data that's being returned.
	
	This implementation uses `OAuth2.parseJSON()` to convert the data to `OAuth2JSON`.
	
	- parameter data:   The NSData instance returned by the server
	- parameter client: The client for which we're doing registration
	- returns:          An OAuth2JSON representation of the registration data
	*/
	open func parseRegistrationResponse(data: Data, client: OAuth2) throws -> OAuth2JSON {
		return try client.parseJSON(data)
	}
	
	/**
	Called when registration has returned data and that data has been parsed.
	
	This implementation extracts `client_id`, `client_secret` and `token_endpoint_auth_method` and invokes the client's
	`storeClientToKeychain()` method.
	
	- parameter json:   The registration data in JSON format
	- parameter client: The client for which we're doing registration
	*/
	open func didRegisterWith(json: OAuth2JSON, client: OAuth2) {
		if let id = json["client_id"] as? String {
			client.clientId = id
			client.logger?.debug("OAuth2", msg: "Did register with client-id “\(id)”, params: \(json)")
		}
		else {
			client.logger?.debug("OAuth2", msg: "Did register but did not get a client-id. Params: \(json)")
		}
		if let secret = json["client_secret"] as? String {
			client.clientSecret = secret
			if let expires = json["client_secret_expires_at"] as? Double, 0 != expires {
				client.logger?.debug("OAuth2", msg: "Client secret will expire on \(Date(timeIntervalSince1970: expires))")
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

