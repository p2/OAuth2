//
//  OAuth2DeviceGrantTests.swift
//  OAuth2
//
//  Created by Dominik Paľo on 4/12/23.
//  Copyright © 2023 Cisco Systems, Inc. All rights reserved.
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


class OAuth2DeviceGrantTests: XCTestCase {
	
	lazy var baseSettings: OAuth2JSON = [
		"client_id": "abc",
		"authorize_uri": "https://auth.ful.io",
		"device_authorize_uri": "https://auth.ful.io/device/code",
		"token_uri": "https://token.ful.io",
		"keychain": false,
	]
	
	func testInit() {
		let oauth = OAuth2DeviceGrant(settings: baseSettings)
		XCTAssertEqual(oauth.clientId, "abc", "Must init `client_id`")
		XCTAssertFalse(oauth.useKeychain, "No keychain")
		XCTAssertNil(oauth.scope, "Empty scope")
		
		XCTAssertEqual(oauth.authURL, URL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
		XCTAssertEqual(oauth.deviceAuthorizeURL, URL(string: "https://auth.ful.io/device/code")!, "Must init `device_authorize_uri`")
		XCTAssertEqual(oauth.tokenURL!, URL(string: "https://token.ful.io")!, "Must init `token_uri`")
	}
	
	func testDeviceAccessTokenRequest() {
		let oauth = OAuth2DeviceGrant(settings: baseSettings)
		
		let req = try! oauth.deviceAccessTokenRequest(with: "pp").asURLRequest(for: oauth)
		let comp = URLComponents(url: req.url!, resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp.host!, "token.ful.io", "Correct host")
		
		let body = String(data: req.httpBody!, encoding: String.Encoding.utf8)
		let query = OAuth2DeviceGrant.params(fromQuery: body!)
		XCTAssertEqual(query["client_id"]!, "abc", "Expecting correct `client_id`")
		XCTAssertEqual(query["grant_type"]!, "urn:ietf:params:oauth:grant-type:device_code", "Expecting correct `grant_type`")
		XCTAssertEqual(query["device_code"]!, "pp", "Expecting correct `device_code`")
	}
	
	func testDeviceAuthorizationRequest() {
		let oauth = OAuth2DeviceGrant(settings: baseSettings)
		
		let req = try! oauth.deviceAuthorizationRequest().asURLRequest(for: oauth)
		let comp = URLComponents(url: req.url!, resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp.host!, "auth.ful.io", "Correct host")
		
		let body = String(data: req.httpBody!, encoding: String.Encoding.utf8)
		let query = OAuth2DeviceGrant.params(fromQuery: body!)
		XCTAssertEqual(query["client_id"]!, "abc", "Expecting correct `client_id`")
	}
	
	func testDeviceAuthorizationRequestWithAdditionalParams() {
		let oauth = OAuth2DeviceGrant(settings: baseSettings)
		let additionalParams = ["test_param": "test_value"]
		
		let req = try! oauth.deviceAuthorizationRequest(params: additionalParams).asURLRequest(for: oauth)
		let comp = URLComponents(url: req.url!, resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp.host!, "auth.ful.io", "Correct host")
		
		let body = String(data: req.httpBody!, encoding: String.Encoding.utf8)
		let query = OAuth2DeviceGrant.params(fromQuery: body!)
		XCTAssertEqual(query["test_param"]!, "test_value", "Expecting correct `test_param`")
	}
	
	func testDeviceAccessTokenResponse() {
		let oauth = OAuth2DeviceGrant(settings: baseSettings)
		var response = [
			"access_token": "2YotnFZFEjr1zCsicMWpAA",
			"expires_in": 3600,
			"refresh_token": "tGzv3JOkF0XG5Qx2TlKWIA",
			"foo": "bar & hat"
		] as [String: Any]
		
		// must throw when "token_type" is missing
		do {
			_ = try oauth.parseAccessTokenResponse(params: response)
			XCTAssertTrue(false, "Should not be here any more")
		}
		catch OAuth2Error.noTokenType {
		}
		catch let error {
			XCTAssertNil(error, "Should not throw wrong error")
		}
		
		// must throw when "token_type" is not known
		response["token_type"] = "guardian"
		do {
			_ = try oauth.parseAccessTokenResponse(params: response)
			XCTAssertTrue(false, "Should not be here any more")
		}
		catch OAuth2Error.unsupportedTokenType(_) {
		}
		catch let error {
			XCTAssertNil(error, "Should not throw wrong error")
		}
		
		// add "token_type"
		response["token_type"] = "bearer"
		do {
			let dict = try oauth.parseAccessTokenResponse(params: response)
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
		] as [String : Any]
		
		do {
			_ = try oauth.parseAccessTokenResponse(params: response2)
			XCTAssertTrue(false, "Should not be here any more")
		}
		catch OAuth2Error.unsupportedTokenType {
			XCTAssertTrue(true, "Throw correct error")
		}
		catch {
			XCTAssertTrue(false, "Should not throw wrong error")
		}
		
		let performer = OAuth2MockPerformer()
		oauth.requestPerformer = performer
		
		// authorization_pending response
		let responseAuthorizationPending = [
			"error": "authorization_pending",
			"error_description": "Anything..."
		]
		
		do {
			_ = try oauth.parseAccessTokenResponse(params: responseAuthorizationPending)
			XCTAssertTrue(false, "Should not be here any more")
		}
		catch OAuth2Error.authorizationPending {
			XCTAssertTrue(true, "Throw correct error")
		}
		catch {
			XCTAssertTrue(false, "Should not throw wrong error")
		}
		
		// slow_down response
		let responseSlowDown = [
			"error": "slow_down",
			"error_description": "Anything..."
		]
		
		do {
			_ = try oauth.parseAccessTokenResponse(params: responseSlowDown)
			XCTAssertTrue(false, "Should not be here any more")
		}
		catch OAuth2Error.slowDown {
			XCTAssertTrue(true, "Throw correct error")
		}
		catch {
			XCTAssertTrue(false, "Should not throw wrong error")
		}
	}
}
