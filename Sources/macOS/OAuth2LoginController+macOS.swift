//
// Created by Amaury David on 08/02/2017.
// Copyright (c) 2017 Pascal Pfiffner. All rights reserved.
//
#if os(macOS)

import Cocoa

#if !NO_MODULE_IMPORT

import Base

#endif


public class OAuth2LoginPresenter: OAuth2LoginPresentable {

	public unowned var oauth2: OAuth2PasswordGrantCustom

	public weak var delegate: OAuth2LoginPresentableDelegate?

	private var presentedController: NSViewController?

	public required init(oauth2: OAuth2PasswordGrantCustom, delegate: OAuth2LoginPresentableDelegate) {
		self.oauth2 = oauth2
		self.delegate = delegate
	}

	public func presentLoginController(animated: Bool) throws {
		guard #available(macOS 10.10, *) else {
			throw OAuth2Error.generic("Native authorizing is only available in OS X 10.10 and later")
		}

		oauth2.logger?.debug("OAuth2", msg: "Presenting the login controller")

		let context = oauth2.authConfig.authorizeContext
		guard let parentController = context as? NSViewController else {
			throw context == nil ? OAuth2Error.noAuthorizationContext : OAuth2Error.invalidAuthorizationContext
		}

		let tmpController = delegate?.loginController(delegate: oauth2)
		guard let controller = tmpController as? NSViewController else {
			throw OAuth2Error.invalidLoginController(actualType: String(describing: type(of: tmpController)),
													 expectedType: String(describing: NSViewController.self))
		}

		parentController.presentViewControllerAsSheet(controller)
		presentedController = controller
	}

	public func dismissLoginController(animated: Bool) {
		//Not throwing an error here should not be a problem because it would have been thrown when presenting the controller
		if #available(macOS 10.10, *) {
			presentedController?.dismiss(nil)
		}
		presentedController = nil
	}
}

#endif
