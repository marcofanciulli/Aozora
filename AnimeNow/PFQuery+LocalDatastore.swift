//
//  PFQuery+LocalDatastore.swift
//  Aozora
//
//  Created by Paul Chavarria Podoliako on 7/12/15.
//  Copyright (c) 2015 AnyTap. All rights reserved.
//

import Foundation
import ANCommonKit
import Parse
import Bolts

extension PFQuery {
    public func findCachedOrNetwork(pinName: String, expirationDays: Double = 1) -> BFTask {
        
        let expired = NSUserDefaults.shouldPerformAction(pinName, expirationDays: Double(expirationDays))
        
        var fetchResult: [AnyObject] = []
        let nonLocalQuery = self.copy() as! PFQuery
        
        return fromPinWithName(pinName).findAllObjectsInBackground()
            .continueWithSuccessBlock { (task: BFTask!) -> AnyObject! in
            
                guard let result = task.result as? [AnyObject] else {
                    return nil
                }
                
                if result.count == 0 || expired {
                    // Not cached, fetch from network
                    return nonLocalQuery.findObjectsInBackground()
                } else {
                    fetchResult += task.result as! [AnyObject]
                    return nil
                }
                
            }.continueWithSuccessBlock { (task: BFTask!) -> AnyObject! in
                
                if let result = task.result as? [AnyObject] where result.count != 0 {
                    
                    NSUserDefaults.completedAction(pinName)
                    PFObject.unpinAllObjectsInBackgroundWithName(pinName).continueWithBlock({ (task: BFTask!) -> AnyObject! in
                        print("Objects from network, saved with tag \(pinName)")
                        return PFObject.pinAllInBackground(result, withName: pinName)
                    })
                    fetchResult += result
                }
                
                return BFTask(result: fetchResult)
        }
    }
}