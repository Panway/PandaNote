//
//  PPButtonBarTabViewController.swift
//  PandaNote
//
//  Created by pan on 2024/3/18.
//  Copyright © 2024 Panway. All rights reserved.
//

import Foundation
import XLPagerTabStrip


public struct PPButtonBarPagerTabStripSettings {

    public struct Style {
        public var buttonBarBackgroundColor: UIColor?
        public var buttonBarMinimumInteritemSpacing: CGFloat = 0
        public var buttonBarMinimumLineSpacing: CGFloat?
        public var buttonBarLeftContentInset: CGFloat?
        public var buttonBarRightContentInset: CGFloat?

        public var selectedBarBackgroundColor = UIColor(hexRGBValue: 0xd5e6fc)
        public var selectedBarHeight: CGFloat = 88
        public var selectedBarVerticalAlignment: SelectedBarVerticalAlignment = .bottom

        public var buttonBarItemBackgroundColor: UIColor?
        public var buttonBarItemFont = UIFont.systemFont(ofSize: 15.0)
        public var buttonBarItemLeftRightMargin: CGFloat = 1
        public var buttonBarItemTitleColor: UIColor?
        public var buttonBarItemsShouldFillAvailableWidth = false
        // only used if button bar is created programaticaly and not using storyboards or nib files
        public var buttonBarHeight: CGFloat?
    }

    public var style = Style()
}

open class PPButtonBarTabViewController: PagerTabStripViewController, PagerTabStripDataSource, PagerTabStripIsProgressiveDelegate, UICollectionViewDelegate, UICollectionViewDataSource {

    public var settings = PPButtonBarPagerTabStripSettings()

    public var changeCurrentIndex: ((_ oldCell: ButtonBarViewCell?, _ newCell: ButtonBarViewCell?, _ animated: Bool) -> Void)?
    public var changeCurrentIndexProgressive: ((_ oldCell: ButtonBarViewCell?, _ newCell: ButtonBarViewCell?, _ progressPercentage: CGFloat, _ changeCurrentIndex: Bool, _ animated: Bool) -> Void)?

    @IBOutlet public weak var buttonBarView: ButtonBarView!
    var vcs: [UIViewController] = []

