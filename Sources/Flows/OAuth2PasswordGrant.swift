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
	Don't forget setting it's oauth2 instance with the one in parameter.
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
	
	/// User's credentials to use during authorization.
	open var username: String?
	open var password: String?
	
	//Properties used to handle the native controller
	lazy var loginPresenter = OAuth2LoginPresenter()
	open var delegate: OAuth2PasswordGrantDelegate?
	
	private var additionalParams:      OAuth2StringDict?
	private var authorizationResponse: OAuth2JSON?
	
	/**
	Adds support for the "password" & "username" setting.
	*/
	override public init(settings: OAuth2JSON) {
		username = settings["username"] as? String
		password = settings["password"] as? String
		super.init(settings: settings)
	}
	
	/*
	In this flow, the client registration process doesn't seem really relevant, hence simply bypassing it.
	*/
	override func registerClientIfNeeded(callback: @escaping ((OAuth2JSON?, OAuth2Error?) -> Void)) {
		callOnMainThread() {
			callback(nil, nil)
		}
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
			throw OAuth2Error.noDelegate
		}
		
		try loginPresenter.present(loginController: delegate.loginController(oauth2: self),
								   fromContext: authConfig.authorizeContext,
								   animated: true)
		additionalParams = params
	}
	
	/**
		Submits loginController's provided credentials to the OAuth server.
		The completionHandler is called once the server responded with the appropriate error or `nil` is the user is
		now authorized.
		This doesn't automatically call `endAuthorization` once the user is authorized, allowing the login controller to
		perform any kind of confirmation before its dismissal.
	*/
	public func tryCredentials(username: String,
							   password: String,
							   completionHandler: @escaping (OAuth2JSON?, OAuth2Error?) -> Void) {
		
		self.username = username
		self.password = password
		
		//Perform the request
		obtainAccessToken(params: additionalParams, callback: { params, error in
			//Reset credentials
			if error != nil {
				self.username = nil
				self.password = nil
			}
			
			completionHandler(params, error)
		})
	}
	
	/**
	Ends the authorization process whether the user had been successfully authorized or not.
	*/
	public func endAuthorization(animated: Bool = true) {
		//Some clean up
		additionalParams = nil
		
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
