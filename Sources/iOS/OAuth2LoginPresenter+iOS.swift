//
// Created by Amaury David on 08/02/2017.
// Copyright (c) 2017 Pascal Pfiffner. All rights reserved.
//
#if os(iOS) || os(tvOS)

import Foundation
import UIKit
#if !NO_MODULE_IMPORT
import Base
#endif


/**
An iOS and tvOS-specific implementation of the `OAuth2LoginPresentable` protocol which simply modally present the login
controller
*/
public class OAuth2LoginPresenter: OAuth2LoginPresentable {
	
	private var presentingController: UIViewController?
	
	/**
	Modally present the login controller from the given context.
	
	- parameter loginController:	The controller to present modally.
	- parameter context: 			The parent controller to use to present the login controller.
	- parameter animated: 			Whether the presentation should be animated.
	*/
	public func present(loginController: OAuth2LoginController,
						fromContext context: AnyObject?,
						animated: Bool) throws {
		
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
	
	- parameter animated:	Whether the dismissal should be animated.
	*/
	public func dismissLoginController(animated: Bool) {
		presentingController?.dismiss(animated: animated)
		presentingController = nil
	}
}

#endif
