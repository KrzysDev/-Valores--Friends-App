-- Migration: Create swipes table
-- Description: Records every swipe (left = skip, right = like) so the app knows
-- which users have already been seen and should not be shown again.

CREATE TABLE IF NOT EXISTS swipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    swiper_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    swiped_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    direction VARCHAR(5) NOT NULL CHECK (direction IN ('left', 'right')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- A user can only swipe another user once (either direction)
    CONSTRAINT swipes_unique_pair UNIQUE (swiper_id, swiped_id),

    -- Prevent self-swipes
    CONSTRAINT swipes_no_self CHECK (swiper_id != swiped_id)
);

-- Index for faster lookup of swipes given by a user
CREATE INDEX IF NOT EXISTS idx_swipes_swiper ON swipes(swiper_id);

-- Enable Row Level Security
ALTER TABLE swipes ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read their own swipes
CREATE POLICY "Users can read their own swipes" ON swipes
    FOR SELECT USING (
        swiper_id = auth.uid()
    );

-- Policy: Users can only insert swipes as themselves
CREATE POLICY "Users can insert their own swipes" ON swipes
    FOR INSERT WITH CHECK (
        swiper_id = auth.uid()
    );

-- Function: Return the IDs a user has already swiped (either direction).
-- Used by discovery to hide people the user has already seen.
CREATE OR REPLACE FUNCTION get_swiped_ids(p_user_id UUID)
RETURNS TABLE (swiped_id UUID)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT swiped_id
    FROM swipes
    WHERE swiper_id = p_user_id;
$$;

-- Function: Record a swipe (left = skip, right = like) atomically.
-- SECURITY DEFINER so the backend can write on behalf of the user without
-- relying on the anon client carrying a user session (same pattern as
-- create_like_and_check_match). Idempotent: re-swiping updates the direction.
CREATE OR REPLACE FUNCTION record_swipe(
    p_swiper_id UUID,
    p_swiped_id UUID,
    p_direction VARCHAR
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF p_swiper_id = p_swiped_id THEN
        RAISE EXCEPTION 'Cannot swipe yourself';
    END IF;

    IF p_direction NOT IN ('left', 'right') THEN
        RAISE EXCEPTION 'direction must be left or right';
    END IF;

    INSERT INTO swipes (swiper_id, swiped_id, direction)
    VALUES (p_swiper_id, p_swiped_id, p_direction)
    ON CONFLICT (swiper_id, swiped_id)
    DO UPDATE SET direction = EXCLUDED.direction;
END;
$$;
