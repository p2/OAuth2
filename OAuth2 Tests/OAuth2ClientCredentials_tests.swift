//
//  OAuth2ClientCredentials_tests.swift
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
import OAuth2


class OAuth2ClientCredentialsTests: XCTestCase
{
	func genericOAuth2() -> OAuth2ClientCredentials {
		return OAuth2ClientCredentials(settings: [
			"client_id": "abc",
			"client_secret": "def",
			"authorize_uri": "https://auth.ful.io",
			"scope": "login and more",
			"verbose": true
		])
	}
    
	func genericOAuth2NoScope() -> OAuth2ClientCredentials {
		return OAuth2ClientCredentials(settings: [
			"client_id": "abc",
			"client_secret": "def",
			"authorize_uri": "https://auth.ful.io",
			"verbose": true
			])
	}
	
	func testInit() {
		let oauth = genericOAuth2()
		XCTAssertEqual(oauth.clientId, "abc", "Must init `client_id`")
		XCTAssertEqual(oauth.clientSecret!, "def", "Must init `client_secret`")
		XCTAssertEqual(oauth.scope!, "login and more", "Must init correct scope")
		XCTAssertEqual(oauth.authURL, NSURL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
		XCTAssertTrue(oauth.verbose, "Set to verbose")
	}
	
	func testTokenRequest() {
		let oauth = genericOAuth2()
		let request = oauth.tokenRequest()
		XCTAssertEqual("POST", request.HTTPMethod, "Must be a POST request")
		
		let authHeader = request.allHTTPHeaderFields?["Authorization"] as? String
		XCTAssertNotNil(authHeader, "Must create “Authorization” header")
		XCTAssertEqual(authHeader!, "Basic YWJjOmRlZg==", "Must correctly Base64 encode header")
		
		let body = NSString(data: request.HTTPBody!, encoding: NSUTF8StringEncoding)
		XCTAssertNotNil(body, "Body data must be present")
		XCTAssertEqual(body!, "grant_type=client_credentials&scope=login+and+more", "Must create correct request body")
	}
	
	func testFailedTokenRequest() {
		let oauth = OAuth2ClientCredentials(settings: [
			"client_id": "abc",
			"authorize_uri": "https://auth.ful.io",
			"scope": "login",
			"verbose": true
		])
		// TODO: this must (and does) raise, but XCTAssertThrows() is not yet available in Swift
//		oauth.tokenRequest()
	}
    
	func testTokenRequestNoScope(){
		let oauth = genericOAuth2NoScope()
		let request = oauth.tokenRequest()
		XCTAssertEqual("POST", request.HTTPMethod, "Must be a POST request")
		
		let body = NSString(data: request.HTTPBody!, encoding: NSUTF8StringEncoding)
		XCTAssertNotNil(body, "Body data must be present")
		XCTAssertEqual(body!, "grant_type=client_credentials", "Must create correct request body")
	}
}

