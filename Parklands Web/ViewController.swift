//
//  ViewController.swift
//  Parklands Web
//
//  Created by Stephan Cilliers on 2017/05/16.
//  Copyright © 2017 Stephan Cilliers. All rights reserved.
//

import UIKit
import WebKit

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, UITextFieldDelegate {

	var webView: WKWebView!
	
	var searchBar: UIView!
	var searchField: UITextField!
	
	var backButton: UIBarButtonItem!
	var forwardButton: UIBarButtonItem!
	var homeButton: UIButton!
	var reloadButton: UIButton!
	
	var darkOrange: UIColor = UIColor(red: 250/255, green: 192/255, blue: 46/255, alpha: 1)
	
	var progressBarView: UIView!
	
	var pageEditorSource: String!
	
	var blockedWords: [String]?
	var blockedHosts: [String]?
	
	var requests: [()->()] = []
	var requestsToComplete: Int = 0

	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Add requests to queue
		requests = [getBlockedWords, getBlockedHosts]
		requestsToComplete = requests.count
		
		// Execute requests
		for request in requests {
			request()
		}
		
		// Starting page
		let myURL = URL(string: "http://www.kiddle.co")
		let myRequest = URLRequest(url: myURL!)
		webView.load(myRequest)
		
		setupNavigationBar()
	}
	
	override func loadView() {
		super.loadView()
		
		// Create WebView
		webView = WKWebView(frame: .zero)
		webView.uiDelegate = self
		webView.navigationDelegate = self
		webView.allowsBackForwardNavigationGestures = true
		view = webView
	}
	
	/* WebKit */
	func goBack() {
		self.webView.goBack()
	}
	
	func goForward() {
		self.webView.goForward()
	}
	
	func goHome() {
		self.searchField.text = ""
		self.webView.goHome()
	}
	
	func reload() {
		self.webView.load(URLRequest.init(url: self.webView.url!))
	}
	
	func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
		print("committed")
		backButton.isEnabled = webView.canGoBack
		forwardButton.isEnabled = webView.canGoForward
		
		startProgressBar()
	}
	
	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		print(error)
		cancelProgressBar()
		if (webView.canGoBack) {
			webView.goBack()
		}
	}
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		print("finished")
		completeProgressBar()
	}
	
	/* External resources */
	
	func getBlockedWords() {
		/*
		-	Fetch words to be censored
		*/
		let endpoint = URL(string: "https://cdn.rawgit.com/stephancill/Parklands-Web/38650c09/blocked-words.txt")

		URLSession.shared.dataTask(with: endpoint!) { (data, response, error) in
			var words = String.init(data: data!, encoding: .utf8)?.components(separatedBy: "\n")
			let _ = words?.popLast()
			self.blockedWords = words
			self.asyncRequestComplete(error: error)
		}.resume()
	}
	
	func getBlockedHosts() {
		/*
		-	Fetch blocked hosts
		*/
		let endpoint = URL(string: "https://cdn.rawgit.com/stephancill/Parklands-Web/38650c09/blocked-hosts.txt")
		
		URLSession.shared.dataTask(with: endpoint!) { (data, response, error) in
			var hosts = String.init(data: data!, encoding: .utf8)?.components(separatedBy: "\n")
			let _ = hosts?.popLast()
			self.blockedHosts = hosts
			self.asyncRequestComplete(error: error)
		}.resume()
	}
    
	
    
    func asyncRequestComplete(error: Error?) {
		/* 
		-	Handle complete request
		*/
        if error != nil {  return }
        requestsToComplete -= 1
		print("Requests remaining: ", requestsToComplete)
        if requestsToComplete == 0 {
            if let source = createPageEditorScript() {
                addPageEditorScript(source: source)
            }
        }
    }
    
    func createPageEditorScript() -> String? {
		/*
		-	Populate the JS base script with external resources
		*/
		guard let hosts = blockedHosts, let words = blockedWords else {
			return nil
		}
		
        var source = ""
        source += "var words = \(words)\n"
        source += "var hosts = \(hosts)\n"
        do {
            if let path = Bundle.main.path(forResource: "page-editor", ofType:"js") {
                source += try String.init(contentsOf: URL(fileURLWithPath: path))
				print(source)
				return source
            } else {
                throw ScriptCreationError.creationFailure
            }
        } catch {
            print("Could not load words")
        }
        return nil
    }
	
	func addPageEditorScript(source: String) {
		/*
		-	Add source to webView
		*/
		let scriptPostLoad = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
		self.webView.configuration.userContentController.addUserScript(scriptPostLoad)
	}
	
	/* UI */
	
	func textFieldDidBeginEditing(_ textField: UITextField) {
		textField.selectAll(self)
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		let text = textField.text!
		let escapedAddress = text.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
		let queryString = "http://www.kiddle.co/s.php?q=\(escapedAddress!)"
		
		webView.load(queryString)
		textField.endEditing(true)
		return true
	}
	
	func textFieldDidEndEditing(_ textField: UITextField) {
		textField.textAlignment = .center
	}
	
	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		self.tearDownNavigationBar()
		self.setupNavigationBar()
	}
	
	func setupNavigationBar() {
		let bar = (self.navigationController?.navigationBar)!
		
		searchBar = UIView(frame: CGRect.init(x: 0, y: 0, width: 500, height: 30))
		if self.view.frame.width < 600 {
			searchBar.setWidth(self.view.frame.width * 40/100)
		}
		searchBar.frame.origin = CGPoint(x: bar.frame.width / 2 - searchBar.frame.width / 2, y: bar.frame.height / 2 - searchBar.frame.height / 2)
		searchBar.backgroundColor = .white
		searchBar.layer.cornerRadius = 7
		searchBar.layer.opacity = 0.75
		searchBar.layer.borderColor = darkOrange.cgColor
		searchBar.layer.shadowOffset = CGSize(width: 1, height: 1)
		searchBar.layer.shadowRadius = 2
		searchBar.layer.shadowColor = UIColor.gray.cgColor
		searchBar.layer.shadowOpacity = 0.3
		
		if self.view.frame.width < 600 {
			searchBar.setWidth(self.view.frame.width * 60/100)
		}
		
		searchField = UITextField(frame: CGRect.init(x: 0, y: 0, width: searchBar.frame.width * 95/100, height: 30))
		searchField.backgroundColor = .clear
		searchField.frame.origin = CGPoint(x: searchBar.frame.width / 2 - searchField.frame.width / 2, y: searchBar.frame.height / 2 - searchField.frame.height / 2)
		searchField.autocorrectionType = .no
		searchField.autocapitalizationType = .none
		searchField.placeholder = "Search..."
		searchField.textAlignment = .center
		searchField.delegate = self
		searchBar.addSubview(searchField)
		
		backButton = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(goBack))
		backButton.tintColor = darkOrange
		backButton.isEnabled = false
		self.navigationItem.setLeftBarButton(backButton, animated: true)
		
		forwardButton = UIBarButtonItem(title: "Forward", style: .plain, target: self, action: #selector(goForward))
		forwardButton.tintColor = darkOrange
		forwardButton.isEnabled = false
		self.navigationItem.setRightBarButton(forwardButton, animated: true)
		
		homeButton = UIButton(frame: CGRect.init(x: 0, y: 0, width: searchBar.frame.height * 96/100, height: searchBar.frame.height * 96/100))
		homeButton.frame.origin = CGPoint(x: searchBar.frame.minX - homeButton.frame.width - 12, y: searchBar.frame.height / 2 - homeButton.frame.height / 2 + 7)
		homeButton.setImage(UIImage.init(named: "icn-home"), for: .normal)
		homeButton.addTarget(self, action: #selector(goHome), for: .touchUpInside)
		
		reloadButton = UIButton(frame: CGRect.init(x: 0, y: 0, width: searchBar.frame.height * 96/100, height: searchBar.frame.height * 96/100))
		reloadButton.frame.origin = CGPoint(x: searchBar.frame.maxX + reloadButton.frame.width - 20, y: searchBar.frame.height / 2 - reloadButton.frame.height / 2 + 6)
		reloadButton.setImage(UIImage.init(named: "icn-reload"), for: .normal)
		reloadButton.addTarget(self, action: #selector(reload), for: .touchUpInside)
		
		progressBarView = UIView(frame: CGRect.init(x: 0, y: searchBar.frame.maxY + 6, width: bar.frame.width, height: 2))
		progressBarView.backgroundColor = .blue
		progressBarView.setWidth(0)
		
		bar.barStyle = .default
		bar.tintColor = darkOrange
		bar.backgroundColor = darkOrange

		bar.addSubviews([searchBar, homeButton, reloadButton, progressBarView])
	}
	
	func tearDownNavigationBar() {
		for view in [searchBar, homeButton, reloadButton, progressBarView] {
			view?.removeFromSuperview()
		}
	}
	
	func startProgressBar() {
		progressBarView.backgroundColor = darkOrange
		progressBarView.setWidth(0)
		UIView.animate(withDuration: 2) {
			self.progressBarView.setWidth(self.view.frame.width - 100)
		}
	}
	
	func completeProgressBar() {
		UIView.animate(withDuration: 0.5) {
			self.progressBarView.setWidth(self.view.frame.width)
		}
		
		UIView.animate(withDuration: 0.5, animations: {
			self.progressBarView.backgroundColor = .clear
		}) { (bool) in
			self.progressBarView.setWidth(0)
		}
	}
	
	func cancelProgressBar() {
		UIView.animate(withDuration: 0.5, animations: {
			self.progressBarView.backgroundColor = .clear
		}) { (bool) in
			self.progressBarView.setWidth(0)
		}
	}

}

enum ScriptCreationError: Error {
    case creationFailure
}

extension UINavigationBar {
	func addSubviews(_ views: [UIView]) {
		for view in views {
			self.addSubview(view)
		}
	}
}

extension WKWebView {
	func load(_ link: String) {
		let myURL = URL(string: link)
		let myRequest = URLRequest(url: myURL!)
		self.load(myRequest)
	}
	
	func goHome() {
		let currentPage = self.url?.absoluteString
		if currentPage != "http://m.kiddle.co/" {
			load("http://m.kiddle.co/")
		}
	}
}

extension UIView {
	func setWidth(_ width: CGFloat) {
		self.frame = CGRect(origin: self.frame.origin, size: CGSize.init(width: width, height: self.frame.height))
	}
}




