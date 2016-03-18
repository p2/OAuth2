//
//  OAuth2AuthRequest_tests.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 18/03/16.
//  Copyright © 2016 Pascal Pfiffner. All rights reserved.
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


class OAuth2AuthRequest_Tests: XCTestCase {
	
	func testMethod() {
		let req1 = OAuth2AuthRequest(url: NSURL())
		XCTAssertTrue(req1.method == .POST)
		let req2 = OAuth2AuthRequest(url: NSURL(), method: .POST)
		XCTAssertTrue(req2.method == .POST)
		let req3 = OAuth2AuthRequest(url: NSURL(), method: .GET)
		XCTAssertTrue(req3.method == .GET)
	}
	
	func testContentType() {
		let req = OAuth2AuthRequest(url: NSURL())
		XCTAssertTrue(req.contentType == .WWWForm)
		XCTAssertEqual("application/x-www-form-urlencoded; charset=utf-8", req.contentType.rawValue)
		
		req.contentType = .JSON
		XCTAssertTrue(req.contentType == .JSON)
		XCTAssertEqual("application/json", req.contentType.rawValue)
	}
	
	func testParams() {
		let req = OAuth2AuthRequest(url: NSURL())
		XCTAssertTrue(0 == req.params.count)
		
		req.params["a"] = "A"
		XCTAssertTrue(1 == req.params.count)
		req.addParams(params: ["a": "AA", "b": "B"])
		XCTAssertTrue(2 == req.params.count)
		XCTAssertEqual("AA", req.params["a"])
		
		req.params["c"] = "A complicated/surprising name & character=fun"
		req.params.removeValueForKey("b")
		XCTAssertTrue(2 == req.params.count)
		let str = req.params.percentEncodedQueryString()
		XCTAssertEqual("a=AA&c=A+complicated%2Fsurprising+name+%26+character%3Dfun", str)
	}
	
	func testURLComponents() {
		let reqNoTLS = OAuth2AuthRequest(url: NSURL(string: "http://not.tls.com")!)
		do {
			try reqNoTLS.asURLComponents()
			XCTAssertTrue(false, "Must no longer be here, must throw because we're not using TLS")
		}
		catch OAuth2Error.NotUsingTLS {
		}
		catch let error {
			XCTAssertTrue(false, "Must throw “.NotUsingTLS” but threw \(error)")
		}
		
		let reqP = OAuth2AuthRequest(url: NSURL(string: "https://auth.io")!)
		reqP.params["a"] = "A"
		do {
			let comp = try reqP.asURLComponents()
			XCTAssertEqual("auth.io", comp.host)
			XCTAssertNil(comp.query, "Must not add params to URL for POST")
			XCTAssertNil(comp.percentEncodedQuery, "Must not add params to URL for POST")
		}
		catch let error {
			XCTAssertTrue(false, "Must not throw but threw \(error)")
		}
		
		let reqG = OAuth2AuthRequest(url: NSURL(string: "https://auth.io")!, method: .GET)
		reqG.params["a"] = "A"
		do {
			let comp = try reqG.asURLComponents()
			XCTAssertEqual("auth.io", comp.host)
			XCTAssertNotNil(comp.query, "Must add params to URL for GET")
			XCTAssertEqual("a=A", comp.query)
			XCTAssertNotNil(comp.percentEncodedQuery, "Must add params to URL for GET")
		}
		catch let error {
			XCTAssertTrue(false, "Must not throw but threw \(error)")
		}
	}
	
	func testRequests() {
		let settings = ["client_id": "id", "client_secret": "secret"]
		let oauth = OAuth2(settings: settings)
		let reqH = OAuth2AuthRequest(url: NSURL(string: "https://auth.io")!)
		do {
			let request = try reqH.asURLRequestFor(oauth)
			XCTAssertEqual("Basic aWQ6c2VjcmV0", request.valueForHTTPHeaderField("Authorization"))
			XCTAssertNil(request.HTTPBody)		// because no params are left
		}
		catch let error {
			XCTAssertTrue(false, "Must not throw but threw \(error)")
		}
		
		oauth.authConfig.secretInBody = true
		let reqB = OAuth2AuthRequest(url: NSURL(string: "https://auth.io")!)
		do {
			let request = try reqB.asURLRequestFor(oauth)
			XCTAssertEqual("client_id=id&client_secret=secret", NSString(data: request.HTTPBody!, encoding: NSUTF8StringEncoding))
			XCTAssertNil(request.valueForHTTPHeaderField("Authorization"))
		}
		catch let error {
			XCTAssertTrue(false, "Must not throw but threw \(error)")
		}
	}
}

