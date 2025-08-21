
import SwiftUI
import FirebaseAuth
import Combine

struct TestContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var preferencesManager = UserPreferencesManager.shared
    
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    @State private var todos: [Todo] = []
    @State private var newTodoTitle = "Test Todo"
    @State private var selectedTodoId: Int?
    @State private var testWakeUpTime = Date()
    @State private var testStepGoal = 8000
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Authentication Status
                    authenticationSection
                    
                    // Supabase Connection Status
                    supabaseSection
                    
                    // Test Controls
                    testControlsSection
                    
                    // Todos Testing
                    if authManager.isUserAuthenticated {
                        todosSection
                    }
                    
                    // Preferences Testing (Local Storage)
                    if authManager.isUserAuthenticated {
                        preferencesSection
                    }
                    
                    // Test Results
                    testResultsSection
                }
                .padding()
            }
            .navigationTitle("Supabase Integration Test")
        }
    }
    
    private var authenticationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🔐 Firebase Authentication")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(authManager.isUserAuthenticated ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(authManager.isUserAuthenticated ? "Authenticated" : "Not Authenticated")
                    .foregroundColor(authManager.isUserAuthenticated ? .green : .red)
                
                Spacer()
            }
            
            if let user = authManager.currentUser {
                VStack(alignment: .leading, spacing: 4) {
                    Text("User ID: \(user.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let email = user.email {
                        Text("Email: \(email)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Login Type: \(String(describing: user.loginType))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !authManager.isUserAuthenticated {
                Button("Sign In Anonymously") {
                    signInAnonymously()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Sign Out") {
                    signOut()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var supabaseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🗄️ Supabase Connection")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(supabaseService.isConnected ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(supabaseService.isConnected ? "Connected" : "Not Connected")
                    .foregroundColor(supabaseService.isConnected ? .green : .red)
                
                Spacer()
                
                if supabaseService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var testControlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🧪 Integration Tests")
                .font(.headline)
            
            Button(action: runIntegrationTests) {
                HStack {
                    if isRunningTests {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isRunningTests ? "Running Tests..." : "Run Integration Tests")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunningTests || !authManager.isUserAuthenticated)
            
            Button("Clear Test Results") {
                testResults.removeAll()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var todosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📝 Todos Test")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Todos:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if todos.isEmpty {
                    Text("No todos loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(todos) { todo in
                            HStack {
                                Text("\(todo.id):")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(todo.title)
                                    .font(.caption)
                                
                                Spacer()
                                
                                Button("Delete") {
                                    selectedTodoId = todo.id
                                    deleteTodo(id: todo.id)
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            VStack(spacing: 8) {
                HStack {
                    TextField("New todo title", text: $newTodoTitle)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Add Todo") {
                        createNewTodo()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTodoTitle.isEmpty)
                }
                
                HStack {
                    Button("Fetch Todos") {
                        fetchTodos()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Clear Todos List") {
                        todos.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("⚙️ User Preferences Test (Local Storage)")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Preferences:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let todaysTime = preferencesManager.getTodaysWakeUpTime() {
                    Text("Today's Wake Up: \(todaysTime, style: .time)")
                        .font(.caption)
                } else {
                    Text("No wake up time set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let method = preferencesManager.preferences.wakeUpMethod {
                    Text("Wake Up Method: \(method.rawValue)")
                        .font(.caption)
                } else {
                    Text("No wake up method set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let goal = preferencesManager.preferences.stepGoal {
                    Text("Step Goal: \(goal)")
                        .font(.caption)
                } else {
                    Text("No step goal set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            VStack(spacing: 8) {
                DatePicker("Test Wake Up Time", selection: $testWakeUpTime, displayedComponents: .hourAndMinute)
                
                Stepper("Test Step Goal: \(testStepGoal)", value: $testStepGoal, in: 1000...50000, step: 1000)
                
                HStack {
                    Button("Set Wake Up Time") {
                        preferencesManager.setEverydayTime(testWakeUpTime)
                        testResults.append("✅ Set wake up time locally")
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Set Step Goal") {
                        preferencesManager.setStepGoal(testStepGoal)
                        testResults.append("✅ Set step goal locally")
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Load Preferences") {
                    Task {
                        await preferencesManager.loadPreferences()
                        testResults.append("✅ Loaded preferences from local storage")
                    }
                }
                .buttonStyle(.borderedProminent)
                
                if preferencesManager.hasUnsavedChanges {
                    Text("⚠️ Unsaved changes")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if preferencesManager.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var testResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📝 Test Results")
                .font(.headline)
            
            if testResults.isEmpty {
                Text("No test results yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(testResults.indices, id: \.self) { index in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(testResults[index])
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Actions
    
    private func signInAnonymously() {
        authManager.signInAnonymously()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        testResults.append("❌ Anonymous sign in failed: \(error.localizedDescription)")
                    case .finished:
                        break
                    }
                },
                receiveValue: { _ in
                    testResults.append("✅ Anonymous sign in successful")
                }
            )
            .store(in: &cancellables)
    }
    
    private func signOut() {
        authManager.signOut()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        testResults.append("❌ Sign out failed: \(error.localizedDescription)")
                    case .finished:
                        testResults.append("✅ Sign out successful")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func fetchTodos() {
        Task {
            do {
                let fetchedTodos = try await supabaseService.fetchTodos()
                await MainActor.run {
                    self.todos = fetchedTodos
                    testResults.append("✅ Fetched \(fetchedTodos.count) todos")
                }
            } catch {
                await MainActor.run {
                    testResults.append("❌ Failed to fetch todos: \(error)")
                }
            }
        }
    }
    
    private func createNewTodo() {
        Task {
            do {
                let newTodo = try await supabaseService.createTodo(title: newTodoTitle)
                await MainActor.run {
                    self.todos.append(newTodo)
                    self.newTodoTitle = "Test Todo \(Int.random(in: 1...1000))"
                    testResults.append("✅ Created todo: \(newTodo.title)")
                }
            } catch {
                await MainActor.run {
                    testResults.append("❌ Failed to create todo: \(error)")
                }
            }
        }
    }
    
    private func deleteTodo(id: Int) {
        Task {
            do {
                try await supabaseService.deleteTodo(id: id)
                await MainActor.run {
                    self.todos.removeAll { $0.id == id }
                    testResults.append("✅ Deleted todo \(id)")
                }
            } catch {
                await MainActor.run {
                    testResults.append("❌ Failed to delete todo: \(error)")
                }
            }
        }
    }
    
    private func runIntegrationTests() {
        isRunningTests = true
        testResults.append("🚀 Starting integration tests...")
        
        Task {
            await performTests()
            
            DispatchQueue.main.async {
                self.isRunningTests = false
                self.testResults.append("🏁 Integration tests completed")
            }
        }
    }
    
    @MainActor
    private func performTests() async {
        // Test 1: Check Firebase Authentication
        if authManager.isUserAuthenticated {
            testResults.append("✅ Test 1: Firebase authentication verified")
            if let user = authManager.currentUser {
                testResults.append("   - Firebase UID: \(user.id)")
            }
        } else {
            testResults.append("❌ Test 1: Firebase authentication failed")
            return
        }
        
        // Test 2: Check Supabase Connection
        if supabaseService.isConnected {
            testResults.append("✅ Test 2: Supabase connection verified")
        } else {
            testResults.append("❌ Test 2: Supabase connection failed")
            return
        }
        
        // Test 2.5: Test database connectivity with todos table
        do {
            try await supabaseService.testDatabaseConnection()
            testResults.append("✅ Test 2.5: Database connectivity verified")
        } catch {
            testResults.append("❌ Test 2.5: Database connectivity failed: \(error)")
            testResults.append("   - This likely means the 'todos' table doesn't exist or has permission issues")
        }
        
        // Test 3: Try to fetch todos
        do {
            let todos = try await supabaseService.fetchTodos()
            testResults.append("✅ Test 3: Successfully fetched todos from Supabase")
            testResults.append("   - Found \(todos.count) todos")
            self.todos = todos
        } catch {
            testResults.append("❌ Test 3: Failed to fetch todos: \(error)")
            if let supabaseError = error as? SupabaseError {
                switch supabaseError {
                case .networkError(let underlyingError):
                    testResults.append("   - Network error details: \(underlyingError)")
                default:
                    testResults.append("   - Supabase error: \(supabaseError.localizedDescription)")
                }
            }
        }
        
        // Test 4: Try to create a todo
        do {
            let testTitle = "Test Todo from Integration - \(Date().timeIntervalSince1970)"
            let newTodo = try await supabaseService.createTodo(title: testTitle)
            testResults.append("✅ Test 4: Successfully created todo in Supabase")
            testResults.append("   - Created todo ID: \(newTodo.id)")
            
            // Add to local list
            if !self.todos.contains(where: { $0.id == newTodo.id }) {
                self.todos.append(newTodo)
            }
        } catch {
            testResults.append("❌ Test 4: Failed to create todo: \(error)")
            if let supabaseError = error as? SupabaseError {
                switch supabaseError {
                case .networkError(let underlyingError):
                    testResults.append("   - Network error details: \(underlyingError)")
                default:
                    testResults.append("   - Supabase error: \(supabaseError.localizedDescription)")
                }
            }
        }
        
        // Test 5: Try to update a todo (if we have any)
        if let firstTodo = self.todos.first {
            do {
                let updatedTitle = "Updated Todo - \(Date().timeIntervalSince1970)"
                try await supabaseService.updateTodo(id: firstTodo.id, title: updatedTitle)
                testResults.append("✅ Test 5: Successfully updated todo \(firstTodo.id)")
                
                // Update local list
                if let index = self.todos.firstIndex(where: { $0.id == firstTodo.id }) {
                    self.todos[index] = Todo(id: firstTodo.id, title: updatedTitle)
                }
            } catch {
                testResults.append("❌ Test 5: Failed to update todo: \(error)")
            }
        } else {
            testResults.append("⚠️ Test 5: Skipped update test - no todos available")
        }
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}

#Preview {
    TestContentView()
}

