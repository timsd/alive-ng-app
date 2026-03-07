-- ALIVE NG App - Donation Management Database Schema
-- This file contains donation and financial tracking tables
-- Compatible with Supabase PostgreSQL

-- Enable UUID extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- DONATION MANAGEMENT TABLES
-- ============================================================================

-- Donation records table
CREATE TABLE IF NOT EXISTS public.donation_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  donor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
  currency VARCHAR(10) DEFAULT 'NGN',
  donation_type VARCHAR(50) NOT NULL, -- mission_support, charity, special_project
  payment_method VARCHAR(50) NOT NULL, -- bank_transfer, mobile_money, card_payment,
  transaction_reference VARCHAR(255) UNIQUE,
  payment_gateway VARCHAR(50), -- paystack, flutterwave, etc.
  gateway_reference VARCHAR(255),
  status VARCHAR(20) DEFAULT 'pending', -- pending, completed, failed, cancelled, refunded
  description TEXT,
  recipient_chapter_id UUID REFERENCES public.chapters(id),
  is_anonymous BOOLEAN DEFAULT false,
  is_recurring BOOLEAN DEFAULT false,
  recurring_frequency VARCHAR(20), -- weekly, monthly, quarterly, yearly
  next_payment_date DATE,
  payment_date TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Donation campaigns table
CREATE TABLE IF NOT EXISTS public.donation_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  target_amount DECIMAL(15,2) NOT NULL CHECK (target_amount > 0),
  current_amount DECIMAL(15,2) DEFAULT 0,
  currency VARCHAR(10) DEFAULT 'NGN',
  campaign_type VARCHAR(50) NOT NULL,
  start_date DATE DEFAULT CURRENT_DATE,
  end_date DATE,
  is_active BOOLEAN DEFAULT true,
  is_featured BOOLEAN DEFAULT false,
  image_url TEXT,
  organizer_id UUID NOT NULL REFERENCES public.users(id),
  chapter_id UUID REFERENCES public.chapters(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Campaign donations linking table
CREATE TABLE IF NOT EXISTS public.campaign_donations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES public.donation_campaigns(id) ON DELETE CASCADE,
  donation_id UUID NOT NULL REFERENCES public.donation_records(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(campaign_id, donation_id)
);

-- Recurring donation schedules
CREATE TABLE IF NOT EXISTS public.recurring_donations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  donor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
  currency VARCHAR(10) DEFAULT 'NGN',
  donation_type VARCHAR(50) NOT NULL,
  payment_method VARCHAR(50) NOT NULL,
  frequency VARCHAR(20) NOT NULL, -- weekly, monthly, quarterly, yearly
  next_payment_date DATE NOT NULL,
  is_active BOOLEAN DEFAULT true,
  start_date DATE DEFAULT CURRENT_DATE,
  end_date DATE,
  total_payments INTEGER DEFAULT 0,
  successful_payments INTEGER DEFAULT 0,
  failed_payments INTEGER DEFAULT 0,
  last_payment_date DATE,
  recipient_chapter_id UUID REFERENCES public.chapters(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Donation receipts table
CREATE TABLE IF NOT EXISTS public.donation_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  donation_id UUID NOT NULL REFERENCES public.donation_records(id) ON DELETE CASCADE,
  receipt_number VARCHAR(100) UNIQUE NOT NULL,
  receipt_url TEXT,
  issued_date TIMESTAMP DEFAULT NOW(),
  tax_deductible BOOLEAN DEFAULT true,
  tax_year INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Financial reports table
CREATE TABLE IF NOT EXISTS public.financial_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_type VARCHAR(50) NOT NULL, -- monthly, quarterly, yearly, campaign
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_donations DECIMAL(15,2) DEFAULT 0,
  total_mission_support DECIMAL(15,2) DEFAULT 0,
  total_charity DECIMAL(15,2) DEFAULT 0,
  total_special_projects DECIMAL(15,2) DEFAULT 0,
  chapter_id UUID REFERENCES public.chapters(id),
  generated_by UUID NOT NULL REFERENCES public.users(id),
  report_data JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Indexes for donation_records
CREATE INDEX IF NOT EXISTS idx_donations_donor_id ON public.donation_records(donor_id);
CREATE INDEX IF NOT EXISTS idx_donations_type ON public.donation_records(donation_type);
CREATE INDEX IF NOT EXISTS idx_donations_status ON public.donation_records(status);
CREATE INDEX IF NOT EXISTS idx_donations_payment_date ON public.donation_records(payment_date);
CREATE INDEX IF NOT EXISTS idx_donations_chapter ON public.donation_records(recipient_chapter_id);
CREATE INDEX IF NOT EXISTS idx_donations_reference ON public.donation_records(transaction_reference);

-- Indexes for donation_campaigns
CREATE INDEX IF NOT EXISTS idx_campaigns_active ON public.donation_campaigns(is_active);
CREATE INDEX IF NOT EXISTS idx_campaigns_featured ON public.donation_campaigns(is_featured);
CREATE INDEX IF NOT EXISTS idx_campaigns_dates ON public.donation_campaigns(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_campaigns_organizer ON public.donation_campaigns(organizer_id);

-- Indexes for recurring_donations
CREATE INDEX IF NOT EXISTS idx_recurring_donor ON public.recurring_donations(donor_id);
CREATE INDEX IF NOT EXISTS idx_recurring_active ON public.recurring_donations(is_active);
CREATE INDEX IF NOT EXISTS idx_recurring_next_payment ON public.recurring_donations(next_payment_date);

-- Indexes for financial_reports
CREATE INDEX IF NOT EXISTS idx_reports_type_period ON public.financial_reports(report_type, period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_reports_chapter ON public.financial_reports(chapter_id);

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Trigger for donation_records table
CREATE TRIGGER update_donation_records_updated_at
  BEFORE UPDATE ON public.donation_records
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for donation_campaigns table
CREATE TRIGGER update_donation_campaigns_updated_at
  BEFORE UPDATE ON public.donation_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for recurring_donations table
CREATE TRIGGER update_recurring_donations_updated_at
  BEFORE UPDATE ON public.recurring_donations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- FUNCTIONS FOR DONATION MANAGEMENT
-- ============================================================================

-- Function to update campaign current amount when donations are added
CREATE OR REPLACE FUNCTION update_campaign_amount()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.donation_campaigns 
    SET current_amount = current_amount + (
      SELECT amount FROM public.donation_records WHERE id = NEW.donation_id
    )
    WHERE id = NEW.campaign_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.donation_campaigns 
    SET current_amount = current_amount - (
      SELECT amount FROM public.donation_records WHERE id = OLD.donation_id
    )
    WHERE id = OLD.campaign_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update campaign amounts
CREATE TRIGGER update_campaign_amount_trigger
  AFTER INSERT OR DELETE ON public.campaign_donations
  FOR EACH ROW
  EXECUTE FUNCTION update_campaign_amount();

-- Function to generate receipt numbers
CREATE OR REPLACE FUNCTION generate_receipt_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.receipt_number = 'RCP-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(nextval('receipt_sequence')::text, 6, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create sequence for receipt numbers
CREATE SEQUENCE IF NOT EXISTS receipt_sequence START 1;

-- Trigger to generate receipt numbers
CREATE TRIGGER generate_receipt_number_trigger
  BEFORE INSERT ON public.donation_receipts
  FOR EACH ROW
  EXECUTE FUNCTION generate_receipt_number();