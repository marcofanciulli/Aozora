//
//  LibrarySyncController.swift
//  Aozora
//
//  Created by Paul Chavarria Podoliako on 7/2/15.
//  Copyright (c) 2015 AnyTap. All rights reserved.
//

import Foundation
import ANCommonKit
import ANParseKit
import Parse
import Bolts
import Alamofire
import RealmSwift

class LibrarySyncController {
    
    static let lastSyncDateDefaultsKey = "LibrarySync.LastSyncDate"
    class var shouldSyncData: Bool {
        get {
            let lastSyncDate = NSUserDefaults.standardUserDefaults().objectForKey(lastSyncDateDefaultsKey) as! NSDate?
            if let lastSyncDate = lastSyncDate {
                
                let cal = NSCalendar.currentCalendar()
                let unit:NSCalendarUnit = .CalendarUnitDay
                let components = cal.components(unit, fromDate: lastSyncDate, toDate: NSDate(), options: nil)
                
                return components.day >= 1 ? true : false
                
            } else {
                return true
            }
        }
    }
    
    class func syncedData() {
        NSUserDefaults.standardUserDefaults().setObject(NSDate(), forKey: lastSyncDateDefaultsKey)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    class func fetchAnimeList() -> BFTask {
        
        if shouldSyncData {
            println("Fetching all anime library from network")
            return loadAnimeList().continueWithSuccessBlock({ (task: BFTask!) -> AnyObject! in
                
                let result = task.result["anime"] as! [[String: AnyObject]]
                let realm = Realm()
                var newAnimeProgress: [AnimeProgress] = []
                for data in result {
                    
                    var animeProgress = AnimeProgress()
                    animeProgress.animeID = data["id"] as! Int
                    animeProgress.status = data["watched_status"] as! String
                    animeProgress.episodes = data["watched_episodes"] as! Int
                    animeProgress.score = data["score"] as! Int
                    newAnimeProgress.append(animeProgress)
                }
                
                realm.write({ () -> Void in
                    realm.add(newAnimeProgress, update: true)
                })
                
                return self.fetchAllAnimeProgress()
            })
        } else {
            println("Only fetching from parse")
            return fetchAllAnimeProgress()
        }
    }
    
    
    class func loadAnimeList() -> BFTask! {
        let completionSource = BFTaskCompletionSource()
        if let username = PFUser.malUsername {
            Alamofire.request(Atarashii.Router.animeList(username: username)).validate().responseJSON {
                (req, res, JSON, error) -> Void in
                if error == nil {
                    completionSource.setResult(JSON)
                } else {
                    completionSource.setError(error)
                }
            }
        }
        return completionSource.task
    }
    
    
    class func fetchAllAnimeProgress() -> BFTask {
        let realm = Realm()
        let animeLibrary = realm.objects(AnimeProgress)
        
        var idList: [Int] = []
        var animeList: [Anime] = []
        for animeProgress in animeLibrary {
            idList.append(animeProgress.animeID)
        }
        
        // Fetch from disk then network
        return fetchAnimeFromLocalDatastore(idList)
        .continueWithSuccessBlock { (task: BFTask!) -> AnyObject! in
            
            if let result = task.result as? [Anime] where result.count > 0 {
                println("found \(result.count) objects from local datastore")
                animeList = result
            }
            
            return nil
        }.continueWithSuccessBlock { (task: BFTask!) -> AnyObject! in
            
            let missingIdList = idList.filter({ (myAnimeListID: Int) -> Bool in
                
                var filteredAnime = animeList.filter({ $0.myAnimeListID == myAnimeListID })
                return filteredAnime.count == 0
            })
            
            if missingIdList.count != 0 {
                return nil//self.fetchAnimeFromNetwork(missingIdList)
            } else {
                return nil
            }
            
        }.continueWithExecutor( BFExecutor.mainThreadExecutor(), withSuccessBlock: { (task: BFTask!) -> AnyObject! in
            
            if let result = task.result as? [Anime] where result.count > 0 {
                println("found \(result.count) objects from network")
                animeList += result
                
                PFObject.pinAllInBackground(result, withName: "InLibrary")
            }
            
            let realm = Realm()
            let animeLibrary = realm.objects(AnimeProgress)
            
            // Match all anime with it's progress..
            for anime in animeList {
                
                if anime.progress != nil {
                    continue
                }
                for progress in animeLibrary {
                    if progress.animeID == anime.myAnimeListID {
                        anime.progress = progress
                        break
                    }
                }
            }
            
            // Update last sync date
            self.syncedData()
            
            return BFTask(result: animeList)
        })
    }
    
    class func fetchAnimeFromNetwork(myAnimeListIDs: [Int]) -> BFTask {
        // Fetch from network for missing titles
        println("From network...")
        let networkQuery = Anime.query()!
        networkQuery.limit = 1000
        networkQuery.whereKey("myAnimeListID", containedIn: myAnimeListIDs)
        return networkQuery.findObjectsInBackground()
    }
    
    class func fetchAnimeFromLocalDatastore(myAnimeListIDs: [Int]) -> BFTask {
        println("From local datastore...")
        let query = Anime.query()!
        query.limit = 1000
        query.fromLocalDatastore()
        query.whereKey("myAnimeListID", containedIn: myAnimeListIDs)
        return query.findObjectsInBackground()
    }
}