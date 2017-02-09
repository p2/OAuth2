//
//  OAuth2PasswordGrantCustom.swift
//  OAuth2
//
//  Created by Amaury David on 7/2/17.
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
A class to handle authorization for clients via password grant, using a custom view.
*/
open class OAuth2PasswordGrantCustom: OAuth2, OAuth2LoginControllerDelegate {

	override open class var grantType: String {
		return "password"
	}

	open var loginPresenter: OAuth2LoginPresentable!

	required public init(settings: OAuth2JSON, loginControllerBuilder: OAuth2LoginPresentableDelegate) {
		super.init(settings: settings)
		loginPresenter = OAuth2LoginPresenter(oauth2: self, delegate: loginControllerBuilder)
	}

	//Temporarily bypass the client registration process
	override func registerClientIfNeeded(callback: @escaping ((OAuth2JSON?, OAuth2Error?) -> Void)) {
		callOnMainThread() {
			callback(nil, nil)
		}
	}

	/**
	Completely bypass the default behavior because with this flow we don't want to show any web view, but a custom
	view controller as a way for the user to provide his credentials.
	*/
	override open func doAuthorize(params: [String : String]? = nil) throws {
		try loginPresenter.presentLoginController(animated: true)
	}

	/**
	Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
	*/
	open func accessTokenRequest(username: String, password: String) throws -> OAuth2AuthRequest {

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

		return req
	}

	/**
	Create a token request and execute it to receive an access token.

	Uses `accessTokenRequest(params:)` to create the request, which you can subclass to change implementation specifics.

	- parameter callback: The callback to call after the request has returned
	*/
	public func obtainAccessToken(username: String, password: String, callback: @escaping ((_ params: OAuth2JSON?, _ error: OAuth2Error?) -> Void)) {
		do {
			let post = try accessTokenRequest(username: username, password: password).asURLRequest(for: self)
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
		catch  {
			callback(nil, error.asOAuth2Error)
		}
	}


	//MARK - OAuth2LoginControllerDelegate

	public func validate(username: String, password: String, completionHandler: @escaping (OAuth2Error?) -> Void) {
		//Default implementation: no additional check on credentials

		//Send the credentials to the server
		obtainAccessToken(username: username, password: password, callback: { params, error in
			if let error = error {
				self.didFail(with: error)
				completionHandler(error) //Send the error to the controller so that it can inform the user of it
			}
			else {
				self.didAuthorize(withParameters: params ?? OAuth2JSON())
				completionHandler(nil) //Tell the controller the user is now authorized
			}
		})
	}

	public func endAuthorization() {
		loginPresenter.dismissLoginController(animated: true)

		//For cases where the user wants to end the process without being authorized
		self.didFail(with: nil)
	}
}

