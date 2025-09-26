-- ALIVE NG App - Daily Verses Database Schema
-- This file contains the daily_verses table and related functionality
-- Compatible with Supabase PostgreSQL

-- Enable UUID extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- DAILY VERSES TABLE
-- ============================================================================

-- Daily verses table - stores daily verses with generation tracking
CREATE TABLE IF NOT EXISTS public.daily_verses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  verse TEXT NOT NULL,
  reference VARCHAR(100) NOT NULL,
  translation VARCHAR(50) DEFAULT 'NIV',
  date DATE NOT NULL UNIQUE,
  reflection TEXT,
  book VARCHAR(50) NOT NULL,
  chapter INTEGER NOT NULL,
  verse_number INTEGER NOT NULL,
  is_generated BOOLEAN DEFAULT true,
  source_verse_id UUID, -- References to bible_verses if applicable
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  -- Ensure unique date constraint
  CONSTRAINT unique_daily_verse_date UNIQUE (date)
);

-- Verse generation tracking table - tracks which verses have been used
CREATE TABLE IF NOT EXISTS public.verse_generation_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  verse_reference VARCHAR(100) NOT NULL,
  book VARCHAR(50) NOT NULL,
  chapter INTEGER NOT NULL,
  verse_number INTEGER NOT NULL,
  used_date DATE,
  is_used BOOLEAN DEFAULT false,
  translation VARCHAR(50) DEFAULT 'NIV',
  created_at TIMESTAMP DEFAULT NOW(),
  
  -- Ensure unique verse per translation
  CONSTRAINT unique_verse_tracking UNIQUE (verse_reference, translation)
);

-- Daily verse generation settings table
CREATE TABLE IF NOT EXISTS public.daily_verse_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key VARCHAR(100) NOT NULL UNIQUE,
  setting_value TEXT,
  description TEXT,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Indexes for daily_verses table
CREATE INDEX IF NOT EXISTS idx_daily_verses_date ON public.daily_verses(date);
CREATE INDEX IF NOT EXISTS idx_daily_verses_book_chapter ON public.daily_verses(book, chapter);
CREATE INDEX IF NOT EXISTS idx_daily_verses_reference ON public.daily_verses(reference);
CREATE INDEX IF NOT EXISTS idx_daily_verses_created_at ON public.daily_verses(created_at);

-- Indexes for verse_generation_tracking table
CREATE INDEX IF NOT EXISTS idx_verse_tracking_reference ON public.verse_generation_tracking(verse_reference);
CREATE INDEX IF NOT EXISTS idx_verse_tracking_used ON public.verse_generation_tracking(is_used);
CREATE INDEX IF NOT EXISTS idx_verse_tracking_book_chapter ON public.verse_generation_tracking(book, chapter);
CREATE INDEX IF NOT EXISTS idx_verse_tracking_used_date ON public.verse_generation_tracking(used_date);

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for daily_verses table
CREATE TRIGGER update_daily_verses_updated_at
  BEFORE UPDATE ON public.daily_verses
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for daily_verse_settings table
CREATE TRIGGER update_daily_verse_settings_updated_at
  BEFORE UPDATE ON public.daily_verse_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- DAILY VERSE GENERATION FUNCTIONS
-- ============================================================================

-- Function to get next unused verse for daily generation
CREATE OR REPLACE FUNCTION get_next_daily_verse()
RETURNS TABLE(
  verse_text TEXT,
  verse_reference VARCHAR(100),
  book_name VARCHAR(50),
  chapter_num INTEGER,
  verse_num INTEGER,
  translation_name VARCHAR(50)
) AS $$
DECLARE
  selected_verse RECORD;
