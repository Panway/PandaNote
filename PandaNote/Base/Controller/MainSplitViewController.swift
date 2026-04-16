//
//  MainSplitViewController.swift
//  PandaNote
//
//  Created by pan on 2025/9/29.
//  Copyright © 2025 Panway. All rights reserved.
//

import SnapKit
import UIKit

// MARK: - AppDelegate



// MARK: - Main Split View Controller

class MainSplitViewController: UISplitViewController {
    private var sidebarTabBarController: UITabBarController!
    private var detailTabBarController: DetailTabBarController!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSplitViewController()
        setupSidebarTabBarController()
        setupDetailViewController()
    }

    private func setupSplitViewController() {
        delegate = self
        preferredDisplayMode = .allVisible
        presentsWithGesture = true

        // 设置Mac Catalyst特定的行为
        if #available(iOS 14.0, *) {
            #if targetEnvironment(macCatalyst)
                preferredSplitBehavior = .tile
            #else
                preferredSplitBehavior = .automatic
            #endif
        }
    }

    private func setupSidebarTabBarController() {
        sidebarTabBarController = UITabBarController()
        preferredPrimaryColumnWidthFraction = 0.4
        minimumPrimaryColumnWidth = 400 // 最小宽度为 400 像素
        maximumPrimaryColumnWidth = 800 // 最大宽度为 800 像素

        // 创建四个Tab页面
        let recentVC = createViewController(title: "最近", imageName: "clock", backgroundColor: .systemGray6)
        let filesVC = FilesViewController()
        let browseVC = createViewController(title: "浏览", imageName: "globe", backgroundColor: .systemGray6)
        let profileVC = createViewController(title: "我的", imageName: "person", backgroundColor: .systemGray6)

        filesVC.delegate = self

        sidebarTabBarController.viewControllers = [recentVC, filesVC, browseVC, profileVC]
//        sidebarTabBarController.tabBar.isTranslucent = false //GPT
//        sidebarTabBarController.tabBar.isHidden = true

        let primaryNavController = UINavigationController(rootViewController: sidebarTabBarController)
        primaryNavController.navigationBar.prefersLargeTitles = true

        // 使用旧版API
        viewControllers = [primaryNavController]
    }

    private func setupDetailViewController() {
        detailTabBarController = DetailTabBarController()
        detailTabBarController.tabBarController?.tabBar.isHidden = true

        let detailNavController = UINavigationController(rootViewController: detailTabBarController)

        // 使用旧版API添加详情页
        if viewControllers.count == 1 {
            viewControllers.append(detailNavController)
        } else {
            viewControllers[1] = detailNavController
        }
    }

    private func createViewController(title: String, imageName: String, backgroundColor: UIColor) -> UIViewController {
        let viewController = PlaceholderViewController()
        viewController.view.backgroundColor = backgroundColor
        viewController.title = title
        viewController.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: imageName), selectedImage: nil)

        return UINavigationController(rootViewController: viewController)
    }
}

// MARK: - Split View Controller Delegate

extension MainSplitViewController: UISplitViewControllerDelegate {
    func splitViewController(_: UISplitViewController, collapseSecondary _: UIViewController, onto _: UIViewController) -> Bool {
        // 在iPhone上折叠时，不显示次要视图控制器
        return true
    }
    @available(macCatalyst 14.0, *)
    func splitViewController(_ svc: UISplitViewController,
                                 topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
            return .primary
        }
}

// MARK: - Files View Controller Delegate

extension MainSplitViewController: FilesViewControllerDelegate {
    func filesViewController(_ controller: FilesViewController, didSelectFile file: FileItem) {
        let detailVC = FileDetailViewController(file: file)

        if traitCollection.horizontalSizeClass == .regular, traitCollection.verticalSizeClass == .regular {
            // iPad 和 Mac Catalyst - 在右侧打开新标签页
            detailTabBarController.addNewTab(with: detailVC)
        } else {
            // iPhone - 推送到新页面
            controller.navigationController?.pushViewController(detailVC, animated: true)
        }
    }
}

// MARK: - Detail Tab Bar Controller

class DetailTabBarController: UIViewController {
    private var containerView: UIView!
    private var tabBarContainerView: UIView!
    private var tabBarScrollView: UIScrollView!
    private var tabBarStackView: UIStackView!
    private var addTabButton: UIButton!
    private var separatorView: UIView!

    private var tabs: [TabItem] = []
    private var currentTabIndex: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        setupUI()

