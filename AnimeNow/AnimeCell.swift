//
//  AnimeCell.swift
//  AnimeNow
//
//  Created by Paul Chavarria Podoliako on 6/4/15.
//  Copyright (c) 2015 AnyTap. All rights reserved.
//

import UIKit
import ANCommonKit
import ANParseKit

class AnimeCell: UICollectionViewCell {
    
    static let id = "AnimeCell"
    @IBOutlet weak var posterImageView: UIImageView?
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var etaLabel: UILabel?
    @IBOutlet weak var informationLabel: UILabel?
    @IBOutlet weak var ratingLabel: UILabel?
    @IBOutlet weak var genresLabel: UILabel?
    @IBOutlet weak var inLibraryView: UIView?
    
    // Poster only
    @IBOutlet weak var nextEpisodeNumberLabel: UILabel?
    @IBOutlet weak var etaTimeLabel: UILabel?
    @IBOutlet weak var posterEpisodeTitleLabel: UILabel?
    @IBOutlet weak var posterDimView: UIView?
    
    var numberFormatter: NSNumberFormatter {
        struct Static {
            static let instance : NSNumberFormatter = {
                let formatter = NSNumberFormatter()
                formatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
                formatter.maximumFractionDigits = 0
                return formatter
                }()
        }
        return Static.instance
    }
    
    class func registerNibFor(collectionView collectionView: UICollectionView) {
        let chartNib = UINib(nibName: AnimeCell.id, bundle: nil)
        collectionView.registerNib(chartNib, forCellWithReuseIdentifier: AnimeCell.id)
    }
    
    func configureWithAnime(
        anime: Anime,
        canFadeImages: Bool = true,
        showEtaAsAired: Bool = false,
        showLibraryEta: Bool = false,
        publicAnime: Bool = false) {

        posterImageView?.setImageFrom(urlString: anime.imageUrl, animated: canFadeImages)
        titleLabel?.text = anime.title
        genresLabel?.text = anime.genres.joinWithSeparator(", ")
        
        updateInformationLabel(anime, informationLabel: informationLabel)
        
        ratingLabel?.text = FontAwesome.Ranking.rawValue + String(format: " %.2f    ", anime.membersScore) + FontAwesome.Members.rawValue + " " + numberFormatter.stringFromNumber(anime.membersCount)!
    
        if let nextEpisode = anime.nextEpisode {
            
            if showEtaAsAired {
                etaLabel?.textColor = .pumpkin()
                etaTimeLabel?.textColor = .pumpkin()
                if showLibraryEta {
                    etaLabel?.text = " Ep\(nextEpisode-1) Aired "
                } else {
                    etaLabel?.text = "Ep \(nextEpisode-1) - Aired"
                }
                
                etaTimeLabel?.text = "Ep\(nextEpisode-1) Aired"
            } else {
                
                let (days, hours, minutes) = etaForDate(anime.nextEpisodeDate!)
                let etaTime: String
                if days != 0 {
                    etaTime = "\(days)d \(hours)h \(minutes)m"
                    if showLibraryEta {
                        etaLabel?.textColor = .whiteColor()
                        etaLabel?.backgroundColor = .belizeHole()
                    } else {
                        etaLabel?.textColor = .belizeHole()
                        etaLabel?.backgroundColor = .clearColor()
                    }
                    etaTimeLabel?.textColor = .belizeHole()
                } else if hours != 0 {
                    etaTime = "\(hours)h \(minutes)m"
                    if showLibraryEta {
                        etaLabel?.textColor = .whiteColor()
                        etaLabel?.backgroundColor = .nephritis()
                    } else {
                        etaLabel?.textColor = .nephritis()
                        etaLabel?.backgroundColor = .clearColor()
                    }
                    etaTimeLabel?.textColor = .nephritis()
                    
                } else {
                    etaTime = "\(minutes)m"
                    if showLibraryEta {
                        etaLabel?.textColor = .whiteColor()
                        etaLabel?.backgroundColor = .belizeHole()
                    } else {
                        etaLabel?.textColor = .belizeHole()
                        etaLabel?.backgroundColor = .clearColor()
                    }
                    etaTimeLabel?.textColor = .pumpkin()
                }
                
                if showLibraryEta {
                    etaLabel?.text = " Ep \(nextEpisode) - " + etaTime + " "
                } else {
                    etaLabel?.text = "Ep \(nextEpisode) - " + etaTime
                }
                
                
                etaTimeLabel?.text = etaTime
            }
            
            nextEpisodeNumberLabel?.text = nextEpisode.description
            posterEpisodeTitleLabel?.text = "Episode"
            posterDimView?.hidden = false
            
        } else {
            etaLabel?.text = ""
            nextEpisodeNumberLabel?.text = ""
            posterEpisodeTitleLabel?.text = ""
            posterDimView?.hidden = true
            
            if let status = AnimeStatus(rawValue: anime.status) where status == AnimeStatus.FinishedAiring {
                etaTimeLabel?.textColor = UIColor.belizeHole()
                etaTimeLabel?.text = "Aired"
            } else {
                etaTimeLabel?.textColor = UIColor.planning()
                etaTimeLabel?.text = "Not aired"
            }
        }
        
        if let progress = publicAnime ? anime.publicProgress : anime.progress {
            
            inLibraryView?.hidden = false
            switch progress.myAnimeListList() {
            case .Planning:
                inLibraryView?.backgroundColor = UIColor.planning()
            case .Watching:
                inLibraryView?.backgroundColor = UIColor.watching()
            case .Completed:
                inLibraryView?.backgroundColor = UIColor.completed()
            case .OnHold:
                inLibraryView?.backgroundColor = UIColor.onHold()
            case .Dropped:
                inLibraryView?.backgroundColor = UIColor.dropped()
            }
            
        } else {
            inLibraryView?.hidden = true
        }
        
    }
    
