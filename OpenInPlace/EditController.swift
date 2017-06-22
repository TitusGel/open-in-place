//
//  DetailViewController.swift
//  OpenInPlace
//
//  Created by Anders Borum on 21/06/2017.
//  Copyright © 2017 Applied Phasor. All rights reserved.
//

import UIKit

class EditController: UIViewController, UITextViewDelegate, NSFilePresenter {
    
    private var securityScoped = false
    
    @IBOutlet var textView: UITextView!
    private func loadContent() {
        // do not load unless we have both url and view loaded
        guard isViewLoaded else { return }
        guard url != nil else {
            self.navigationItem.title = "<DELETED>"
            self.textView.text = ""
            return
        }
        
        navigationItem.title = _url?.lastPathComponent
        
        let coordinator = NSFileCoordinator(filePresenter: self)
        url!.coordinatedRead(coordinator, callback: { (text, error) in
            
            if(error != nil) {
                self.showError(error!)
            } else {
                self.textView.text = text
            }
            
        })
    }
    
    private var unwrittenChanges = false
    private func writeContentIfNeeded(callback: ((Error?) -> ())) {
        guard unwrittenChanges else {
            callback(nil)
            return
            
        }
        unwrittenChanges = false
        
        guard url != nil else { return }
        let coordinator = NSFileCoordinator(filePresenter: self)
        url!.coordinatedWrite(textView.text, coordinator, callback: callback)
    }
    
    // calls writeContentIfNeeded(callback:) showing errors
    @objc private func writeContentShowingError() {
        
        writeContentIfNeeded(callback: { error in
            if(error != nil) {
                self.showError(error!)
            }
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadContent()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // clean up when removed
        if url != nil && self.isMovingFromParentViewController {
            url = nil
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private var _url: URL?
    public var url: URL? {
        set {
            if(_url != nil) {
                if securityScoped {
                    _url!.stopAccessingSecurityScopedResource()
                    securityScoped = false
                }
                NSFileCoordinator.removeFilePresenter(self)
            }
            
            _url = newValue
            
            if(_url != nil) {
                securityScoped = _url!.startAccessingSecurityScopedResource()
                NSFileCoordinator.addFilePresenter(self)
            }
            loadContent()
        }
        get {
            return _url
        }
    }

    //MARK: - NSFilePresenter
    var presentedItemURL: URL? {
        return url
    }
    
    private var presenterQueue : OperationQueue?
    var presentedItemOperationQueue: OperationQueue {
        if(presenterQueue == nil) {
            presenterQueue = OperationQueue()
        }
        return presenterQueue!
    }
    
    // file was changed by someone else and we want to reload
    func presentedItemDidChange() {
        loadContent()
    }
    
    // someone wants to read the file and we make sure pending changes are written
    func relinquishPresentedItem(toReader reader: @escaping ((() -> Void)?) -> Void) {
        writeContentIfNeeded(callback: { error in
            reader(nil)
        })
    }
    
    // someone wants to write the file and we make sure pending changes are written
    func relinquishPresentedItem(toWriter writer: @escaping ((() -> Void)?) -> Void) {
        writeContentIfNeeded(callback: { error in
            writer(nil)
        })
    }
    
    // file is being renamed by someone else and we keep work in new file location
    func presentedItemDidMove(to newURL: URL) {
        url = newURL
    }
    
    // file is being deleted and we stop tracking it
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        url = nil
        completionHandler(nil)
    }
    
    //MARK: - UITextViewDelegate
    
    func textViewDidChange(_ textView: UITextView) {
        // we want to write changes, but not after every keystroke and wait for a
        // whole second without changes
        unwrittenChanges = true
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(writeContentShowingError), object: nil)
        perform(#selector(writeContentShowingError), with: nil, afterDelay: 1.0)
    }
    
    //MARK: -
    
}

