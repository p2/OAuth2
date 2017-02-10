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
	weak var delegate: OAuth2LoginControllerDelegate? { get set }
}

/*
	An `OAuth2LoginControllerDelegate` is responsible of validating user's credentials against the authorization server.
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
	Called to end the authorization process, whether the user had been authorized or not.
	*/
	func endAuthorization()
}
