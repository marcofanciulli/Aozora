//
//  UserProfileManager.swift
//  Aozora
//
//  Created by Paul Chavarria Podoliako on 8/7/15.
//  Copyright (c) 2015 AnyTap. All rights reserved.
//

import Foundation
import RSKImageCropper
import Bolts
import Parse

public protocol UserProfileManagerDelegate: class {
    func selectedAvatar(avatar: UIImage)
    func selectedBanner(banner: UIImage)
}

public class UserProfileManager: NSObject {
    
    static let ImageMinimumSideSize: CGFloat = 120
    static let ImageMaximumSideSize: CGFloat = 400
    
    var viewController: UIViewController!
    var delegate: UserProfileManagerDelegate?
    var imagePicker: UIImagePickerController!
    var selectingAvatar = true
    
    public func initWith(controller: UIViewController, delegate: UserProfileManagerDelegate) {
        self.viewController = controller
        self.delegate = delegate
    }
    
    public func selectAvatar() {
        selectingAvatar = true
        selectImage()
    }
    
    public func selectBanner() {
        selectingAvatar = false
        selectImage()
    }
    
    func selectImage() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.SavedPhotosAlbum){
            if imagePicker == nil {
                imagePicker = UIImagePickerController()
            }
            
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.SavedPhotosAlbum;
            imagePicker.allowsEditing = false
            
            viewController.presentViewController(imagePicker, animated: true, completion: nil)
        }
    }
    
    public func createUser(
        viewController: UIViewController,
        username: String,
        password: String,
        email: String,
        avatar: UIImage?) -> BFTask {
        
        if !email.validEmail(viewController) ||
            !password.validPassword(viewController) ||
            !username.validUsername(viewController){
                return BFTask(error: NSError())
        }
        
        return username.usernameIsUnique().continueWithExecutor(BFExecutor.mainThreadExecutor(), withSuccessBlock: { (task: BFTask!) -> AnyObject! in
            
            if let user = task.result as? User {
                let error = NSError(domain: "Aozora.App", code: 700, userInfo: ["error": "User exists, try another one"])
                return BFTask(error: error)
            }
            
            let user = User()

            // Fill user fields
            if user.username == nil {
                user.username = username
            }
            
            user.aozoraUsername = username
            user.password = password
            user.email = email
            user.avatarThumb = self.avatarThumbImageToPFFile(avatar)

            // Add user detail object
            let userDetails = UserDetails()
            userDetails.avatarRegular = self.avatarRegularImageToPFFile(avatar)
            userDetails.about = ""
            userDetails.planningAnimeCount = 0
            userDetails.watchingAnimeCount = 0
            userDetails.completedAnimeCount = 0
            userDetails.onHoldAnimeCount = 0
            userDetails.droppedAnimeCount = 0
            userDetails.gender = "Not specified"
            userDetails.joinDate = NSDate()
            userDetails.posts = 0
            userDetails.watchedTime = 0.0
            user.details = userDetails
            
            return user.signUpInBackground()
            
        }).continueWithExecutor(BFExecutor.mainThreadExecutor(), withBlock: { (task: BFTask!) -> AnyObject! in
            
            if let error = task.error {
                let errorMessage = error.userInfo?["error"] as! String
                viewController.presentBasicAlertWithTitle("Error", message: errorMessage)
                return BFTask(error: NSError())
            } else {
                return nil
            }
        })
        
    }
    
    
    public func updateUser(
    viewController: UIViewController,
    user: User,
    email: String? = nil,
    avatar: UIImage? = nil,
    banner: UIImage? = nil,
    about: String? = nil
    ) -> BFTask {
        
        if let email = email where !email.validEmail(viewController) {
            return BFTask(error: NSError())
        }
        
        if let avatar = avatar {
            self.avatarThumbImageToPFFile(avatar)
        }
        
        if let email = email {
            user.email = email
        }
        
        if let banner = banner {
            let avatarRegularData = UIImagePNGRepresentation(banner)
            user.banner = PFFile(name:"banner.png", data:avatarRegularData)
        }
        
        if let about = about {
            user.details.about = about
        }
        
        return user.saveInBackground().continueWithExecutor(BFExecutor.mainThreadExecutor(), withBlock: { (task: BFTask!) -> AnyObject! in
            
            if let error = task.error {
                let errorMessage = error.userInfo?["error"] as! String
                viewController.presentBasicAlertWithTitle("Error", message: errorMessage)
                return BFTask(error: error)
            } else {
                return nil
            }
        })
            
    }
    
    // MARK: - Internal functions
    
    func avatarThumbImageToPFFile(avatar: UIImage?) -> PFFile {
        let avatar = avatar ?? UIImage(named: "default-avatar")!
        let thumbAvatar = UIImage.imageWithImage(avatar, newSize: CGSize(width: UserProfileManager.ImageMinimumSideSize, height: UserProfileManager.ImageMinimumSideSize))
        let avatarThumbData = UIImagePNGRepresentation(thumbAvatar)
        return PFFile(name:"avatarThumb.png", data:avatarThumbData)
    }
    
    func avatarRegularImageToPFFile(avatar: UIImage?) -> PFFile {
        let avatar = avatar ?? UIImage(named: "default-avatar")!
        let regularAvatar = UIImage.imageWithImage(avatar, maxSize: CGSize(width: UserProfileManager.ImageMaximumSideSize, height: UserProfileManager.ImageMaximumSideSize))
        let avatarRegularData = UIImagePNGRepresentation(regularAvatar)
        return PFFile(name:"avatarRegular.png", data:avatarRegularData)
    }
    
}

