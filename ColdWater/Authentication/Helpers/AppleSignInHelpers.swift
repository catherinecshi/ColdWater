import CryptoKit
import AuthenticationServices

// Helper delegate for Apple Sign In
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completionHandler: (ASAuthorization?, Error?) -> Void
    
    init(completionHandler: @escaping (ASAuthorization?, Error?) -> Void) {
        self.completionHandler = completionHandler
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completionHandler(authorization, nil)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completionHandler(nil, error)
    }
}

// Context provider for Apple Sign In
class PresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    private let presentingViewController: UIViewController
    
    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
        super.init()
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return presentingViewController.view.window!
    }
}

// Helper delegate for Apple Sign In with async/await
class AppleSignInContinuationDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let continuation: CheckedContinuation<ASAuthorization, Error>
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}
