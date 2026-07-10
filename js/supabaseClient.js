import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Publishable (anon) key — safe to ship to the browser, all access is gated by RLS.
const SUPABASE_URL = 'https://gitiijehmmovfopgzmtl.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdpdGlpamVobW1vdmZvcGd6bXRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3MDYzNDcsImV4cCI6MjA5OTI4MjM0N30.PsjTQs0cBMihjwKEHtwMtd3GfDOn1vahd-VrrDXR9jU';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
