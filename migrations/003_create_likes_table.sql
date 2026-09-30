-- Migration: Create likes table
-- Description: Stores user likes (swipes right / "+" presses) and handles match detection

CREATE TABLE IF NOT EXISTS likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    liked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- A user can only like another user once
    CONSTRAINT likes_unique_pair UNIQUE (liker_id, liked_id),
    
    -- Prevent self-likes
    CONSTRAINT likes_no_self_like CHECK (liker_id != liked_id)
);

-- Index for faster lookup of likes given by a user
CREATE INDEX IF NOT EXISTS idx_likes_liker ON likes(liker_id);

-- Index for faster lookup of likes received by a user
CREATE INDEX IF NOT EXISTS idx_likes_liked ON likes(liked_id);

-- Enable Row Level Security
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see their own likes (given and received)
CREATE POLICY "Users can read their own likes" ON likes
    FOR SELECT USING (
        liker_id = auth.uid() OR liked_id = auth.uid()
    );

-- Policy: Users can only insert likes as themselves
CREATE POLICY "Users can like others" ON likes
    FOR INSERT WITH CHECK (
        liker_id = auth.uid()
    );

-- Policy: Users cannot delete likes (or only their own given likes)
CREATE POLICY "Users can unlike (delete their given likes)" ON likes
    FOR DELETE USING (
        liker_id = auth.uid()
    );

-- Function: Check if a mutual like (match) exists between two users
-- Returns true if both users have liked each other
CREATE OR REPLACE FUNCTION check_mutual_like(p_user_1 UUID, p_user_2 UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Count how many likes exist between the two users (should be 2 for a match)
    SELECT COUNT(*) INTO v_count
    FROM likes
    WHERE (liker_id = p_user_1 AND liked_id = p_user_2)
       OR (liker_id = p_user_2 AND liked_id = p_user_1);
    
    RETURN v_count = 2;
END;
$$;

-- Function: Create a like and check for match in a single atomic operation
-- This is the main function the backend will call when a user presses "+"
-- Returns: 
--   - is_match: BOOLEAN - whether this like created a mutual match
--   - conversation_id: UUID - the conversation ID if matched, NULL otherwise
CREATE OR REPLACE FUNCTION create_like_and_check_match(p_liker_id UUID, p_liked_id UUID)
RETURNS TABLE (
    is_match BOOLEAN,
    conversation_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_match BOOLEAN;
    v_conversation_id UUID;
    v_user_1 UUID;
    v_user_2 UUID;
BEGIN
    -- Validate input
    IF p_liker_id = p_liked_id THEN
        RAISE EXCEPTION 'Cannot like yourself';
    END IF;

    -- Insert the like (or do nothing if already exists)
    INSERT INTO likes (liker_id, liked_id)
    VALUES (p_liker_id, p_liked_id)
    ON CONFLICT (liker_id, liked_id) DO NOTHING;

    -- Check if this created a mutual like (match)
    SELECT check_mutual_like(p_liker_id, p_liked_id) INTO v_is_match;

    IF v_is_match THEN
        -- Determine consistent ordering for conversation (user_1 < user_2)
        IF p_liker_id < p_liked_id THEN
            v_user_1 := p_liker_id;
            v_user_2 := p_liked_id;
        ELSE
            v_user_1 := p_liked_id;
            v_user_2 := p_liker_id;
        END IF;

        -- Create conversation if it doesn't exist
        INSERT INTO conversations (id_user_1, id_user_2)
        VALUES (v_user_1, v_user_2)
        ON CONFLICT (id_user_1, id_user_2) DO NOTHING
        RETURNING id INTO v_conversation_id;

        -- If conversation already existed, fetch its ID
        IF v_conversation_id IS NULL THEN
            SELECT id INTO v_conversation_id
            FROM conversations
            WHERE id_user_1 = v_user_1 AND id_user_2 = v_user_2;
        END IF;

        RETURN QUERY SELECT v_is_match, v_conversation_id;
    ELSE
        RETURN QUERY SELECT false, NULL::UUID;
    END IF;
END;
$$;

-- Function: Get all matches for a user (conversations they're part of)
CREATE OR REPLACE FUNCTION get_user_matches(p_user_id UUID)
RETURNS TABLE (
    conversation_id UUID,
    other_user_id UUID,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        CASE 
            WHEN c.id_user_1 = p_user_id THEN c.id_user_2 
            ELSE c.id_user_1 
        END,
        c.created_at
    FROM conversations c
    WHERE c.id_user_1 = p_user_id OR c.id_user_2 = p_user_id
    ORDER BY c.updated_at DESC;
END;
$$;

-- Function: Get unread message count for a user across all conversations
CREATE OR REPLACE FUNCTION get_unread_message_count(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM messages
    WHERE id_user_2 = p_user_id AND status = 'unread';
    
    RETURN v_count;
END;
$$;