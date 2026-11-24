//
//  PPEasyTableView.swift
//  PandaNote
//
//  Created by pan on 2026/11/10.
//  Copyright © 2026 Panway. All rights reserved.
//

import UIKit
/*
 
 */
/// 单 section、单 cell 类型的快速列表容器，替代 XDFastTableView。
///
/// 外层仍是 UIView（不是 UITableView），调用方可以直接在外层做 cornerRadius + shadow，
/// 内部 tableView 用 anchor 贴满四边，不再写死屏幕尺寸。
///
/// ```swift
/// let table = PPEasyTableView<String, PPEasyTextCell>()
/// view.addSubview(table)
/// table.snp.makeConstraints { make in make.edges.equalToSuperview() }
/// table.items = ["A", "B"]        // 赋值即刷新
/// table.didSelectRow = { index, item in print(index, item) }
/// ```
///
/// cell 类型由泛型在编译期确定，所以没有 registerCellClass，也不存在忘记注册导致的运行时崩溃；
/// 代价是这个类用不了 ObjC 和 Interface Builder，delegate 方法也必须写在类体里
/// （泛型类的 extension 不能有 @objc 成员）。
final class PPEasyTableView<Item, Cell: PPEasyTableViewCell<Item>>: UIView, UITableViewDataSource, UITableViewDelegate {

    // MARK: - 配置

    /// 内部真实的 tableView，需要 visibleRows、cellForRow、contentOffset 这类操作时直接用它。
    let tableView: UITableView

    /// 列表数据，赋值即整表刷新。这里是唯一数据源，外部不要再维护第二份数组。
    var items: [Item] = [] {
        didSet { tableView.reloadData() }
    }

    /// 行高。设为 .automaticDimension 走 cell 自适应高度。
    var rowHeight: CGFloat = 44 {
        didSet { applyRowHeight() }
    }

    /// 逐行指定高度，设置后优先于 rowHeight。
    var heightForItem: ((Item, Int) -> CGFloat)?

    /// 是否允许左滑删除，默认关闭。XDFastTableView 里所有表都能左滑删，配置页也不例外，这里改成显式开启。
    var allowsDelete = false

    /// 点击某行，回调 (index, item)。
    var didSelectRow: ((Int, Item) -> Void)?

    /// 左滑删除。内部已把该行从 items 移除，回调 (原 index, 被删的 item)，外部据此同步自己的 model。
    var didDeleteRow: ((Int, Item) -> Void)?

    // MARK: - 初始化

    init(style: UITableView.Style = .plain, frame: CGRect = .zero) {
        tableView = UITableView(frame: .zero, style: style)
        super.init(frame: frame)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()  // 去掉末尾多余的分割线
        tableView.register(Cell.self, forCellReuseIdentifier: Cell.pp_reuseIdentifier)
        addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        applyRowHeight()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PPEasyTableView 是泛型类，只能在代码里创建")
    }

    // MARK: - 公开方法

    func reloadData() {
        tableView.reloadData()
    }

    /// 只刷新一行，替代“改完 model 再整表 reloadData”。
    func reloadItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }

    private func applyRowHeight() {
        tableView.rowHeight = rowHeight
        // 自适应高度必须有非 0 的预估值，否则首次布局会跳一下；固定行高则关掉预估，省掉无用计算
        tableView.estimatedRowHeight = (rowHeight == UITableView.automaticDimension) ? 44 : 0
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 类型由 init 里的 register 保证，这里的强转不会失败
        let cell = tableView.dequeueReusableCell(withIdentifier: Cell.pp_reuseIdentifier, for: indexPath) as! Cell
        cell.pp_apply(item: items[indexPath.row], at: indexPath.row)
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let heightForItem = heightForItem else { return rowHeight }
        return heightForItem(items[indexPath.row], indexPath.row)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        didSelectRow?(indexPath.row, items[indexPath.row])
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return allowsDelete ? .delete : .none
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, items.indices.contains(indexPath.row) else { return }
        let removed = items.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
        didDeleteRow?(indexPath.row, removed)
    }
}

/// cell 基类：setupSubviews 只在创建时调一次，configure 每次复用都调。
class PPEasyTableViewCell<Item>: UITableViewCell {

    /// 当前这一行的数据，configure 之后可读，cell 内部的按钮回调用得上。
    private(set) var item: Item?

    static var pp_reuseIdentifier: String {
        return String(describing: self)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PPEasyTableViewCell 只能在代码里创建")
    }

    /// PPEasyTableView 通过这个入口调用 cell：先存下 item，再交给子类的 configure。不要重写。
    final func pp_apply(item: Item, at index: Int) {
        self.item = item
        configure(with: item, at: index)
    }

    /// 子类在这里创建并约束子视图，整个 cell 生命周期只调用一次。
    func setupSubviews() {}

    /// 子类在这里把 item 填到 UI 上。基类什么都不做，也不像 XDFastTableView 那样兜底写 textLabel。
    func configure(with item: Item, at index: Int) {}

    override func prepareForReuse() {
        super.prepareForReuse()
        item = nil
    }
}

/// 纯文本 cell，对应 XDFastTableView 里 PandaFastTableViewCell 直接显示 String 的场景。
final class PPEasyTextCell: PPEasyTableViewCell<String> {

    override func configure(with item: String, at index: Int) {
        textLabel?.text = item
    }
}
