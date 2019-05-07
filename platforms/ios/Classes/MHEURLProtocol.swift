import UIKit
import CoreData

var requestCount:Int = 0
var recording:Bool = true

let currentDomains = NSMutableSet()
var whiteList:Dictionary = [
  "main":   "webplatform.io",
  "assets": "assets.mheducation.com",
  "video":  "video.mehducation.com"
]

@objc class MHEURLProtocol: NSURLProtocol {
  
  var connection: NSURLConnection!
  var mutableData: NSMutableData!
  var response: NSURLResponse!
  
  private class func pushDomain(domain:String) {
    
    if !isWhiteListed(domain) {
      
      currentDomains.addObject(domain)
      
    }
    
  }
  
  private class func isWhiteListed(url:String) -> Bool {
    
    var value = false
    
    for domain in whiteList {
      
      if url == domain.1 {
        
        value = true
        break
        
      }
      
    }
    
    return value
    
  }
  
  override class func canInitWithRequest(request: NSURLRequest) -> Bool {
    
    println("Request #\(requestCount++): URL = \(request.URL.absoluteString)\n")
    
    if recording {
      
      pushDomain(request.URL.absoluteString!)
      
    }
    
    return true
    
  }
  
  override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
    return request
  }
  
  override class func requestIsCacheEquivalent(aRequest: NSURLRequest, toRequest bRequest: NSURLRequest) -> Bool {
    return super.requestIsCacheEquivalent(aRequest, toRequest:bRequest)
  }
  
  // MARK: public static methods
  class func switchRecording (status:Bool) {
    
    recording = status
    
  }
  
  class func pushWhiteListedDoamin(key:String, value:String) {
    
    if let current = whiteList[key] {
      
      whiteList.updateValue(value, forKey: key)
      
    }else{
      
      whiteList[key] = value
      
    }
    
  }
  
  class func domainList() -> [String] {
    
    return currentDomains.allObjects as [String]
    
  }
  
}
