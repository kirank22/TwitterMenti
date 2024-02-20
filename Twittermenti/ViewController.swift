//
//  ViewController.swift
//  Twittermenti
//
//  Created by Kiran Kothapalli on 2/14/2024
//

// When authenticating with OAuth 1.0a, rewrite consumerKey and consumerSecret.
private let consumerKey = "eJI7WV4CN0QZpr53pDgsZkKKx"
private let consumerSecret = "f7yEWHgtEbw7JmztyH070bP1XUBE3UkTDFhNViMMuPRzJDIgrj"

// If you want to authenticate with OAuth 20 Public Client, please rewrite the clientID.
// When authenticating with OAuth 20's Confidential Client, rewrite clientID and Client Secret.
// For more information, please visit https://github.com/mironal/TwitterAPIKit/blob/main/HowDoIAuthenticate.md
private let clientID = "TWJFRmNkMlVXa25pcUJxbEU4V2U6MTpjaQ"
private let clientSecret = "l42_eTqxajMAyEkw1NwvL0gfaxfP_fpp2zRDHX9_fwqZoOTtLc"

import UIKit
import TwitterAPIKit
import AuthenticationServices

class ViewController: UIViewController {
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var sentimentLabel: UILabel!
    
    var client: TwitterAPIClient!
    
    private var env = Env(clientID: clientID, clientSecret: clientSecret)

    @IBAction func predictPressed(_ sender: Any) {
        Task {
            let response = await client.v2.user.getMe(.init()).responseData
            print(response.prettyString)
            
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        client = TwitterAPIClient(.requestOAuth20WithPKCE(.publicClient))
        signIn()
    }

    // MARK: - Private
    private func signIn() {
        let state = "xyz123" // Rewrite your state

        let clientID = env.clientID!
        let authorizeURL = client.auth.oauth20.makeOAuth2AuthorizeURL(.init(
            clientID: clientID,
            redirectURI: "twittermenti-kiran://", // Rewrite your scheme
            state: state,
            codeChallenge: "code challenge",
            codeChallengeMethod: "plain", // OR S256
            scopes: ["tweet.read", "tweet.write", "users.read", "offline.access"]
        ))!

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
                    self.updateClientWithToken(token: .init(clientID: clientID, token: token))
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
    
    private func updateClientWithToken(token: TwitterAuthenticationMethod.OAuth20) {
        self.client = TwitterAPIClient(.oauth20(token))
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
