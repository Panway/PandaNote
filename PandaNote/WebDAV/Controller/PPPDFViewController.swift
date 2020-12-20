//
//  PPPDFViewController.swift
//  PandaNote
//
//  Created by panwei on 2020/4/8.
//  Copyright © 2020 WeirdPan. All rights reserved.
//  thanks https://github.com/tzshlyt/iOS11-PDFKit-Example

import UIKit
import PDFKit

@available(iOS 11.0, *)
class PPPDFViewController: PPBaseViewController {
    var pdfdocument: PDFDocument?
    var pdfview: PDFView!
    var filePathStr: String = ""//文件相对路径
    ///文件ID（仅百度网盘）
    var fileID = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        self.pdfview = PDFView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        PPFileManager.shared.getFileData(path: filePathStr, fileID: fileID,cacheToDisk:true) { (contents: Data?,isFromCache, error) in
            guard let contents = contents else { return }
            
//            let url = Bundle.main.url(forResource: "sample", withExtension: "pdf")
//            self.pdfdocument = PDFDocument(url: url!)
            self.pdfdocument = PDFDocument(data: contents)
            self.pdfview.document = self.pdfdocument
            self.pdfview.displayMode = PDFDisplayMode.singlePageContinuous
            self.pdfview.autoScales = true
            
            self.view.addSubview(self.pdfview)
            
        }
        

    }
    

    

}