        // 添加欢迎页作为初始标签
        let welcomeVC = WelcomeViewController()
        addNewTab(with: welcomeVC, isInitial: true)
    }

    private func setupUI() {
        // 标签栏容器
        tabBarContainerView = UIView()
        tabBarContainerView.backgroundColor = .systemBackground
        view.addSubview(tabBarContainerView)

        // 标签栏滚动视图
        tabBarScrollView = UIScrollView()
        tabBarScrollView.showsHorizontalScrollIndicator = false
        tabBarScrollView.showsVerticalScrollIndicator = false
        tabBarContainerView.addSubview(tabBarScrollView)

        // 标签栏堆栈视图
        tabBarStackView = UIStackView()
        tabBarStackView.axis = .horizontal
        tabBarStackView.spacing = 0
        tabBarStackView.alignment = .fill
        tabBarStackView.distribution = .fill
        tabBarScrollView.addSubview(tabBarStackView)

        // 添加标签按钮
        addTabButton = UIButton(type: .system)
        addTabButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addTabButton.tintColor = .label
        addTabButton.backgroundColor = .secondarySystemBackground
        addTabButton.addTarget(self, action: #selector(addNewTabButtonTapped), for: .touchUpInside)
        tabBarContainerView.addSubview(addTabButton)

        // 分隔线
        separatorView = UIView()
        separatorView.backgroundColor = .separator
        view.addSubview(separatorView)

        // 内容容器
        containerView = UIView()
        containerView.backgroundColor = .systemBackground
        view.addSubview(containerView)

        // 设置约束
        tabBarContainerView.snp.makeConstraints { make in
            make.top.left.right.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(44)
        }

        tabBarScrollView.snp.makeConstraints { make in
            make.top.bottom.left.equalToSuperview()
            make.right.equalTo(addTabButton.snp.left).offset(-8)
        }

        tabBarStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }

        addTabButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        separatorView.snp.makeConstraints { make in
            make.top.equalTo(tabBarContainerView.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(0.5)
        }

        containerView.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
    }

    func addNewTab(with viewController: UIViewController, isInitial: Bool = false) {
        // 创建标签项
        let tabItem = TabItem(viewController: viewController)

        // 添加到tabs数组
        tabs.append(tabItem)

        // 创建标签按钮
        let tabButton = createTabButton(for: tabItem, at: tabs.count - 1)
        tabBarStackView.addArrangedSubview(tabButton)

        // 添加视图控制器
        addChild(viewController)
        containerView.addSubview(viewController.view)
        viewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        viewController.didMove(toParent: self)

        // 隐藏所有其他标签
        if !isInitial {
            for (index, tab) in tabs.enumerated() {
                tab.viewController.view.isHidden = (index != tabs.count - 1)
            }
            currentTabIndex = tabs.count - 1
            updateTabButtons()
        }
    }

    private func createTabButton(for tabItem: TabItem, at index: Int) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .secondarySystemBackground

        let button = UIButton(type: .system)
        button.setTitle(tabItem.title, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        button.tag = index
        button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
        containerView.addSubview(button)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.tag = index
        closeButton.addTarget(self, action: #selector(closeTabButtonTapped(_:)), for: .touchUpInside)
        containerView.addSubview(closeButton)

        button.snp.makeConstraints { make in
            make.top.bottom.left.equalToSuperview()
            make.right.equalTo(closeButton.snp.left).offset(-4)
            make.width.greaterThanOrEqualTo(120)
            make.width.lessThanOrEqualTo(200)
        }

        closeButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-8)
            make.width.height.equalTo(24)
        }

        containerView.snp.makeConstraints { make in
            make.height.equalTo(44)
        }

        tabItem.containerView = containerView

        return containerView
    }

    @objc private func tabButtonTapped(_ sender: UIButton) {
        switchToTab(at: sender.tag)
    }

    @objc private func closeTabButtonTapped(_ sender: UIButton) {
        closeTab(at: sender.tag)
    }

    @objc private func addNewTabButtonTapped() {
        let welcomeVC = WelcomeViewController()
        addNewTab(with: welcomeVC)
    }

    private func switchToTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }

        // 隐藏当前标签
        tabs[currentTabIndex].viewController.view.isHidden = true

        // 显示新标签
        currentTabIndex = index
        tabs[currentTabIndex].viewController.view.isHidden = false

        // 更新标签按钮状态
        updateTabButtons()
    }

    private func closeTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        guard tabs.count > 1 else { return } // 至少保留一个标签

        let tabItem = tabs[index]

        // 移除视图控制器
        tabItem.viewController.willMove(toParent: nil)
        tabItem.viewController.view.removeFromSuperview()
        tabItem.viewController.removeFromParent()

        // 移除标签按钮
        if let containerView = tabItem.containerView {
            tabBarStackView.removeArrangedSubview(containerView)
            containerView.removeFromSuperview()
        }

        // 从数组中移除
        tabs.remove(at: index)

        // 更新所有标签按钮的tag
        for (newIndex, arrangedSubview) in tabBarStackView.arrangedSubviews.enumerated() {
            if let button = arrangedSubview.subviews.first(where: { $0 is UIButton }) as? UIButton {
                button.tag = newIndex
            }
            if let closeButton = arrangedSubview.subviews.last as? UIButton {
                closeButton.tag = newIndex
            }
        }

        // 调整当前标签索引
        if currentTabIndex >= tabs.count {
            currentTabIndex = tabs.count - 1
        } else if index < currentTabIndex {
            currentTabIndex -= 1
        }

        // 显示新的当前标签
        if !tabs.isEmpty {
            tabs[currentTabIndex].viewController.view.isHidden = false
            updateTabButtons()
        }
    }

    private func updateTabButtons() {
        for (index, arrangedSubview) in tabBarStackView.arrangedSubviews.enumerated() {
            if index == currentTabIndex {
                arrangedSubview.backgroundColor = .systemBackground
            } else {
                arrangedSubview.backgroundColor = .secondarySystemBackground
            }
        }
    }
}

