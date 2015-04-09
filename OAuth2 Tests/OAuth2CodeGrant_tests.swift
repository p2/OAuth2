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
import OAuth2


class OAuth2CodeGrantTests: XCTestCase
{
	func testInit() {
		//var oauth = OAuth2(settings: NSDictionary())		// TODO: how to test that this raises?
		
		var oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
			"client_secret": "xyz",
			"verbose": 1,
			"authorize_uri": "https://auth.ful.io",
			"token_uri": "https://token.ful.io",
		])
		XCTAssertEqual(oauth.clientId, "abc", "Must init `client_id`")
		XCTAssertEqual(oauth.clientSecret!, "xyz", "Must init `client_secret`")
		XCTAssertTrue(oauth.verbose, "Set to verbose")
		XCTAssertNil(oauth.scope, "Empty scope")
		
		XCTAssertEqual(oauth.authURL!, NSURL(string: "https://auth.ful.io")!, "Must init `authorize_uri`")
		XCTAssertEqual(oauth.tokenURL!, NSURL(string: "https://token.ful.io")!, "Must init `token_uri`")
	}
	
	func testAuthorizeURI() {
		var oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
			"client_secret": "xyz",
			"authorize_uri": "https://auth.ful.io",
			"token_uri": "https://token.ful.io",
		])
		
		XCTAssertNotNil(oauth.authURL, "Must init `authorize_uri`")
		let comp = NSURLComponents(URL: oauth.authorizeURLWithRedirect("oauth2://callback", scope: nil, params: nil), resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp.host!, "auth.ful.io", "Correct host")
		let query = OAuth2CodeGrant.paramsFromQuery(comp.percentEncodedQuery!)
		XCTAssertEqual(query["client_id"]!, "abc", "Expecting correct `client_id`")
		XCTAssertNil(query["client_secret"], "Must not have `client_secret`")
		XCTAssertEqual(query["response_type"]!, "code", "Expecting correct `response_type`")
		XCTAssertEqual(query["redirect_uri"]!, "oauth2://callback", "Expecting correct `redirect_uri`")
		XCTAssertTrue(8 == count(query["state"]!), "Expecting an auto-generated UUID for `state`")
		
		// TODO: test for non-https URLs (must raise)
	}
	
	func testTokenURI() {
		var oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
			"client_secret": "xyz",
			"authorize_uri": "https://auth.ful.io",
			"token_uri": "https://token.ful.io",
		])
		
		XCTAssertNotNil(oauth.tokenURL, "Must init `token_uri`")
		let comp = NSURLComponents(URL: oauth.tokenURLWithRedirect("oauth2://callback", code: "pp", params: nil), resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp.host!, "token.ful.io", "Correct host")
		
		let query = OAuth2CodeGrant.paramsFromQuery(comp.percentEncodedQuery!)
		XCTAssertEqual(query["client_id"]!, "abc", "Expecting correct `client_id`")
		XCTAssertEqual(query["client_secret"]!, "xyz", "Expecting correct `client_secret`")
		XCTAssertEqual(query["code"]!, "pp", "Expecting correct `code`")
		XCTAssertEqual(query["grant_type"]!, "authorization_code", "Expecting correct `grant_type`")
		XCTAssertEqual(query["redirect_uri"]!, "oauth2://callback", "Expecting correct `redirect_uri`")		// using "comp.query" percent-decodes the query fragment
		XCTAssertTrue(8 == count(query["state"]!), "Expecting an auto-generated UUID for `state`")
		
		// test authURL fallback
		oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
			"client_secret": "xyz",
			"authorize_uri": "https://auth.ful.io",
		])
		let comp2 = NSURLComponents(URL: oauth.tokenURLWithRedirect("oauth2://callback", code: "pp", params: nil), resolvingAgainstBaseURL: true)!
		XCTAssertEqual(comp2.host!, "auth.ful.io", "Correct host")
		
		// TODO: test for non-https URLs (must raise)
	}
	
	func testTokenRequest() {
		var oauth = OAuth2CodeGrant(settings: [
			"client_id": "abc",
			"client_secret": "xyz",
			"authorize_uri": "https://auth.ful.io",
			"token_uri": "https://token.ful.io",
		])
		oauth.redirect = "oauth2://callback"
		
		let req = oauth.tokenRequest("pp")
		let body = NSString(data: req.HTTPBody!, encoding: NSUTF8StringEncoding)
		let query = OAuth2CodeGrant.paramsFromQuery(body! as String)
		XCTAssertEqual(query["client_id"]!, "abc", "Expecting correct `client_id`")
		XCTAssertEqual(query["client_secret"]!, "xyz", "Expecting correct `client_secret`")
		XCTAssertEqual(query["code"]!, "pp", "Expecting correct `code`")
		XCTAssertEqual(query["grant_type"]!, "authorization_code", "Expecting correct `grant_type`")
		XCTAssertEqual(query["redirect_uri"]!, "oauth2://callback", "Expecting correct `redirect_uri`")
		XCTAssertTrue(8 == count(query["state"]!), "Expecting an auto-generated UUID for `state`")
	}

    /*func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }*/
}
