import Foundation
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://yjwtklwgsmpctaeontfx.supabase.co")!,
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlqd3RrbHdnc21wY3RhZW9udGZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTg3MTMsImV4cCI6MjA3MDkzNDcxM30.xNrYkx43lzcux3Xw8PTZRmsYeXN6ea8L4ITNNVEXBoE"
)

struct Todo: Identifiable, Decodable {
  var id: Int
  var title: String
}

struct TodoInsert: Encodable {
  var title: String
}

struct TodoUpdate: Encodable {
  var title: String
}
