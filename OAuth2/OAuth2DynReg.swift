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
#if IMPORT_SWIFT_KEYCHAIN
import SwiftKeychain
#endif


/**
	Class to handle OAuth2 Dynamic Client Registration.

	This class is WiP and not complete. For the full spec see https://tools.ietf.org/html/draft-ietf-oauth-dyn-reg-30
 */
public class OAuth2DynReg: OAuth2Base
{
	/// The URL to register against.
	public final let registrationURL: NSURL
	
	/// The name of the App to advertise during registration.
	public final var clientName: String?
	
	/// Client id/key.
	public final var clientId: String?
	
	/// The client secret.
	public final var clientSecret: String?
	
	/// The redirect-URIs to register.
	public final var redirectURIs: [String]?
	
	/// Where a logo identifying the app can be found.
	public final var logo: String?
	
	/// Additional HTTP headers to supply during registration.
	public var extraHeaders: OAuth2StringDict?
	
	
	/**
	Designated initializer.
	
	The following settings keys are currently supported:
	
	- client_name (string)
	- registration_uri (URL-string)
	- redirect_uris (list of URL-strings)
	- logo_uri (URL-string)
	
	- keychain (bool, true by default, applies to using the system keychain)
	- verbose (bool, false by default, applies to client logging)
	
	NOTE that you **must** supply at least `registration_uri` upon initialization. If you forget, a _fatalError_ will be raised.
	*/
	override public init(settings: OAuth2JSON) {
		if let client = settings["client_name"] as? String {
			clientName = client
		}
		if let redirect = settings["redirect_uris"] as? [String] {
			redirectURIs = redirect
		}
		if let logoURL = settings["logo_uri"] as? String {
			logo = logoURL
		}
		
		// registration URL
		var aURL: NSURL?
		if let reg = settings["registration_uri"] as? String, let url = NSURL(string: reg) {
			aURL = url
		}
		else {
			fatalError("You must provide a valid “registration_uri” in the settings dictionary")
		}
		registrationURL = aURL!
		super.init(settings: settings)
	}
	
	
	// MARK: - Keychain
	
	public override func keychainServiceName() -> String {
		return registrationURL.description
	}
	
	public override func keychainKeyName() -> String {
		return "clientCredentials"
	}
	
	override func updateFromKeychainItems(items: [String : NSCoding]) {
		if let id = items["id"] as? String {
			clientId = id
		}
		if let secret = items["secret"] as? String {
			clientSecret = secret
		}
	}
	
	override func storableKeychainItems() -> [String: NSCoding]? {
		var dict = [String: NSCoding]()
		if let id = clientId {
			dict["id"] = id
		}
		if let secret = clientSecret {
			dict["secret"] = secret
		}
		return dict.isEmpty ? nil : dict
	}
	
	/** Unsets the client credentials and deletes them from the keychain. */
	public func forgetClient() {
		logIfVerbose("Forgetting client credentials and removing them from keychain")
		let keychain = Keychain(serviceName: keychainServiceName())
		let key = ArchiveKey(keyName: keychainKeyName())
		if let error = keychain.remove(key) {
			NSLog("Failed to delete tokens from keychain: \(error.localizedDescription)")
		}
		
		clientId = nil
		clientSecret = nil
	}
	
	
	// MARK: - Registration
	
	/**
	Attempts to register for client credentials **unless** the given client (1st priority) or the receiver (2nd priority) already have a
	client id. If `onlyIfNeeded` is false will try to register anyway.
	
	- parameter client: The OAuth2 client to update credentials on.
	- parameter onlyIfNeeded: If set to false will register even when the receiver and the client already have a client-id
	- parameter callback: The callback to call when done. Any combination of json and error is possible (in regards to nil-ness)
	*/
	public func registerAndUpdateClient(client: OAuth2, onlyIfNeeded: Bool = true, callback: ((json: OAuth2JSON?, error: ErrorType?) -> Void)) {
		clientId = client.clientConfig.clientId.isEmpty ? clientId : client.clientConfig.clientId
		clientSecret = client.clientConfig.clientSecret ?? clientSecret
		
		// update the client in the callback
		let cb: ((json: OAuth2JSON?, error: ErrorType?) -> Void) = { json, error in
			if let id = self.clientId {
				client.clientConfig.clientId = id
			}
			if let secret = self.clientSecret {
				client.clientConfig.clientSecret = secret
			}
			callback(json: json, error: error)
		}
		
		if onlyIfNeeded {
			registerIfNeeded(cb)
		}
		else {
			register(cb)
		}
	}
	
	/**
	Attempts to register the client **unless** the given client (1st priority) or the receiver (2nd priority) already have a client id.
	
	- parameter callback: The callback to call when done. Any combination of json and error is possible (in regards to nil-ness)
	*/
	public func registerIfNeeded(callback: ((json: OAuth2JSON?, error: ErrorType?) -> Void)) {
		if nil == clientId {
			logIfVerbose("No client id, will need to register")
			register(callback)
		}
		else {
			logIfVerbose("Already have a client id, no need to register")
			callback(json: nil, error: nil)
		}
	}
	
	/**
	Register using the receiver's current setup.
	
	- parameter callback: The callback to call when done with the registration response (JSON) and/or an error
	*/
	public func register(callback: ((json: OAuth2JSON?, error: ErrorType?) -> Void)) {
		let req = registrationRequest()
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
						self.didRegisterWith(dict)
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
	
	/** Returns a mutable URL request, set up to be used for registration: POST method, JSON body data. */
	public func registrationRequest() -> NSMutableURLRequest {
		var body: NSData? = nil
		do {
			body = try NSJSONSerialization.dataWithJSONObject(registrationBody(), options: [])
		}
		catch {}
		if nil == body {
			logIfVerbose("WARNING: the registration body is empty, which will likely cause registration to fail")
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
		req.HTTPBody = body
		
		return req
	}
	
	/** The body data to use for registration. */
	public func registrationBody() -> OAuth2JSON {
		var dict = [String: NSCoding]()
		if let client = clientName {
			dict["client_name"] = client
		}
		if let redirect = redirectURIs {
			dict["redirect_uris"] = redirect
		}
		if let logoURL = logo {
			dict["logo_uri"] = logoURL
		}
		// TODO: "grant_types"
		return dict
	}
	
	public func parseRegistrationResponse(data: NSData) throws -> OAuth2JSON {
		return try parseJSON(data)
	}
	
	public func didRegisterWith(json: OAuth2JSON) {
		if let id = json["client_id"] as? String {
			clientId = id
			logIfVerbose("Did register with client-id “\(id)”")
		}
		else {
			logIfVerbose("Did register but did not get a client-id. Not good.")
		}
		if let secret = json["client_secret"] as? String {
			clientSecret = secret
			// TODO: look at "client_secret_expires_at"
		}
		if useKeychain && nil != clientId {
			storeToKeychain()
		}
	}
}

