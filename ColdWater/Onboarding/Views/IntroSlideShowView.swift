import SwiftUI

struct IntroSlideShowView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @State private var currentSlide = 0
    
    private let slides = [
        SlideData(
            title: "You set an alarm for when you want to wake up",
            imageName: "alarm.fill"
        ),
        SlideData(
            title: "You have some time to get ready and move around",
            imageName: "tshirt.fill"
        ),
        SlideData(
            title: "The app checks if you've gotten out of bed and moved around",
            imageName: "figure.walk"
        ),
        SlideData(
            title: "If not, consequences happen (e.g. an alarm that doesn't turn off)",
            imageName: "exclamationmark.triangle.fill"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentSlide) {
                ForEach(0..<slides.count, id: \.self) { index in
                    SlideView(slide: slides[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentSlide)
            
            VStack(spacing: 24) {
                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentSlide ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentSlide)
                    }
                }
                
                // Continue button (only shows on last slide)
                if currentSlide == slides.count - 1 {
                    Button(action: {
                        coordinator.nextStep()
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut.delay(0.3), value: currentSlide)
                }
            }
            .padding(.bottom, 40)
        }
        .navigationBarBackButtonHidden(true)
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold && currentSlide > 0 {
                        // Swipe right - previous slide
                        withAnimation {
                            currentSlide -= 1
                        }
                    } else if value.translation.width < -threshold && currentSlide < slides.count - 1 {
                        // Swipe left - next slide
                        withAnimation {
                            currentSlide += 1
                        }
                    }
                }
        )
    }
}

struct SlideView: View {
    let slide: SlideData
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Image area
            VStack(spacing: 24) {
                Image(systemName: slide.imageName)
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .frame(height: 120)
                
                VStack(spacing: 16) {
                    Text(slide.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct SlideData {
    let title: String
    let imageName: String
}
