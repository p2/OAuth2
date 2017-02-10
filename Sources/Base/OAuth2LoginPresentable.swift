//
// Created by Amaury David on 08/02/2017.
// Copyright (c) 2017 Pascal Pfiffner. All rights reserved.
//

import Foundation

/**
Platform-dependent login presenters must adopt this protocol.
*/

public protocol OAuth2LoginPresentable {

	/*
	This function is responsible of the login controller presentation.
	*/
	func present(loginController: OAuth2LoginController, fromContext context: AnyObject?, animated: Bool) throws

	/*
	This function is responsible of the login controller dismissal.
	*/
	func dismissLoginController(animated: Bool)
}

/*
	Custom login controllers must adopt this protocol
*/

public protocol OAuth2LoginController: class {
	weak var oauth2: OAuth2PasswordGrantCustom! { get set }
}
