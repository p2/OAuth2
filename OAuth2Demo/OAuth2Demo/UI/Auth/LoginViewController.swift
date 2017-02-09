//
// Created by tymate on 07/02/2017.
// Copyright (c) 2017 tymate. All rights reserved.
//

import Foundation
import UIKit
import OAuth2

class LoginViewController: UIViewController, OAuth2LoginController {

	weak var delegate: OAuth2LoginControllerDelegate?

	@IBOutlet weak var usernameTextField: UITextField!
	@IBOutlet weak var passwordTextField: UITextField!

	@IBAction func didClickLogin(_ sender: Any) {
		delegate?.validate(username: usernameTextField.text!,
						   password: passwordTextField.text!,
						   completionHandler: { error in
							   if let error = error {
								   self.showError(error)
							   } else {
								   self.showGratz()
							   }
						   })
	}

	@IBAction func didClickLater(_ sender: Any) {
		delegate?.endAuthorization()
	}

	private func showError(_ error: OAuth2Error) {
		let alert = UIAlertController(title: "Error", message: error.description, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))

		callOnMainThread({present(alert, animated: true)})
	}

	private func showGratz() {
		let alert = UIAlertController(title: "Well played", message: "You're now logged in", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Great",
									  style: .default,
									  handler: { _ in self.delegate?.endAuthorization() }))
		callOnMainThread({present(alert, animated: true)})
	}
}
