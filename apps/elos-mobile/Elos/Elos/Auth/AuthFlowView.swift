import SwiftUI

struct AuthFlowView: View {
    @State private var showSignup = false

    var body: some View {
        ZStack {
            if showSignup {
                SignupView(showSignup: $showSignup)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else {
                LoginView(showSignup: $showSignup)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading), 
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSignup)
    }
}
