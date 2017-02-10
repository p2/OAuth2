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


public class OAuth2LoginPresenter: OAuth2LoginPresentable {

	private var presentingController: UIViewController?

	public func present(loginController: OAuth2LoginController, fromContext context: AnyObject?, animated: Bool) throws {

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

	public func dismissLoginController(animated: Bool) {
		presentingController?.dismiss(animated: animated)
		presentingController = nil
	}
}

#endif
