// _shared/wc-countries.ts
// WC country display metadata for Live Activity pushes (match-watcher). Mirrors
// the iOS Country enum's shortName + flagEmoji (Country.swift) so the Lock
// Screen / Dynamic Island shows the same names + flags whether the activity was
// push-started (data from here) or foreground-started (data from Country.swift).
// Flags are emoji because the widget process can't load the remote crest CDN.

export interface WcCountryMeta {
  name: string; // short name, fits the Dynamic Island
  flag: string; // unicode flag emoji
}

export const WC_COUNTRY_META: Record<string, WcCountryMeta> = {
  algeria: { name: "Algeria", flag: "🇩🇿" },
  argentina: { name: "Argentina", flag: "🇦🇷" },
  australia: { name: "Australia", flag: "🇦🇺" },
  austria: { name: "Austria", flag: "🇦🇹" },
  belgium: { name: "Belgium", flag: "🇧🇪" },
  bosnia_herzegovina: { name: "Bosnia", flag: "🇧🇦" },
  brazil: { name: "Brazil", flag: "🇧🇷" },
  canada: { name: "Canada", flag: "🇨🇦" },
  cape_verde: { name: "Cape Verde", flag: "🇨🇻" },
  colombia: { name: "Colombia", flag: "🇨🇴" },
  congo_dr: { name: "DR Congo", flag: "🇨🇩" },
  croatia: { name: "Croatia", flag: "🇭🇷" },
  curacao: { name: "Curaçao", flag: "🇨🇼" },
  czech_republic: { name: "Czechia", flag: "🇨🇿" },
  ecuador: { name: "Ecuador", flag: "🇪🇨" },
  egypt: { name: "Egypt", flag: "🇪🇬" },
  england: { name: "England", flag: "🏴󠁧󠁢󠁥󠁮󠁧󠁿" },
  france: { name: "France", flag: "🇫🇷" },
  germany: { name: "Germany", flag: "🇩🇪" },
  ghana: { name: "Ghana", flag: "🇬🇭" },
  haiti: { name: "Haiti", flag: "🇭🇹" },
  iran: { name: "Iran", flag: "🇮🇷" },
  iraq: { name: "Iraq", flag: "🇮🇶" },
  ivory_coast: { name: "Ivory Coast", flag: "🇨🇮" },
  japan: { name: "Japan", flag: "🇯🇵" },
  jordan: { name: "Jordan", flag: "🇯🇴" },
  mexico: { name: "Mexico", flag: "🇲🇽" },
  morocco: { name: "Morocco", flag: "🇲🇦" },
  netherlands: { name: "Netherlands", flag: "🇳🇱" },
  new_zealand: { name: "NZ", flag: "🇳🇿" },
  norway: { name: "Norway", flag: "🇳🇴" },
  panama: { name: "Panama", flag: "🇵🇦" },
  paraguay: { name: "Paraguay", flag: "🇵🇾" },
  portugal: { name: "Portugal", flag: "🇵🇹" },
  qatar: { name: "Qatar", flag: "🇶🇦" },
  saudi_arabia: { name: "Saudi", flag: "🇸🇦" },
  scotland: { name: "Scotland", flag: "🏴󠁧󠁢󠁳󠁣󠁴󠁿" },
  senegal: { name: "Senegal", flag: "🇸🇳" },
  south_africa: { name: "S. Africa", flag: "🇿🇦" },
  south_korea: { name: "Korea", flag: "🇰🇷" },
  spain: { name: "Spain", flag: "🇪🇸" },
  sweden: { name: "Sweden", flag: "🇸🇪" },
  switzerland: { name: "Swiss", flag: "🇨🇭" },
  tunisia: { name: "Tunisia", flag: "🇹🇳" },
  turkiye: { name: "Türkiye", flag: "🇹🇷" },
  uruguay: { name: "Uruguay", flag: "🇺🇾" },
  usa: { name: "USA", flag: "🇺🇸" },
  uzbekistan: { name: "Uzbekistan", flag: "🇺🇿" },
};

/// Period-based status label for the activity badge. Deliberately NOT the live
/// minute — minute-ticking would push an update every minute per activity;
/// period changes + goals are the moments worth a push, keeping APNs volume
/// sane while the activity stays fresh (a generous stale-date covers quiet
/// periods).
export function wcStatusLabel(status: string): string {
  switch (status) {
    case "NS":
      return "KO";
    case "1H":
      return "1st half";
    case "HT":
      return "HT";
    case "2H":
      return "2nd half";
    case "ET":
      return "Extra time";
    case "BT":
      return "Extra time";
    case "P":
      return "Penalties";
    case "FT":
    case "AET":
    case "PEN":
      return "FT";
    default:
      return status;
  }
}