    func updateInformationLabel(anime: Anime, informationLabel: UILabel?) {
        var information = "\(anime.type) · "
        
        if let mainStudio = anime.studio.first {
            let studioString = mainStudio["studio_name"] as! String
            information += studioString
        } else {
            information += "?"
        }
        
        if let source = anime.source where source.characters.count != 0 {
            information += " · " + source
        }
        
        informationLabel?.text = information
    }
    
    // Helper date functions
    func etaForDate(nextDate: NSDate) -> (days: Int, hours: Int, minutes: Int) {
        let now = NSDate()
        let cal = NSCalendar.currentCalendar()
        let unit: NSCalendarUnit = [.Day, .Hour, .Minute]
        let components = cal.components(unit, fromDate: now, toDate: nextDate, options: [])
        
        return (components.day,components.hour, components.minute)
    }
    
}

// MARK: - Layout
extension AnimeCell {
    class func updateLayoutItemSizeWithLayout(layout: UICollectionViewFlowLayout, viewSize: CGSize) {
        let margin: CGFloat = 4
        let columns: CGFloat = UIDevice.isLandscape() ? 3 : 2
        let cellHeight: CGFloat = 132
        var cellWidth: CGFloat = 0
        
        layout.minimumLineSpacing = margin
        
        if UIDevice.isPad() {
            layout.sectionInset = UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
            let totalWidth: CGFloat = viewSize.width - (margin * (columns + 1))
            cellWidth = totalWidth / columns
            layout.minimumInteritemSpacing = margin
            layout.minimumLineSpacing = margin
        } else {
            layout.sectionInset = UIEdgeInsetsZero
            cellWidth = viewSize.width
            layout.minimumInteritemSpacing = 1
            layout.minimumLineSpacing = 1
        }
        
        layout.itemSize = CGSize(width: cellWidth, height: cellHeight)
    }
}
