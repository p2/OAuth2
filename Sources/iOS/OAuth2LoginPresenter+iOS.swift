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

	public unowned var oauth2: OAuth2PasswordGrantCustom

	public weak var delegate: OAuth2LoginPresentableDelegate?

	private var presentingController: UIViewController?

	public required init(oauth2: OAuth2PasswordGrantCustom, delegate: OAuth2LoginPresentableDelegate) {
		self.oauth2 = oauth2
		self.delegate = delegate
	}

	public func presentLoginController(animated: Bool) throws {
		oauth2.logger?.debug("OAuth2", msg: "Presenting the login controller")

		let context = oauth2.authConfig.authorizeContext
		guard let parentController = context as? UIViewController else {
			throw context == nil ? OAuth2Error.noAuthorizationContext : OAuth2Error.invalidAuthorizationContext
		}

		let tmpController = delegate?.loginController(delegate: oauth2)
		guard let controller = tmpController as? UIViewController else {
			throw OAuth2Error.invalidLoginController(actualType: String(describing: type(of: tmpController)),
													 expectedType: String(describing: UIViewController.self))
		}

		presentingController = parentController
		presentingController?.present(controller, animated: animated)
	}

	public func dismissLoginController(animated: Bool) {
		oauth2.logger?.debug("OAuth2", msg: "Dismissing the login controller")
		if let controller = presentingController {
			controller.dismiss(animated: animated, completion: {
				self.presentingController = nil
			})
		}
	}
}

#endif
