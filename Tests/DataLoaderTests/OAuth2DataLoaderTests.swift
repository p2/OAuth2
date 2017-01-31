//
//  OAuth2DataLoaderTests.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 9/12/16.
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

#if !NO_MODULE_IMPORT
 @testable
 import Base
 @testable
 import Flows
 @testable
 import DataLoader
#else
 @testable
 import OAuth2
#endif


class OAuth2DataLoaderTests: XCTestCase {
	
	var oauth2: OAuth2PasswordGrant?
	
	var loader: OAuth2DataLoader?
	
	var authPerformer: OAuth2MockPerformer?
	
	var dataPerformer: OAuth2AnyBearerPerformer?
	
	override func setUp() {
		super.setUp()
		authPerformer = OAuth2MockPerformer()
		authPerformer!.responseJSON = ["access_token": "toktok", "token_type": "bearer"]
		oauth2 = OAuth2PasswordGrant(settings: ["client_id": "abc", "authorize_url": "https://oauth.io/authorize", "keychain": false] as OAuth2JSON)
		oauth2!.logger = OAuth2DebugLogger(.debug)
//		oauth2!.logger = OAuth2DebugLogger(.trace)
		oauth2!.username = "p2"
		oauth2!.password = "test"
		oauth2!.requestPerformer = authPerformer
		
		dataPerformer = OAuth2AnyBearerPerformer()
		loader = OAuth2DataLoader(oauth2: oauth2!)
		loader!.requestPerformer = dataPerformer
	}
	
	func testAutoEnqueue() {
		XCTAssertNil(oauth2!.accessToken)
		let req1 = oauth2!.request(forURL: URL(string: "http://auth.io/data/user")!)
		let wait1 = expectation(description: "req1")
		loader!.perform(request: req1) { response in
			XCTAssertNotNil(self.oauth2!.accessToken)
			do {
				let json = try response.responseJSON()
				XCTAssertNotNil(json["data"])
			}
			catch let error {
				XCTAssertNil(error)
			}
			wait1.fulfill()
		}
		
		let req2 = oauth2!.request(forURL: URL(string: "http://auth.io/data/home")!)
		let wait2 = expectation(description: "req2")
		loader!.perform(request: req2) { response in
			XCTAssertNotNil(self.oauth2!.accessToken)
			do {
				let json = try response.responseJSON()
				XCTAssertNotNil(json["data"])
			}
			catch let error {
				XCTAssertNil(error)
			}
			wait2.fulfill()
		}
		waitForExpectations(timeout: 4.0) { error in
			XCTAssertNil(error)
		}
	}
}


class OAuth2AnyBearerPerformer: OAuth2RequestPerformer {
	
	func perform(request: URLRequest, completionHandler callback: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionTask? {
		let authorized = (nil != request.value(forHTTPHeaderField: "Authorization"))
		let status = authorized ? 201 : 401
		let http = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
		if authorized {
			let data = try? JSONSerialization.data(withJSONObject: ["data": ["in": "response"]], options: [])
			callback(data, http, nil)
		}
		else {
			callback(nil, http, nil)
		}
		return nil
	}
}

