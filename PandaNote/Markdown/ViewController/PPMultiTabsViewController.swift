//
//  PPMultiTabsViewController.swift
//  PandaNote
//
//  Created by pan on 2024/3/5.
//  Copyright © 2024 Panway. All rights reserved.
//

import Foundation
import XLPagerTabStrip

class PPMultiTabsViewController: PPButtonBarTabViewController {

    
    override public func viewControllers(for pagerTabStripController: PagerTabStripViewController) -> [UIViewController] {
      return vcs
    }
    
    init(vcs: [UIViewController]) {
        super.init(nibName: nil, bundle: nil)
        self.vcs = vcs
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        // Mac 上是用鼠标点的，不需要手指那么大的点击区。
        // 而且标签文字和关闭按钮都是贴着底边排的（见 PPTabCollectionViewCell 的约束），
        // 高度给到 80 时上面 46 点全是空白，整条看着又高又空，
        // 所以 Catalyst 下压到 44 —— 这是系统控件的最小标准点击高度，文字和 x 都在中间偏下的位置，
        // 视觉上刚好。iPad 保持原来的 80，那里本来就要照顾手指点击
        #if targetEnvironment(macCatalyst)
        self.settings.style.buttonBarHeight = 44
        #else
        self.settings.style.buttonBarHeight = 80
        #endif
        super.viewDidLoad()
    }

    // MARK: - 进这个页面时藏掉系统导航栏
    //
    // 这个页面自己已经有一条标签栏，系统导航栏再压一条上去就是两层标题，
    // 而且 Mac Catalyst 下导航栏是浮层，会把标签栏整个盖住（之前关闭按钮点不到的根因也是它）。
    // 所以进来时把导航栏收起来，让标签栏直接顶到窗口最上面。
    //
    // 离开时必须还原：从这个页面再 push 出去的普通页面还要靠导航栏显示标题和返回按钮，
    // 所以这里记下进来之前的隐藏状态，走的时候原样恢复，而不是一刀切地设成 false。

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 只在「第一次进来」时记一次原状态，避免来回切换标签页把状态记串
        if let navigationController = navigationController, !pp_hasStashedNavigationBarState {
            pp_navigationBarWasHidden = navigationController.isNavigationBarHidden
            pp_hasStashedNavigationBarState = true
        }
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard pp_hasStashedNavigationBarState else { return }
        navigationController?.setNavigationBarHidden(pp_navigationBarWasHidden, animated: animated)
        pp_hasStashedNavigationBarState = false
    }

    /// 进来之前导航栏的隐藏状态（用于还原）
    private var pp_navigationBarWasHidden = false
    /// 有没有记过状态：没记过就不去还原，免得把别人的导航栏改成显示
    private var pp_hasStashedNavigationBarState = false
}