// MARK: - Tab Item

class TabItem {
    let viewController: UIViewController
    var title: String
    var containerView: UIView?

    init(viewController: UIViewController) {
        self.viewController = viewController
        title = viewController.title ?? "新标签页"
    }
}

// MARK: - File Item Model

struct FileItem {
    let name: String
    let type: String
    let size: String
    let modifiedDate: Date
    let icon: String
}

// MARK: - Files View Controller Delegate Protocol

protocol FilesViewControllerDelegate: AnyObject {
    func filesViewController(_ controller: FilesViewController, didSelectFile file: FileItem)
}

// MARK: - Files View Controller

class FilesViewController: UIViewController {
    weak var delegate: FilesViewControllerDelegate?

    private var tableView: UITableView!
    private var files: [FileItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "文件"
        tabBarItem = UITabBarItem(title: "文件", image: UIImage(systemName: "folder"), selectedImage: nil)

        setupTableView()
        loadSampleFiles()
    }

    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FileTableViewCell.self, forCellReuseIdentifier: "FileCell")

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func loadSampleFiles() {
        files = [
            FileItem(name: "项目文档.docx", type: "Word文档", size: "2.5 MB", modifiedDate: Date(), icon: "doc.text"),
            FileItem(name: "演示文稿.pptx", type: "PowerPoint", size: "8.1 MB", modifiedDate: Date().addingTimeInterval(-3600), icon: "doc.richtext"),
            FileItem(name: "数据表格.xlsx", type: "Excel表格", size: "1.2 MB", modifiedDate: Date().addingTimeInterval(-7200), icon: "tablecells"),
            FileItem(name: "图片素材.png", type: "PNG图像", size: "3.7 MB", modifiedDate: Date().addingTimeInterval(-10800), icon: "photo"),
            FileItem(name: "视频文件.mp4", type: "MP4视频", size: "125 MB", modifiedDate: Date().addingTimeInterval(-14400), icon: "play.rectangle"),
            FileItem(name: "音频文件.mp3", type: "MP3音频", size: "4.2 MB", modifiedDate: Date().addingTimeInterval(-18000), icon: "music.note"),
            FileItem(name: "PDF文档.pdf", type: "PDF文件", size: "6.8 MB", modifiedDate: Date().addingTimeInterval(-21600), icon: "doc.pdf"),
            FileItem(name: "代码文件.swift", type: "Swift源码", size: "45 KB", modifiedDate: Date().addingTimeInterval(-25200), icon: "curlybraces"),
            FileItem(name: "压缩文件.zip", type: "ZIP压缩包", size: "12.3 MB", modifiedDate: Date().addingTimeInterval(-28800), icon: "archivebox"),
            FileItem(name: "设计稿.sketch", type: "Sketch文件", size: "15.7 MB", modifiedDate: Date().addingTimeInterval(-32400), icon: "paintbrush"),
        ]

        tableView.reloadData()
    }
}

// MARK: - Files Table View Data Source & Delegate

extension FilesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return files.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FileCell", for: indexPath) as! FileTableViewCell
        let file = files[indexPath.row]
        cell.configure(with: file)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let file = files[indexPath.row]
        delegate?.filesViewController(self, didSelectFile: file)
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        return 72
    }
}

