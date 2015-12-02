//
//  OAuth2CodeGrant.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/18/14.
//  Copyright 2014 Pascal Pfiffner
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


class OAuth2CodeGrantTests: XCTestCase
{
	func testInit() {
		let oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
			"client_secret": "xyz",
			"authorize_uri": "https://auth.ful.io",
			"token_uri": "https://token.ful.io",
			"keychain": false,
		])
		XCTAssertEqual(oauth.clientId, "abc", "Must init `client_id`")
		XCTAssertEqual(oauth.clientSecret!, "xyz", "Must init `client_secret`")
		XCTAssertFalse(oauth.useKeychain, "No keychain")
		XCTAssertNil(oauth.scope, "Empty scope")
		
		XCTAssertEqual(oauth.authURL, NSURL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
		XCTAssertEqual(oauth.tokenURL!, NSURL(string: "https://token.ful.io")!, "Must init `token_uri`")
	}
	
	func testAuthorizeURI() {
		let oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
			"client_secret": "xyz",
			"authorize_uri": "https://auth.ful.io",
			"token_uri": "https://token.ful.io",
			"keychain": false,
		])
		
		XCTAssertNotNil(oauth.authURL, "Must init `authorize_uri`")
		let comp = NSURLComponents(URL: try! oauth.authorizeURLWithRedirect("oauth2://callback", scope: nil, params: nil), resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp.host!, "auth.ful.io", "Correct host")
		let query = OAuth2CodeGrant.paramsFromQuery(comp.percentEncodedQuery!)
		XCTAssertEqual(query["client_id"]!, "abc", "Expecting correct `client_id`")
		XCTAssertNil(query["client_secret"], "Must not have `client_secret`")
		XCTAssertEqual(query["response_type"]!, "code", "Expecting correct `response_type`")
		XCTAssertEqual(query["redirect_uri"]!, "oauth2://callback", "Expecting correct `redirect_uri`")
		XCTAssertTrue(8 == (query["state"]!).characters.count, "Expecting an auto-generated UUID for `state`")
		
		// TODO: test for non-https URLs (must raise)
	}
	
	func testTokenRequest() {
		let oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
			"client_secret": "xyz",
			"authorize_uri": "https://auth.ful.io",
			"token_uri": "https://token.ful.io",
			"keychain": false,
		])
		oauth.redirect = "oauth2://callback"
		
		// no redirect in context - fail
		do {
			try oauth.tokenRequestWithCode("pp")
			XCTAssertTrue(false, "Should not be here any more")
		}
		catch OAuth2Error.NoRedirectURL {
			XCTAssertTrue(true, "Must be here")
		}
		catch {
			XCTAssertTrue(false, "Should not be here")
		}
		
		// with redirect in context - success
		oauth.context.redirectURL = "oauth2://callback"
		
		let req = try! oauth.tokenRequestWithCode("pp")
		let comp = NSURLComponents(URL: req.URL!, resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp.host!, "token.ful.io", "Correct host")
		
		let body = NSString(data: req.HTTPBody!, encoding: NSUTF8StringEncoding) as? String
		let query = OAuth2CodeGrant.paramsFromQuery(body!)
		XCTAssertEqual(query["client_id"]!, "abc", "Expecting correct `client_id`")
		XCTAssertNil(query["client_secret"], "Must not have `client_secret`")
		XCTAssertEqual(query["code"]!, "pp", "Expecting correct `code`")
		XCTAssertEqual(query["grant_type"]!, "authorization_code", "Expecting correct `grant_type`")
		XCTAssertEqual(query["redirect_uri"]!, "oauth2://callback", "Expecting correct `redirect_uri`")
		XCTAssertNil(query["state"], "`state` must be empty")
	}
	
	func testTokenRequestAgainstAuthURL() {
		
		// test fallback to authURL
		let oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
			"client_secret": "xyz",
			"authorize_uri": "https://auth.ful.io",
			"keychain": false,
		])
		oauth.redirect = "oauth2://callback"
		oauth.context.redirectURL = "oauth2://callback"
		
		let req = try! oauth.tokenRequestWithCode("pp")
		let comp = NSURLComponents(URL: req.URL!, resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp.host!, "auth.ful.io", "Correct host")
	}
	
	func testTokenResponse() {
		let oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
			"client_secret": "xyz",
			"authorize_uri": "https://auth.ful.io",
			"keychain": false,
		])
		let response = [
			"access_token": "2YotnFZFEjr1zCsicMWpAA",
			"token_type": "bearer",
			"expires_in": 3600,
			"refresh_token": "tGzv3JOkF0XG5Qx2TlKWIA",
			"foo": "bar & hat"
		]
		
		do {
			let dict = try oauth.parseAccessTokenResponse(response)
			XCTAssertEqual("bar & hat", dict["foo"] as? String)
			XCTAssertEqual("2YotnFZFEjr1zCsicMWpAA", oauth.accessToken, "Must extract access token")
			XCTAssertNotNil(oauth.accessTokenExpiry, "Must extract access token expiry date")
			XCTAssertEqual("tGzv3JOkF0XG5Qx2TlKWIA", oauth.refreshToken, "Must extract refresh token")
		}
		catch {
			XCTAssertTrue(false, "Not expected to throw")
		}
		
		// unsupported bearer type
		let response2 = [
			"access_token": "2YotnFZFEjr1zCsicMWpAA",
			"token_type": "not_my_type",
			"expires_in": 3600,
			"refresh_token": "tGzv3JOkF0XG5Qx2TlKWIA",
			"foo": "bar & hat"
		]
		
		do {
			try oauth.parseAccessTokenResponse(response2)
			XCTAssertTrue(false, "Should not be here any more")
		}
		catch OAuth2Error.UnsupportedTokenType {
			XCTAssertTrue(true, "Throw correct error")
		}
		catch {
			XCTAssertTrue(false, "Should not throw wrong error")
		}
	}
}

