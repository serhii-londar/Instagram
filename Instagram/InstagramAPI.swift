//
//  InstagramAPI.swift
//  Photo Tiles
//
//  Created by Scott Gauthreaux on 10/01/16.
//  Copyright © 2016 Scott Gauthreaux. All rights reserved.
//

import Foundation

public enum HTTPMethod : String {
    case Get = "GET"
    case Post = "POST"
    case Put = "PUT"
    case Delete = "DELETE"
}




public class InstagramAPI {
    let baseAPIURL = "https://api.instagram.com/v1"
    var clientId : String?
    var clientSecret : String?
    public var accessToken : String?
    
    // TODO: add login and auth functions
    // TODO: do we need to move some of the relative API methods to objects? For example getUserRecentMedia, what about a user.getRecentMedia() function?
    // TODO: add caching
    
    // MARK: - Convenience methods
    
    /// Initializes the API instance
    public init(clientId: String, clientSecret: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    
    /// Performs a given API request and retrieves data from the Instagram REST API
    /// This method shouldn't be accessed outside of the scope of this library as it is a low level method
    func performAPIRequest( urlString: String, withParameters parameters: [String:AnyObject]? = nil, usingMethod method: HTTPMethod = .Get, completion: @escaping (AnyObject?) -> Void) {
        var urlString = urlString
        guard let accessTokenString = accessToken else {
            print("Attempted to call \"performAPIRequest\" before authentication")
            completion(nil)
            return
        }
        
        urlString += "?access_token=" + accessTokenString
        
        if parameters != nil {
            for (parameterKey, parameterValue) in parameters! {
                urlString += "&\(parameterKey)=\(parameterValue)"
            }
        }
        
        guard let url = NSURL(string: baseAPIURL + urlString) else {
            print("Invalid url string supplied\"\(urlString)\" when calling performAPIRequest")
            completion(nil)
            return
        }
        

        
        print(url)
        
        let request = NSMutableURLRequest(url: url as URL)
        request.httpMethod = method.rawValue
    
        let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            guard error == nil && data != nil else {                                                          // check for fundamental networking error
                print("error=\(String(describing: error))")
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(String(describing: response))")
                if data != nil {
                    print("data = \(String(data: data!, encoding: String.Encoding.utf8)!)")
                }
            }
            
            do {
                let responseObject = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String:AnyObject]
                
                if responseObject!["meta"]!["code"] as! Int == 200 {
                    completion(responseObject!["data"]!)
                }

            } catch {
                print("An error occurred while trying to convert the json data to an object")
            }
        }
        task.resume()
        
