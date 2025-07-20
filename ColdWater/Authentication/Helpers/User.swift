/// User Object representing authenticated user
struct User {
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
