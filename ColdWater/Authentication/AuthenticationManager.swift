import Combine
import CryptoKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices

/// Types of Errors Authentication Manager can throw
enum AuthError: Error {
    case missingClientID
    case signInCancelled
    case missingCredentials
    case unknown(message: String)
    case notAuthenticated
    case notAnonymous
}

/// Defining AuthenticationManager behaviors for testing purposes
protocol AuthenticationServiceProtocol {
    var isUserAuthenticated: Bool { get }
    var isAnonymous: Bool { get }
    var isLoading: Bool { get }
    var currentUser: CWUser? { get }
    
    // publisher for loading state - for binding
    var isLoadingPublisher: Published<Bool>.Publisher { get }
    
    func login(email: String, password: String) -> Future<CWUser?, Error>
    func signUp(email: String, password: String) -> Future<CWUser?, Error>
    func googleSignIn(presentingViewController: UIViewController) -> Future<CWUser?, Error>
    func appleSignIn(presentingViewController: UIViewController) -> Future<CWUser?, Error>
    func signInAnonymously() -> Future<CWUser?, Error>
    func convertAnonymousUserWithEmail(email: String, password: String) -> Future<CWUser?, Error>
    func convertAnonymousUserWithGoogle(presentingViewController: UIViewController) async throws -> CWUser
    func signOut() -> Future<Void, Error>
    func deleteCurrentAccount() -> Future<Void, Error>
}

