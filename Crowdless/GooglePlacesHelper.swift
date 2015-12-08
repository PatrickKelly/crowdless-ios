//
//  GooglePlacesHelper.swift
//  Crowdless
//
//  Created by Patrick Kelly on 11/18/15.
//  Copyright © 2015 Crowdless, Inc. All rights reserved.
//

import CocoaLumberjack

class GooglePlacesHelper {
    
    private let apiKey = "AIzaSyB1jJfkYz4TCe44phcFEswoaTQsMwj95eQ";
    
    func getPlacesInBackgroundWithBlock(searchString: String, userGeoPoint: PFGeoPoint?, results: [Place] -> ()) {
        var params = [
            "input": searchString,
            "types": "establishment",
            "key": apiKey
        ]
        
        if let userGeoPoint = userGeoPoint {
            params["location"] = "\(userGeoPoint.latitude),\(userGeoPoint.longitude)"
        }
        params["radius"] = "4000"
        
        if (searchString == ""){
            return
        }
        
        GooglePlacesRequestHelpers.doRequest(
            "https://maps.googleapis.com/maps/api/place/autocomplete/json",
            params: params
            ) { json, error in
                if let json = json{
                    if let predictions = json["predictions"] as? Array<[String: AnyObject]> {
                        let placesPredictions = predictions.map { (prediction: [String: AnyObject]) -> Place in
                            return Place(prediction: prediction)
                        }
                        results(placesPredictions)
                    }
                }
        }
    }
}

class GooglePlaceDetailsRequest {
    let place: Place
    private let apiKey = "AIzaSyC_Ydzgdq62x0XXgy6vMp8p3aNs6PlOh0M";
    
    init(place: Place) {
        self.place = place
    }
    
    func request(result: PlaceDetails -> ()) {
        GooglePlacesRequestHelpers.doRequest(
            "https://maps.googleapis.com/maps/api/place/details/json",
            params: [
                "placeid": place.id,
                "key": apiKey
            ]
            ) { json, error in
                if let json = json as? [String: AnyObject] {
                    result(PlaceDetails(json: json))
                }
                if let error = error {
                    // TODO: We should probably pass back details of the error
                    DDLogError("Error fetching google place details: \(error)")
                }
        }
    }
}

class GooglePlacesRequestHelpers {
    /**
     Build a query string from a dictionary
     - parameter parameters: Dictionary of query string parameters
     - returns: The properly escaped query string
     */
    private class func query(parameters: [String: AnyObject]) -> String {
        var components: [(String, String)] = []
        for key in Array(parameters.keys).sort(<) {
            let value: AnyObject! = parameters[key]
            components += [(escape(key), escape("\(value)"))]
        }
        
        return (components.map{"\($0)=\($1)"} as [String]).joinWithSeparator("&")
    }
    
    private class func escape(string: String) -> String {
        let legalURLCharactersToBeEscaped: CFStringRef = ":/?&=;+!@#$()',*"
        return CFURLCreateStringByAddingPercentEscapes(nil, string, nil, legalURLCharactersToBeEscaped, CFStringBuiltInEncodings.UTF8.rawValue) as String
    }
    
    private class func doRequest(url: String, params: [String: String], completion: (NSDictionary?,NSError?) -> ()) {
        let request = NSMutableURLRequest(
            URL: NSURL(string: "\(url)?\(query(params))")!
        )
        
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            self.handleResponse(data, response: response as? NSHTTPURLResponse, error: error, completion: completion)
        }
        
        task.resume()
    }
    
    private class func handleResponse(data: NSData!, response: NSHTTPURLResponse!, error: NSError!, completion: (NSDictionary?, NSError?) -> ()) {
        
        // Always return on the main thread...
        let done: ((NSDictionary?, NSError?) -> Void) = {(json, error) in
            dispatch_async(dispatch_get_main_queue(), {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                completion(json,error)
            })
        }
        
        if let error = error {
            DDLogError("GooglePlaces Error: \(error.localizedDescription)")
            done(nil,error)
            return
        }
        
        if response == nil {
            DDLogError("GooglePlaces Error: No response from API")
            let error = NSError(domain: ErrorDomain, code: 1001, userInfo: [NSLocalizedDescriptionKey:"No response from API"])
            done(nil,error)
            return
        }
        
        if response.statusCode != 200 {
            DDLogError("GooglePlaces Error: Invalid status code \(response.statusCode) from API")
            let error = NSError(domain: ErrorDomain, code: response.statusCode, userInfo: [NSLocalizedDescriptionKey:"Invalid status code"])
            done(nil,error)
            return
        }
        
        let json: NSDictionary?
        do {
            json = try NSJSONSerialization.JSONObjectWithData(
                data,
                options: NSJSONReadingOptions.MutableContainers) as? NSDictionary
        } catch {
            DDLogError("Serialisation error")
            let serialisationError = NSError(domain: ErrorDomain, code: 1002, userInfo: [NSLocalizedDescriptionKey:"Serialization error"])
            done(nil,serialisationError)
            return
        }
        
        if let status = json?["status"] as? String {
            if status != "OK" {
                DDLogError("GooglePlaces API Error: \(status)")
                let error = NSError(domain: ErrorDomain, code: 1002, userInfo: [NSLocalizedDescriptionKey:status])
                done(nil,error)
                return
            }
        }
        
        done(json,nil)
        
    }
}

public class Place: NSObject {
    public let id: String
    public let desc: String
    public var detail: String?
    public var name: String?
    
    override public var description: String {
        get { return desc }
    }
    
    public init(id: String, description: String) {
        self.id = id
        self.desc = description
    }
    
    public convenience init(prediction: [String: AnyObject]) {
        self.init(
            id: prediction["place_id"] as! String,
            description: prediction["description"] as! String
        )
        
        if let placeTerms = (prediction["terms"] as? NSArray) as Array? {
            if placeTerms.count >= 4 {
                detail = (placeTerms[1]["value"] as! String) + ", " + (placeTerms[2]["value"] as! String) + ", " + (placeTerms[3]["value"] as! String)
            } else if placeTerms.count >= 3 {
                detail = (placeTerms[1]["value"] as! String) + ", " + (placeTerms[2]["value"] as! String)
            } else if (placeTerms.count == 2) {
                detail = placeTerms[1]["value"] as? String
            } else {
                detail = ""
            }
            
            name = placeTerms[0]["value"] as? String
        }
    }
    
    /**
     Call Google Place Details API to get detailed information for this place
     
     Requires that Place#apiKey be set
     
     - parameter result: Callback on successful completion with detailed place information
     */
    public func getDetails(result: PlaceDetails -> ()) {
        GooglePlaceDetailsRequest(place: self).request(result)
    }
}

public class PlaceDetails: CustomStringConvertible {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let raw: [String: AnyObject]
    
    public init(json: [String: AnyObject]) {
        let result = json["result"] as! [String: AnyObject]
        let geometry = result["geometry"] as! [String: AnyObject]
        let location = geometry["location"] as! [String: AnyObject]
        
        self.name = result["name"] as! String
        self.latitude = location["lat"] as! Double
        self.longitude = location["lng"] as! Double
        self.raw = json
    }
    
    public var description: String {
        return "PlaceDetails: \(name) (\(latitude), \(longitude))"
    }
}
