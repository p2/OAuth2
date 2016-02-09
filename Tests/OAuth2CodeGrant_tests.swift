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


class OAuth2CodeGrantTests: XCTestCase {
	
	lazy var baseSettings: OAuth2JSON = [
		"client_id": "abc",
		"client_secret": "xyz",
		"authorize_uri": "https://auth.ful.io",
		"token_uri": "https://token.ful.io",
		"keychain": false,
	]
	
	func testInit() {
		let oauth = OAuth2CodeGrant(settings: baseSettings)
		XCTAssertEqual(oauth.clientId, "abc", "Must init `client_id`")
		XCTAssertEqual(oauth.clientSecret!, "xyz", "Must init `client_secret`")
		XCTAssertFalse(oauth.useKeychain, "No keychain")
		XCTAssertNil(oauth.scope, "Empty scope")
		
		XCTAssertEqual(oauth.authURL, NSURL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
		XCTAssertEqual(oauth.tokenURL!, NSURL(string: "https://token.ful.io")!, "Must init `token_uri`")
	}
	
	func testNotTLS() {
		let oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
			"client_secret": "xyz",
			"authorize_uri": "http://auth.ful.io",
			"token_uri": "http://token.ful.io",
			"keychain": false,
		])
		
		XCTAssertNotNil(oauth.authURL, "Must init `authorize_uri`")
		do {
			try oauth.authorizeURLWithRedirect("oauth2://callback", scope: nil, params: nil)
			XCTAssertTrue(false, "Should no longer be here")
		}
		catch OAuth2Error.NotUsingTLS {
		}
		catch let error {
			XCTAssertNil(error, "Should not be catching")
		}
		
