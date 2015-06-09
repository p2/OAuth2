//
//  OAuth2PasswordGrant_Tests.swift
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
import OAuth2

class OAuth2PasswordGrantTests: XCTestCase{
	
	func genericOAuth2Password() -> OAuth2PasswordGrant {
		return OAuth2PasswordGrant(settings: [
			"client_id": "abc",
			"client_secret": "def",
			"authorize_uri": "https://auth.ful.io",
			"scope": "login and more",
			"username":"My User",
			"password":"Here is my password",
			"verbose": true
			])
	}
	
	func testInit() {
		let oauth = genericOAuth2Password()
		XCTAssertEqual(oauth.clientId, "abc", "Must init `client_id`")
		XCTAssertEqual(oauth.clientSecret!, "def", "Must init `client_secret`")
		XCTAssertEqual(oauth.scope!, "login and more", "Must init correct scope")
		XCTAssertEqual(oauth.username, "My User", "Must init user")
		XCTAssertEqual(oauth.password, "Here is my password", "Must init password")
		XCTAssertEqual(oauth.authURL, NSURL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
		XCTAssertTrue(oauth.verbose, "Set to verbose")
	}
	
	func testTokenRequest() {
		let oauth = genericOAuth2Password()
		let request = oauth.tokenRequest()
		XCTAssertEqual("POST", request.HTTPMethod, "Must be a POST request")
		
		let authHeader = request.allHTTPHeaderFields?["Authorization"] as? String
		XCTAssertNotNil(authHeader, "Must create “Authorization” header")
		XCTAssertEqual(authHeader!, "Basic YWJjOmRlZg==", "Must correctly Base64 encode header")
		
		let body = NSString(data: request.HTTPBody!, encoding: NSUTF8StringEncoding)
		XCTAssertNotNil(body, "Body data must be present")
		XCTAssertEqual(body!, "grant_type=password&scope=login+and+more&username=My+User&password=Here+is+my+password", "Must create correct request body")
	}
	
	func testTokenRequestNoScope() {
		let oauth = OAuth2PasswordGrant(settings: [
			"client_id": "abc",
			"client_secret": "def",
			"authorize_uri": "https://auth.ful.io",
			"username":"My User",
			"password":"Here is my password",
			"verbose": true
			])
		let request = oauth.tokenRequest()
		
		let body = NSString(data: request.HTTPBody!, encoding: NSUTF8StringEncoding)
		XCTAssertNotNil(body, "Body data must be present")
		XCTAssertEqual(body!, "grant_type=password&username=My+User&password=Here+is+my+password", "Must create correct request body")
	}
}