extension UserProfileManager: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [NSObject : AnyObject]!) {
        viewController.dismissViewControllerAnimated(true, completion: { () -> Void in
            
            if image.size.width < UserProfileManager.ImageMinimumSideSize || image.size.height < UserProfileManager.ImageMinimumSideSize {
                self.viewController.presentBasicAlertWithTitle("Pick a larger image", message: "Select an image with at least 120x120px")
            } else {
                let imageCropVC: RSKImageCropViewController!
                
                if self.selectingAvatar {
                    imageCropVC = RSKImageCropViewController(image: image)
                } else {
                    imageCropVC = RSKImageCropViewController(image: image, cropMode: RSKImageCropMode.Custom)
                    imageCropVC.dataSource = self
                }
                
                imageCropVC.delegate = self
                self.viewController.presentViewController(imageCropVC, animated: true, completion: nil)
            }
        })
    }
}

extension UserProfileManager: RSKImageCropViewControllerDelegate {
    
    public func imageCropViewController(controller: RSKImageCropViewController!, didCropImage croppedImage: UIImage!, usingCropRect cropRect: CGRect) {
        controller.dismissViewControllerAnimated(true, completion: nil)
        
        if selectingAvatar {
            delegate?.selectedAvatar(croppedImage)
        } else {
            delegate?.selectedBanner(croppedImage)
        }
    }
    
    public func imageCropViewControllerDidCancelCrop(controller: RSKImageCropViewController!) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
}

extension UserProfileManager: RSKImageCropViewControllerDataSource {
    
    public func imageCropViewControllerCustomMaskRect(controller: RSKImageCropViewController!) -> CGRect {
        let imageHeight: CGFloat = 120
        let yPosition = (viewController.view.bounds.size.height - imageHeight) / 2
        return CGRect(x: 0, y: yPosition, width: viewController.view.bounds.size.width, height: imageHeight)
    }

    public func imageCropViewControllerCustomMaskPath(controller: RSKImageCropViewController!) -> UIBezierPath! {
        let imageHeight: CGFloat = 120
        let yPosition = (viewController.view.bounds.size.height - imageHeight) / 2
        return UIBezierPath(rect: CGRect(x: 0, y: yPosition, width: viewController.view.bounds.size.width, height: imageHeight))
    }
    
    public func imageCropViewControllerCustomMovementRect(controller: RSKImageCropViewController!) -> CGRect {
        return controller.maskRect
    }
}