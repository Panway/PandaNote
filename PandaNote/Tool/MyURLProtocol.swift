import UIKit
import CoreData

var requestCount = 0
//https://www.raywenderlich.com/2292-using-nsurlprotocol-with-swift#toc-anchor-007
//https://stackoverflow.com/questions/36297813/custom-nsurlprotocol-with-nsurlsession
class MyURLProtocol: URLProtocol {
  
    var connection: NSURLConnection!
    var mutableData: NSMutableData!
    var response: URLResponse!
  
    override class func canInit(with request: URLRequest) -> Bool {
        //    debugPrint("Request #\(requestCount = requestCount + 1): URL = \(request.URL?.absoluteString)")
        
        if URLProtocol.property(forKey: "MyURLProtocolHandledKey", in: request as URLRequest) != nil {
            return false
        }
        
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return super.requestIsCacheEquivalent(a, to: b)
    }
    
    override func startLoading() {
        // 1
        let possibleCachedResponse = self.cachedResponse
        if let cachedResponse = possibleCachedResponse {
            debugPrint("Serving response from cache")
            
            // 2
            let data = cachedResponse.value(forKey: "data") as! NSData?
            let mimeType = cachedResponse.value(forKey:"mimeType") as! String?
            let encoding = cachedResponse.value(forKey:"encoding") as! String?
            
            // 3
            guard let requesturl = self.request.url else { return }
            
            let response = URLResponse(url: requesturl, mimeType: mimeType, expectedContentLength: data?.length ?? 0, textEncodingName: encoding)
            
            // 4
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data! as Data)
            self.client?.urlProtocolDidFinishLoading(self)
        } else {
            // 5
            debugPrint("Serving response from NSURLConnection")
            guard let newRequest = self.request as? NSMutableURLRequest else { return }
            
            URLProtocol.setProperty(true, forKey: "MyURLProtocolHandledKey", in: newRequest)
            self.connection = NSURLConnection(request: newRequest as URLRequest, delegate: self)
        }
    }
  
    override func stopLoading() {
        if self.connection != nil {
            self.connection.cancel()
        }
        self.connection = nil
    }
    
    func connection(connection: NSURLConnection!, didReceiveResponse response: URLResponse!) {
        self.client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        
        self.response = response
        self.mutableData = NSMutableData()
    }
    
    func connection(connection: NSURLConnection!, didReceiveData data: NSData!) {
        self.client!.urlProtocol(self, didLoad: data as Data)
        self.mutableData.append(data as Data)
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection!) {
        self.client!.urlProtocolDidFinishLoading(self)
        self.saveCachedResponse()
    }
    
    func connection(connection: NSURLConnection!, didFailWithError error: NSError!) {
        self.client!.urlProtocol(self, didFailWithError: error)
    }
    
    func saveCachedResponse () {
        debugPrint("Saving cached response")
        
        // 1
        let delegate = UIApplication.shared.delegate as! PPAppDelegate
        let context = delegate.managedObjectContext!
        
        // 2
        let cachedResponse = NSEntityDescription.insertNewObject(forEntityName: "CachedURLResponse", into: context) as NSManagedObject
        
        cachedResponse.setValue(self.mutableData, forKey: "data")
        cachedResponse.setValue(self.request.url?.absoluteString, forKey: "url")
        cachedResponse.setValue(NSDate(), forKey: "timestamp")
        cachedResponse.setValue(self.response.mimeType, forKey: "mimeType")
        cachedResponse.setValue(self.response.textEncodingName, forKey: "encoding")
        
        // 3
        //    var error: NSError?
        
        let success: ()? = try? context.save()
        if success == nil {
            debugPrint("Could not cache the response")
        }
    }
    
    func cachedResponseForCurrentRequest() -> NSManagedObject? {
        // 1
        let delegate = UIApplication.shared.delegate as! PPAppDelegate
        let context = delegate.managedObjectContext!
        
        // 2
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        let entity = NSEntityDescription.entity(forEntityName: "CachedURLResponse", in: context)
        fetchRequest.entity = entity
        
        // 3
        guard let aaaaa = self.request.url?.absoluteString else { return nil }
        let predicate = NSPredicate(format:"url == %@", aaaaa)
        fetchRequest.predicate = predicate
        
        // 4
        //    var error: NSError?
        let possibleResult = try? context.execute(fetchRequest) as? [NSManagedObject]//executeFetchRequest(fetchRequest, error: &error) as Array<NSManagedObject>?
        
        // 5
        if let result = possibleResult {
            if !result.isEmpty {
                return result[0]
            }
        }
        
        return nil
    }
}



class PPAppDelegate: AppDelegate {
    override func applicationWillTerminate(_ application: UIApplication) {
        super.applicationWillTerminate(application)
        self.saveContext()
    }
    // MARK: - Core Data stack
    
    lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.daylimotion.Test" in the application's documents Application Support directory.
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return (urls[urls.count-1] as NSURL) as URL
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "NSURLProtocolExample", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("NSURLProtocolExample.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        if let aaa = try?coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil) {
//        if coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil, error: &error) == nil {
            coordinator = nil
            // Report any error we got.
            let dict = NSMutableDictionary()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain:"YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict as? [String : Any])
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(String(describing: error)), \(error!.userInfo)")
            abort()
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext.init(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if self.managedObjectContext != nil {
//            var error: NSError? = nil
            /*
            if moc.hasChanges && !moc.save() {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog("Unresolved error \(String(describing: error)), \(error!.userInfo)")
                abort()
            }
 */
        }
    }

}
