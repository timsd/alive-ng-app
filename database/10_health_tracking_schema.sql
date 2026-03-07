-- ALIVE NG App - Health Tracking Database Schema
-- This file contains health and wellness tracking tables
-- Compatible with Supabase PostgreSQL

-- Enable UUID extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- HEALTH TRACKING TABLES
-- ============================================================================

-- Nigerian meal plans table
CREATE TABLE IF NOT EXISTS public.nigerian_meal_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  meal_type VARCHAR(50) NOT NULL, -- breakfast, lunch, dinner, snack
  region VARCHAR(50) NOT NULL, -- north, south, middle_belt, coastal
  difficulty_level VARCHAR(20) DEFAULT 'medium', -- easy, medium, hard
  prep_time_minutes INTEGER,
  cook_time_minutes INTEGER,
  servings INTEGER DEFAULT 1,
  calories_per_serving INTEGER,
  ingredients JSONB,
  instructions TEXT[],
  nutritional_info JSONB,
  tags TEXT[],
  is_vegetarian BOOLEAN DEFAULT false,
  is_vegan BOOLEAN DEFAULT false,
  is_gluten_free BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Meal plan days table
CREATE TABLE IF NOT EXISTS public.meal_plan_days (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  breakfast_meal_id UUID REFERENCES public.nigerian_meal_plans(id),
  lunch_meal_id UUID REFERENCES public.nigerian_meal_plans(id),
  dinner_meal_id UUID REFERENCES public.nigerian_meal_plans(id),
  snack_meal_ids UUID[],
  total_calories INTEGER DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(user_id, date)
);

-- Health goals table
CREATE TABLE IF NOT EXISTS public.health_goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  goal_type VARCHAR(50) NOT NULL, -- weight_loss, muscle_gain, maintenance, etc.
  target_value DECIMAL(10,2),
  current_value DECIMAL(10,2),
  unit VARCHAR(20), -- kg, lbs, etc.
  target_date DATE,
  is_active BOOLEAN DEFAULT true,
  is_achieved BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Health metrics tracking
CREATE TABLE IF NOT EXISTS public.health_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  metric_type VARCHAR(50) NOT NULL, -- weight, height, bmi, blood_pressure, etc.
  value DECIMAL(10,2) NOT NULL,
  unit VARCHAR(20) NOT NULL,
  recorded_date DATE DEFAULT CURRENT_DATE,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Natural remedies table
CREATE TABLE IF NOT EXISTS public.natural_remedies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  remedy_type VARCHAR(50) NOT NULL, -- herbal, dietary, lifestyle, etc.
  ingredients TEXT[],
  preparation_method TEXT,
  usage_instructions TEXT,
  benefits TEXT[],
  precautions TEXT[],
  region VARCHAR(50), -- Nigerian region where commonly used
  is_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- User remedy tracking
CREATE TABLE IF NOT EXISTS public.user_remedy_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  remedy_id UUID NOT NULL REFERENCES public.natural_remedies(id) ON DELETE CASCADE,
  started_date DATE DEFAULT CURRENT_DATE,
  ended_date DATE,
  effectiveness_rating INTEGER CHECK (effectiveness_rating >= 1 AND effectiveness_rating <= 5),
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Indexes for nigerian_meal_plans
CREATE INDEX IF NOT EXISTS idx_meal_plans_meal_type ON public.nigerian_meal_plans(meal_type);
CREATE INDEX IF NOT EXISTS idx_meal_plans_region ON public.nigerian_meal_plans(region);
CREATE INDEX IF NOT EXISTS idx_meal_plans_difficulty ON public.nigerian_meal_plans(difficulty_level);

-- Indexes for meal_plan_days
CREATE INDEX IF NOT EXISTS idx_meal_plan_days_user_date ON public.meal_plan_days(user_id, date);
CREATE INDEX IF NOT EXISTS idx_meal_plan_days_date ON public.meal_plan_days(date);

-- Indexes for health_goals
CREATE INDEX IF NOT EXISTS idx_health_goals_user_id ON public.health_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_health_goals_type ON public.health_goals(goal_type);
CREATE INDEX IF NOT EXISTS idx_health_goals_active ON public.health_goals(is_active);

-- Indexes for health_metrics
CREATE INDEX IF NOT EXISTS idx_health_metrics_user_type ON public.health_metrics(user_id, metric_type);
CREATE INDEX IF NOT EXISTS idx_health_metrics_date ON public.health_metrics(recorded_date);

-- Indexes for natural_remedies
CREATE INDEX IF NOT EXISTS idx_remedies_type ON public.natural_remedies(remedy_type);
CREATE INDEX IF NOT EXISTS idx_remedies_region ON public.natural_remedies(region);
CREATE INDEX IF NOT EXISTS idx_remedies_verified ON public.natural_remedies(is_verified);

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Trigger for nigerian_meal_plans table
CREATE TRIGGER update_meal_plans_updated_at
  BEFORE UPDATE ON public.nigerian_meal_plans
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for meal_plan_days table
CREATE TRIGGER update_meal_plan_days_updated_at
  BEFORE UPDATE ON public.meal_plan_days
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for health_goals table
CREATE TRIGGER update_health_goals_updated_at
  BEFORE UPDATE ON public.health_goals
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for natural_remedies table
CREATE TRIGGER update_natural_remedies_updated_at
  BEFORE UPDATE ON public.natural_remedies
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for user_remedy_tracking table
CREATE TRIGGER update_user_remedy_tracking_updated_at
  BEFORE UPDATE ON public.user_remedy_tracking
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();