		do {
			try oauth.tokenURLWithCode("pp")
			XCTAssertTrue(false, "Should no longer be here")
		}
		catch OAuth2Error.NotUsingTLS {
		}
		catch let error {
			XCTAssertNil(error, "Should not be catching")
		}
	}
	
	func testAuthorizeURI() {
		let oauth = OAuth2CodeGrant(settings: baseSettings)
		XCTAssertNotNil(oauth.authURL, "Must init `authorize_uri`")
		
		let comp = NSURLComponents(URL: try! oauth.authorizeURLWithRedirect("oauth2://callback", scope: nil, params: nil), resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp.host!, "auth.ful.io", "Correct host")
		let query = OAuth2CodeGrant.paramsFromQuery(comp.percentEncodedQuery!)
		XCTAssertEqual(query["client_id"]!, "abc", "Expecting correct `client_id`")
		XCTAssertNil(query["client_secret"], "Must not have `client_secret`")
		XCTAssertEqual(query["response_type"]!, "code", "Expecting correct `response_type`")
		XCTAssertEqual(query["redirect_uri"]!, "oauth2://callback", "Expecting correct `redirect_uri`")
		XCTAssertTrue(8 == (query["state"]!).characters.count, "Expecting an auto-generated UUID for `state`")
	}
	
	func testRedirectURI() {
		let oauth = OAuth2CodeGrant(settings: baseSettings)
		oauth.redirect = "oauth2://callback"
		oauth.context.redirectURL = oauth.redirect
		
		// parse error
		var redirect = NSURL(string: "oauth2://callback?error=invalid_scope")!
		do {
			try oauth.validateRedirectURL(redirect)
			XCTAssertTrue(false, "Should not be here")
		}
		catch OAuth2Error.InvalidScope {
		}
		catch let error {
			XCTAssertTrue(false, "Must not end up here with \(error)")
		}
		
		// parse custom error
		redirect = NSURL(string: "oauth2://callback?error=invalid_scope&error_description=BadScopeDude")!
		do {
			try oauth.validateRedirectURL(redirect)
			XCTAssertTrue(false, "Should not be here")
		}
		catch let error {
			XCTAssertEqual("BadScopeDude", "\(error)", "Must parse `error_description`")
		}
		
		// parse wrong callback
		redirect = NSURL(string: "oauth3://callback?error=invalid_scope")!
		do {
			try oauth.validateRedirectURL(redirect)
			XCTAssertTrue(false, "Should not be here")
		}
		catch OAuth2Error.InvalidRedirectURL {
		}
		catch let error {
			XCTAssertTrue(false, "Should have caught invalid redirect URL error, but got \(error)")
		}
		
		// parse no state
		redirect = NSURL(string: "oauth2://callback?code=C0D3")!
		do {
			try oauth.validateRedirectURL(redirect)
			XCTAssertTrue(false, "Should not be here")
		}
		catch OAuth2Error.InvalidState {
		}
		catch let error {
			XCTAssertTrue(false, "Must not end up here with \(error)")
		}
		
		// parse all good
		redirect = NSURL(string: "oauth2://callback?code=C0D3&state=\(oauth.context.state)")!
		do {
			try oauth.validateRedirectURL(redirect)
		}
		catch let error {
			XCTAssertTrue(false, "Should not throw, but threw \(error)")
		}
		
		// parse oob with invalid redirect
		oauth.redirect = "urn:ietf:wg:oauth:2.0:oob"
		oauth.context.redirectURL = oauth.redirect
		redirect = NSURL(string: "oauth2://callback?code=C0D3&state=\(oauth.context.state)")!
		do {
			try oauth.validateRedirectURL(redirect)
		}
		catch OAuth2Error.InvalidRedirectURL {
		}
		catch let error {
			XCTAssertTrue(false, "Must not end up here with \(error)")
		}
		
		// oob with valid redirect
		redirect = NSURL(string: "http://localhost?code=C0D3&state=\(oauth.context.state)")!
		do {
			try oauth.validateRedirectURL(redirect)
		}
		catch let error {
			XCTAssertTrue(false, "Should not throw, but threw \(error)")
		}
	}
	
	func testTokenRequest() {
		let oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
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
	
	func testTokenRequestWithSecret() {
		let oauth = OAuth2CodeGrant(settings: baseSettings)
		oauth.redirect = "oauth2://callback"
		oauth.context.redirectURL = "oauth2://callback"
		
		// not in body
		let req = try! oauth.tokenRequestWithCode("pp")
		let comp = NSURLComponents(URL: req.URL!, resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp.host!, "token.ful.io", "Correct host")
		
		let body = NSString(data: req.HTTPBody!, encoding: NSUTF8StringEncoding) as? String
		let query = OAuth2CodeGrant.paramsFromQuery(body!)
		XCTAssertNil(query["client_id"], "No `client_id` in body")
		XCTAssertNil(query["client_secret"], "Must not have `client_secret`")
		XCTAssertEqual(query["code"]!, "pp", "Expecting correct `code`")
		XCTAssertEqual(query["grant_type"]!, "authorization_code", "Expecting correct `grant_type`")
		XCTAssertEqual(query["redirect_uri"]!, "oauth2://callback", "Expecting correct `redirect_uri`")
		XCTAssertNil(query["state"], "`state` must be empty")
		
		// in body
		oauth.authConfig.secretInBody = true
		
		let req2 = try! oauth.tokenRequestWithCode("pp")
		let comp2 = NSURLComponents(URL: req2.URL!, resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp2.host!, "token.ful.io", "Correct host")
		
		let body2 = NSString(data: req2.HTTPBody!, encoding: NSUTF8StringEncoding) as? String
		let query2 = OAuth2CodeGrant.paramsFromQuery(body2!)
		XCTAssertEqual(query2["client_id"]!, "abc", "Expecting correct `client_id`")
		XCTAssertEqual(query2["client_secret"]!, "xyz", "Expecting correct `client_secret`")
		XCTAssertEqual(query2["code"]!, "pp", "Expecting correct `code`")
		XCTAssertEqual(query2["grant_type"]!, "authorization_code", "Expecting correct `grant_type`")
		XCTAssertEqual(query2["redirect_uri"]!, "oauth2://callback", "Expecting correct `redirect_uri`")
		XCTAssertNil(query2["state"], "`state` must be empty")
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
		let settings = [
			"client_id": "abc",
			"client_secret": "xyz",
			"authorize_uri": "https://auth.ful.io",
			"keychain": false,
		]
		let oauth = OAuth2CodeGrant(settings: settings)
		var response = [
			"access_token": "2YotnFZFEjr1zCsicMWpAA",
			"expires_in": 3600,
			"refresh_token": "tGzv3JOkF0XG5Qx2TlKWIA",
			"foo": "bar & hat"
		]
		
		// must throw when "token_type" is missing
		do {
			let _ = try oauth.parseAccessTokenResponse(response)
			XCTAssertTrue(false, "Should not be here any more")
		}
		catch OAuth2Error.NoTokenType {
		}
		catch let error {
			XCTAssertNil(error, "Should not throw wrong error")
		}
		
		// LinkedIn on the other hand must not throw
		let linkedin = OAuth2CodeGrantLinkedIn(settings: settings)
		do {
			let _ = try linkedin.parseAccessTokenResponse(response)
		}
		catch let error {
			XCTAssertNil(error, "Should not throw")
		}
		
		// Nor the generic no-token-type class
		let noType = OAuth2CodeGrantNoTokenType(settings: settings)
		do {
			let _ = try noType.parseAccessTokenResponse(response)
		}
		catch let error {
			XCTAssertNil(error, "Should not throw")
		}
		
		// must throw when "token_type" is not known
		response["token_type"] = "guardian"
		do {
			let _ = try oauth.parseAccessTokenResponse(response)
			XCTAssertTrue(false, "Should not be here any more")
		}
		catch OAuth2Error.UnsupportedTokenType(_) {
		}
		catch let error {
			XCTAssertNil(error, "Should not throw wrong error")
		}
		
		// the no-token-type class must still ignore it
		do {
			let _ = try noType.parseAccessTokenResponse(response)
		}
		catch let error {
			XCTAssertNil(error, "Should not throw")
		}
		
		// add "token_type"
		response["token_type"] = "bearer"
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

