//
//  PPFilePicker.swift
//  PandaNote
//
//  Created by Panway on 2023/2/10.
//  Copyright © 2023 Panway. All rights reserved.
//  https://github.com/amangona/SwiftyDocPicker 搜索关键字uidocumentbrowserviewcontroller 使用

import Foundation
import UIKit
import MobileCoreServices


public enum SourceType: Int {
    case files
    case folder
}

protocol PPDocumentDelegate : AnyObject {
    func didPickDocuments(documents: [PPDocument]?)
}

class PPDocument: UIDocument {
    var data: Data?
    override func contents(forType typeName: String) throws -> Any {
        guard let data = data else { return Data() }
        
        if #available(iOS 11.0, *) {
            return try NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true)
        } else {
            return Data()
        }
    }
    override func load(fromContents contents: Any, ofType typeName:String?) throws {
        guard let data = contents as? Data else { return }
        self.data = data
    }
}

open class PPFilePicker: NSObject {
    private var pickerController: UIDocumentPickerViewController?
    private weak var presentationController: UIViewController?
    private weak var delegate: PPDocumentDelegate?
    
    private var folderURL: URL?
    private var sourceType: SourceType!
    private var documents = [PPDocument]()
    
    init(presentationController: UIViewController, delegate: PPDocumentDelegate) {
        super.init()
        
        self.presentationController = presentationController
        self.delegate = delegate
    }
    
    public func folderAction(for type: SourceType, title: String) -> UIAlertAction? {
        return UIAlertAction(title: title, style: .default) { [unowned self] _ in
            self.pickerController = UIDocumentPickerViewController(documentTypes: [kUTTypeFolder as String], in: .open)
            self.pickerController!.delegate = self
            self.sourceType = type
            self.presentationController?.present(self.pickerController!, animated: true)
        }
    }
    public func showFilePicker() {
        //导入所有类型的文件
//https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/understanding_utis/understand_utis_intro/understand_utis_intro.html
        self.pickerController  = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
//        self.pickerController = UIDocumentPickerViewController(documentTypes: ["public.content"], in: .open) //媒体和文档类型

        //打开视频和图片类型的文件
//        self.pickerController = UIDocumentPickerViewController(documentTypes: [kUTTypeMovie as String, kUTTypeImage as String], in: .open)
        self.pickerController!.delegate = self
        if #available(iOS 11.0, *) {
            self.pickerController!.allowsMultipleSelection = true //默认一次可以选择多个文件
        } else {
            
        }
        self.sourceType = .files
        self.pickerController?.modalPresentationStyle = .formSheet
        self.presentationController?.present(self.pickerController!, animated: true)
    }
    public func fileAction(for type: SourceType, title: String) -> UIAlertAction? {
        return UIAlertAction(title: title, style: .default) { [unowned self] _ in
            self.showFilePicker()
        }
    }
    
    public func present(from sourceView: UIView) {
        
        let alertController = UIAlertController(title: "Select From", message: nil, preferredStyle: .actionSheet)
        
        if let action = self.fileAction(for: .files, title: "Files") {
            alertController.addAction(action)
        }
        
        if let action = self.folderAction(for: .folder, title: "Folder") {
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            alertController.popoverPresentationController?.sourceView = sourceView
            alertController.popoverPresentationController?.sourceRect = sourceView.bounds
            alertController.popoverPresentationController?.permittedArrowDirections = [.down, .up]
        }
        
        self.presentationController?.present(alertController, animated: true)
        
    }
}

extension PPFilePicker: UIDocumentPickerDelegate {
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
//        guard let url = urls.first else {
//            return
//        }
        documents.removeAll() //先清空
        for url in urls {
            documentFromURL(pickedURL: url)
        }
        delegate?.didPickDocuments(documents: documents)
    }
    
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        delegate?.didPickDocuments(documents: nil)
    }
    
    private func documentFromURL(pickedURL: URL) {
        let shouldStopAccessing = pickedURL.startAccessingSecurityScopedResource()
        
        defer {
            if shouldStopAccessing {
                pickedURL.stopAccessingSecurityScopedResource()
            }
        }
        NSFileCoordinator().coordinate(readingItemAt: pickedURL, error: NSErrorPointer.none) { (folderURL) in
            
            let keys: [URLResourceKey] = [.nameKey, .isDirectoryKey]
            let fileList = FileManager.default.enumerator(at: pickedURL, includingPropertiesForKeys: keys)
            
            switch sourceType {
            case .files:
                let document = PPDocument(fileURL: pickedURL)
                documents.append(document)
                
            case .folder:
                for case let fileURL as URL in fileList! {
                    if !fileURL.isDirectory {
                        let document = PPDocument(fileURL: fileURL)
                        documents.append(document)
                    }
                }
            case .none:
                break
            }
            
        }
        
    }
    
}

extension URL {
    var isDirectory: Bool! {
        return (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
    }
}
