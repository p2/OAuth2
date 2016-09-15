//
//  OAuth2DynRegTests.swift
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

#if !NO_MODULE_IMPORT
@testable
import Base
@testable
import Flows
#else
@testable
import OAuth2
#endif


class OAuth2DynRegTests: XCTestCase {
	
	func genericOAuth2(_ extra: OAuth2JSON? = nil) -> OAuth2 {
		var settings = [
			"authorize_uri": "https://auth.ful.io",
			"token_uri": "https://token.ful.io",
			"scope": "login",
			"keychain": false,
		] as OAuth2JSON
		if let extra = extra {
			extra.forEach() { settings[$0] = $1 }
		}
		return OAuth2ImplicitGrant(settings: settings)
	}
	
	func testRegistrationRequest() {
		let oauth = genericOAuth2(["registration_uri": "https://register.ful.io"])
		XCTAssertNotNil(oauth.clientConfig.registrationURL, "Must parse registration URL from settings dict")
		XCTAssertEqual(oauth.clientConfig.registrationURL!.absoluteString, "https://register.ful.io")
		let dynreg = OAuth2DynReg()
		dynreg.extraHeaders = ["Foo": "Bar & Hat"]
		
		do {
			let req = try dynreg.registrationRequest(for: oauth)
			XCTAssertEqual("register.ful.io", req.url?.host)
			XCTAssertEqual("POST", req.httpMethod)
			let dict = try oauth.parseJSON(req.httpBody!)
			
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
		oauth.registerClientIfNeeded() { json, error in
			if let error = error {
				switch error {
				case .noRegistrationURL: break
				default:                 XCTAssertTrue(false, "Expecting no-registration-url error")
				}
			}
			else {
				XCTAssertTrue(false, "Should return no-registration-url error")
			}
		}
		
		oauth.clientId = "abc"
		oauth.registerClientIfNeeded { json, error in
			XCTAssertNil(error, "Shouldn't even start registering")
		}
	}
	
	func testCustomDynRegInstance() {
		let oauth = genericOAuth2(["registration_uri": "https://register.ful.io"])
		
		// return subclass
		oauth.onBeforeDynamicClientRegistration = { url in
			XCTAssertEqual(url.absoluteString, "https://register.ful.io", "Should be passed registration URL")
			return OAuth2TestDynReg()
		}
		oauth.registerClientIfNeeded() { json, error in
			if let error = error {
				switch error {
				case .temporarilyUnavailable: break
				default:                      XCTAssertTrue(false, "Expecting random `TemporarilyUnavailable` error as implemented in `OAuth2TestDynReg`")
				}
			}
			else {
				XCTAssertTrue(false, "Should return no-registration-url error")
			}
		}
	}
}


class OAuth2TestDynReg: OAuth2DynReg {
	override func register(client: OAuth2, callback: @escaping ((OAuth2JSON?, OAuth2Error?) -> Void)) {
		callback(nil, OAuth2Error.temporarilyUnavailable)
	}
}

