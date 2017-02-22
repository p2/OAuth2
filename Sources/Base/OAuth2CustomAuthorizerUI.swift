//
//  OAuth2CustomAuthorizerUI.swift
//  OAuth2
//
//  Created by Amaury David on 08/02/2017.
//  Copyright (c) 2017 Pascal Pfiffner. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//


/**
Platform-dependent login presenters that present custom login views must adopt this protocol.
*/
public protocol OAuth2CustomAuthorizerUI {
	
	/**
	This function is responsible of the login controller presentation.
	
	- parameter loginController: The controller to present; the type is platform dependent
	- parameter fromContext:     The presenting context, typically another controller of platform-dependent type
	- parameter animated:        Whether the presentation should be animated
	*/
	func present(loginController: AnyObject, fromContext context: AnyObject?, animated: Bool) throws
	
	/**
	This function must dismiss the login controller.
	
	- parameter animated: Whether the dismissal should be animated
	*/
	func dismissLoginController(animated: Bool)
}

