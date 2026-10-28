-- 141_set_team_page_cards.sql  (bug hunt 2026-10-27)
--
-- Three writers read a club's whole team_pages.content and wrote it back: the
-- two-hourly refresh (team-page-generator dynamic_only) and match-watcher's
-- post_match and last_match cards. A refresh that read before full time and
-- saved after it erased the After card, which is written once and never
-- again. This writes cards, not documents: the given keys are set, p_drop
-- removed, everything else on the row left exactly as it is now.
CREATE OR REPLACE FUNCTION public.set_team_page_cards(
  p_team_id text, p_cards jsonb, p_drop text[] DEFAULT '{}', p_touch boolean DEFAULT false
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $$
  WITH u AS (
    UPDATE public.team_pages
       SET content = jsonb_set(content, '{cards}',
             (COALESCE(content->'cards', '{}'::jsonb) - p_drop) || p_cards),
           updated_at = CASE WHEN p_touch THEN now() ELSE updated_at END
     WHERE team_id = p_team_id
    RETURNING 1
  )
  SELECT EXISTS (SELECT 1 FROM u);
$$;
REVOKE EXECUTE ON FUNCTION public.set_team_page_cards(text, jsonb, text[], boolean) FROM PUBLIC, anon, authenticated;
