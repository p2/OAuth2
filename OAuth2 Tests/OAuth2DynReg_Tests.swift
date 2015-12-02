//
//  OAuth2DynReg_Tests.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 12/2/15.
//  Copyright © 2015 Pascal Pfiffner. All rights reserved.
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

import XCTest
@testable
import OAuth2


class OAuth2DynReg_Tests: XCTestCase {
	
	func genericOAuth2() -> OAuth2 {
		return OAuth2ImplicitGrant(settings: [
			"authorize_uri": "https://auth.ful.io",
			"token_uri": "https://token.ful.io",
			"scope": "login",
			"keychain": false,
		])
	}
	
	func testRegistrationRequest() {
		let oauth = genericOAuth2()
		oauth.clientConfig.registrationURL = NSURL(string: "https://register.ful.io")
		let dynreg = OAuth2DynReg()
		dynreg.extraHeaders = ["Foo": "Bar & Hat"]
		
		do {
			let req = try dynreg.registrationRequest(oauth)
			XCTAssertEqual("register.ful.io", req.URL?.host)
			XCTAssertEqual("POST", req.HTTPMethod)
			let dict = try dynreg.parseJSON(req.HTTPBody!)
			
			XCTAssertEqual("none", dict["token_endpoint_auth_method"] as? String)
			XCTAssertEqual("login", dict["scope"] as? String)
			XCTAssertEqual("refresh_token", (dict["grant_types"] as? [String])?.last)
			XCTAssertEqual("token", (dict["response_types"] as? [String])?.first)
		}
		catch {
			XCTAssertTrue(false, "Should not throw")
		}
	}
	
	func testNotAttemptingRegistration() {
		let oauth = genericOAuth2()
		oauth.registerClientIfNeeded() { error in
			if let error = error as? OAuth2Error {
				switch error {
				case .NoRegistrationURL: break
				default:                 XCTAssertTrue(false, "Expecting no-registration-url error")
				}
			}
			else {
				XCTAssertTrue(false, "Should return no-registration-url error")
			}
		}
		
		oauth.clientId = "abc"
		oauth.registerClientIfNeeded { error in
			XCTAssertNil(error, "Shouldn't even start registering")
		}
	}
}

