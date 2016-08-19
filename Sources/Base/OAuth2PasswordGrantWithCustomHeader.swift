//
//  OAuth2PasswordGrantWithCustomHeader.swift
//  OAuth2
//
//  Created by Владислав on 19.08.16.
//  Copyright © 2016 Pascal Pfiffner. All rights reserved.
//

import Foundation

public class OAuth2PasswordGrantWithCustomHeader: OAuth2PasswordGrant {
    
    ///Stores header parameters
    public var headerParams: OAuth2StringDict
    
    public override init(settings: OAuth2JSON) {
        headerParams = settings["header_params"] as? OAuth2StringDict ?? ["":""]
        super.init(settings: settings)
    }
    
    override func obtainAccessToken(params params: OAuth2StringDict? = nil, callback: ((params: OAuth2JSON?, error: ErrorType?) -> Void)) {
        do {
            let post = try tokenRequest(params: params).asURLRequestFor(self)
            
            for (key, value) in headerParams {
                post.setValue(value, forHTTPHeaderField: key)
            }
            
            logger?.debug("OAuth2", msg: "Requesting new access token from \(post.URL?.description ?? "nil")")
            
            performRequest(post) { data, status, error in
                do {
                    guard let data = data else {
                        throw error ?? OAuth2Error.NoDataInResponse
                    }
                    
                    let dict = try self.parseAccessTokenResponseData(data)
                    if status < 400 {
                        self.logger?.debug("OAuth2", msg: "Did get access token [\(nil != self.clientConfig.accessToken)]")
                        callback(params: dict, error: nil)
                    }
                    else {
                        callback(params: dict, error: OAuth2Error.ResponseError("The username or password is incorrect"))
                    }
                }
                catch let error {
                    self.logger?.debug("OAuth2", msg: "Error parsing response: \(error)")
                    callback(params: nil, error: error)
                }
            }
        }
        catch let err {
            callback(params: nil, error: err)
        }
    }
}