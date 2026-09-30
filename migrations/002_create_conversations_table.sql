-- Migration: Create conversations table
-- Description: Stores conversations between two matched users

CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_user_1 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    id_user_2 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Ensure user_1 < user_2 to prevent duplicate conversations (same pair in different order)
    CONSTRAINT conversations_user_order_check CHECK (id_user_1 < id_user_2),
    
    -- Ensure a conversation between the same two users is unique
    CONSTRAINT conversations_unique_pair UNIQUE (id_user_1, id_user_2)
);

-- Index for faster conversation lookup by user
CREATE INDEX IF NOT EXISTS idx_conversations_user_1 ON conversations(id_user_1);
CREATE INDEX IF NOT EXISTS idx_conversations_user_2 ON conversations(id_user_2);

-- Enable Row Level Security
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see conversations they participate in
CREATE POLICY "Users can read their conversations" ON conversations
    FOR SELECT USING (
        id_user_1 = auth.uid() OR id_user_2 = auth.uid()
    );

-- Policy: Users can only create conversations where they are one of the participants
-- (The actual creation should happen via a server-side function after match verification)
CREATE POLICY "Users can create conversations they participate in" ON conversations
    FOR INSERT WITH CHECK (
        id_user_1 = auth.uid() OR id_user_2 = auth.uid()
    );

-- Trigger to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_conversations_updated_at ON conversations;
CREATE TRIGGER update_conversations_updated_at
    BEFORE UPDATE ON conversations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();