        return
    }
    
    /// This is a convenience method used to convert an arbitrary response into an array of *InstagramModel* objects
    func objectsArray<T: InstagramModel>(withType: T.Type, fromData data: AnyObject?) -> [T]? {
        guard let datas = data as? [AnyObject] else {
            return nil
        }
        
        var newObjects = [T]()
        
        for objectData in datas {
            if let newObject = T(data: objectData) {
                newObjects.append(newObject)
            }
        }
        
        return newObjects
    }
    
    
    // MARK: - User Endpoint
    
    
   
    /// Get information about the current user
    public func getUser(completion: @escaping (InstagramUser?) -> Void) {
        _getUser(userId: nil, completion: completion)
    }
    
    /// Get information about a user with the given id
    public func getUser(userId: String, completion: @escaping (InstagramUser?) -> Void) {
        _getUser(userId: userId, completion: completion)
    }
    
    /// The method that actually gets information about users from the Instagram API
    func _getUser(userId: String?, completion: @escaping (InstagramUser?) -> Void) {
        let userIdParameter = userId != nil ? "\(userId!)" : "self"
        performAPIRequest(urlString: "/users/"+userIdParameter) { responseData in
            guard let responseData = responseData, let instagramUser = InstagramUser(data: responseData) else {
                completion(nil)
                return
            }
            
            completion(instagramUser)
        }
    }
    
    /// Gets the current user's recent media
    public func getUserRecentMedia(count: Int? = nil, minId: String? = nil, maxId: String? = nil, completion: @escaping ([InstagramMedia]?) -> Void) {
        _getUserRecentMedia(userId: nil, count: count, minId: minId, maxId: maxId, completion: completion)
    }
    
    
    /// Gets the specified user's recent media
    public func getUserRecentMedia(userId: String, count: Int? = nil, minId: String? = nil, maxId: String? = nil, completion: @escaping ([InstagramMedia]?) -> Void) {
        _getUserRecentMedia(userId: userId, count: count, minId: minId, maxId: maxId, completion: completion)
    }

    /// The method that actually gets a user's recent media
    func _getUserRecentMedia(userId: String?, count: Int? = nil, minId: String? = nil, maxId: String? = nil, completion: @escaping ([InstagramMedia]?) -> Void) {
        let userIdParameter = userId != nil ? "\(userId!)" : "self"
        var parameters = [String:AnyObject]()
        if count != nil {
            parameters["count"] = count! as AnyObject
        }
        
        if minId != nil {
            parameters["min_id"] = minId! as AnyObject
        }
        
        if maxId != nil {
            parameters["max_id"] = maxId! as AnyObject
        }
        
        performAPIRequest(urlString: "/users/\(userIdParameter)/media/recent", withParameters: parameters) {[weak self] in completion(self?.objectsArray(withType: InstagramMedia.self, fromData: $0))}
    }
    
    /// Gets the current user's recently liked media
    public func getUserLikedMedia(count: Int? = nil, maxLikeId: String? = nil, completion: @escaping ([InstagramMedia]?) -> Void) {
        var parameters = [String:AnyObject]()
        
        if count != nil {
            parameters["count"] = count! as AnyObject
        }
        
        if maxLikeId != nil {
            parameters["max_like_id"] = maxLikeId! as AnyObject
        }
        
        performAPIRequest(urlString: "/users/self/media/liked", withParameters: parameters) {[weak self] in completion(self?.objectsArray(withType: InstagramMedia.self, fromData: $0))}
    }
    
    /// Searches users with usernames containing the given keyword
    public func searchForUsers(query: String, count: Int? = nil, completion: @escaping ([InstagramUser]?) -> Void) {
        var parameters = [String:AnyObject]()
        
        parameters["q"] = query as AnyObject
        
        if count != nil {
            parameters["count"] = count! as AnyObject
        }
        
        
        performAPIRequest(urlString: "/users/search", withParameters: parameters) {[weak self] in completion(self?.objectsArray(withType: InstagramUser.self, fromData: $0))}
        
    }
    
    /// Searches for one user with a given username
    /// Will only return a user if the username matches exactly the provided username
    public func searchForUser(userName: String, completion: @escaping (InstagramUser?) -> ()) {
        searchForUsers(query: userName) { users in
            guard let users = users else {
                completion(nil)
                return
            }
            for user in users {
                if user.username == userName {
                    completion(user)
                    return
                }
            }
            completion(nil)
        }
    }
    
    
    // MARK: - Relationships Endpoint
    
    /// Gets the users followed by the current user
    public func getUserFollows(completion: @escaping ([InstagramUser]?) -> Void) {
        performAPIRequest(urlString: "/users/self/follows") {[weak self] in completion(self?.objectsArray(withType: InstagramUser.self, fromData: $0))}
    }
    
    /// Gets the followers of the current user
    public func getUserFollowedBy(completion: @escaping ([InstagramUser]?) -> Void) {
        performAPIRequest(urlString: "/users/self/followed-by") {[weak self] in completion(self?.objectsArray(withType: InstagramUser.self, fromData: $0))}
    }
    
    /// Gets the follow requests for the current user
    /// Note: This will be empty if the current user has a public profile because requests instantly become followers
    public func getUserRequestedBy(completion: @escaping ([InstagramUser]?) -> Void) {
        performAPIRequest(urlString: "/users/self/requested-by") {[weak self] in completion(self?.objectsArray(withType: InstagramUser.self, fromData: $0))}
    }
    
    /// Gets information about the current user's relationship to the specified user
    public func getUserRelationship(to userId:String, completion:@escaping (InstagramRelationship?) -> Void) {
        performAPIRequest(urlString: "/users/\(userId)/relationship") { responseData in
            guard let responseData = responseData, let relationship = InstagramRelationship(data: responseData) else {
                completion(nil)
                return
            }
            
            completion(relationship)
        }
    
    }
    
    /// Updates the current user's relationship to the specified user
    public func setUserRelationship(to userId:String, relation: String, completion:@escaping (InstagramRelationship?) -> Void) {
        performAPIRequest(urlString: "/users/\(userId)/relationship", withParameters: ["action":relation as AnyObject], usingMethod: .Post) { responseData in
            guard let responseData = responseData, let relationship = InstagramRelationship(data: responseData) else {
                completion(nil)
                return
            }
            
            completion(relationship)
        }
    }
    
    // MARK: Relationships Objects Endpoint
    
    /// The same as getUserRelationship(to:completion:) but an instance of InstagrammUser can be passed as the first argument
    public func getUserRelationship(to user:InstagramUser, completion:@escaping (InstagramRelationship?) -> Void) {
        getUserRelationship(to: user.id, completion: completion)
    }
    
    /// The same as setUserRelationship(to:relation:completion:) but instances of InstagramUser and InstagramRelationship can be passed instead of strings
    public func setUserRelationship(to user:InstagramUser, relation: InstagramRelationship, completion:@escaping (InstagramRelationship?) -> Void) {
        setUserRelationship(to: user.id, relation: relation.outgoingStatus, completion: completion)
    }
    
    
    // MARK: - Media Endpoint
    
    /// Gets the media with the specified ID
    public func getMedia(id: String, completion: @escaping (InstagramMedia?) -> Void) {
        performAPIRequest(urlString: "/media/"+id) { responseData in
            guard let responseData = responseData, let media = InstagramMedia(data: responseData) else {
                completion(nil)
                return
            }
            completion(media)
        }
    }
    
    /// Gets the media with the specified shortcode
    public func getMedia(shortcode: String, completion: @escaping (InstagramMedia?) -> Void) {
        performAPIRequest(urlString: "/media/shortcode/\(shortcode)") { responseData in
            guard let responseData = responseData, let media = InstagramMedia(data: responseData) else {
                completion(nil)
                return
            }
            completion(media)
        }
    }
    
    /// Searches for media in a specific location 
    /// The default distance is 1000 (1 km) and the max is 5 km
    public func searchMedia(lat: Double, lng: Double, distance: Int? = nil, completion: @escaping ([InstagramMedia]?) -> Void) {
        var parameters = [String:AnyObject]()
        parameters["lat"] = lat as AnyObject
        parameters["lng"] = lng as AnyObject
        if distance != nil {
            parameters["distance"] = distance! as AnyObject
        }
        
        performAPIRequest(urlString: "/media/search", withParameters: parameters, usingMethod: .Get) {[weak self] in completion(self?.objectsArray(withType: InstagramMedia.self, fromData: $0))}
    }
    
    
    // MARK: - Comments Endpoint
    
    /// Gets the comments on a specified media
    public func getMediaComments(mediaId id: String, completion: @escaping ([InstagramComment]?) -> Void) {
        performAPIRequest(urlString: "/media/\(id)/comments") {[weak self] in completion(self?.objectsArray(withType: InstagramComment.self, fromData: $0))}
    }
    
    /// Adds a comment to the specified media
    public func addMediaComment(mediaId id: String, comment: String, completion: @escaping (Bool) -> Void) {
        performAPIRequest(urlString: "/media/\(id)/comments", withParameters: ["text":comment as AnyObject], usingMethod: .Post) { responseData in
            completion(responseData != nil)
        }
    }
    
    /// Removes the user's specified comment from the media
    public func removeMediaComment(mediaId id: String, commentId: String, completion: @escaping (Bool) -> Void) {
        performAPIRequest(urlString: "/media/\(id)/comments/\(commentId)", usingMethod: .Delete) { responseData in
            completion(responseData != nil)
        }
    }
    
    // MARK: Comments Objects Endpoint
    
    /// The same as getMediaComments(mediaId:completion:) but can pass an instance of InstagramMedia instead of its id
    public func getMediaComments(media: InstagramMedia, completion: @escaping ([InstagramComment]?) -> Void) {
        getMediaComments(mediaId: media.id, completion: completion)
    }
    
    /// The same as addMediaComment(mediaId:comment:completion:) but can pass instances of InstagramMedia and InstagramComment instead of strings
    public func addMediaComment(media: InstagramMedia, comment: InstagramComment, completion: @escaping (Bool) -> Void) {
        addMediaComment(mediaId: media.id, comment: comment.text, completion: completion)
    }
    
    /// The same as removeMediaComment(mediaId:commentId:completion:) but can pass instances of InstagramMedia and InstagramComment instead of strings
    public func removeMediaComment(media: InstagramMedia, comment: InstagramComment, completion: @escaping (Bool) -> Void) {
        removeMediaComment(mediaId: media.id, commentId: comment.id, completion: completion)
    }
    
    
    // MARK: - Likes Endpoint
    
    /// Gets all the likes on the specified media
    public func getMediaLikes(mediaId id: String, completion: @escaping ([InstagramLike]?) -> Void) {
        performAPIRequest(urlString: "/media/\(id)/likes") {[weak self] in completion(self?.objectsArray(withType: InstagramLike.self, fromData: $0))}
    }
    
    /// Sets a like for the current user on the specified media
    public func setMediaLike(mediaId id: String, completion: @escaping (Bool) -> Void) {
        performAPIRequest(urlString: "/media/\(id)/comments", usingMethod: .Post) { responseData in
            completion(responseData != nil)
        }
    }
    
    /// Removes the current user's like on the specified media
    public func removeMediaLike(mediaId id: String, completion: @escaping (Bool) -> Void) {
        performAPIRequest(urlString: "/media/\(id)/comments", usingMethod: .Delete) { responseData in
            completion(responseData != nil)
        }
    }
    
    
    // MARK: - Tags Endpoint
    
    /// Gets information about a certain tag
    public func getTag(name: String, completion: @escaping (InstagramTag?) -> Void) {
        performAPIRequest(urlString: "/tags/\(name)") { responseData in
            guard let responseData = responseData, let tag = InstagramTag(data: responseData) else {
                completion(nil)
                return
            }
            
            completion(tag)
        }
    }
    
    
    /// Gets recent media with the specified tag
    public func getTagRecentMedia(name: String, count: Int? = nil, minTagId: String? = nil, maxTagId: String? = nil, completion: @escaping ([InstagramMedia]?) -> Void) {
        var parameters = [String:AnyObject]()
        if count != nil {
            parameters["count"] = count! as AnyObject
        }
        
        if minTagId != nil {
            parameters["min_tag_id"] = minTagId! as AnyObject
        }
        
        if maxTagId != nil {
            parameters["max_tag_id"] = maxTagId! as AnyObject
        }

        performAPIRequest(urlString: "/tags/\(name)/media/recent", withParameters: parameters) {[weak self] in completion(self?.objectsArray(withType: InstagramMedia.self, fromData: $0))}
    }
    
    /// Searches for tags containing the specified string
    public func searchTags(query: String, completion: @escaping ([InstagramTag]?) -> Void) {
        performAPIRequest(urlString: "/tags/search", withParameters: ["q":query as AnyObject]) {[weak self] in completion(self?.objectsArray(withType: InstagramTag.self, fromData: $0))}
    }
    
    // MARK: Tags Objects Endpoint
    
    /// The same as getTagRecentMedia(name:count:minTagId:maxTagId:completion:) but can pass an instance of InstagramTag instead of the name of the tag
    public func getTagRecentMedia(tag: InstagramTag, count: Int? = nil, minTagId: String? = nil, maxTagId: String? = nil, completion: ([InstagramMedia]?) -> Void) {
        getTagRecentMedia(tag: tag, count: count, minTagId: minTagId, maxTagId: maxTagId, completion: completion)
    }

    
    // MARK: - Locations Endpoint
    
    /// Gets the location with the specified id
    public func getLocation(locationId: String, completion: @escaping (InstagramLocation?) -> Void) {
        performAPIRequest(urlString: "/locations/\(locationId)") { responseData in
            guard let responseData = responseData, let location = InstagramLocation(data: responseData) else {
                completion(nil)
                return
            }
            
            completion(location)
        }
    }
    
    /// Gets the recent media for the specified location
    public func getLocationRecentMedia(locationId: String, minId: String? = nil, maxId: String? = nil, completion: @escaping ([InstagramMedia]?) -> Void) {
        var parameters = [String:AnyObject]()
        if minId != nil {
            parameters["min_id"] = minId! as AnyObject
        }
        
        if maxId != nil {
            parameters["max_id"] = maxId! as AnyObject
        }
        
        performAPIRequest(urlString: "/locations/\(locationId)/media/recent", withParameters: parameters) {[weak self] in completion(self?.objectsArray(withType: InstagramMedia.self, fromData: $0))}

    }
    
    /// Searches locations by coordinates
    /// The default distance is 1000 (1km) and the max distance is 5km
    public func searchLocationsByCoordinates(lat: Double, lng: Double, distance: Int? = nil, completion: @escaping ([InstagramLocation]?) -> Void) {
        var parameters = [String:AnyObject]()
        parameters["lat"] = lat as AnyObject
        parameters["lng"] = lng as AnyObject
        
        if distance != nil {
            parameters["distance"] = distance as AnyObject
        }
        
        performAPIRequest(urlString: "/locations/search", withParameters: parameters) {[weak self] in completion(self?.objectsArray(withType: InstagramLocation.self, fromData: $0))}
    }
    
    /// Searches locations by Facebook Places ID
    public func searchLocationsByFacebookPlacesId(id: String, completion: @escaping ([InstagramLocation]?) -> Void) {
        performAPIRequest(urlString: "/locations/search", withParameters: ["facebook_places_id":id as AnyObject]) {[weak self] in completion(self?.objectsArray(withType: InstagramLocation.self, fromData: $0))}
    }
    
    /// Searches locations by Foursquare ID
    public func searchLocationsByFoursquareId(id: String, completion: @escaping ([InstagramLocation]?) -> Void) {
        performAPIRequest(urlString: "/locations/search", withParameters: ["foursquare_id":id as AnyObject]) {[weak self] in completion(self?.objectsArray(withType: InstagramLocation.self, fromData: $0))}
    }
    
    /// Searches locations by Foursquare V2 ID
    public func searchLocationsByFoursquareV2Id(id: String, completion: @escaping ([InstagramLocation]?) -> Void) {
        performAPIRequest(urlString: "/locations/search", withParameters: ["foursquare_v2_id":id as AnyObject]) {[weak self] in completion(self?.objectsArray(withType: InstagramLocation.self, fromData: $0))}
    }

}


