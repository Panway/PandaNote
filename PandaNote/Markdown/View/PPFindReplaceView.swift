//
//  PPFindReplaceView.swift
//  PandaNote
//
//  Created by Panway on 2023/4/15.
//  Copyright © 2023 Panway. All rights reserved.
//

import Foundation
public protocol PPFindReplaceDelegate: AnyObject {
    func didFind(range:NSRange, msg:String)
}
public class PPFindReplaceView: UIView {
    var searchField: PPTextField = PPTextField(frame: CGRect(x: 0, y: 0, width: 320, height: 33))
    var replaceField: UITextField!
    var searchBG: UIView!
    var searchBtn: UIButton!
    var searchNextBtn: UIButton!
    var replaceBtn: UIButton!
    var closeBtn = UIButton(type: .custom)
    var showReplaceBtn = UIButton(type: .custom) ///< 显示替换按钮
    var searchRange:NSRange!
    var lastSearchRange:NSRange!
    weak var delegate: PPFindReplaceDelegate?
    var currentResultIndex = 0
    var occurrences = 0
    private var text = ""
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        pp_addSubviews()
    }
    private lazy var resultCount: UILabel = {
        let lb = UILabel()
        lb.font = UIFont.systemFont(ofSize: 12)
        lb.textColor = .lightGray
        return lb
    }()
    
    func pp_addSubviews() {
        
        let contentEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)

        let searchH = 30.0
        let padding = 5.0
        searchBG = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 30))
        self.addSubview(searchBG)
        searchBG.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(searchH + padding*2)
        }
        searchBG.backgroundColor = "#f0f0f0".pp_HEXColor()

        //显示展开按钮
        searchBG.addSubview(showReplaceBtn)
        showReplaceBtn.snp.makeConstraints { make in
            make.left.top.bottom.equalToSuperview()
            make.width.equalTo(44)
        }
        showReplaceBtn.setImage(UIImage(named: "icon_back_black")?.pp_rotate(180), for: .normal)
        //关闭按钮
        searchBG.addSubview(closeBtn)
        closeBtn.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-8)
            make.size.equalTo(CGSize(width: searchH, height: searchH))
            make.centerY.equalToSuperview()
        }
        closeBtn.setTitle("❌", for: .normal)
        closeBtn.addTarget(self, action: #selector(closeFindPanel), for: .touchUpInside)
        
        //搜索内容
//        searchField.contentEdgeInsets = contentEdgeInsets
        searchBG.addSubview(searchField)
        searchField.backgroundColor = .white
        searchField.autocorrectionType = .no        //disable auto correction
        searchField.autocapitalizationType = .none   //disable default capitalization
        
        self.addSubview(self.resultCount)
        self.resultCount.text = "第0项，共0项"
        

        searchNextBtn = UIButton(type: .custom)
        searchBG.addSubview(searchNextBtn)
        searchNextBtn.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(closeBtn.snp.left).offset(-padding)
            make.width.equalTo(searchH)
            make.height.equalTo(searchH)
        }
//        searchNextBtn.setTitle("查找下一处", for: .normal)
        searchNextBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        searchNextBtn.setImage(UIImage(named: "icon_back_black")?.pp_rotate(-90), for: .normal)
        searchNextBtn.backgroundColor = PPCOLOR_GREEN
        searchNextBtn.addTarget(self, action: #selector(searchNextClicked), for: .touchUpInside)
        
        searchBtn = UIButton(type: .custom)
        searchBG.addSubview(searchBtn)
        searchBtn.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(searchNextBtn.snp.left).offset(-padding)
            make.width.equalTo(searchH)
            make.height.equalTo(searchH)
        }
