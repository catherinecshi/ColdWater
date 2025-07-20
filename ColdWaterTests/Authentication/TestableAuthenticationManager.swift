import Combine
import GoogleSignIn
@testable import ColdWater

/// Testable version of AuthenticationManager with dependency injection
class TestableAuthenticationManager: AuthenticationServiceProtocol, ObservableObject {
    @Published private(set) var currentUser: CWUser?
    @Published private(set) var isLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let mockAuth: MockFirebaseAuth
    
    var isUserAuthenticated: Bool {
        return mockAuth.currentUser != nil
    }
    
    var isAnonymous: Bool {
        return mockAuth.currentUser?.isAnonymous ?? false
    }
    
    var isLoadingPublisher: Published<Bool>.Publisher {
        return $isLoading
    }
    
    init(mockAuth: MockFirebaseAuth) {
        self.mockAuth = mockAuth
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        _ = mockAuth.addStateDidChangeListener { [weak self] (_, firebaseUser) in
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
    
    private func determineLoginType(from firebaseUser: FirebaseUserProtocol) -> CWUser.LoginType {
        if firebaseUser.isAnonymous {
            return .guest
        }
        
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
    
    func login(email: String, password: String) -> Future<CWUser?, Error> {
        isLoading = true
        return Future { [weak self] promise in
            self?.mockAuth.signIn(withEmail: email, password: password) { (result, error) in
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
    
    func signUp(email: String, password: String) -> Future<CWUser?, Error> {
        isLoading = true
        return Future { [weak self] promise in
            self?.mockAuth.createUser(withEmail: email, password: password) { (result, error) in
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
    
    func signInAnonymously() -> Future<CWUser?, Error> {
        isLoading = true
        return Future { [weak self] promise in
            self?.mockAuth.signInAnonymously { (result, error) in
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
    
    func signOut() -> Future<Void, Error> {
        return Future { [weak self] promise in
            do {
                try self?.mockAuth.signOut()
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
    }
    
    // Simplified implementations for methods not directly testable without more complex mocking
    func googleSignIn(presentingViewController: UIViewController) -> Future<CWUser?, Error> {
        return Future { promise in
            promise(.failure(NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign In not implemented in tests"])))
        }
    }
    
    func appleSignIn(presentingViewController: UIViewController) -> Future<CWUser?, Error> {
        return Future { promise in
            promise(.failure(NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign In not implemented in tests"])))
        }
    }
    
    func convertAnonymousUserWithEmail(email: String, password: String) -> Future<CWUser?, Error> {
        return Future { promise in
            promise(.failure(NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Convert anonymous not implemented in tests"])))
        }
    }
    
    func convertAnonymousUserWithGoogle(presentingViewController: UIViewController) async throws -> CWUser {
        throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Convert anonymous Google not implemented in tests"])
    }
    
    func deleteCurrentAccount() -> Future<Void, Error> {
        return Future { promise in
            promise(.failure(NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Delete account not implemented in tests"])))
        }
    }
}
