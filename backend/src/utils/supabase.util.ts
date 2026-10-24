import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

if (!supabaseUrl || !supabaseServiceKey) {
  throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment');
}

export const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { persistSession: false },
});

export const DOCUMENTS_BUCKET = 'study-documents';

/** Generate a signed upload URL (60s expiry) */
export async function createSignedUploadUrl(storagePath: string) {
  const { data, error } = await supabase.storage
    .from(DOCUMENTS_BUCKET)
    .createSignedUploadUrl(storagePath);
  if (error) throw error;
  return data;
}

/** Generate a signed download URL (5 min expiry) for workers to download */
export async function createSignedDownloadUrl(storagePath: string) {
  const { data, error } = await supabase.storage
    .from(DOCUMENTS_BUCKET)
    .createSignedUrl(storagePath, 300);
  if (error) throw error;
  return data.signedUrl;
}

/** Real size of a stored file, or null if it doesn't exist. */
export async function getStorageFileInfo(storagePath: string): Promise<{ size: number } | null> {
  const { data, error } = await supabase.storage
    .from(DOCUMENTS_BUCKET)
    .info(storagePath);
  if (error || !data) return null;
  return { size: data.size ?? 0 };
}

/** Delete a file from Supabase Storage */
export async function deleteStorageFile(storagePath: string) {
  const { error } = await supabase.storage
    .from(DOCUMENTS_BUCKET)
    .remove([storagePath]);
  if (error) throw error;
}
