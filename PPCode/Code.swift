import Foundation

class PPPPP {
    func pp_alertController() {
        let alertController = UIAlertController(title: "title", message: "message", preferredStyle: .actionSheet)
        let defaultAction = UIAlertAction(title: "destructive", style: .destructive, handler: nil)
        alertController.addAction(defaultAction)
        
        let aaa = UIAlertAction(title: "default", style: .default, handler: nil)
        alertController.addAction(aaa)
        
        let bbb = UIAlertAction(title: "cancel", style: .cancel, handler: nil)
        alertController.addAction(bbb)
        
        self.present(alertController, animated: true, completion: nil)
        
    }
}
