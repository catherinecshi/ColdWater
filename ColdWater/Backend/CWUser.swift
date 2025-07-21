/// User Object representing authenticated user
struct CWUser {
    /// Types of ways the user can be logged in
    enum LoginType {
        case email
        case guest
        case google
        case apple
    }
    
    let id: String // UID used when retrieving data from Firestore
    let email: String? // if the user logged in using email
    let loginType: LoginType
    let isAnonymous: Bool
    
    init(id: String, email: String?, loginType: LoginType = .guest, isAnonymous: Bool = false) {
        self.id = id
        self.email = email
        self.loginType = loginType
        self.isAnonymous = isAnonymous
    }
}

// MARK: - Equatable Conformance
extension CWUser: Equatable {
    static func == (lhs: CWUser, rhs: CWUser) -> Bool {
        return lhs.id == rhs.id &&
               lhs.email == rhs.email &&
               lhs.loginType == rhs.loginType &&
               lhs.isAnonymous == rhs.isAnonymous
    }
}

extension CWUser.LoginType: Equatable {
    // making it explicit for clarity
}
