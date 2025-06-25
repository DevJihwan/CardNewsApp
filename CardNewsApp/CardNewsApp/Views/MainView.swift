import SwiftUI

struct MainView: View {
    @State private var showFileUpload = false
    @State private var selectedFileURL: URL? // 파일 선택 상태 유지
    @State private var shouldReopenModal = false // 모달 재열기 플래그
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // 앱 로고 영역
                VStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("CardNews App")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("문서를 카드뉴스로 변환하세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 선택된 파일 정보 표시 (모달이 닫혔을 때)
                if let fileURL = selectedFileURL, !showFileUpload {
                    selectedFileCard(fileURL)
                }
                
                // 파일 업로드 버튼
                Button(action: {
                    print("🔍 [MainView] 파일 업로드 버튼 클릭")
                    showFileUpload = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                        Text("파일 업로드")
                            .font(.headline)
                        Text("PDF 파일")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                
                // 기능 안내 카드들
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    featureCard(
                        icon: "rectangle.3.group.fill",
                        title: "4/6/8컷",
                        description: "원하는 길이 선택"
                    )
                    
                    featureCard(
                        icon: "paintbrush.fill",
                        title: "3가지 스타일",
                        description: "웹툰/텍스트/이미지"
                    )
                    
                    featureCard(
                        icon: "heart.fill",
                        title: "첫 사용 무료",
                        description: "체험해보세요"
                    )
                    
                    featureCard(
                        icon: "iphone",
                        title: "모바일 최적화",
                        description: "언제 어디서나"
                    )
                }
                
                // 최근 요약 목록 (임시)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("최근 요약")
                            .font(.headline)
                        Spacer()
                        Button("전체 보기") {
                            // TODO: 히스토리 화면으로 이동
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    VStack {
                        Image(systemName: "tray")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                        Text("아직 요약된 문서가 없습니다")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("첫 번째 문서를 업로드해보세요!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("CardNews")
            .sheet(isPresented: $showFileUpload) {
                FileUploadView(preselectedFile: selectedFileURL)
                    .onAppear {
                        print("🔍 [MainView] FileUploadView 모달 표시")
                    }
            }
            .onChange(of: showFileUpload) { _, newValue in
                print("🔍 [MainView] showFileUpload 변경: \(newValue)")
                
                // 모달이 예상치 못하게 닫혔을 때 처리
                if !newValue && shouldReopenModal {
                    print("🔧 [MainView] 모달 재열기 시도")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showFileUpload = true
                        shouldReopenModal = false
                    }
                }
            }
        }
    }
    
    // 선택된 파일 카드 (메인 화면에 표시)
    private func selectedFileCard(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.blue)
                Text("선택된 파일")
                    .font(.headline)
                Spacer()
                Button("계속 처리") {
                    showFileUpload = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            Text(url.lastPathComponent)
                .font(.body)
                .lineLimit(2)
        }
        .padding()
        .background(Color(.systemBlue).opacity(0.1))
        .cornerRadius(8)
    }
    
    // 기능 안내 카드
    private func featureCard(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    MainView()
}
