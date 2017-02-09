//
//  ViewController.swift
//  OAuth2Demo
//
//  Created by tymate on 07/02/2017.
//  Copyright © 2017 tymate. All rights reserved.
//

import UIKit
import OAuth2

class ViewController: UIViewController, OAuth2LoginPresentableDelegate {

	var viewModel: ViewModel!

	override func viewDidLoad() {
		super.viewDidLoad()

		let oauth2 = OAuth2PasswordGrantCustom(settings: [
				"authorize_uri": "https://myAPI.com/back/oauth/token"
		], loginControllerBuilder: self)

		oauth2.verbose = true
		oauth2.authConfig.authorizeContext = self

		viewModel = ViewModel(oauth2: oauth2)
	}

	func loginController(delegate: OAuth2LoginControllerDelegate) -> OAuth2LoginController {
		let controller = UIStoryboard(name: "Auth", bundle: nil).instantiateInitialViewController() as! OAuth2LoginController
		controller.delegate = delegate
		return controller
	}


	@IBAction func clicStartAuth(_ sender: Any) {
		viewModel.authorize()
	}
}

