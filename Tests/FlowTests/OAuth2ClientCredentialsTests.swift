//
//  OAuth2ClientCredentialsTests.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 5/29/15.
//  Copyright 2015 Pascal Pfiffner
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


class OAuth2ClientCredentialsTests: XCTestCase {
	
	func genericOAuth2() -> OAuth2ClientCredentials {
		return OAuth2ClientCredentials(settings: [
			"client_id": "abc",
			"client_secret": "def",
			"authorize_uri": "https://auth.ful.io",
			"scope": "login and more",
			"keychain": false,
		])
	}
    
	func genericOAuth2NoScope() -> OAuth2ClientCredentials {
		return OAuth2ClientCredentials(settings: [
			"client_id": "abc",
			"client_secret": "def",
			"authorize_uri": "https://auth.ful.io",
			"keychain": false,
		])
	}
	
	func testInit() {
		let oauth = genericOAuth2()
		XCTAssertEqual(oauth.clientId, "abc", "Must init `client_id`")
		XCTAssertEqual(oauth.clientSecret!, "def", "Must init `client_secret`")
		XCTAssertEqual(oauth.scope!, "login and more", "Must init correct scope")
		XCTAssertEqual(oauth.authURL, URL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
		XCTAssertFalse(oauth.useKeychain, "Don't use keychain")
	}
	
	func testTokenRequest() {
		let oauth = genericOAuth2()
		let request = try! oauth.accessTokenRequest().asURLRequest(for: oauth)
		XCTAssertEqual("POST", request.httpMethod, "Must be a POST request")
		
		let authHeader = request.allHTTPHeaderFields?["Authorization"]
		XCTAssertNotNil(authHeader, "Must create “Authorization” header")
		XCTAssertEqual(authHeader!, "Basic YWJjOmRlZg==", "Must correctly Base64 encode header")
		
		let body = String(data: request.httpBody!, encoding: String.Encoding.utf8)
		XCTAssertNotNil(body, "Body data must be present")
		XCTAssertEqual(body!, "grant_type=client_credentials&scope=login+and+more", "Must create correct request body")
	}
	
	func testFailedTokenRequest() {
		let oauth = OAuth2ClientCredentials(settings: [
			"client_id": "abc",
			"authorize_uri": "https://auth.ful.io",
			"scope": "login",
			"keychain": false,
		])
		
		do {
			_ = try oauth.accessTokenRequest()
			XCTAssertFalse(true, "`tokenRequest()` without client secret must throw .NoClientSecret")
		}
		catch OAuth2Error.noClientSecret {
		}
		catch let err {
			XCTAssertFalse(true, "`tokenRequest()` without client secret must throw .NoClientSecret, but threw \(err)")
		}
	}
    
	func testTokenRequestNoScope() {
		let oauth = genericOAuth2NoScope()
		let request = try! oauth.accessTokenRequest().asURLRequest(for: oauth)
		XCTAssertEqual("POST", request.httpMethod, "Must be a POST request")
		
		let body = String(data: request.httpBody!, encoding: String.Encoding.utf8)
		XCTAssertNotNil(body, "Body data must be present")
		XCTAssertEqual(body!, "grant_type=client_credentials", "Must create correct request body")
	}
	
	func testClientCredsReddit() {
		var oauth = OAuth2ClientCredentialsReddit(settings: [
			"client_id": "abc",
			"authorize_uri": "https://auth.ful.io",
			"scope": "profile",
			"keychain": false,
			])
		
		do {
			_ = try oauth.accessTokenRequest()
			XCTAssertFalse(true, "`tokenRequest()` without device_id must throw .Generic")
		}
		catch OAuth2Error.generic(let message) {
			XCTAssertEqual("You must configure this flow with a `device_id` (via settings) or manually assign `deviceId`", message)
		}
		catch let err {
			XCTAssertFalse(true, "`tokenRequest()` without device_id must throw .Generic, but threw \(err)")
		}
		
		oauth.deviceId = "def"
		do {
			let req = try oauth.accessTokenRequest().asURLRequest(for: oauth)
			XCTAssertEqual("Basic YWJjOg==", req.value(forHTTPHeaderField: "Authorization"))
		}
		catch let err {
			XCTAssertFalse(true, "`tokenRequest()` should not have thrown but threw \(err)")
		}
		
		// initialize device_id via settings
		oauth = OAuth2ClientCredentialsReddit(settings: [
			"client_id": "abc",
			"device_id": "def",
			"authorize_uri": "https://auth.ful.io",
			"scope": "profile",
			"keychain": false,
			])
		
		do {
			_ = try oauth.accessTokenRequest()
		}
		catch let err {
			XCTAssertFalse(true, "`tokenRequest()` should not have thrown but threw \(err)")
		}
	}
}

