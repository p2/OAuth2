//
//  OAuth2PasswordGrantTests.swift
//  OAuth2
//
//  Created by Tim Sneed on 6/5/15.
//  Copyright (c) 2015 Pascal Pfiffner. All rights reserved.
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


class OAuth2PasswordGrantTests: XCTestCase {
	
	func genericOAuth2Password() -> OAuth2PasswordGrant {
		return OAuth2PasswordGrant(settings: [
			"client_id": "abc",
			"client_secret": "def",
			"authorize_uri": "https://auth.ful.io",
			"scope": "login and more",
			"username":"My User",
			"password":"Here is my password",
			"keychain": false,
		])
	}
	
	func testInit() {
		let oauth = genericOAuth2Password()
		XCTAssertEqual(oauth.clientId, "abc", "Must init `client_id`")
		XCTAssertEqual(oauth.clientSecret!, "def", "Must init `client_secret`")
		XCTAssertEqual(oauth.scope!, "login and more", "Must init correct scope")
		XCTAssertEqual(oauth.username, "My User", "Must init user")
		XCTAssertEqual(oauth.password, "Here is my password", "Must init password")
		XCTAssertEqual(oauth.authURL, URL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
		XCTAssertFalse(oauth.useKeychain, "Don't use keychain")
	}
	
	func testTokenRequest() {
		let oauth = genericOAuth2Password()
		let request = try! oauth.accessTokenRequest().asURLRequest(for: oauth)
		XCTAssertEqual("POST", request.httpMethod, "Must be a POST request")
		
		let authHeader = request.allHTTPHeaderFields?["Authorization"]
		XCTAssertNotNil(authHeader, "Must create “Authorization” header")
		XCTAssertEqual(authHeader!, "Basic YWJjOmRlZg==", "Must correctly Base64 encode header")
		
		let body = String(data: request.httpBody!, encoding: String.Encoding.utf8)
		XCTAssertNotNil(body, "Body data must be present")
		XCTAssertTrue(body!.contains("username=My+User"), "Must create correct request body")
		XCTAssertTrue(body!.contains("grant_type=password"), "Must create correct request body")
		XCTAssertTrue(body!.contains("scope=login+and+more"), "Must create correct request body")
		XCTAssertTrue(body!.contains("password=Here+is+my+password"), "Must create correct request body")
	}
	
	func testTokenResponse() {
		let oauth = genericOAuth2Password()
		let response = [
			"access_token": "2YotnFZFEjr1zCsicMWpAA",
			"token_type": "bearer",
			"expires_in": 3600,
			"refresh_token": "tGzv3JOkF0XG5Qx2TlKWIA",
			"foo": "bar"
		] as [String: Any]
		do {
			let dict = try oauth.parseAccessTokenResponse(params: response)
			XCTAssertEqual("bar", dict["foo"] as? String)
			XCTAssertEqual("2YotnFZFEjr1zCsicMWpAA", oauth.accessToken, "Must extract access token")
			XCTAssertNotNil(oauth.accessTokenExpiry, "Must extract access token expiry date")
			XCTAssertEqual("tGzv3JOkF0XG5Qx2TlKWIA", oauth.refreshToken, "Must extract refresh token")
		}
		catch {
			XCTAssertTrue(false, "Not expected to throw")
		}
	}
	
	func testTokenRequestNoScope() {
		let oauth = OAuth2PasswordGrant(settings: [
			"client_id": "abc",
			"authorize_uri": "https://auth.ful.io",
			"username":"My User",
			"password":"Here is my password",
			"verbose": true
		])
		let request = try! oauth.accessTokenRequest(params: ["foo": "bar & hat"]).asURLRequest(for: oauth)
		
		let body = String(data: request.httpBody!, encoding: String.Encoding.utf8)
		XCTAssertNotNil(body, "Body data must be present")
		XCTAssertTrue(body!.contains("grant_type=password"), "Must create correct request body")
		XCTAssertTrue(body!.contains("username=My+User"), "Must create correct request body")
		XCTAssertTrue(body!.contains("password=Here+is+my+password"), "Must create correct request body")
		XCTAssertTrue(body!.contains("client_id=abc"), "Must add client_id to request body")
		XCTAssertTrue(body!.contains("foo=bar+%26+hat"), "Must create correct request body")
	}
}

