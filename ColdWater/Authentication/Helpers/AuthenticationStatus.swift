/// Returns status corresponding to whether authentication has succeeded or not
import Foundation

class AuthenticationStatus: Equatable, Identifiable, ObservableObject {
    var title: String
    var message: String
    
    init(title: String = "", message: String = "") {
        self.title = title
        self.message = message
    }
    
    static var signUpSuccessStatus: AuthenticationStatus {
        return AuthenticationStatus(title: "Successful", message: "Your account has been created successfully")
    }
    
    static var logInSuccessStatus: AuthenticationStatus {
        return AuthenticationStatus(title: "Successful", message: "Your account has been logged in successfully")
    }
    
    static var errorStatus: AuthenticationStatus {
        return AuthenticationStatus(title: "Error", message: "Oops! Something went wrong. Please try again.")
    }
    
    static func == (lhs: AuthenticationStatus, rhs: AuthenticationStatus) -> Bool {
        return lhs.title == rhs.title && lhs.message == rhs.message
    }
}
