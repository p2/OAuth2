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
#endif

/**
An object adopting this protocol is responsible of the creation of the login controller
*/
public protocol OAuth2PasswordGrantDelegate: class {
	/**
	Instanciates and configures the login controller to present.
	
	Don't forget setting its oauth2 instance with the one in parameter.
	*/
	func loginController(oauth2: OAuth2PasswordGrant) -> OAuth2LoginController
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
	
	///The username to use during authorization.
	open var username: String?
	///The password to use during authorization.
	open var password: String?
	
	//Properties used to handle the native controller
	lazy var loginPresenter = OAuth2LoginPresenter()
	
	/**
	If credentials are unknown when trying to authorize, the delegate will be asked a login controller to present.
	
	`OAuth2Error.noPasswordGrantDelegate` will be thrown if the delegate is needed but not set.
	*/
	open var delegate: OAuth2PasswordGrantDelegate?
	
	private var customAuthParams:      OAuth2StringDict?
	private var authorizationResponse: OAuth2JSON?
	
	/**
	Adds support for the "password" & "username" setting.
	*/
	override public init(settings: OAuth2JSON) {
		username = settings["username"] as? String
		password = settings["password"] as? String
		super.init(settings: settings)
	}
	
	/**
	Performs the accessTokenRequest if credentials are already provided, or ask for them with a native controller.
	*/
	override open func doAuthorize(params: OAuth2StringDict? = nil) throws {
		
		authorizationResponse = nil
		
		if username?.isEmpty ?? true || password?.isEmpty ?? true {
			try askForCredentials()
		} else {
			obtainAccessToken(params: params) { params, error in
				if let error = error {
					self.didFail(with: error)
				} else {
					self.didAuthorize(withParameters: params ?? OAuth2JSON())
				}
			}
		}
	}
	
	/**
	Present the delegate's loginController to the user.
	*/
	private func askForCredentials(params: OAuth2StringDict? = nil) throws {
		logger?.debug("OAuth2", msg: "Presenting the login controller")
		
		guard let delegate = delegate else {
			throw OAuth2Error.noPasswordGrantDelegate
		}
		
		try loginPresenter.present(loginController: delegate.loginController(oauth2: self),
								   fromContext: authConfig.authorizeContext,
								   animated: true)
		customAuthParams = params
	}
	
	/**
	Submits loginController's provided credentials to the OAuth server.
	
	This doesn't automatically dismiss the login controller once the user is authorized, allowing the login controller to
	perform any kind of confirmation before its dismissal. Use `endAuthorization` to end the authorizing by dismissing
	the login controller.
	
	- parameter username:			The username to try against the server
	- parameter password:			The password to try against the server
	- parameter completionHandler:	The closure to call once the server responded. The response's JSON is send if the
									server accepted the given credentials. If the JSON is empty, see the error field for
									more information about the failure.
	*/
	public func tryCredentials(username: String,
							   password: String,
							   completionHandler: @escaping (OAuth2JSON?, OAuth2Error?) -> Void) {
		
		self.username = username
		self.password = password
		
		//Perform the request
		obtainAccessToken(params: customAuthParams, callback: { params, error in
			//Reset credentials
			if error != nil {
				self.username = nil
				self.password = nil
			}
			
			completionHandler(params, error)
		})
	}
	
	/**
	Ends the authorization process by dismissing the loginController (if any), whether the user had been successfully
	authorized or not.
	
	- parameter animated:	Whether the dismissal should be animated.
	*/
	public func endAuthorization(animated: Bool = true) {
		//Some clean up
		customAuthParams = nil
		
		logger?.debug("OAuth2", msg: "Dismissing the login controller")
		loginPresenter.dismissLoginController(animated: animated)
		
		//Call the right authorization callback according to the last server response
		if let response = authorizationResponse {
			self.didAuthorize(withParameters: response)
		} else {
			self.didFail(with: nil)
		}
	}
	
	/**
	Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
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
					self.authorizationResponse = dict
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
