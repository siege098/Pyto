//
//  ProjectsBrowserViewController.swift
//  Pyto
//
//  Created by Adrian Labbé on 21-02-20.
//  Copyright © 2020 Adrian Labbé. All rights reserved.
//

import UIKit

/// A View controller for managing projects.
@available(iOS 13.0, *)
class ProjectsBrowserViewController: UITableViewController, UIDocumentPickerDelegate {
    
    /// Recent projects.
    var recent: [URL] = [] {
        didSet {
            _recent = recent
        }
    }
    
    private var _recent: [URL] {
        set {
            var strings = [String]()
            
            for url in newValue {
                do {
                    strings.append((try url.bookmarkData()).base64EncodedString())
                } catch {
                    continue
                }
            }
            
            UserDefaults.standard.set(strings, forKey: "recentProjects")
        }
        
        get {
            guard let urlsData = UserDefaults.standard.stringArray(forKey: "recentProjects") else {
                return []
            }
            
            var urls = [URL]()
            
            for url in urlsData {
                guard let data = Data(base64Encoded: url) else {
                    continue
                }
                
                do {
                    var isStale = false
                    urls.append((try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)))
                    sleep(UInt32(0.02))
                } catch {
                    continue
                }
            }
            
            return urls
        }
    }
    
    /// Opens a project at given URL.
    ///
    /// - Parameters:
    ///     - url: The URL of the folder to open.
    ///     - viewController: A View controller where the project should be presented.
    ///     - show: If set to `true` (default), the project navigator will be shown.
    ///
    /// - Returns: The view controller.
    @discardableResult func open(url: URL, viewController: UIViewController? = nil, show: Bool = true) -> UIViewController {
        
        if let i = recent.index(of: url) {
            recent.remove(at: i)
        }
        recent.insert(url, at: 0)
                
        _ = url.startAccessingSecurityScopedResource()
        
        let uiSplitVC = EditorSplitViewController.ProjectSplitViewController()
        
        //uiSplitVC.editor = splitVC
        #if Xcode11
        uiSplitVC.preferredDisplayMode = .primaryHidden
        #else
        uiSplitVC.preferredDisplayMode = .allVisible
        #endif
        uiSplitVC.view.backgroundColor = .systemBackground
        uiSplitVC.modalPresentationStyle = .fullScreen
        
        let browser = FileBrowserViewController()
        browser.directory = url
        browser.navigationItem.largeTitleDisplayMode = .always
        let browserNavVC = UINavigationController(rootViewController: browser)
        browserNavVC.navigationBar.prefersLargeTitles = true
        browserNavVC.navigationBar.sizeToFit()
        
        uiSplitVC.viewControllers = [browserNavVC]
        
        if show {
            if let vc = viewController {
                vc.present(uiSplitVC, animated: true, completion: nil)
            } else {
                let presenting = presentingViewController
                dismiss(animated: true) {
                    presenting?.present(uiSplitVC, animated: true, completion: nil)
                }
            }
        }
        
        return uiSplitVC
    }
    
    /// Closes the View controller.
    @IBAction func close(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Table view controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DispatchQueue.global().async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.recent = self._recent
            DispatchQueue.main.async { [weak self] in
                
                guard let self = self else {
                    return
                }
                
                self.tableView.reloadData()
            }
        }
        
        title = Localizable.ProjectsBrowser.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        
        tableView.backgroundColor = .systemGroupedBackground
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let header = UIView()
        header.backgroundColor = .clear
        header.frame.size.height = 30
        tableView.tableHeaderView = header
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return Localizable.ProjectsBrowser.recent
        } else {
            return nil
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return recent.count
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let picker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
            picker.delegate = self
            picker.directoryURL = DocumentBrowserViewController.iCloudContainerURL ?? DocumentBrowserViewController.localContainerURL
            present(picker, animated: true, completion: nil)
        } else {
            let url = recent[indexPath.row]
            _ = url.startAccessingSecurityScopedResource()
            open(url: url)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath {
        case IndexPath(row: 0, section: 0):
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.imageView?.image = UIImage(systemName: "arrow.up.right.square.fill")
            cell.backgroundColor = .secondarySystemGroupedBackground
            cell.textLabel?.text = Localizable.ProjectsBrowser.open
            return cell
        default:
            if indexPath.section == 1 {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.imageView?.image = UIImage(systemName: "cube.box.fill")
                cell.textLabel?.text = FileManager.default.displayName(atPath: recent[indexPath.row].path)
                
                if recent[indexPath.row].path.hasSuffix("com~apple~CloudDocs/Documents/") || recent[indexPath.row].path.hasSuffix("com~apple~CloudDocs/Desktop/") || recent[indexPath.row].path.hasSuffix("com~apple~CloudDocs/Documents") || recent[indexPath.row].path.hasSuffix("com~apple~CloudDocs/Desktop") {
                    
                    cell.textLabel?.text = recent[indexPath.row].lastPathComponent
                }
                
                cell.backgroundColor = .secondarySystemGroupedBackground
                return cell
            } else {
                return UITableViewCell()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete, recent.indices.contains(indexPath.row) {
            recent.remove(at: indexPath.row)
            tableView.reloadData()
        }
    }
    
    // MARK: - Document picker delegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        _ = urls[0].startAccessingSecurityScopedResource()
        open(url: urls[0])
    }
}