//        searchBtn.setTitle("查找上一处", for: .normal)
        searchBtn.setImage(UIImage(named: "icon_back_black")?.pp_rotate(90), for: .normal)
        searchBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        searchBtn.backgroundColor = PPCOLOR_GREEN
        searchBtn.addTarget(self, action: #selector(searchClicked), for: .touchUpInside)
        
        resultCount.snp.makeConstraints { make in
            make.right.equalTo(searchBtn.snp.left).offset(-padding)
//            make.width.equalTo(100)
            make.centerY.equalTo(searchField)
        }
        resultCount.snp.contentHuggingHorizontalPriority = 1000 //防止拉伸变长
        resultCount.snp.contentCompressionResistanceHorizontalPriority = 1000//UILayoutPriority.required.rawValue //防止压缩

        searchField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(padding)
            make.left.equalToSuperview().offset(44)
            make.right.equalTo(resultCount.snp.left).offset(-padding)
            make.height.equalTo(searchH)
        }

        //默认搜索范围：全部

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initSearchText(_ fullText: String) {
        text = fullText
        searchRange = NSRange(location: 0, length: text.length)
//        lastSearchRange = NSRange(location: 0, length: text.length)
    }
    func matchCount(searchText:String) {
        let occurrences = countOccurrences(of: searchText, in: text)
    }
    //搜索上一个
    @IBAction func searchClicked(_ sender: Any) {
        let searchText = searchField.text ?? ""
        searchRange.location = 0
        
        //找不到的时候,searchRange.length是无限大
        if lastSearchRange == nil || lastSearchRange?.location == NSNotFound {
            searchRange = NSRange(location: 0, length: text.length)
        }
        else {
            searchRange.length = lastSearchRange.location
        }
        debugPrint("搜索范围:", searchRange ?? "")
        let nsstr = text as NSString
        lastSearchRange = nsstr.range(of: searchText, options: [.caseInsensitive, .backwards], range: searchRange)
        if lastSearchRange == nil || lastSearchRange.location != NSNotFound {
            // 找到了匹配项
            debugPrint("找到了匹配项 Found at:", lastSearchRange ?? "")
            delegate?.didFind(range: lastSearchRange, msg: "findNext")
            currentResultIndex -= 1
            debugPrint("==========\(currentResultIndex)-\(occurrences)")
            if currentResultIndex < 0 {
                currentResultIndex = occurrences - 1
            }
            resultCount.text = "第\(currentResultIndex)项，共\(occurrences)项"
        }
        else {
            PPHUD.showHUDFromTop("已查找到第一个结果")
        }
//        search(for: searchText, next: false)
    }
    //搜索下一个
    @IBAction func searchNextClicked(_ sender: Any) {
        let searchText = searchField.text ?? ""
        if lastSearchRange == nil || lastSearchRange?.location == NSNotFound {
            searchRange = NSRange(location: 0, length: text.length)
            currentResultIndex = 0
            occurrences = countOccurrences(of: searchText, in: text)
            resultCount.text = "第0项，共\(occurrences)项"

        }
        else {
            // 将搜索范围缩小为已匹配的文字后面部分
            searchRange.location = lastSearchRange?.upperBound ?? 0
            searchRange.length = text.length - searchRange.location
            
        }
//        guard var searchRange = searchRange else { return }
//        let textStorage = textView.textStorage
        debugPrint("搜索范围:", searchRange ?? "" )
        let nsstr = text as NSString
        lastSearchRange = nsstr.range(of: searchText, options: .caseInsensitive,range: searchRange)
        if lastSearchRange?.location != NSNotFound {
            // 找到了匹配项
            debugPrint("找到了 Found at:", lastSearchRange ?? "")
            delegate?.didFind(range: lastSearchRange, msg: "findNext")
            currentResultIndex += 1
            resultCount.text = "第\(currentResultIndex)项，共\(occurrences)项"
        }
        else {
            PPHUD.showHUDFromTop("已查找到最后一个结果，请重新点击查找")
        }
    }
    @IBAction func replaceClicked(_ sender: Any) {
    }
    
    //查找一个字符串A中包含的另一个字符串B的次数，可以使用 Swift 的 range(of:) 函数来查找匹配项，并在找到一个匹配项后将搜索范围缩小以在剩余的部分中继续查找。
    func countOccurrences(of searchString: String, in string: String) -> Int {
        var count = 0
        var searchRange = string.startIndex..<string.endIndex
        
        while let range = string.range(of: searchString, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<searchRange.upperBound
        }
        
        return count
    }
    
    func replaceAll(searchText: String, replaceText: String) {
//        let textStorage = textView.textStorage
//        let textRange = NSRange(location: 0, length: textStorage.length)
//        let regex = try! NSRegularExpression(pattern: searchText, options: .caseInsensitive)
//        let replacedString = regex.stringByReplacingMatches(in: textStorage.string, options: [], range: textRange, withTemplate: replaceText)
//        textStorage.replaceCharacters(in: textRange, with: replacedString)
    }
    
    @objc func closeFindPanel() {
        self.isHidden = true
    }
}
