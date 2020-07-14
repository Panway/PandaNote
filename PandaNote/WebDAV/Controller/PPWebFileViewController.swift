//
//  PPWebFileViewController.swift
//  PandaNote
//
//  Created by panwei on 2020/5/5.
//  Copyright © 2020 WeirdPan. All rights reserved.
//

import UIKit
import SKPhotoBrowser
import Photos
import Alamofire

class PPWebFileViewController: PPBaseViewController,UITableViewDataSource,UITableViewDelegate {
    var dataSource:Array<PPFileObject> = []
    var originalData:Array<PPFileObject> = []
    var photoBrowser: SKPhotoBrowser!

    var tableView = UITableView()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView = UITableView.init(frame: self.view.bounds)
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.top.left.right.equalTo(self.view)
            make.bottom.equalTo(self.view).offset(0);
        }
        tableView.dataSource = self
        tableView.delegate = self
        self.tableView.register(PPFileListTableViewCell.self, forCellReuseIdentifier: kPPBaseCellIdentifier)
        tableView.tableFooterView = UIView.init()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "过滤", style: UIBarButtonItem.Style.plain, target: self, action: #selector(moreAction))
        
        for item in PPUserInfo.shared.pp_WebViewResource {
            let name = item.split(string: "?").first ?? ""
            let ppFile = PPFileObject(name: name, path: item,size: 0,isDirectory: false,modifiedDate: "2020")
            dataSource.append(ppFile)
            
        }
        originalData = dataSource
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kPPBaseCellIdentifier, for: indexPath) as! PPFileListTableViewCell
        let fileObj = self.dataSource[indexPath.row]
        cell.updateUIWithData(fileObj as AnyObject)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let fileObj = self.dataSource[indexPath.row]
        debugPrint("You tapped cell  \(fileObj.path)")
        if (fileObj.name.pp_isImageFile())  {
            self.showImage(index: indexPath.row, image: nil, imageName: "", imageURL: fileObj.name)
        }
        else if (fileObj.name.pp_isVideoFile())  {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-dd-MM_HHmmss"
            let currentDate: String = formatter.string(from: Date())
            
            PPAlertAction.showAlert(withTitle: "是否保存到相册", msg: "", buttonsStatement: ["好的👌","不了"]) { (index) in
                if (index == 0) {
                    
                    let destination: DownloadRequest.Destination = { _, _ in
                        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let fileURL = documentsURL.appendingPathComponent(currentDate+".mp4")
                        
                        return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
                    }
                    
                    AF.download(fileObj.path, to: destination).response { response in
                        debugPrint(response)
                        
                        if response.error == nil, let imagePath = response.fileURL {
                            PHPhotoLibrary.shared().performChanges({
                                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: imagePath)
                            }) { saved, error in
                                if saved {
                                    DispatchQueue.main.async {
                                        let alertController = UIAlertController(title: "您的视频已成功保存", message: nil, preferredStyle: .alert)
                                        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                                        alertController.addAction(defaultAction)
                                        self.present(alertController, animated: true, completion: nil)
                                        
                                    }
                                }
                            }
                            
                            
                        }
                    }
                    
                    
//Alamofire.download(fileObj.path).responseData { response in
//    if let data = response.result.value {
//        let template =  NSTemporaryDirectory().appending("/"+fileObj.name)
//
//        PPDiskCache.shared.setDataSync(data, destPath:template , key: fileObj.name)
//    }
//}
                    
                    
                }
                
            }
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
    func showImage(index:Int,image:UIImage?,imageName:String,imageURL:String) -> Void {
        DispatchQueue.main.async {
//            if let image_down = UIImage.init(data: contents) {
                // 1. create SKPhoto Array from UIImage
                var images = [SKPhoto]()
                
            
            for fileObj in self.dataSource {
                let photo = SKPhoto.photoWithImageURL(fileObj.name)// add some UIImage
                photo.caption = fileObj.name
//                photo.photoURL = imageURL
                images.append(photo)
                
            }
                
                // 2. create PhotoBrowser Instance, and present from your viewController.
                self.photoBrowser = SKPhotoBrowser(photos: images)
                self.photoBrowser.initializePageIndex(index)
//                self.photoBrowser.delegate = self
                SKPhotoBrowserOptions.actionButtonTitles = ["微信原图分享","作为微信表情分享😄","UIActivityViewController分享"]
                
                self.present(self.photoBrowser, animated: true, completion: {})
                
                
//            }
        }
    }
    @objc func moreAction()  {
        PPAlertAction.showSheet(withTitle: "更多操作", message: nil, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitle: ["全部","视频","图片"]) { (index) in
            debugPrint(index)
            if index == 1 {
                self.dataSource = self.originalData
                self.tableView.reloadData()
            }
            else if index == 2 {
                self.dataSource = self.originalData.filter { $0.name.contains(".mp4")  }
                self.tableView.reloadData()
            }
            else if index == 3 {
                self.dataSource = self.originalData.filter { $0.name.hasSuffix("jpg")||$0.name.hasSuffix("png")  }
                self.tableView.reloadData()
            }
        }
    }

}