BEGIN
  -- Try to get an unused verse from tracking table
  SELECT vgt.verse_reference, vgt.book, vgt.chapter, vgt.verse_number, vgt.translation
  INTO selected_verse
  FROM public.verse_generation_tracking vgt
  WHERE vgt.is_used = false
  ORDER BY RANDOM()
  LIMIT 1;
  
  -- If no unused verse found, reset all verses and pick one
  IF selected_verse IS NULL THEN
    -- Reset all verses to unused
    UPDATE public.verse_generation_tracking 
    SET is_used = false, used_date = NULL;
    
    -- Get a random verse again
    SELECT vgt.verse_reference, vgt.book, vgt.chapter, vgt.verse_number, vgt.translation
    INTO selected_verse
    FROM public.verse_generation_tracking vgt
    WHERE vgt.is_used = false
    ORDER BY RANDOM()
    LIMIT 1;
  END IF;
  
  -- If still no verse (empty tracking table), return null
  IF selected_verse IS NULL THEN
    RETURN;
  END IF;
  
  -- Mark the verse as used
  UPDATE public.verse_generation_tracking 
  SET is_used = true, used_date = CURRENT_DATE
  WHERE verse_reference = selected_verse.verse_reference 
    AND translation = selected_verse.translation;
  
  -- Return the verse information (verse text would need to be fetched from bible data)
  RETURN QUERY SELECT 
    NULL::TEXT as verse_text, -- Will be populated by application
    selected_verse.verse_reference,
    selected_verse.book,
    selected_verse.chapter,
    selected_verse.verse_number,
    selected_verse.translation;
END;
$$ LANGUAGE plpgsql;

-- Function to generate daily verse for a specific date
CREATE OR REPLACE FUNCTION generate_daily_verse_for_date(target_date DATE)
RETURNS UUID AS $$
DECLARE
  verse_info RECORD;
  new_verse_id UUID;
BEGIN
  -- Check if verse already exists for this date
  SELECT id INTO new_verse_id
  FROM public.daily_verses
  WHERE date = target_date;
  
  IF new_verse_id IS NOT NULL THEN
    RETURN new_verse_id;
  END IF;
  
  -- Get next verse
  SELECT * INTO verse_info
  FROM get_next_daily_verse()
  LIMIT 1;
  
  IF verse_info IS NULL THEN
    RAISE EXCEPTION 'No verses available for generation';
  END IF;
  
  -- Insert new daily verse (verse text will be populated by application)
  INSERT INTO public.daily_verses (
    verse, reference, translation, date, book, chapter, verse_number, is_generated
  ) VALUES (
    'Verse text to be populated by application',
    verse_info.verse_reference,
    verse_info.translation_name,
    target_date,
    verse_info.book_name,
    verse_info.chapter_num,
    verse_info.verse_num,
    true
  ) RETURNING id INTO new_verse_id;
  
  RETURN new_verse_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DEFAULT SETTINGS AND DATA
-- ============================================================================

-- Insert default settings
INSERT INTO public.daily_verse_settings (setting_key, setting_value, description) VALUES
('auto_generation_enabled', 'true', 'Enable automatic daily verse generation'),
('default_translation', 'NIV', 'Default Bible translation for daily verses'),
('generation_time', '00:00:00', 'Time of day to generate new daily verse'),
('reset_cycle_days', '365', 'Number of days before resetting verse cycle'),
('include_reflection', 'false', 'Whether to include reflection with daily verses')
ON CONFLICT (setting_key) DO NOTHING;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE public.daily_verses IS 'Stores daily Bible verses with generation tracking';
COMMENT ON TABLE public.verse_generation_tracking IS 'Tracks which verses have been used to prevent repetition';
COMMENT ON TABLE public.daily_verse_settings IS 'Configuration settings for daily verse generation';

COMMENT ON FUNCTION get_next_daily_verse IS 'Returns the next unused verse for daily generation';
COMMENT ON FUNCTION generate_daily_verse_for_date IS 'Generates a daily verse for a specific date';
COMMENT ON FUNCTION update_updated_at_column IS 'Updates the updated_at timestamp automatically';