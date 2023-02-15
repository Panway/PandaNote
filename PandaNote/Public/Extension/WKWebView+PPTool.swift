//
//  WKWebView+PPTool.swift
//  PandaNote
//
//  Created by Panway on 2022/3/1.
//  Copyright © 2022 Panway. All rights reserved.
//

import Foundation
import WebKit.WKWebView


extension WKWebView {
    
    /// from: https://stackoverflow.com/a/55160117/4493393
    // Call this function when WKWebView finish loading
    func exportToPdf(completion: ((Data) -> Void)? = nil) {
        if #available(iOS 14.0, *) {
            let config = WKPDFConfiguration()
            self.createPDF(configuration: config) { result in
                switch result {
                case .success(let data):
                    if let completion = completion {
                        completion(data)
                    }
                    debugPrint("create pdf success")
                case .failure(let error):
                    debugPrint("create pdf failure: \(error)")
                }
            }
            
        } else {
            // before iOS14
            let pdfData = createPdfFile(printFormatter: self.viewPrintFormatter())
            if let completion = completion {
                completion(pdfData as Data)
            }
//            return self.saveWebViewPdf(data: pdfData)
        }
    }
    
    func createPdfFile(printFormatter: UIViewPrintFormatter) -> NSMutableData {
        
        let originalBounds = self.bounds
        self.bounds = CGRect(x: originalBounds.origin.x, y: bounds.origin.y, width: self.bounds.size.width, height: self.scrollView.contentSize.height)
        let pdfPageFrame = CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.scrollView.contentSize.height)
        let printPageRenderer = UIPrintPageRenderer()
        printPageRenderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)
        printPageRenderer.setValue(NSValue(cgRect: UIScreen.main.bounds), forKey: "paperRect")
        printPageRenderer.setValue(NSValue(cgRect: pdfPageFrame), forKey: "printableRect")
        self.bounds = originalBounds
        return printPageRenderer.generatePdfData()
    }
    
    // Save pdf file in document directory
    func saveWebViewPdf(data: NSMutableData) -> String {
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docDirectoryPath = paths[0]
        let pdfPath = docDirectoryPath.appendingPathComponent("webViewPdf.pdf")
        if data.write(to: pdfPath, atomically: true) {
            return pdfPath.path
        } else {
            return ""
        }
    }
}

extension UIPrintPageRenderer {
    
    func generatePdfData() -> NSMutableData {
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, self.paperRect, nil)
        self.prepare(forDrawingPages: NSMakeRange(0, self.numberOfPages))
        let printRect = UIGraphicsGetPDFContextBounds()
        for pdfPage in 0 ..< self.numberOfPages {
            UIGraphicsBeginPDFPage()
            self.drawPage(at: pdfPage, in: printRect)
        }
        UIGraphicsEndPDFContext();
        return pdfData
    }
}
