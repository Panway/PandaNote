/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The table view controller responsible for displaying the filtered products as the user types in the search field.
*/

import UIKit

class PPResultsTableController: UITableViewController {
        
    var filteredProducts = [PPFileObject]()
    
//    @IBOutlet weak var resultsLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(PPFileListTableViewCell.self, forCellReuseIdentifier: kPPBaseCellIdentifier)

    }
   
    // MARK: - UITableViewDataSource 展示搜索结果列表数据源
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredProducts.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kPPBaseCellIdentifier, for: indexPath) as! PPFileListTableViewCell
        let fileObj = self.filteredProducts[indexPath.row]
        cell.updateUIWithData(fileObj as AnyObject)
        return cell
    }
}
