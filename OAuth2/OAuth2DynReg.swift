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

	This class is WiP and not complete. For the full spec see https://tools.ietf.org/html/rfc7591
 */
public class OAuth2DynReg: OAuth2Base {
	
	/// The endpoint auth method to use. If left nil will use server's default.
	public var endpointAuthMethod: OAuth2EndpointAuthMethod?
	
	/// Additional HTTP headers to supply during registration.
	public var extraHeaders: OAuth2StringDict?
	
	/// Whether registration should also allow refresh tokens. Defaults to true.
	public var allowRefreshTokens = true
	
	
	// MARK: - Registration
	
	/**
	Attempts to register for client credentials **unless** the given client already has a client id. If `onlyIfNeeded` is false will try to
	register anyway.
	
	- parameter client: The OAuth2 client to register and update credentials, once registered.
	- parameter onlyIfNeeded: If set to false will register even when the receiver and the client already have a client-id
	- parameter callback: The callback to call when done. Any combination of json and error is possible (in regards to nil-ness)
	*/
	public func registerAndUpdateClient(client: OAuth2, onlyIfNeeded: Bool = true, callback: ((json: OAuth2JSON?, error: ErrorType?) -> Void)) {
		if onlyIfNeeded {
			registerClientIfNeeded(client, callback: callback)
		}
		else {
			registerClient(client, callback: callback)
		}
	}
	
	/**
	Attempts to register the client **unless** the given client (1st priority) or the receiver (2nd priority) already have a client id.
	
	- parameter callback: The callback to call when done. Any combination of json and error is possible (in regards to nil-ness)
	*/
	public func registerClientIfNeeded(client: OAuth2, callback: ((json: OAuth2JSON?, error: ErrorType?) -> Void)) {
		if let clientId = client.clientConfig.clientId where !clientId.isEmpty {
			logIfVerbose("Already have a client id, no need to register")
			callback(json: nil, error: nil)
		}
		else {
			logIfVerbose("No client id, will need to register")
			registerClient(client, callback: callback)
		}
	}
	
	/**
	Register using the receiver's current setup.
	
	- parameter callback: The callback to call when done with the registration response (JSON) and/or an error
	*/
	public func registerClient(client: OAuth2, callback: ((json: OAuth2JSON?, error: ErrorType?) -> Void)) {
		do {
			let req = try registrationRequest(client)
			logIfVerbose("Registering client at \(req.URL!)")
			
			performRequest(req) { data, status, error in
				if let data = data {
					do {
						let dict = try self.parseRegistrationResponse(data)
						try self.assureNoErrorInResponse(dict)
						if status >= 400 {
							self.logIfVerbose("Registration failed with \(status)")
						}
						else {
							self.didRegisterWith(dict, client: client)
						}
						callback(json: dict, error: nil)
					}
					catch let err {
						callback(json: nil, error: err)
					}
				}
				else {
					callback(json: nil, error: error ?? OAuth2Error.NoDataInResponse)
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
		req.HTTPBody = try NSJSONSerialization.dataWithJSONObject(registrationBody(client), options: [])
		
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
		if let logoURL = client.clientConfig.logoURL {
			dict["logo_uri"] = logoURL
		}
		if let authMethod = endpointAuthMethod {
			dict["token_endpoint_auth_method"] = authMethod.rawValue
		}
		
		// grant types
		var grant_types = [client.dynamicType.grantType]
		if allowRefreshTokens {
			grant_types.append("refresh_token")
		}
		dict["grant_types"] = grant_types
		return dict
	}
	
	public func parseRegistrationResponse(data: NSData) throws -> OAuth2JSON {
		return try parseJSON(data)
	}
	
	public func didRegisterWith(json: OAuth2JSON, client: OAuth2) {
		if let id = json["client_id"] as? String {
			client.clientId = id
			client.logIfVerbose("Did register with client-id “\(id)”")
		}
		else {
			client.logIfVerbose("Did register but did not get a client-id")
		}
		if let secret = json["client_secret"] as? String {
			client.clientSecret = secret
			// TODO: look at "client_secret_expires_at"
		}
		if useKeychain {
			client.storeClientToKeychain()
		}
	}
}