// MARK: - File Table View Cell

class FileTableViewCell: UITableViewCell {
    private let fileIconImageView = UIImageView()
    private let fileNameLabel = UILabel()
    private let fileTypeLabel = UILabel()
    private let fileSizeLabel = UILabel()
    private let modifiedDateLabel = UILabel()
    private let containerStackView = UIStackView()
    private let infoStackView = UIStackView()
    private let rightStackView = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // 配置文件图标
        fileIconImageView.contentMode = .scaleAspectFit
        fileIconImageView.tintColor = .systemBlue

        // 配置文件名标签
        fileNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        fileNameLabel.textColor = .label
        fileNameLabel.numberOfLines = 1

        // 配置文件类型标签
        fileTypeLabel.font = UIFont.systemFont(ofSize: 14)
        fileTypeLabel.textColor = .secondaryLabel
        fileTypeLabel.numberOfLines = 1

        // 配置文件大小标签
        fileSizeLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        fileSizeLabel.textColor = .tertiaryLabel
        fileSizeLabel.textAlignment = .right

        // 配置修改日期标签
        modifiedDateLabel.font = UIFont.systemFont(ofSize: 12)
        modifiedDateLabel.textColor = .tertiaryLabel
        modifiedDateLabel.textAlignment = .right

        // 配置堆栈视图
        infoStackView.axis = .vertical
        infoStackView.spacing = 4
        infoStackView.alignment = .leading
        infoStackView.distribution = .fill

        rightStackView.axis = .vertical
        rightStackView.spacing = 4
        rightStackView.alignment = .trailing
        rightStackView.distribution = .fill

        containerStackView.axis = .horizontal
        containerStackView.spacing = 12
        containerStackView.alignment = .center
        containerStackView.distribution = .fill

        // 添加子视图到堆栈
        infoStackView.addArrangedSubview(fileNameLabel)
        infoStackView.addArrangedSubview(fileTypeLabel)

        rightStackView.addArrangedSubview(fileSizeLabel)
        rightStackView.addArrangedSubview(modifiedDateLabel)

        containerStackView.addArrangedSubview(fileIconImageView)
        containerStackView.addArrangedSubview(infoStackView)
        containerStackView.addArrangedSubview(rightStackView)

        contentView.addSubview(containerStackView)

        // 使用SnapKit设置约束
        fileIconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(36)
        }

        rightStackView.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(80)
        }

        containerStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }

        // 设置内容优先级
        fileNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        fileSizeLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        modifiedDateLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }

    func configure(with file: FileItem) {
        fileIconImageView.image = UIImage(systemName: file.icon)
        fileNameLabel.text = file.name
        fileTypeLabel.text = file.type
        fileSizeLabel.text = file.size

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        modifiedDateLabel.text = formatter.string(from: file.modifiedDate)
    }
}

// MARK: - File Detail View Controller

class FileDetailViewController: UIViewController {
    private let file: FileItem
    private var scrollView: UIScrollView!
    private var contentView: UIView!

    init(file: FileItem) {
        self.file = file
        super.init(nibName: nil, bundle: nil)
        title = file.name
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        setupScrollView()
        setupContent()
    }

    private func setupScrollView() {
        scrollView = UIScrollView()
        contentView = UIView()

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
    }

    private func setupContent() {
        // 文件图标
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: file.icon)
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        contentView.addSubview(iconImageView)

        // 文件信息容器
        let infoContainerView = UIView()
        infoContainerView.backgroundColor = .secondarySystemBackground
        infoContainerView.layer.cornerRadius = 12
        contentView.addSubview(infoContainerView)

        // 文件信息堆栈视图
        let infoStackView = UIStackView()
        infoStackView.axis = .vertical
        infoStackView.spacing = 16
        infoStackView.alignment = .fill
        infoContainerView.addSubview(infoStackView)

        // 创建信息行
        let infoData = [
            ("文件名", file.name),
            ("文件类型", file.type),
            ("文件大小", file.size),
            ("修改时间", DateFormatter.localizedString(from: file.modifiedDate, dateStyle: .medium, timeStyle: .short)),
        ]

        for (label, value) in infoData {
            let infoView = createInfoRow(label: label, value: value)
            infoStackView.addArrangedSubview(infoView)
        }

        // 预览标题
        let previewLabel = UILabel()
        previewLabel.text = "文件预览"
        previewLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        contentView.addSubview(previewLabel)

