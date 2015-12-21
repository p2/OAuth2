//
//  OAuth2Error.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 16/11/15.
//  Copyright © 2015 Pascal Pfiffner. All rights reserved.
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

import Foundation


/**
All errors that might occur.

The response errors return a description as defined in the spec: http://tools.ietf.org/html/rfc6749#section-4.1.2.1
*/
public enum OAuth2Error: ErrorType, CustomStringConvertible, Equatable {
	case Generic(String)
	case NSError(Foundation.NSError)
	
	// Client errors
	case NoClientId
	case NoClientSecret
	case NoRedirectURL
	case NoUsername
	case NoPassword
	case NoAuthorizationContext
	case InvalidAuthorizationContext
	case InvalidRedirectURL(String)
	case NoRefreshToken
	
	case NoRegistrationURL
	
	// Request errors
	case NotUsingTLS
	case UnableToOpenAuthorizeURL
	case InvalidRequest
	case RequestCancelled
	case NoTokenType
	case UnsupportedTokenType(String)
	case NoDataInResponse
	case PrerequisiteFailed(String)
	case InvalidState
	case JSONParserError
	case UTF8EncodeError
	case UTF8DecodeError
	
	// OAuth2 errors
	case UnauthorizedClient
	case AccessDenied
	case UnsupportedResponseType
	case InvalidScope
	case ServerError
	case TemporarilyUnavailable
	case ResponseError(String)
	
	public static func fromResponseError(code: String, fallback: String? = nil) -> OAuth2Error {
		switch code {
		case "invalid_request":
			return .InvalidRequest
		case "unauthorized_client":
			return .UnauthorizedClient
		case "access_denied":
			return .AccessDenied
		case "unsupported_response_type":
			return .UnsupportedResponseType
		case "invalid_scope":
			return .InvalidScope
		case "server_error":
			return .ServerError
		case "temporarily_unavailable":
			return .TemporarilyUnavailable
		default:
			return .ResponseError(fallback ?? "Authorization error: \(code)")
		}
	}
	
	public var description: String {
		switch self {
		case .Generic(let message):
			return message
		case .NSError(let error):
			return error.localizedDescription
		
		case NoClientId:
			return "Client id not set"
		case NoClientSecret:
			return "Client secret not set"
		case NoRedirectURL:
			return "Redirect URL not set"
		case NoUsername:
			return "No username"
		case NoPassword:
			return "No password"
		case NoAuthorizationContext:
			return "No authorization context present"
		case InvalidAuthorizationContext:
			return "Invalid authorization context"
		case InvalidRedirectURL(let url):
			return "Invalid redirect URL: \(url)"
		case .NoRefreshToken:
			return "I don't have a refresh token, not trying to refresh"
		
		case .NoRegistrationURL:
			return "No registration URL defined"
		
		case .NotUsingTLS:
			return "You MUST use HTTPS/SSL/TLS"
		case .UnableToOpenAuthorizeURL:
			return "Cannot open authorize URL"
		case .InvalidRequest:
			return "The request is missing a required parameter, includes an invalid parameter value, includes a parameter more than once, or is otherwise malformed."
		case .RequestCancelled:
			return "The request has been cancelled"
		case NoTokenType:
			return "No token type received, will not use the token"
		case UnsupportedTokenType(let message):
			return message
		case NoDataInResponse:
			return "No data in the response"
		case PrerequisiteFailed(let message):
			return message
		case InvalidState:
			return "The state was either empty or did not check out"
		case JSONParserError:
			return "Error parsing JSON"
		case UTF8EncodeError:
			return "Failed to UTF-8 encode the given string"
		case UTF8DecodeError:
			return "Failed to decode given data as a UTF-8 string"
		
		case .UnauthorizedClient:
			return "The client is not authorized to request an access token using this method."
		case .AccessDenied:
			return "The resource owner or authorization server denied the request."
		case .UnsupportedResponseType:
			return "The authorization server does not support obtaining an access token using this method."
		case .InvalidScope:
			return "The requested scope is invalid, unknown, or malformed."
		case .ServerError:
			return "The authorization server encountered an unexpected condition that prevented it from fulfilling the request."
		case .TemporarilyUnavailable:
			return "The authorization server is currently unable to handle the request due to a temporary overloading or maintenance of the server."
		case .ResponseError(let message):
			return message
		}
	}
}


public func ==(lhs: OAuth2Error, rhs: OAuth2Error) -> Bool {
	switch (lhs, rhs) {
	case (.Generic(let lhm), .Generic(let rhm)):    return lhm == rhm
	case (.NSError(let lhe), .NSError(let rhe)):    return lhe.isEqual(rhe)
	
	case (.NoClientId, .NoClientId):                             return true
	case (.NoClientSecret, .NoClientSecret):                     return true
	case (.NoRedirectURL, .NoRedirectURL):                       return true
	case (.NoUsername, .NoUsername):                             return true
	case (.NoPassword, .NoPassword):                             return true
	case (.NoAuthorizationContext, .NoAuthorizationContext):                 return true
	case (.InvalidAuthorizationContext, .InvalidAuthorizationContext):       return true
	case (.InvalidRedirectURL(let lhu), .InvalidRedirectURL(let rhu)):       return lhu == rhu
	case (.NoRefreshToken, .NoRefreshToken):			         return true
	
	case (.NotUsingTLS, .NotUsingTLS):                           return true
	case (.UnableToOpenAuthorizeURL, .UnableToOpenAuthorizeURL): return true
	case (.InvalidRequest, .InvalidRequest):                     return true
	case (.RequestCancelled, .RequestCancelled):                 return true
	case (.NoTokenType, .NoTokenType):                           return true
	case (.UnsupportedTokenType(let lhm), .UnsupportedTokenType(let rhm)):   return lhm == rhm
	case (.NoDataInResponse, .NoDataInResponse):                 return true
	case (.PrerequisiteFailed(let lhm), .PrerequisiteFailed(let rhm)):       return lhm == rhm
	case (.InvalidState, .InvalidState):                         return true
	case (.JSONParserError, .JSONParserError):                   return true
	case (.UTF8EncodeError, .UTF8EncodeError):                   return true
	case (.UTF8DecodeError, .UTF8DecodeError):                   return true
	
	case (.UnauthorizedClient, .UnauthorizedClient):             return true
	case (.AccessDenied, .AccessDenied):                         return true
	case (.UnsupportedResponseType, .UnsupportedResponseType):   return true
	case (.InvalidScope, .InvalidScope):                         return true
	case (.ServerError, .ServerError):                           return true
	case (.TemporarilyUnavailable, .TemporarilyUnavailable):     return true
	case (.ResponseError(let lhm), .ResponseError(let rhm)):     return lhm == rhm
	default:                                                     return false
	}
}

