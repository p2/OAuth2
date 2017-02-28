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
#if !NO_MODULE_IMPORT
 import Base
 #if os(macOS)
  import macOS
 #elseif os(iOS)
  import iOS
 #elseif os(tvOS)
  import tvOS
 #endif
#endif


/**
An object adopting this protocol is responsible of the creation of the login controller
*/
public protocol OAuth2PasswordGrantDelegate: class {
	
	/**
	Instantiates and configures the login controller to present.
	
	- returns: A view controller that can be presented on the current platform
	*/
	func loginController(oauth2: OAuth2PasswordGrant) -> AnyObject
}


/**
A class to handle authorization for clients via password grant.

If no credentials are set when authorizing, a native controller is shown so that the user can provide them.
*/
open class OAuth2PasswordGrant: OAuth2 {
	
	override open class var grantType: String {
		return "password"
	}
	
	override open class var clientIdMandatory: Bool {
		return false
	}
	
	/// The username to use during authorization.
	open var username: String?
	
	/// The password to use during authorization.
	open var password: String?
	
	/// Properties used to handle the native controller.
	lazy var customAuthorizer: OAuth2CustomAuthorizerUI = OAuth2CustomAuthorizer()
	
	/**
	If credentials are unknown when trying to authorize, the delegate will be asked a login controller to present.
	
	`OAuth2Error.noPasswordGrantDelegate` will be thrown if the delegate is needed but not set.
	*/
	open var delegate: OAuth2PasswordGrantDelegate?
	
	/// Custom authorization parameters to pass when requesting the token.
	private var customAuthParams: OAuth2StringDict?
	
	/**
	Adds support for the "password" & "username" setting.
	*/
	override public init(settings: OAuth2JSON) {
		username = settings["username"] as? String
		password = settings["password"] as? String
		super.init(settings: settings)
	}
	
	
	// MARK: - Auth Flow
	
	/**
	Performs the accessTokenRequest if credentials are already provided, or ask for them with a native view controller.
	
	If you choose to **not** automatically dismiss the login controller, you can do so on your own by calling
	`dismissLoginController(animated:)`.
	
	- parameter params: Optional key/value pairs to pass during authorization
	*/
	override open func doAuthorize(params: OAuth2StringDict? = nil) throws {
		if username?.isEmpty ?? true || password?.isEmpty ?? true {
			try askForCredentials()
		}
		else {
			obtainAccessToken(params: params) { params, error in
				if let error = error {
					self.didFail(with: error)
				}
				else {
					self.didAuthorize(withParameters: params ?? OAuth2JSON())
				}
			}
		}
	}
	
	/**
	Present the delegate's loginController to the user.
	
	- parameter params: Optional key/value pairs to pass during authorization
	*/
	private func askForCredentials(params: OAuth2StringDict? = nil) throws {
		logger?.debug("OAuth2", msg: "Presenting the login controller")
		guard let delegate = delegate else {
			throw OAuth2Error.noPasswordGrantDelegate
		}
		
		// set internal after auth callback to dismiss vc if there was no error, unless configured otherwise
		internalAfterAuthorizeOrFail = { wasFailure , error in
			self.customAuthParams = nil
			
			if self.authConfig.authorizeEmbeddedAutoDismiss, (!wasFailure || error! == OAuth2Error.requestCancelled) {
				self.dismissLoginController(animated: true)
			}
		}
		
		// tell the custom authorizer to present the login screen
		customAuthParams = params
		let controller = delegate.loginController(oauth2: self)
		try customAuthorizer.present(loginController: controller, fromContext: authConfig.authorizeContext, animated: true)
	}
	
	/**
	Submits loginController's provided credentials to the OAuth server.
	
	This doesn't automatically dismiss the login controller once the user is authorized, allowing the login controller to perform any kind
	of confirmation before its dismissal. Use `endAuthorization` to end the authorizing by dismissing the login controller.
	
	- parameter username:          The username to try against the server
	- parameter password:          The password to try against the server
	- parameter completionHandler: The closure to call once the server responded. The response's JSON is send if the server accepted the
	                               given credentials. If the JSON is empty, see the error field for more information about the failure.
	*/
	public func tryCredentials(username: String, password: String, errorHandler: @escaping (OAuth2Error) -> Void) {
		self.username = username
		self.password = password
		
		// perform the request
		obtainAccessToken(params: customAuthParams) { params, error in
			
			// reset credentials on error
			if let error = error {
				self.username = nil
				self.password = nil
				errorHandler(error)
			}
			
			// automatically end the authorization process with a success
			else {
				self.didAuthorize(withParameters: params ?? OAuth2JSON())
			}
		}
	}
	
	/**
	Dismiss the login controller, if any.
	
	- parameter animated: Whether dismissal should be animated
	*/
	open func dismissLoginController(animated: Bool = true) {
		logger?.debug("OAuth2", msg: "Dismissing the login controller")
		customAuthorizer.dismissLoginController(animated: animated)
		if isAuthorizing {
			didFail(with: nil)
		}
	}
	
	
	// MARK: - Access Token Request
	
	/**
	Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
	
	- parameter params: Optional key/value pairs to pass during authorization
	*/
	open func accessTokenRequest(params: OAuth2StringDict? = nil) throws -> OAuth2AuthRequest {
		if username?.isEmpty ?? true {
			throw OAuth2Error.noUsername
		}
		if password?.isEmpty ?? true {
			throw OAuth2Error.noPassword
		}
		
		let req = OAuth2AuthRequest(url: (clientConfig.tokenURL ?? clientConfig.authorizeURL))
		req.params["grant_type"] = type(of: self).grantType
		req.params["username"] = username
		req.params["password"] = password
		if let clientId = clientConfig.clientId {
			req.params["client_id"] = clientId
		}
		if let scope = clientConfig.scope {
			req.params["scope"] = scope
		}
		req.add(params: params)
		
		return req
	}
	
	/**
	Create a token request and execute it to receive an access token.
	
	Uses `accessTokenRequest(params:)` to create the request, which you can subclass to change implementation specifics.
	
	- parameter params: Optional key/value pairs to pass during authorization
	- parameter callback: The callback to call after the request has returned
	*/
	public func obtainAccessToken(params: OAuth2StringDict? = nil, callback: @escaping ((_ params: OAuth2JSON?, _ error: OAuth2Error?) -> Void)) {
		do {
			let post = try accessTokenRequest(params: params).asURLRequest(for: self)
			logger?.debug("OAuth2", msg: "Requesting new access token from \(post.url?.description ?? "nil")")
			
			perform(request: post) { response in
				do {
					let data = try response.responseData()
					let dict = try self.parseAccessTokenResponse(data: data)
					if response.response.statusCode >= 400 {
						throw OAuth2Error.generic("Failed with status \(response.response.statusCode)")
					}
					self.logger?.debug("OAuth2", msg: "Did get access token [\(nil != self.clientConfig.accessToken)]")
					callback(dict, nil)
				}
				catch OAuth2Error.unauthorizedClient {     // TODO: which one is it?
					callback(nil, OAuth2Error.wrongUsernamePassword)
				}
				catch OAuth2Error.forbidden {              // TODO: which one is it?
					callback(nil, OAuth2Error.wrongUsernamePassword)
				}
				catch let error {
					self.logger?.debug("OAuth2", msg: "Error obtaining access token: \(error)")
					callback(nil, error.asOAuth2Error)
				}
			}
		}
		catch {
			callback(nil, error.asOAuth2Error)
		}
	}
}

