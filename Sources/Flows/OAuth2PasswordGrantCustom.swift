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

/*
An object adopting this protocol is responsible of the creation of the login controller
*/

public protocol OAuth2PasswordGrantCustomDelegate: class {
	/*
	Instanciates and configures the login controller to present.
	Don't forget setting it's oauth2 instance with the one in parameter.
	*/
	func loginController(oauth2: OAuth2PasswordGrantCustom) -> OAuth2LoginController
}

/**
A class to handle authorization for clients via password grant, using a native view.
*/

open class OAuth2PasswordGrantCustom: OAuth2PasswordGrant {
	
	open var loginPresenter: OAuth2LoginPresentable
	var delegate: OAuth2PasswordGrantCustomDelegate
	
	//Those params are retrieved from the OAuth2JSON and used in the accessToken request
	private var additionalParams: OAuth2StringDict?
	
	required public init(settings: OAuth2JSON, delegate: OAuth2PasswordGrantCustomDelegate) {
		loginPresenter = OAuth2LoginPresenter()
		self.delegate = delegate
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
	Completely bypass the default behavior because with this flow we don't want to show any web view, but a custom
	view controller as a way for the user to provide his credentials.
	*/
	override open func doAuthorize(params: OAuth2StringDict? = nil) {
		logger?.debug("OAuth2", msg: "Presenting the login controller")
		do {
			try loginPresenter.present(loginController: delegate.loginController(oauth2: self),
									   fromContext: authConfig.authorizeContext,
									   animated: true)
			additionalParams = params
		} catch {
			logger?.debug("OAuth2", msg: "Cannot present the login controller")
			self.didFail(with: error as? OAuth2Error)
		}
	}
	
	/*
		In this func, user's credentials are submitted to the OAuth server.
		The completionHandler is called once the server responded with the appropriate error or `nil` is the user is
		now authorized.
		This doesn't automatically call `endAuthorization` once the user is authorized, allowing the login controller to
		perform any kind of confirmation before its dismissal.
	*/
	public func tryCredentials(username: String,
							   password: String,
							   completionHandler: @escaping (OAuth2Error?) -> Void) {
		
		//Set credentials properties so that the accessToken request is made properly.
		self.username = username
		self.password = password
		
		obtainAccessToken(params: additionalParams, callback: { params, error in
			
			//Reset user's credentials as we don't need them
			self.username = ""
			self.password = ""
			
			if let error = error {
				self.didFail(with: error)
				completionHandler(error) //Send the error to the controller so that it can inform the user of it
			} else {
				self.didAuthorize(withParameters: params ?? OAuth2JSON())
				completionHandler(nil) //Tell the controller the user is now authorized
			}
		})
	}
	
	/*
	Called to end the authorization process, whether the user had been authorized or not.
	*/
	public func endAuthorization() {
		logger?.debug("OAuth2", msg: "Dismissing the login controller")
		loginPresenter.dismissLoginController(animated: true)
		
		//For cases where the user wants to end the process without being authorized
		self.didFail(with: nil)
		additionalParams = nil
	}
}

