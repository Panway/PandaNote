//
//  PPPDFViewController.swift
//  PandaNote
//
//  Created by panwei on 2020/4/8.
//  Copyright © 2020 WeirdPan. All rights reserved.
//  thanks https://github.com/tzshlyt/iOS11-PDFKit-Example

import UIKit
import PDFKit


#if canImport(SnapKit)
import SnapKit
#endif



@available(iOS 11.0, *)
class PPPDFViewController: PPBaseViewController {

    var pdfdocument: PDFDocument?
    var pdfview: PDFView!

    ///文件绝对路径
    var filePathStr: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        self.pdfview = PDFView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        self.view.addSubview(self.pdfview)
        self.pdfview.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        //let url = Bundle.main.url(forResource: "sample", withExtension: "pdf")
        self.pdfdocument = PDFDocument(url: URL(fileURLWithPath: filePathStr))
        //self.pdfdocument = PDFDocument(data: contents)
        self.pdfview.document = self.pdfdocument
        self.pdfview.displayMode = PDFDisplayMode.singlePageContinuous
        self.pdfview.autoScales = true
    }
    

    

}
