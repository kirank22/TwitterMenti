//
//  ViewController.swift
//  Twittermenti
//
//  Created by Kiran Kothapalli on 2/14/2024
//
import UIKit
import TwitterAPIKit
import AuthenticationServices
import CoreML

class ViewController: UIViewController {
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var sentimentLabel: UILabel!
    
    let sentimentClassifier = TweetSentimentClassifier()
    
    var client: TwitterAPIClient!
    
    private var env: Env {
        //  Pull client ID from plist
        var string = String()
        if let infoPlistPath = Bundle.main.url(forResource: "Secrets", withExtension: "plist") {
            do {
                let infoPlistData = try Data(contentsOf: infoPlistPath)
                
                if let dict = try PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any] {
                    string = dict.values.first as! String
                }
            } catch {
                print(error)
            }
        }
        return Env(clientID: string)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        client = TwitterAPIClient(.requestOAuth20WithPKCE(.publicClient))
        signIn()
    }
    
    //  Service call and parsing
    @IBAction func predictPressed(_ sender: Any) {
        if let searchText = textField.text {
            Task {
                var tweetsToClassify = [TweetSentimentClassifierInput]()
                //  English tweets only for model
                let filteredQuery = searchText + " lang:en"
                //  Search Tweets
                let data = try await client.v2.search.searchTweetsRecent(.init(query: filteredQuery, maxResults: 100)).responseDecodable(type: TwitterDataResponseV2<[TwitterTweetV2], TwitterTweetV2.Meta>.self).result.get().data
                //  Convert tweets to model inputs
                for tweet in data {
                    let tweetToClassify = TweetSentimentClassifierInput(text: tweet.text)
                    tweetsToClassify.append(tweetToClassify)
                }
                //  Pass model inputs to model
                self.makePrediction(with: tweetsToClassify)
            }
        }
    }
    
    // MARK: - Private
    private func makePrediction(with tweets: [TweetSentimentClassifierInput]) {
        do {
            let predictions = try self.sentimentClassifier.predictions(inputs: tweets)
            var sentiScore = 0
            //  Adjust overall score
            for pred in predictions {
                let sentiment = pred.label
                if sentiment == "Pos" {
                    sentiScore += 1
                } else if sentiment == "Neg" {
                    sentiScore -= 1
                }
            }
            updateUI(with: sentiScore)
        } catch {
            print("There was an error with making a prediction, \(error)")
        }
    }
    
    private func updateUI(with sentimentScore: Int) {
        if sentimentScore > 20 {
            self.sentimentLabel.text = "😍"
        } else if sentimentScore > 10 {
            self.sentimentLabel.text = "😀"
        } else if sentimentScore > 0 {
            self.sentimentLabel.text = "🙂"
        } else if sentimentScore == 0 {
            self.sentimentLabel.text = "😐"
        } else if sentimentScore > -10 {
            self.sentimentLabel.text = "😕"
        } else if sentimentScore > -20 {
            self.sentimentLabel.text = "😡"
        } else {
            self.sentimentLabel.text = "🤮"
        }
    }

    //  Sign In to Twitter at start
    private func signIn() {
        let state = "xyz123"
        let clientID = env.clientID!
        //  Creating custom auth URL for our app
        let authorizeURL = client.auth.oauth20.makeOAuth2AuthorizeURL(.init(
            clientID: clientID,
            redirectURI: "twittermenti-kiran://",
            state: state,
            codeChallenge: "code challenge",
            codeChallengeMethod: "plain",
            scopes: ["tweet.read", "tweet.write", "users.read", "offline.access"]
        ))!

        //  Configure and start auth session
        let session = ASWebAuthenticationSession(url: authorizeURL, callbackURLScheme: "twittermenti-kiran") { [weak self] url, error in
            guard let self = self else { return }

            guard let url = url else {
                print(error!)
                return
            }
            print("return url", url)

            let component = URLComponents(url: url, resolvingAgainstBaseURL: false)

            guard let returnedState = component?.queryItems?.first(where: {$0.name == "state"})?.value,
                  let code = component?.queryItems?.first(where: { $0.name == "code" })?.value else {
                print("Invalid return url")
                return
            }
            guard state == returnedState else {
                print("Invalid state", state, returnedState)
                return
            }

            self.client.auth.oauth20.postOAuth2AccessToken(.init(
                code: code,
                clientID: clientID,
                redirectURI: "twittermenti-kiran://", codeVerifier: "code challenge"
            )).responseObject { response in
                do {
                    let token = try response.result.get()
                    //  Update client with token and ID
                    self.client = TwitterAPIClient(.oauth20(.init(clientID: clientID, token: token)))
                    self.showAlert(title: "Success!", message: nil) {
                        self.navigationController?.popViewController(animated: true)
                    }
                } catch let error {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true

        session.start()
    }
}

extension ViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}

extension UIViewController {

    func showAlert(title: String?, message: String?, tapOK block: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default) { _ in
            block?()
        })
        present(alert, animated: true)
    }
}

// Response Wrapper
public struct TwitterDataResponseV2<DataType: Decodable, Meta: Decodable>: Decodable {
    public var data: DataType
    public var meta: Meta?
}

// Response Decodable Object
struct TwitterTweetV2: Decodable {
    struct Meta: Decodable {
        var resultCount: Int
    }
    var id: String
    var text: String
}
