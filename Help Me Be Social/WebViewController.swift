//
//  WebViewController.swift
//  Help Me Be Social
//
//  Created by Venkatesh Sivaraman on 10/22/17.
//  Copyright © 2017 Hack Harvard 2017. All rights reserved.
//

import UIKit

class WebViewController: UIViewController, UIWebViewDelegate {

    @IBOutlet var webView: UIWebView?
    @IBOutlet var backButton: UIBarButtonItem?
    @IBOutlet var forwardButton: UIBarButtonItem?
    @IBOutlet var activityIndicatorItem: UIBarButtonItem?
    @IBOutlet var activityIndicator: UIActivityIndicatorView?
    
    var url: URL? {
        didSet {
            if webView != nil, let newURL = url {
                webView?.loadRequest(URLRequest(url: newURL))
            }
        }
    }
    
    func updateButtons() {
        backButton?.isEnabled = webView?.canGoBack ?? false
        forwardButton?.isEnabled = webView?.canGoForward ?? false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let newURL = url {
            webView?.loadRequest(URLRequest(url: newURL))
        }
        activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
        activityIndicator?.hidesWhenStopped = true
        activityIndicatorItem?.customView = activityIndicator
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.setToolbarHidden(false, animated: true)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func backButtonPressed(_ sender: AnyObject) {
        webView?.goBack()
    }
    
    @IBAction func forwardButtonPressed(_ sender: AnyObject) {
        webView?.goForward()
    }
    
    @IBAction func reloadButtonPressed(_ sender: AnyObject) {
        webView?.reload()
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        updateButtons()
        activityIndicator?.stopAnimating()
        navigationItem.title = webView.stringByEvaluatingJavaScript(from: "document.title")
    }
    
    func webViewDidStartLoad(_ webView: UIWebView) {
        activityIndicator?.startAnimating()
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        activityIndicator?.stopAnimating()
        updateButtons()
        let alert = UIAlertController(title: "Error Loading Page", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