        // 预览容器
        let previewView = UIView()
        previewView.backgroundColor = .systemGray6
        previewView.layer.cornerRadius = 12
        contentView.addSubview(previewView)

        let previewPlaceholder = UILabel()
        previewPlaceholder.text = "文件预览将在此处显示"
        previewPlaceholder.textColor = .secondaryLabel
        previewPlaceholder.textAlignment = .center
        previewPlaceholder.numberOfLines = 0
        previewView.addSubview(previewPlaceholder)

        // 操作按钮堆栈
        let actionStackView = UIStackView()
        actionStackView.axis = .horizontal
        actionStackView.spacing = 12
        actionStackView.distribution = .fillEqually
        contentView.addSubview(actionStackView)

        let shareButton = createActionButton(title: "分享", systemImageName: "square.and.arrow.up")
        let openButton = createActionButton(title: "打开", systemImageName: "doc.text")
        let moreButton = createActionButton(title: "更多", systemImageName: "ellipsis")

        actionStackView.addArrangedSubview(shareButton)
        actionStackView.addArrangedSubview(openButton)
        actionStackView.addArrangedSubview(moreButton)

        // 设置SnapKit约束
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(32)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(80)
        }

        infoContainerView.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(32)
            make.left.right.equalToSuperview().inset(20)
        }

        infoStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(20)
        }

        previewLabel.snp.makeConstraints { make in
            make.top.equalTo(infoContainerView.snp.bottom).offset(32)
            make.left.equalToSuperview().offset(20)
        }

        previewView.snp.makeConstraints { make in
            make.top.equalTo(previewLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(200)
        }

        previewPlaceholder.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.right.equalToSuperview().inset(20)
        }

        actionStackView.snp.makeConstraints { make in
            make.top.equalTo(previewView.snp.bottom).offset(24)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(-32)
        }
    }

    private func createInfoRow(label: String, value: String) -> UIView {
        let containerView = UIView()

        let labelView = UILabel()
        labelView.text = label
        labelView.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        labelView.textColor = .label

        let valueView = UILabel()
        valueView.text = value
        valueView.font = UIFont.systemFont(ofSize: 16)
        valueView.textColor = .secondaryLabel
        valueView.numberOfLines = 0
        valueView.textAlignment = .right

        containerView.addSubview(labelView)
        containerView.addSubview(valueView)

        labelView.snp.makeConstraints { make in
            make.left.top.bottom.equalToSuperview()
            make.width.equalTo(80)
        }

        valueView.snp.makeConstraints { make in
            make.left.equalTo(labelView.snp.right).offset(16)
            make.right.top.bottom.equalToSuperview()
        }

        return containerView
    }

    private func createActionButton(title: String, systemImageName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: systemImageName), for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)

        // 设置图像和标题的布局
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)

        return button
    }
}

// MARK: - Welcome View Controller

class WelcomeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "欢迎"
        view.backgroundColor = .systemBackground

        let containerView = UIView()
        view.addSubview(containerView)

        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: "folder.badge.gearshape")
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        containerView.addSubview(iconImageView)

        let titleLabel = UILabel()
        titleLabel.text = "文件管理器"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "选择左侧文件以查看详情"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        containerView.addSubview(subtitleLabel)

        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
        }

        iconImageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(64)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(16)
            make.left.right.equalToSuperview()
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.left.right.bottom.equalToSuperview()
        }
    }
}

// MARK: - Placeholder View Controller

class PlaceholderViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let containerView = UIView()
        view.addSubview(containerView)

        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue
        containerView.addSubview(iconImageView)

        let placeholderLabel = UILabel()
        placeholderLabel.text = title ?? "页面"
        placeholderLabel.textAlignment = .center
        placeholderLabel.textColor = .label
        placeholderLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        containerView.addSubview(placeholderLabel)

        let descriptionLabel = UILabel()
        descriptionLabel.text = "此页面内容待开发"
        descriptionLabel.textAlignment = .center
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        containerView.addSubview(descriptionLabel)

        // 根据页面标题设置不同的图标
        switch title {
        case "最近":
            iconImageView.image = UIImage(systemName: "clock")
        case "浏览":
            iconImageView.image = UIImage(systemName: "globe")
        case "我的":
            iconImageView.image = UIImage(systemName: "person.circle")
        default:
            iconImageView.image = UIImage(systemName: "app")
        }

        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(250)
        }

        iconImageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(48)
        }

        placeholderLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(16)
            make.left.right.equalToSuperview()
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(placeholderLabel.snp.bottom).offset(8)
            make.left.right.bottom.equalToSuperview()
        }
    }
}
