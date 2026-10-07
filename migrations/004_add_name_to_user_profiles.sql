-- Migration: Add name column to user_profiles
-- Description: Stores the user's first name so it can be displayed above their board.

ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS name TEXT;
