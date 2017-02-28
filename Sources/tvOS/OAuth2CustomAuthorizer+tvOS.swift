//
//  OAuth2CustomAuthorizer+tvOS.swift
//  OAuth2
//
//  Created by Amaury David on 08/02/2017.
//  Copyright (c) 2017 Pascal Pfiffner. All rights reserved.
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
#if os(tvOS)

import Foundation
import UIKit
#if !NO_MODULE_IMPORT
import Base
#endif


/**
An iOS and tvOS-specific implementation of the `OAuth2CustomAuthorizerUI` protocol which modally presents the login controller.
*/
public class OAuth2CustomAuthorizer: OAuth2CustomAuthorizerUI {
	
	private var presentingController: UIViewController?
	
	public init() {  }
	
	
	// MARK: - OAuth2CustomAuthorizerUI
	
	/**
	Modally present the login controller from the given context.
	
	- parameter loginController: The controller to present modally.
	- parameter context:         The parent controller to use to present the login controller.
	- parameter animated:        Whether the presentation should be animated.
	*/
	public func present(loginController: AnyObject, fromContext context: AnyObject?, animated: Bool) throws {
		guard let parentController = context as? UIViewController else {
			throw context == nil ? OAuth2Error.noAuthorizationContext : OAuth2Error.invalidAuthorizationContext
		}
		guard let controller = loginController as? UIViewController else {
			throw OAuth2Error.invalidLoginController(actualType: String(describing: type(of: loginController)),
													 expectedType: String(describing: UIViewController.self))
		}
		
		presentingController = parentController
		presentingController?.present(controller, animated: animated)
	}
	
	
	/**
	Dismiss the presented login controller if any.
	
	- parameter animated: Whether the dismissal should be animated.
	*/
	public func dismissLoginController(animated: Bool) {
		presentingController?.dismiss(animated: animated)
		presentingController = nil
	}
}

#endif
