//
// Created by tymate on 07/02/2017.
// Copyright (c) 2017 tymate. All rights reserved.
//

import Foundation
import OAuth2

class ViewModel {

	let loader: OAuth2DataLoader

	init(oauth2: OAuth2) {
		loader = OAuth2DataLoader(oauth2: oauth2)
	}

	func authorize() {
		loader.attemptToAuthorize { json, error in
			if let error = error {
				print("ViewModel: Auth completed with error: \(error)")
			} else {
				print("ViewModel: Auth completed with data: \(json)")
			}
		}
	}
}