    lazy private var cachedCellWidths: [CGFloat]? = { [unowned self] in
        return self.calculateWidths()
    }()

    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        delegate = self
        datasource = self
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        delegate = self
        datasource = self
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        
        let buttonBarViewAux = buttonBarView ?? {
                let flowLayout = UICollectionViewFlowLayout()
                flowLayout.scrollDirection = .horizontal
                let buttonBarHeight = settings.style.buttonBarHeight ?? 44
                let buttonBar = ButtonBarView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: buttonBarHeight), collectionViewLayout: flowLayout)
                buttonBar.backgroundColor = .white
                buttonBar.selectedBar.backgroundColor = .black
                buttonBar.autoresizingMask = .flexibleWidth
                var newContainerViewFrame = containerView.frame
                newContainerViewFrame.origin.y = buttonBarHeight
                newContainerViewFrame.size.height = containerView.frame.size.height - (buttonBarHeight - containerView.frame.origin.y)
                containerView.frame = newContainerViewFrame
                return buttonBar
            }()
        buttonBarView = buttonBarViewAux

        if buttonBarView.superview == nil {
            view.addSubview(buttonBarView)
        }
        if buttonBarView.delegate == nil {
            buttonBarView.delegate = self
        }
        if buttonBarView.dataSource == nil {
            buttonBarView.dataSource = self
        }
        buttonBarView.scrollsToTop = false
        let flowLayout = buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout // swiftlint:disable:this force_cast
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumInteritemSpacing = settings.style.buttonBarMinimumInteritemSpacing 
        flowLayout.minimumLineSpacing = settings.style.buttonBarMinimumLineSpacing ?? flowLayout.minimumLineSpacing
        let sectionInset = flowLayout.sectionInset
        flowLayout.sectionInset = UIEdgeInsets(top: sectionInset.top, left: settings.style.buttonBarLeftContentInset ?? sectionInset.left, bottom: sectionInset.bottom, right: settings.style.buttonBarRightContentInset ?? sectionInset.right)

        buttonBarView.showsHorizontalScrollIndicator = false
        buttonBarView.backgroundColor = settings.style.buttonBarBackgroundColor ?? buttonBarView.backgroundColor
        buttonBarView.selectedBar.backgroundColor = settings.style.selectedBarBackgroundColor

        buttonBarView.selectedBarHeight = settings.style.selectedBarHeight
        buttonBarView.selectedBarVerticalAlignment = settings.style.selectedBarVerticalAlignment

        buttonBarView.register(PPTabCollectionViewCell.self, forCellWithReuseIdentifier:"Cell")

        // iOS 26 起，滚动视图默认会在四周挂一圈「滚动边缘效果」（就是 Liquid Glass 那层毛玻璃）。
        // 问题是这个标签栏只有 80 点高，上下两条毛玻璃一铺就把按钮条整个糊成一片白，
        // 标签文字和关闭按钮全被盖住 —— 在 Mac Catalyst 上鼠标划过去尤其明显。
        // 这个标签栏是横向滚动的，上下两条边缘效果本来也没任何意义，直接关掉；
        // 左右两条保留，内容超宽时还能提示「旁边还有标签」
        if #available(iOS 26.0, *) {
            buttonBarView.topEdgeEffect.isHidden = true
            buttonBarView.bottomEdgeEffect.isHidden = true
        }
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        buttonBarView.layoutIfNeeded()
    }

    // MARK: - 分屏（Mac Catalyst / iPad）安全区适配
    //
    // 背景：在 Mac Catalyst 上（iPad 的浮层式分屏也一样），UISplitViewController 右侧那一列
    // 在 frame 上是铺满整个窗口的 —— 被左边侧边栏盖住的那部分宽度不会体现在 frame 里，
    // 只会体现在 safeAreaInsets.left 上。顶部导航栏同理，只体现在 safeAreaInsets.top 上。
    // 而 XLPagerTabStrip 内部一律拿 view.bounds.width 当「一页有多宽」，它不认识安全区，
    // 于是每一页都按整个窗口宽度去排版，右边多出来的那截被推到窗口外面，用户就看不见了。
    //
    // 解决思路：先算出可用宽度（自身宽度 − 左右安全区），然后
    //   1. 把顶部按钮条和分页容器挪进安全区（右边让开侧边栏、下面让开导航栏）；
    //   2. 让每一页的宽度也按这个可用宽度走（见下面 offsetForChild / updateContent 两个重写）。
    // 全程不去动 pager 自己的 view.frame —— 那会跟 UINavigationController 互相重置，
    // 形成无限布局循环（实测能刷出 5 万多轮）。

    /// 真正能用来放内容的宽度：自身宽度减掉左右安全区。
    /// 没有分屏时（比如 iPhone）左右安全区都是 0，算出来就等于自身宽度，行为跟改动前完全一致。
    private var pp_availableWidth: CGFloat {
        let insets = view.safeAreaInsets
        return max(0, view.bounds.width - insets.left - insets.right)
    }

    /// 把顶部按钮条和分页容器挪进安全区，宽度收窄到可用宽度
    private func pp_applySafeAreaInsets() {
        // 只有「在分屏里」才需要处理：那时右侧列铺满整个窗口，被侧边栏挡住的那部分宽度
        // 只体现在安全区上。普通的 iPhone 不在分屏里（左右安全区本来就是 0），
        // 横屏时刘海虽然也会产生安全区，但页面本来就是铺满整屏的，收窄反而会让按钮条的
        // 背景色在边缘露出缝隙，所以这里干脆不去动它
        guard splitViewController != nil else { return }

        let insets = view.safeAreaInsets
        let availableWidth = pp_availableWidth
        // 宽度还没量出来（是 0）时先跳过，免得把布局改成 0 宽
        guard availableWidth > 0 else { return }

        // 1. 顶部按钮条：x 让开侧边栏，y 让开导航栏，宽度收窄到可用宽度
        if let buttonBarView = buttonBarView {
            // 关掉 autoresizing，否则它下一次布局时会按旧规律把宽度又撑回全宽
            buttonBarView.autoresizingMask = []
            let barHeight = settings.style.buttonBarHeight ?? 44
            var barFrame = buttonBarView.frame
            barFrame.origin.x = insets.left
            // Mac Catalyst 下导航栏也是浮层，按钮条原本 y=0 会被压在导航栏底下，
            // 用户看着标签是亮的，点下去却被导航栏的按钮接走了，所以这里必须让开顶部安全区。
            // iPad 上 view 已经被导航栏推下来，insets.top 是 0，这一行等于没改
            barFrame.origin.y = insets.top
            barFrame.size.width = availableWidth
            barFrame.size.height = barHeight
            // 值没变就别碰，避免每帧都刷新 collection view 造成闪烁
            if buttonBarView.frame != barFrame {
                buttonBarView.frame = barFrame
                // 宽度变了，每个 tab 的宽度要重算，并让布局失效一次
                cachedCellWidths = calculateWidths()
                buttonBarView.collectionViewLayout.invalidateLayout()
            }
        }

        // 2. 分页容器：跟着按钮条一起下移，高度扣掉顶部安全区和按钮条
        containerView.autoresizingMask = []
        let barHeight = settings.style.buttonBarHeight ?? 44
        var containerFrame = containerView.frame
        containerFrame.origin.x = insets.left
        containerFrame.origin.y = insets.top + barHeight
        containerFrame.size.width = availableWidth
        containerFrame.size.height = view.bounds.height - insets.top - barHeight - insets.bottom
        if containerView.frame != containerFrame {
            containerView.frame = containerFrame
        }
    }

    /// 每次布局前先把按钮条和容器摆好。这样紧接着的 viewDidLayoutSubviews 里，
    /// 父类算出来的 pageWidth（也就是 containerView.bounds.width）已经是收窄后的值了
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard isViewLoaded else { return }
        pp_applySafeAreaInsets()
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard isViewAppearing || isViewRotating else { return }

        cachedCellWidths = calculateWidths()
        buttonBarView.collectionViewLayout.invalidateLayout()
        // When the view first appears or is rotated we also need to ensure that the barButtonView's
        // selectedBar is resized and its contentOffset/scroll is set correctly (the selected
        // tab/cell may end up either skewed or off screen after a rotation otherwise)
        buttonBarView.moveTo(index: currentIndex, animated: false, swipeDirection: .none, pagerScroll: .scrollOnlyIfOutOfScreen)
        buttonBarView.selectItem(at: IndexPath(item: currentIndex, section: 0), animated: false, scrollPosition: [])
        
        buttonBarView.sendSubviewToBack(buttonBarView.selectedBar)
        buttonBarView.selectedBar.layer.zPosition = 0
    }

    // MARK: - 让分页宽度跟着可用宽度走

    /// 父类的实现里带了一项「居中修正」：拿容器宽度和自身宽度的差值折半再加到偏移上。
    /// 容器被我们收窄之后这个差值会变成负数，把每一页整体往左推，所以这里去掉它，
    /// 改成直接用容器宽度做步进 —— 这样跟父类里 pageOffsetForChild（决定滚动到第几页）的口径就一致了
    open override func offsetForChild(at index: Int) -> CGFloat {
        return CGFloat(index) * containerView.bounds.width
    }

    /// 父类给每一页定的宽度是 view.bounds.width，也就是整个窗口的宽度，这正是溢出的直接来源。
    /// 这里等它排完之后，把宽度改成可用宽度。
    /// 注意只改宽度、不动 x：x 是父类按当前滚动位置算好的（快速跨页切换时它还会临时调整页序），
    /// 跟着它走才不会错位。
    open override func updateContent() {
        super.updateContent()

        let availableWidth = pp_availableWidth
        // 没有分屏时可用宽度就等于自身宽度，不需要介入，完全保持父类原样
        guard availableWidth > 0, availableWidth < view.bounds.width - 0.5 else { return }

        for childController in viewControllers {
            // isViewLoaded 是安全检查，不会把「还没用到的页面」的 view 提前创建出来；
            // 再看一眼 superview，确认这一页此刻确实挂在分页容器里
            guard childController.isViewLoaded,
                  childController.view.superview === containerView else { continue }
            // 宽度已经对了就别重复赋值，省掉没必要的布局
            if abs(childController.view.frame.size.width - availableWidth) > 0.5 {
                childController.view.frame.size.width = availableWidth
            }
        }
    }

    // MARK: - Public Methods

    open override func reloadPagerTabStripView() {
        super.reloadPagerTabStripView()
        guard isViewLoaded else { return }
        buttonBarView.reloadData()
        cachedCellWidths = calculateWidths()
        buttonBarView.moveTo(index: currentIndex, animated: false, swipeDirection: .none, pagerScroll: .yes)
    }

    open func calculateStretchedCellWidths(_ minimumCellWidths: [CGFloat], suggestedStretchedCellWidth: CGFloat, previousNumberOfLargeCells: Int) -> CGFloat {
        var numberOfLargeCells = 0
        var totalWidthOfLargeCells: CGFloat = 0

        for minimumCellWidthValue in minimumCellWidths where minimumCellWidthValue > suggestedStretchedCellWidth {
            totalWidthOfLargeCells += minimumCellWidthValue
            numberOfLargeCells += 1
        }

        guard numberOfLargeCells > previousNumberOfLargeCells else { return suggestedStretchedCellWidth }

        let flowLayout = buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout // swiftlint:disable:this force_cast
        let collectionViewAvailiableWidth = buttonBarView.frame.size.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
        let numberOfCells = minimumCellWidths.count
        let cellSpacingTotal = CGFloat(numberOfCells - 1) * flowLayout.minimumLineSpacing

        let numberOfSmallCells = numberOfCells - numberOfLargeCells
        let newSuggestedStretchedCellWidth = (collectionViewAvailiableWidth - totalWidthOfLargeCells - cellSpacingTotal) / CGFloat(numberOfSmallCells)

        return calculateStretchedCellWidths(minimumCellWidths, suggestedStretchedCellWidth: newSuggestedStretchedCellWidth, previousNumberOfLargeCells: numberOfLargeCells)
    }

    open func updateIndicator(for viewController: PagerTabStripViewController, fromIndex: Int, toIndex: Int) {
        guard shouldUpdateButtonBarView else { return }
        buttonBarView.moveTo(index: toIndex, animated: false, swipeDirection: toIndex < fromIndex ? .right : .left, pagerScroll: .yes)

        if let changeCurrentIndex = changeCurrentIndex {
            let oldIndexPath = IndexPath(item: currentIndex != fromIndex ? fromIndex : toIndex, section: 0)
            let newIndexPath = IndexPath(item: currentIndex, section: 0)

            let cells = cellForItems(at: [oldIndexPath, newIndexPath], reloadIfNotVisible: collectionViewDidLoad)
            changeCurrentIndex(cells.first!, cells.last!, true)
        }
    }

    open func updateIndicator(for viewController: PagerTabStripViewController, fromIndex: Int, toIndex: Int, withProgressPercentage progressPercentage: CGFloat, indexWasChanged: Bool) {
        guard shouldUpdateButtonBarView else { return }
        buttonBarView.move(fromIndex: fromIndex, toIndex: toIndex, progressPercentage: progressPercentage, pagerScroll: .yes)
        if let changeCurrentIndexProgressive = changeCurrentIndexProgressive {
            let oldIndexPath = IndexPath(item: currentIndex != fromIndex ? fromIndex : toIndex, section: 0)
            let newIndexPath = IndexPath(item: currentIndex, section: 0)

            let cells = cellForItems(at: [oldIndexPath, newIndexPath], reloadIfNotVisible: collectionViewDidLoad)
            changeCurrentIndexProgressive(cells.first!, cells.last!, progressPercentage, indexWasChanged, true)
        }
    }

    private func cellForItems(at indexPaths: [IndexPath], reloadIfNotVisible reload: Bool = true) -> [ButtonBarViewCell?] {
        let cells = indexPaths.map { buttonBarView.cellForItem(at: $0) as? ButtonBarViewCell }

        if reload {
            let indexPathsToReload = cells.enumerated()
                .compactMap { (arg) -> IndexPath? in
                    let (index, cell) = arg
                    return cell == nil ? indexPaths[index] : nil
                }
                .compactMap { (indexPath: IndexPath) -> IndexPath? in
                    return (indexPath.item >= 0 && indexPath.item < buttonBarView.numberOfItems(inSection: indexPath.section)) ? indexPath : nil
                }

            if !indexPathsToReload.isEmpty {
                buttonBarView.reloadItems(at: indexPathsToReload)
            }
        }

        return cells
    }

    // MARK: - UICollectionViewDelegateFlowLayut

    @objc open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        guard let cellWidthValue = cachedCellWidths?[indexPath.row] else {
            fatalError("cachedCellWidths for \(indexPath.row) must not be nil")
        }
        return CGSize(width: cellWidthValue, height: collectionView.frame.size.height)
    }

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item != currentIndex else { return }

        buttonBarView.moveTo(index: indexPath.item, animated: true, swipeDirection: .none, pagerScroll: .yes)
        shouldUpdateButtonBarView = false

        let oldIndexPath = IndexPath(item: currentIndex, section: 0)
        let newIndexPath = IndexPath(item: indexPath.item, section: 0)

        let cells = cellForItems(at: [oldIndexPath, newIndexPath], reloadIfNotVisible: collectionViewDidLoad)

        if pagerBehaviour.isProgressiveIndicator {
            if let changeCurrentIndexProgressive = changeCurrentIndexProgressive {
                changeCurrentIndexProgressive(cells.first!, cells.last!, 1, true, true)
            }
        } else {
            if let changeCurrentIndex = changeCurrentIndex {
                changeCurrentIndex(cells.first!, cells.last!, true)
            }
        }
        moveToViewController(at: indexPath.item, animated: false)
        buttonBarView.sendSubviewToBack(buttonBarView.selectedBar)
        buttonBarView.selectedBar.layer.zPosition = 0
    }

    // MARK: - UICollectionViewDataSource

    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewControllers.count
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as? PPTabCollectionViewCell else {
            fatalError("UICollectionViewCell should be or extend from ButtonBarViewCell")
        }

        collectionViewDidLoad = true

        let childController = viewControllers[indexPath.item] as! IndicatorInfoProvider // swiftlint:disable:this force_cast
        let indicatorInfo = childController.indicatorInfo(for: self)

        cell.label.text = indicatorInfo.title
        cell.label.font = settings.style.buttonBarItemFont
        cell.label.textColor = settings.style.buttonBarItemTitleColor ?? cell.label.textColor
        cell.contentView.backgroundColor = settings.style.buttonBarItemBackgroundColor ?? cell.contentView.backgroundColor
        cell.backgroundColor = settings.style.buttonBarItemBackgroundColor ?? cell.backgroundColor

        cell.isAccessibilityElement = true
        cell.accessibilityLabel = indicatorInfo.accessibilityLabel ?? cell.label.text
        cell.accessibilityTraits.insert([.button, .header])
        cell.cellIndex = indexPath.item
        cell.closeButtonTappedHandler = { cellIndex in
//            debugPrint("=====\(cellIndex)")
            if self.vcs.count == 1 {
                self.navigationController?.popViewController(animated: true)
            }
            else {
                self.vcs.remove(at: cellIndex)
                self.reloadPagerTabStripView()
            }
        }
        return cell
    }

    // MARK: - UIScrollViewDelegate

    open override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        super.scrollViewDidEndScrollingAnimation(scrollView)

        guard scrollView == containerView else { return }
        shouldUpdateButtonBarView = true
    }

    open func configureCell(_ cell: ButtonBarViewCell, indicatorInfo: IndicatorInfo) {
    }

    private func calculateWidths() -> [CGFloat] {
        let flowLayout = buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout // swiftlint:disable:this force_cast
        let numberOfCells = viewControllers.count

        var minimumCellWidths = [CGFloat]()
        var collectionViewContentWidth: CGFloat = 0

        for viewController in viewControllers {
            let childController = viewController as! IndicatorInfoProvider // swiftlint:disable:this force_cast
            let indicatorInfo = childController.indicatorInfo(for: self)
            let textW = indicatorInfo.title?.pp_calcTextWidth(font: settings.style.buttonBarItemFont) ?? 0
            var width = textW + self.settings.style.buttonBarItemLeftRightMargin * 2 + 30 + 8 + 1
            width = min(width, 300.0) //限制最大宽度
            minimumCellWidths.append(width)
            collectionViewContentWidth += width
        }

        let cellSpacingTotal = CGFloat(numberOfCells - 1) * flowLayout.minimumLineSpacing
        collectionViewContentWidth += cellSpacingTotal

        let collectionViewAvailableVisibleWidth = buttonBarView.frame.size.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right

        if !settings.style.buttonBarItemsShouldFillAvailableWidth || collectionViewAvailableVisibleWidth < collectionViewContentWidth {
            return minimumCellWidths
        } else {
            let stretchedCellWidthIfAllEqual = (collectionViewAvailableVisibleWidth - cellSpacingTotal) / CGFloat(numberOfCells)
            let generalMinimumCellWidth = calculateStretchedCellWidths(minimumCellWidths, suggestedStretchedCellWidth: stretchedCellWidthIfAllEqual, previousNumberOfLargeCells: 0)
            var stretchedCellWidths = [CGFloat]()

            for minimumCellWidthValue in minimumCellWidths {
                let cellWidth = (minimumCellWidthValue > generalMinimumCellWidth) ? minimumCellWidthValue : generalMinimumCellWidth
                stretchedCellWidths.append(cellWidth)
            }

            return stretchedCellWidths
        }
    }

    private var shouldUpdateButtonBarView = true
    private var collectionViewDidLoad = false

}
