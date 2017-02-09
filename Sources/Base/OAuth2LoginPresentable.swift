//
// Created by Amaury David on 08/02/2017.
// Copyright (c) 2017 Pascal Pfiffner. All rights reserved.
//

import Foundation

/**
Platform-dependent login presenters must adopt this protocol.
*/
public protocol OAuth2LoginPresentable {

	/// The OAuth2 instance this authorizer belongs to.
	unowned var oauth2: OAuth2PasswordGrantCustom { get }

	weak var delegate: OAuth2LoginPresentableDelegate? {get set}

	func presentLoginController(animated: Bool) throws

	func dismissLoginController(animated: Bool)
}


public protocol OAuth2LoginPresentableDelegate: class {
	/*
	Instanciate and configure the login controller to present according to parameters.
	*/
	func loginController(delegate: OAuth2LoginControllerDelegate) -> OAuth2LoginController
}

/*
	Custom Login controllers must adopt this protocol
*/
public protocol OAuth2LoginController: class {
	weak var delegate: OAuth2LoginControllerDelegate? {get set}
}

/*

*/
public protocol OAuth2LoginControllerDelegate: class {
	/*
		In this func, user's credentials must be submitted to the OAuth server.
		The completionHandler must be called once the server responded with the appropriate error or `nil` is the user is
		now authorized.
		An alternative is to perform some custom check on username's and password's format before sending them. In that case
		the completionHandler can be called without making any request
	*/
	func validate(username: String, password: String, completionHandler: @escaping (OAuth2Error?) -> Void)

	/*
	Called by the loginController when it wants to be dismissed
	*/
	func endAuthorization()
}
