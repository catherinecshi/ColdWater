-- ColdWater App Database Schema for Supabase
-- Run this in your Supabase SQL editor after setting up Firebase JWT integration

-- Enable Row Level Security
ALTER DATABASE postgres SET "app.jwt_secret" TO 'your-firebase-project-secret';

-- User preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    firebase_uid TEXT NOT NULL UNIQUE,
    
    -- Wake up times (JSON object with weekday keys and ISO time values)
    wake_up_times JSONB,
    
    -- Time preferences
    everyday_time TIMESTAMPTZ,
    weekdays_time TIMESTAMPTZ,
    weekends_time TIMESTAMPTZ,
    
    -- Wake up method
    wake_up_method TEXT CHECK (wake_up_method IN ('steps', 'location')),
    
    -- Step goal
    step_goal INTEGER,
    
    -- Location preferences
    location_latitude DOUBLE PRECISION,
    location_longitude DOUBLE PRECISION,
    location_radius DOUBLE PRECISION,
    location_name TEXT,
    
    -- Grace period (in seconds)
    grace_period DOUBLE PRECISION,
    
    -- Motivation method
    motivation_method TEXT CHECK (motivation_method IN ('phone', 'money', 'noise', 'none')),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index on firebase_uid for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_preferences_firebase_uid ON user_preferences(firebase_uid);

-- Enable Row Level Security
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only access their own data
CREATE POLICY "Users can only access their own preferences" ON user_preferences
    FOR ALL USING (auth.jwt() ->> 'sub' = firebase_uid);

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to automatically update updated_at
CREATE TRIGGER update_user_preferences_updated_at 
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable real-time for user_preferences table
ALTER PUBLICATION supabase_realtime ADD TABLE user_preferences;

-- Example scheduled activities table (for future time-based processing)
CREATE TABLE IF NOT EXISTS scheduled_activities (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    firebase_uid TEXT NOT NULL,
    activity_type TEXT NOT NULL, -- 'notification', 'phone_call', etc.
    scheduled_time TIMESTAMPTZ NOT NULL,
    is_completed BOOLEAN DEFAULT FALSE,
    metadata JSONB, -- Additional data for the activity
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for efficient time-based queries
CREATE INDEX IF NOT EXISTS idx_scheduled_activities_time ON scheduled_activities(scheduled_time);
CREATE INDEX IF NOT EXISTS idx_scheduled_activities_uid ON scheduled_activities(firebase_uid);

-- RLS for scheduled activities
ALTER TABLE scheduled_activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access their own activities" ON scheduled_activities
    FOR ALL USING (auth.jwt() ->> 'sub' = firebase_uid);

-- Trigger for scheduled_activities updated_at
CREATE TRIGGER update_scheduled_activities_updated_at 
    BEFORE UPDATE ON scheduled_activities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable real-time for scheduled_activities
ALTER PUBLICATION supabase_realtime ADD TABLE scheduled_activities;

-- Example function for time-based processing
CREATE OR REPLACE FUNCTION get_upcoming_activities(user_id TEXT, hours_ahead INTEGER DEFAULT 24)
RETURNS TABLE (
    id UUID,
    activity_type TEXT,
    scheduled_time TIMESTAMPTZ,
    metadata JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sa.id,
        sa.activity_type,
        sa.scheduled_time,
        sa.metadata
    FROM scheduled_activities sa
    WHERE sa.firebase_uid = user_id
      AND sa.is_completed = FALSE
      AND sa.scheduled_time BETWEEN NOW() AND (NOW() + INTERVAL '1 hour' * hours_ahead)
    ORDER BY sa.scheduled_time ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant usage on schema to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Comment with setup instructions
COMMENT ON TABLE user_preferences IS 'Stores user preferences synced from iOS app. Uses Firebase UID as the primary key for RLS.';
COMMENT ON TABLE scheduled_activities IS 'Stores scheduled activities for time-based processing like notifications and phone calls.';