/// Handles all interaction with FirebaseAuth from authentication models
class AuthenticationManager: AuthenticationServiceProtocol, Resettable, ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published private(set) var currentUser: CWUser?
    @Published private(set) var isLoading: Bool = false // flag for when an operation is processing
    private var cancellables = Set<AnyCancellable>()
    private var currentNonce: String? // for apple sign in security
    private var currentAppleSignInDelegate: ASAuthorizationControllerDelegate? // for apple sign in delegate storage

    /// Returns true when user is logged in
    var isUserAuthenticated: Bool {
        return Auth.auth().currentUser != nil
    }
    
    /// Returns true when the current user is anonymously logged in
    var isAnonymous: Bool {
        return Auth.auth().currentUser?.isAnonymous ?? false
    }
    
    /// Publishes loading status
    var isLoadingPublisher: Published<Bool>.Publisher {
        return $isLoading
    }
    
    /// Initializes Authentication Manager
    /// - Establishes Firebase authentication state listener for
    ///     - Sign-ins
    ///     - Sign-outs
    ///     - Session expirations
    ///     - Authentication revocations
    /// - Updates currentUser accordingly
    private init() {
        SingletonRegistry.shared.register(self)
        
        Auth.auth().addStateDidChangeListener { [weak self] (_, firebaseUser) in
            guard let self = self else { return }
            
            if let firebaseUser = firebaseUser {
                let loginType = self.determineLoginType(from: firebaseUser)
                
                let user = CWUser(
                    id: firebaseUser.uid,
                    email: firebaseUser.email,
                    loginType: loginType,
                    isAnonymous: firebaseUser.isAnonymous
                )
                self.currentUser = user
            } else {
                self.currentUser = nil
            }
        }
    }
    
    /// reset cancellables when signing out
    func reset() {
        cancellables.removeAll()
    }
    
    /// Determines login type using Firebase authentication provider data
    ///
    /// Parameter
    /// - firebaseUser : Firebase user object
    ///     - contains authentication data
    ///
    /// Returns
    /// - User.LoginType
    ///     - logintype for user
    private func determineLoginType(from firebaseUser: FirebaseAuth.User) -> CWUser.LoginType {
        if firebaseUser.isAnonymous {
            return .guest
        }
        
        // If user has provider data, check the first provider
        if !firebaseUser.providerData.isEmpty {
            let providerId = firebaseUser.providerData[0].providerID
            
            switch providerId {
            case "google.com":
                return .google
            case "password":
                return .email
            default:
                return .guest
            }
        }
        
        return .guest
    }
    
    /// Authenticates user with email and password credentials
    /// Updates currentUser upon successful authentication
    ///
    /// Parameters:
    /// - email : String
    ///     - User's email address
    /// - password : String
    ///     - User's password
    ///
    /// Returns:
    /// - User object
    func login(email: String, password: String) -> Future<CWUser?, Error> {
        isLoading = true
        return Future { [weak self] promise in
            Auth.auth().signIn(withEmail: email, password: password) { (result, error) in
                self?.isLoading = false // finished processing
                
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let result = result else {
                    promise(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])))
                    return
                }
                
                let user = CWUser(
                    id: result.user.uid,
                    email: result.user.email,
                    loginType: CWUser.LoginType.email,
                    isAnonymous: false
                )
                promise(.success(user))
            }
        }
    }
    
    /// Creates new user with provided email and password
    /// Updates currentUser upon successful creation
    ///
    /// Parameters:
    /// - email : String
    ///     - email address for new account
    /// - password : String
    ///     - password for new account
    ///
    /// Returns:
    /// - User object
    func signUp(email: String, password: String) -> Future<CWUser?, Error> {
        print("📱 AuthManager: Attempting to sign up with email: \(email)")
        isLoading = true
        return Future { [weak self] promise in
            print("📱 AuthManager: Calling Firebase createUser")
            Auth.auth().createUser(withEmail: email, password: password) { (result, error) in
                self?.isLoading = false // finished processing
                
                if let error = error {
                    print("❌ AuthManager: Sign up failed with error: \(error)")
                    print("❌ Error code: \((error as NSError).code)")
                    print("❌ Error domain: \((error as NSError).domain)")
                    print("❌ Error description: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                guard let result = result else {
                    print("❌ AuthManager: Sign up failed with unknown error (nil result)")
                    promise(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])))
                    return
                }
                
                print("✅ AuthManager: Sign up successful for user: \(result.user.uid)")
                let user = CWUser(
                    id: result.user.uid,
                    email: result.user.email,
                    loginType: CWUser.LoginType.email,
                    isAnonymous: false
                )
                promise(.success(user))
            }
        }
    }
    
    /// Authenticates user with Google Sign-In
    /// Updates currentUser upon successful authentication
    ///
    /// Parameters:
    /// - presentingViewController : UIViewController
    ///     - viewcontroller upon which to present google sign in UI
    ///
    /// Returns:
    /// - User Object
    ///
    /// Throws:
    /// - AuthError.missingClientID
    ///     - if the firebase configuration lacks google client id
    /// - AuthError.missingCrendentials
    ///     - if authentication succeeds but required tokens are missing
    func googleSignIn(presentingViewController: UIViewController) -> Future<CWUser?, Error> {
        isLoading = true
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(AuthError.unknown(message: "Self is deallocated")))
                return
            }
            
            print("🔍 Starting Google Sign-In flow")
            
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                self.isLoading = false
                print("❌ Missing Firebase client ID")
                promise(.failure(AuthError.missingClientID))
                return
            }
            
            // create google sgin in configuration object
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // sign in flow
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                print("🔍 Google Sign-In attempt completed")
                self.isLoading = false
                if let error = error {
                    print("❌ Google Sign-In error: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    print("❌ Missing Google credentials")
                    promise(.failure(AuthError.missingCredentials))
                    return
                }
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                               accessToken: user.accessToken.tokenString)
                print("✅ Google Sign-In successful, proceeding to Firebase auth")
                
                Auth.auth().signIn(with: credential) { authResult, error in
                    if let error = error {
                        promise(.failure(error))
                        print("❌ Firebase auth error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let authResult = authResult else {
                        print("❌ Firebase auth result is nil")
                        promise(.failure(AuthError.unknown(message: "Firebase auth result is nil")))
                        return
                    }
                    
                    print("✅ Firebase auth successful")
                    
                    let user = CWUser(
                        id: authResult.user.uid,
                        email: authResult.user.email,
                        loginType: CWUser.LoginType.google,
                        isAnonymous: false
                    )
                    
                    print("✅ User created: \(user.id), email: \(user.email ?? "no email")")
                    promise(.success(user))
                }
            }
        }
    }
    
    // Apple Sign In implementation
    func appleSignIn(presentingViewController: UIViewController) -> Future<CWUser?, Error> {
        isLoading = true
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(AuthError.unknown(message: "Self is deallocated")))
                return
            }
            
            print("Starting Apple Sign-In flow")
            
            // Generate nonce for authentication
            let nonce = self.randomNonceString()
            self.currentNonce = nonce
            
            // Create Apple Sign In request
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = self.sha256(nonce)
            
            // Create authorization controller
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            
            // Create a completion handler
            let completionHandler: (ASAuthorization?, Error?) -> Void = { authResult, error in
                self.isLoading = false
                
                if let error = error {
                    print("❌ Apple Sign-In error: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                guard let authResult = authResult,
                      let appleIDCredential = authResult.credential as? ASAuthorizationAppleIDCredential,
                      let nonce = self.currentNonce,
                      let identityToken = appleIDCredential.identityToken,
                      let tokenString = String(data: identityToken, encoding: .utf8) else {
                    print("❌ Missing Apple credentials")
                    promise(.failure(AuthError.missingCredentials))
                    return
                }
                
                // Create Firebase credential
                let credential = OAuthProvider.appleCredential(
                    withIDToken: tokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                
                print("✅ Apple Sign-In successful, proceeding to Firebase auth")
                
                // Sign in with Firebase
                Auth.auth().signIn(with: credential) { authResult, error in
                    if let error = error {
                        print("❌ Firebase auth error: \(error.localizedDescription)")
                        promise(.failure(error))
                        return
                    }
                    
                    guard let authResult = authResult else {
                        print("❌ Firebase auth result is nil")
                        promise(.failure(AuthError.unknown(message: "Firebase auth result is nil")))
                        return
                    }
                    
                    print("✅ Firebase auth successful")
                    
                    // Create and return user
                    let user = CWUser(
                        id: authResult.user.uid,
                        email: authResult.user.email,
                        loginType: CWUser.LoginType.apple,
                        isAnonymous: false
                    )
                    
                    print("✅ User created: \(user.id), email: \(user.email ?? "no email")")
                    promise(.success(user))
                }
            }
            
            // Create delegate
            let delegate = AppleSignInDelegate(completionHandler: completionHandler)
            
            // Set delegate and present
            authorizationController.delegate = delegate
            authorizationController.presentationContextProvider = PresentationContextProvider(presentingViewController: presentingViewController)
            
            // Store delegate to prevent it from being deallocated
            self.currentAppleSignInDelegate = delegate
            
            // Perform request
            authorizationController.performRequests()
        }
    }
    
    /// Anonymous sign in using Firebase
    /// Updates currentUser upon successful authentication
    ///
    /// Returns:
    /// - User Object
    func signInAnonymously() -> Future<CWUser?, Error> {
        isLoading = true
        return Future { [weak self] promise in
            Auth.auth().signInAnonymously { (result, error) in
                self?.isLoading = false
                
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let result = result else {
                    promise(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])))
                    return
                }
                
                let user = CWUser(
                    id: result.user.uid,
                    email: result.user.email,
                    loginType: CWUser.LoginType.guest,
                    isAnonymous: true
                )
                promise(.success(user))
            }
        }
    }
    
    /// Links an anonymous to a permanent email/password account
    /// Updates currentUser upon successful authentication
    ///
    /// Parameters:
    /// - email : String
    ///     - email address to be linked
    /// - password : String
    ///     - password to be linked
    ///
    /// Returns:
    /// - User Object
    func convertAnonymousUserWithEmail(email: String, password: String) -> Future<CWUser?, Error> {
        isLoading = true
        return Future { [weak self] promise in
            guard let currentUser = Auth.auth().currentUser, currentUser.isAnonymous else {
                self?.isLoading = false
                promise(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User is not anonymous"])))
                return
            }
            
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            
            currentUser.link(with: credential) { (result, error) in
                self?.isLoading = false
                
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let result = result else {
                    promise(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])))
                    return
                }
                
                let user = CWUser(
                    id: result.user.uid,
                    email: result.user.email,
                    loginType: CWUser.LoginType.email,
                    isAnonymous: false
                )
                promise(.success(user))
            }
        }
    }
    
    /// Links an anonymous to a permanent account with Google credentials
    /// Updates currentUser upon successful authentication
    ///
    /// Parameters:
    /// - presentingViewController : UIViewController
    ///     - view controller to present the google sign in UI upon
    ///
    /// Returns:
    /// - User Object
    ///
    /// Throws:
    /// - AuthError.notAnonymous
    ///     - user didn't start as anonymous user
    /// - AuthError.missingClientID
    ///     - if firebase configuration lacks a google client ID
    /// - AuthError.missingCredentials
    ///     - google authentication succeeds but required tokens are missing
    @MainActor
    func convertAnonymousUserWithGoogle(presentingViewController: UIViewController) async throws -> CWUser {
        guard let currentUser = Auth.auth().currentUser, currentUser.isAnonymous else {
            throw AuthError.notAnonymous
        }
        
        isLoading = true
        
        do {
            // Get Google sign-in configuration
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                isLoading = false
                throw AuthError.missingClientID
            }
            
            // Create Google sign-in configuration
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // Start Google sign-in flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            let user = result.user
            
            guard let idToken = user.idToken?.tokenString else {
                isLoading = false
                throw AuthError.missingCredentials
            }
            
            // Create Google credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            // Link the anonymous account with Google credential
            let authResult = try await currentUser.link(with: credential)
            
            isLoading = false
            
            // Return updated user
            return CWUser(
                id: authResult.user.uid,
                email: authResult.user.email,
                loginType: CWUser.LoginType.google,
                isAnonymous: false
            )
        } catch {
            isLoading = false
            throw error
        }
    }
    
    /// Links an anonymous account to a permanent apple id account
    /// updates currentUser upon successful authentication
    ///
    /// - Parameters:
    /// - presentingViewController : UIViewController
    ///     - view controller to present the apple sign in upon
    ///
    /// - Returns:
    /// - User Object
    ///
    /// - Throws:
    /// - AuthError.notAnonymous
    ///     - user didn't start as an anonymous user
    /// - AuthError.missingCredentials
    ///     - apple authentication succeds but required tokens are missing
    @MainActor
    func convertAnonymousUserWithApple(presentingViewController: UIViewController) async throws -> CWUser {
        guard let currentUser = Auth.auth().currentUser, currentUser.isAnonymous else {
            throw AuthError.notAnonymous
        }
        
        isLoading = true
        
        do {
            // generate nonce of authentication
            let nonce = self.randomNonceString()
            self.currentNonce = nonce
            
            // create apple sign in request
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = self.sha256(nonce)
            
            // create and configure authorization controller
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            
            // create completion handle closure to handle the result
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
                let delegate = AppleSignInContinuationDelegate(continuation: continuation)
                authorizationController.delegate = delegate
                authorizationController.presentationContextProvider = PresentationContextProvider(presentingViewController: presentingViewController)
                self.currentAppleSignInDelegate = delegate
                authorizationController.performRequests()
            }
            
            // process authorization result
            guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                isLoading = false
                throw AuthError.missingCredentials
            }
            
            // Create Apple credential for Firebase
            let credential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            // Link the anonymous account with Apple credential
            let authResult = try await currentUser.link(with: credential)
            
            isLoading = false
            
            // Return updated user
            return CWUser(
                id: authResult.user.uid,
                email: authResult.user.email,
                loginType: CWUser.LoginType.apple,
                isAnonymous: false
            )
        } catch {
            isLoading = false
            throw error
        }
    }
    
    /// Signs out current user out of firebase and session
    /// Throws firebase authentication error if sign out fails
    func signOut() -> Future<Void, Error> {
        return Future { promise in
            do {
                // This triggers the auth state listener which updates currentUser to nil
                try Auth.auth().signOut()
                
                // Clean up local data after successful sign out
                if let bundleIdentifier = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
                }
                
                // Reset all singletons
                SingletonRegistry.shared.resetAll()
                
                promise(.success(()))
            } catch {
                // Handle sign out error
                promise(.failure(error))
            }
        }
    }
    
    /// Deletes the current user's acocunt from Firebase
    /// - Returns: Future that completes when account becomes deleted
    func deleteCurrentAccount() -> Future<Void, Error> {
        isLoading = true
        return Future { [weak self] promise in
            guard let currentUser = Auth.auth().currentUser else {
                self?.isLoading = false
                promise(.failure(AuthError.notAuthenticated))
                return
            }
            
            currentUser.delete { error in
                self?.isLoading = false
                
                if let error = error {
                    print("❌ Account deletion failed: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }
                
                print("✅ Account successfully deleted")
                
                // Account successfully deleted, now clean up local data
                if let bundleIdentifier = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
                }
                
                // Reset all singletons
                SingletonRegistry.shared.resetAll()
                
                promise(.success(()))
            }
        }
    }
}

/// Extension for nonce methods for apple sign in
extension AuthenticationManager {
    
    // generate random nonce for authentication
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    // hash nonce for security
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}
