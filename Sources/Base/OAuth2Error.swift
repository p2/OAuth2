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
	
	/// An error for which we don't have a specific one.
	case Generic(String)
	
	/// An error holding on to an NSError.
	case NSError(Foundation.NSError)
	
	/// Invalid URL components, failed to create a URL
	case InvalidURLComponents(NSURLComponents)
	
	
	// MARK: - Client errors
	
	/// There is no client id.
	case NoClientId
	
	/// There is no client secret.
	case NoClientSecret
	
	/// There is no redirect URL.
	case NoRedirectURL
	
	/// There is no username.
	case NoUsername
	
	/// There is no password.
	case NoPassword
	
	/// There is no authorization context.
	case NoAuthorizationContext
	
	/// The authorization context is invalid.
	case InvalidAuthorizationContext
	
	/// The redirect URL is invalid; with explanation.
	case InvalidRedirectURL(String)
	
	/// There is no refresh token.
	case NoRefreshToken
	
	/// There is no registration URL.
	case NoRegistrationURL
	
	
	// MARK: - Request errors
	
	/// The request is not using SSL/TLS.
	case NotUsingTLS
	
	/// Unable to open the authorize URL.
	case UnableToOpenAuthorizeURL
	
	/// The request is invalid.
	case InvalidRequest
	
	/// The request was cancelled.
	case RequestCancelled
	
	
	// MARK: - Response Errors
	
	/// There was no token type in the response.
	case NoTokenType
	
	/// The token type is not supported.
	case UnsupportedTokenType(String)
	
	/// There was no data in the response.
	case NoDataInResponse
	
	/// Some prerequisite failed; with explanation.
	case PrerequisiteFailed(String)
	
	/// The state parameter was invalid.
	case InvalidState
	
	/// The JSON response could not be parsed.
	case JSONParserError
	
	/// Unable to UTF-8 encode.
	case UTF8EncodeError
	
	/// Unable to decode to UTF-8.
	case UTF8DecodeError
	
	
	// MARK: - OAuth2 errors
	
	/// The client is unauthorized.
	case UnauthorizedClient
	
	/// Access was denied.
	case AccessDenied
	
	/// Response type is not supported.
	case UnsupportedResponseType
	
	/// Scope was invalid.
	case InvalidScope
	
	/// A 500 was thrown.
	case ServerError
	
	/// The service is temporarily unavailable.
	case TemporarilyUnavailable
	
	/// Other response error, as defined in its String.
	case ResponseError(String)
	
	
	/**
	Instantiate the error corresponding to the OAuth2 response code, if it is known.
	
	- parameter code: The code, like "access_denied", that should be interpreted
	- parameter fallback: The error string to use in case the error code is not known
	- returns: An appropriate OAuth2Error
	*/
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
	
	/// Human understandable error string.
	public var description: String {
		switch self {
		case .Generic(let message):
			return message
		case .NSError(let error):
			return error.localizedDescription
		case .InvalidURLComponents(let components):
			return "Failed to create URL from components: \(components)"
		
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
	case (.InvalidURLComponents(let lhe), .InvalidURLComponents(let rhe)):   return lhe.isEqual(rhe)
	
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

