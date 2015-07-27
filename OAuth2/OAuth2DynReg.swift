//
//  OAuth2DynReg.swift
//  c3-pro
//
//  Created by Pascal Pfiffner on 6/1/15.
//  Copyright (c) 2015 Boston Children's Hospital. All rights reserved.
//

import Foundation


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
	public var extraHeaders: [String: String]?
	
	
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
	client id.
	
	:param: callback The callback to call when done. Any combination of json and error is possible (in regards to nil-ness)
	*/
	public func registerIfNeededAndUpdateClient(client: OAuth2, callback: ((json: OAuth2JSON?, error: NSError?) -> Void)) {
		clientId = client.clientId.isEmpty ? clientId : client.clientId
		clientSecret = client.clientSecret ?? clientSecret
		
		registerIfNeeded { json, error in
			if let id = self.clientId {
				client.clientId = id
			}
			if let secret = self.clientSecret {
				client.clientSecret = secret
			}
			callback(json: json, error: error)
		}
	}
	
	/**
	Attempts to register the client **unless** the receiver already has a client id.
	
	:param: callback The callback to call when done. Any combination of json and error is possible (in regards to nil-ness)
	*/
	public func registerIfNeeded(callback: ((json: OAuth2JSON?, error: NSError?) -> Void)) {
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
	
	:param: callback The callback to call when done with the registration response (JSON) and/or an error
	*/
	public func register(callback: ((json: OAuth2JSON?, error: NSError?) -> Void)) {
		let req = registrationRequest()
		logIfVerbose("Registering client at \(req.URL!)")
		
		performRequest(req) { data, status, error in
			var myError = error
			if let data = data, let json = self.parseRegistrationResponse(data, error: &myError) {
				if status < 400 && nil == json["error"] {
					self.didRegisterWith(json)
					callback(json: json, error: nil)
					return
				}
				
				myError = self.errorForErrorResponse(json)
			}
			
			let err = myError ?? genOAuth2Error("Unknown error during client registration")
			self.logIfVerbose("Registration failed: \(err.localizedDescription)")
			callback(json: nil, error: err)
		}
	}
	
	/** Returns a mutable URL request, set up to be used for registration: POST method, JSON body data. */
	public func registrationRequest() -> NSMutableURLRequest {
        var body: NSData?
        do {
            body = try NSJSONSerialization.dataWithJSONObject(registrationBody(), options: NSJSONWritingOptions())
            if (body == nil) {
                print("JSON Body is empty, this request will likely fail")
            }
        } catch {
            print(error)
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
	
	public func parseRegistrationResponse(data: NSData, error: NSErrorPointer) -> OAuth2JSON? {
        do {
		if let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as? OAuth2JSON {
			return json
		}
        } catch {
            print(error)
        }
		return nil
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

