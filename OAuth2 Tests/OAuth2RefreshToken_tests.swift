//
//  OAuth2RefreshToken_tests.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 12/20/15.
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

#if os(OSX)
import Cocoa
#endif
import XCTest

@testable
import OAuth2


class OAuth2RefreshTokenTests: XCTestCase {
	
	func genericOAuth2() -> OAuth2 {
		return OAuth2(settings: [
			"client_id": "abc",
			"authorize_uri": "https://auth.ful.io",
			"token_uri": "https://token.ful.io",
			"keychain": false,
		])
	}
	
	func testCannotRefresh() {
		let oauth = genericOAuth2()
		do {
			let _ = try oauth.tokenRequestForTokenRefresh()
			XCTAssertTrue(false, "Should throw when trying to create refresh token request without refresh token")
		}
		catch OAuth2Error.NoRefreshToken {
		}
		catch {
			XCTAssertTrue(false, "Should have thrown `NoRefreshToken`")
		}
	}
	
	func testRefreshRequest() {
		let oauth = genericOAuth2()
		oauth.clientConfig.refreshToken = "pov"
		
		let req = try? oauth.tokenRequestForTokenRefresh()
		XCTAssertNotNil(req)
		XCTAssertNotNil(req?.URL)
		XCTAssertNotNil(req?.HTTPBody)
		XCTAssertEqual("https://token.ful.io", req!.URL!.absoluteString)
		let comp = NSURLComponents(URL: req!.URL!, resolvingAgainstBaseURL: true)
		let params = comp?.percentEncodedQuery
		XCTAssertNil(params)
		let body = NSString(data: req!.HTTPBody!, encoding: NSUTF8StringEncoding) as? String
		XCTAssertNotNil(body)
		let dict = OAuth2.paramsFromQuery(body!)
		XCTAssertEqual(dict["client_id"], "abc")
		XCTAssertEqual(dict["refresh_token"], "pov")
		XCTAssertEqual(dict["grant_type"], "refresh_token")
		XCTAssertNil(dict["client_secret"])
		XCTAssertNil(req!.allHTTPHeaderFields?["Authorization"])
	}
	
	func testRefreshRequestWithSecret() {
		let oauth = genericOAuth2()
		oauth.clientConfig.refreshToken = "pov"
		oauth.clientConfig.clientSecret = "uvw"
		
		let req = try? oauth.tokenRequestForTokenRefresh()
		XCTAssertNotNil(req)
		XCTAssertNotNil(req?.HTTPBody)
		let body = NSString(data: req!.HTTPBody!, encoding: NSUTF8StringEncoding) as? String
		XCTAssertNotNil(body)
		let dict = OAuth2.paramsFromQuery(body!)
		XCTAssertNil(dict["client_id"])
		XCTAssertNil(dict["client_secret"])
		let auth = req!.allHTTPHeaderFields?["Authorization"]
		XCTAssertNotNil(auth)
		XCTAssertEqual("Basic YWJjOnV2dw==", auth, "Expecting correctly base64-encoded Authorization header")
	}
	
	func testRefreshRequestWithSecretInBody() {
		let oauth = genericOAuth2()
		oauth.clientConfig.refreshToken = "pov"
		oauth.clientConfig.clientSecret = "uvw"
		oauth.authConfig.secretInBody = true
		
		let req = try? oauth.tokenRequestForTokenRefresh()
		XCTAssertNotNil(req)
		XCTAssertNotNil(req?.HTTPBody)
		let body = NSString(data: req!.HTTPBody!, encoding: NSUTF8StringEncoding) as? String
		XCTAssertNotNil(body)
		let dict = OAuth2.paramsFromQuery(body!)
		XCTAssertEqual(dict["client_id"], "abc")
		XCTAssertEqual(dict["client_secret"], "uvw")
		XCTAssertNil(req!.allHTTPHeaderFields?["Authorization"])
	}
}

