//
// Created by Amaury David on 08/02/2017.
// Copyright (c) 2017 Pascal Pfiffner. All rights reserved.
//
#if os(macOS)

import Cocoa
#if !NO_MODULE_IMPORT
import Base
#endif

/**
A macOS-specific implementation of the `OAuth2LoginPresentable` protocol which simply present the login controller as a sheet over another
controller.
*/
public class OAuth2LoginPresenter: OAuth2LoginPresentable {
	
	private var presentedController: NSViewController?
	
	/**
	Present the given login controller as a sheet over a parent controller.
	
	Throws an error if called on macOS 10.9 or earlier.
	
	- parameter loginController: The controller to present as a sheet
	- parameter fromContext:     The controller to which present the login controller. Should be a `NSViewController`
	- parameter animated:        Whether the presentation should be animated.
	*/
	public func present(loginController: OAuth2LoginController, fromContext context: AnyObject?, animated: Bool) throws {
		guard #available(macOS 10.10, *) else {
			throw OAuth2Error.generic("Native authorizing is only available in OS X 10.10 and later")
		}
		
		guard let parentController = context as? NSViewController else {
			throw context == nil ? OAuth2Error.noAuthorizationContext : OAuth2Error.invalidAuthorizationContext
		}
		
		guard let controller = loginController as? NSViewController else {
			throw OAuth2Error.invalidLoginController(actualType: String(describing: type(of: loginController)),
													 expectedType: String(describing: NSViewController.self))
		}
		
		parentController.presentViewControllerAsSheet(controller)
		presentedController = controller
	}
	
	/**
	Dismiss the presented login controller if any.
	
	Throws an error if called on macOS 10.9 or earlier.
	
	- parameter animated: Whether the dismissal should be animated.
	*/
	public func dismissLoginController(animated: Bool) {
		// Not throwing an error here should not be a problem because it would have been thrown when presenting the controller
		if #available(macOS 10.10, *) {
			presentedController?.dismiss(nil)
		}
		presentedController = nil
	}
}

#endif
