-- Migration: Create messages table
-- Description: Stores individual messages between matched users

CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    id_user_1 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    id_user_2 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(10) NOT NULL DEFAULT 'unread' CHECK (status IN ('read', 'unread'))
);

-- Index for faster message retrieval by conversation
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sent_at ON messages(sent_at DESC);

-- Index for faster unread message count queries
CREATE INDEX IF NOT EXISTS idx_messages_status_user ON messages(id_user_2, status) WHERE status = 'unread';

-- Enable Row Level Security
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read messages from conversations they participate in
CREATE POLICY "Users can read messages from their conversations" ON messages
    FOR SELECT USING (
        id_user_1 = auth.uid() OR id_user_2 = auth.uid()
    );

-- Policy: Users can only insert messages as themselves in conversations they participate in
CREATE POLICY "Users can send messages in their conversations" ON messages
    FOR INSERT WITH CHECK (
        id_user_1 = auth.uid() 
        AND EXISTS (
            SELECT 1 FROM conversations 
            WHERE id = conversation_id 
            AND (id_user_1 = auth.uid() OR id_user_2 = auth.uid())
        )
    );

-- Policy: Users can only update their own messages (e.g., mark as read)
CREATE POLICY "Users can update their own messages" ON messages
    FOR UPDATE USING (
        id_user_2 = auth.uid()  -- Only recipient can mark as read
    );