# Supabase + Firebase Integration Setup

## 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Note down your project URL and anon key from Settings > API

## 2. Configure Firebase JWT Integration

### In Supabase Dashboard:

1. Go to **Settings > Auth > JWT Settings**
2. Set **JWT Secret** to your Firebase project's secret key
3. Enable **Custom JWT** provider

### Get Firebase Project Secret:
```bash
# Install Firebase CLI if you haven't
npm install -g firebase-tools

# Login and get project config
firebase login
firebase projects:list
firebase functions:config:get --project YOUR_PROJECT_ID
```

Or get it from Firebase Console > Project Settings > Service Accounts > Generate new private key

## 3. Configure Supabase Auth

In your Supabase dashboard, go to **Authentication > Providers** and:

1. **Enable Email provider** (if not already enabled)
2. **Configure Google OAuth**:
   - Enable Google provider
   - Add your Google Client ID and Secret (same ones from Firebase)
   - Add redirect URL: `https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback`

3. **Configure Apple OAuth**:
   - Enable Apple provider  
   - Add your Apple Developer credentials
   - Add redirect URL: `https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback`

## 4. Set up Database Schema

1. Go to **SQL Editor** in your Supabase dashboard
2. Copy and paste the contents of `database_schema.sql`
3. Replace `'your-firebase-project-secret'` with your actual Firebase project secret
4. Run the SQL script

## 5. Configure Row Level Security (RLS)

The schema automatically sets up RLS policies that:
- Only allow users to access their own data based on Firebase UID
- Use JWT token validation for authentication

## 6. Update iOS App Configuration

1. **Update SupabaseService.swift**:
   ```swift
   // Replace these values in SupabaseService.swift
   guard let url = URL(string: "https://YOUR_PROJECT_ID.supabase.co"),
         let anonKey = "YOUR_SUPABASE_ANON_KEY" else {
   ```

2. **Add Supabase configuration file** (optional):
   Create `Supabase-Info.plist`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>SUPABASE_URL</key>
       <string>https://YOUR_PROJECT_ID.supabase.co</string>
       <key>SUPABASE_ANON_KEY</key>
       <string>YOUR_SUPABASE_ANON_KEY</string>
   </dict>
   </plist>
   ```

## 7. Test the Integration

1. **Build and run your app**
2. **Sign in with Firebase** (any method)
3. **Check Supabase logs** to see authentication events
4. **Verify data sync** by updating preferences and checking the database

## 8. Enable Real-time (Optional)

For real-time features:
1. Go to **Database > Replication**
2. Enable replication for `user_preferences` and `scheduled_activities` tables
3. The app automatically subscribes to changes

## Environment Variables (Recommended)

For security, consider using environment variables:

1. Create `.env` file (don't commit to git):
   ```
   SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
   SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
   ```

2. Update `SupabaseService.swift` to read from environment or config file

## Troubleshooting

### Authentication Issues:
- Verify Firebase JWT secret is correctly set in Supabase
- Check that Firebase user has valid ID token
- Ensure RLS policies are correctly configured

### Database Connection Issues:
- Verify Supabase URL and anon key are correct
- Check network connectivity
- Review Supabase logs for errors

### Real-time Not Working:
- Ensure tables are added to replication
- Check WebSocket connection in browser dev tools
- Verify user has proper permissions

## Security Notes

1. **Never commit secrets** to version control
2. **Use environment variables** for production
3. **Regularly rotate** API keys
4. **Monitor access logs** in Supabase dashboard
5. **Test RLS policies** thoroughly before production

## Next Steps

Once setup is complete:
1. Test all authentication flows
2. Verify preferences sync correctly
3. Test real-time updates across devices
4. Set up time-based processing with Edge Functions
5. Configure monitoring and alerts