import 'package:flutter/widgets.dart';
import '../services/settings_service.dart';

class I18n {
  // Romanize Romanian (strip diacritics) per requirement
  static String _romanizeRo(String input) {
    return input
        .replaceAll('ș', 's')
        .replaceAll('ş', 's')
        .replaceAll('ț', 't')
        .replaceAll('ţ', 't')
        .replaceAll('ă', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('Ș', 'S')
        .replaceAll('Ş', 'S')
        .replaceAll('Ț', 'T')
        .replaceAll('Ţ', 'T')
        .replaceAll('Ă', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('Î', 'I');
  }

  static const _k = <String, Map<String, String>>{
    // Core
    'app_title': {'hu': 'Alkalmazás', 'en': 'Application', 'ro': 'Aplicatie'},
    'home': {'hu': 'Kezdőlap', 'en': 'Home', 'ro': 'Acasa'},
    'profile': {'hu': 'Profil', 'en': 'Profile', 'ro': 'Profil'},
    'settings': {'hu': 'Beállítások', 'en': 'Settings', 'ro': 'Setari'},
    'help': {'hu': 'Súgó', 'en': 'Help', 'ro': 'Ajutor'},
    'create': {'hu': 'Létrehozás', 'en': 'Create', 'ro': 'Creeaza'},
    'search': {'hu': 'Keresés', 'en': 'Search', 'ro': 'Cauta'},
    'messages': {'hu': 'Üzenetek', 'en': 'Messages', 'ro': 'Mesaje'},
    'new_posts': {'hu': 'Új bejegyzések érhetők el', 'en': 'New posts available', 'ro': 'Sunt postari noi disponibile'},
    'reload': {'hu': 'Frissít', 'en': 'Reload', 'ro': 'Reincarca'},
    'saved': {'hu': 'Mentve', 'en': 'Saved', 'ro': 'Salvat'},
    'posted': {'hu': 'Közzétéve', 'en': 'Posted', 'ro': 'Postat'},
    'error': {'hu': 'Hiba', 'en': 'Error', 'ro': 'Eroare'},
    'help_placeholder': {
      'hu': 'Itt hamarosan tippek és útmutatók lesznek.',
      'en': 'Helpful tips are coming soon.',
      'ro': 'Sfaturi utile vor fi disponibile in curand.'
    },
    'theme': {'hu': 'Téma', 'en': 'Theme', 'ro': 'Tema'},
    'language': {'hu': 'Nyelv', 'en': 'Language', 'ro': 'Limba'},
    'system': {'hu': 'Rendszer', 'en': 'System', 'ro': 'Sistem'},
    'light': {'hu': 'Világos', 'en': 'Light', 'ro': 'Luminos'},
    'dark': {'hu': 'Sötét', 'en': 'Dark', 'ro': 'Intunecat'},
    'scheduled': {'hu': 'Ütemezett', 'en': 'Scheduled', 'ro': 'Programat'},
    'appearance': {'hu': 'Megjelenés', 'en': 'Appearance', 'ro': 'Aspect'},
    'appearance_hint': {
      'hu': 'Hangold a felületet a hangulatodhoz – téma, színek, fényerő.',
      'en': 'Fine-tune the interface with futuristic themes and colors.',
      'ro': 'Personalizează interfața cu teme și culori futuriste.'
    },
    'settings_tagline': {
      'hu': 'Állíts be mindent a 2025-ös vibe-hoz igazodva.',
      'en': 'Tailor every pixel for a 2025-ready experience.',
      'ro': 'Personalizează fiecare detaliu pentru o experiență 2025.'
    },
    'theme_mode': {'hu': 'Téma mód', 'en': 'Theme mode', 'ro': 'Mod temă'},
    'dynamic_color': {'hu': 'Dinamikus színek', 'en': 'Dynamic colors', 'ro': 'Culori dinamice'},
    'dynamic_color_hint': {
      'hu': 'Automatikus Material You árnyalatok az eszköz háttérképe alapján.',
      'en': 'Adopt Material You shades from your device wallpaper.',
      'ro': 'Adoptă nuanțe Material You inspirate de tapetul dispozitivului.'
    },
    'true_black': {'hu': 'Valódi fekete mód', 'en': 'True black mode', 'ro': 'Mod negru absolut'},
    'high_contrast': {'hu': 'Magas kontraszt', 'en': 'High contrast', 'ro': 'Contrast ridicat'},
    'accent_color': {'hu': 'Kiemelő szín', 'en': 'Accent color', 'ro': 'Culoare accent'},
    'accent_default': {'hu': 'Alapértelmezett', 'en': 'Default', 'ro': 'Implicit'},
    'start_time': {'hu': 'Indulás', 'en': 'Start', 'ro': 'Start'},
    'end_time': {'hu': 'Leállítás', 'en': 'End', 'ro': 'Final'},
    'reading_experience': {'hu': 'Olvasási élmény', 'en': 'Reading experience', 'ro': 'Experiență de lectură'},
    'reading_experience_hint': {
      'hu': 'Betűméret, animációk és rezgések testreszabása.',
      'en': 'Adjust typography, motion and tactile feedback.',
      'ro': 'Ajustează tipografia, mișcarea și feedback-ul haptic.'
    },
    'text_scale': {'hu': 'Szövegméret', 'en': 'Text size', 'ro': 'Dimensiune text'},
    'haptics': {'hu': 'Haptikus visszajelzés', 'en': 'Haptic feedback', 'ro': 'Feedback haptic'},
    'language_hint': {
      'hu': 'Válaszd ki az alkalmazás nyelvét. Rendszer = automatikus.',
      'en': 'Choose the interface language. System = automatic.',
      'ro': 'Alege limba interfeței. Sistem = automat.'
    },
    'advanced': {'hu': 'Haladó', 'en': 'Advanced', 'ro': 'Avansat'},
    'advanced_hint': {
      'hu': 'Exportálás, importálás és gyári alaphelyzet.',
      'en': 'Export, import and reset settings.',
      'ro': 'Exportă, importă și resetează setările.'
    },
    'export_settings': {'hu': 'Beállítások exportálása', 'en': 'Export settings', 'ro': 'Exportă setările'},
    'export_settings_hint': {
      'hu': 'Másold vágólapra JSON formátumban.',
      'en': 'Copy everything as JSON to your clipboard.',
      'ro': 'Copiază totul în format JSON în clipboard.'
    },
    'import_settings': {'hu': 'Beállítások importálása', 'en': 'Import settings', 'ro': 'Importă setările'},
    'import_settings_hint': {
      'hu': 'Illessz be korábban exportált JSON-t.',
      'en': 'Paste JSON exported from another device.',
      'ro': 'Inserează JSON exportat de pe alt dispozitiv.'
    },
    'paste_settings_hint': {
      'hu': 'Illeszd be ide a JSON konfigurációt...',
      'en': 'Paste the JSON configuration here...',
      'ro': 'Lipește aici configurația JSON...'
    },
    'settings_copied': {'hu': 'Beállítások vágólapra másolva.', 'en': 'Settings copied to clipboard.', 'ro': 'Setările au fost copiate.'},
    'import_success': {'hu': 'Importálás sikeres.', 'en': 'Import successful.', 'ro': 'Import reușit.'},
    'import_failed': {'hu': 'Importálás sikertelen', 'en': 'Import failed', 'ro': 'Import eșuat'},
    'reset': {'hu': 'Alaphelyzet', 'en': 'Reset', 'ro': 'Resetare'},
    'reset_hint': {
      'hu': 'Minden beállítás visszaáll az alap értékre.',
      'en': 'Restore every preference to its default.',
      'ro': 'Revino la valorile implicite pentru toate preferințele.'
    },
    'reset_confirm': {
      'hu': 'Biztosan visszaállítod az összes beállítást?',
      'en': 'Do you really want to reset all settings?',
      'ro': 'Sigur dorești să resetezi toate setările?'
    },
    'reset_done': {'hu': 'Beállítások visszaállítva.', 'en': 'Settings restored.', 'ro': 'Setările au fost resetate.'},
    // Common actions
    'ok': {'hu': 'OK', 'en': 'OK', 'ro': 'OK'},
    'cancel': {'hu': 'Mégse', 'en': 'Cancel', 'ro': 'Anuleaza'},
    'close': {'hu': 'Bezárás', 'en': 'Close', 'ro': 'Inchide'},
    'save': {'hu': 'Mentés', 'en': 'Save', 'ro': 'Salveaza'},
    'discard': {'hu': 'Elvet', 'en': 'Discard', 'ro': 'Renunta'},
    'delete': {'hu': 'Törlés', 'en': 'Delete', 'ro': 'Sterge'},
    'open': {'hu': 'Megnyitás', 'en': 'Open', 'ro': 'Deschide'},
    'edit': {'hu': 'Szerkesztés', 'en': 'Edit', 'ro': 'Editeaza'},
    'copied': {'hu': 'Másolva', 'en': 'Copied', 'ro': 'Copiat'},
    // Profile specific
    'not_authenticated': {'hu': 'Nem vagy bejelentkezve.', 'en': 'You are not authenticated.', 'ro': 'Nu esti autentificat.'},
    'profile_saved': {'hu': 'Profil mentve.', 'en': 'Profile saved.', 'ro': 'Profil salvat.'},
    'save_failed': {'hu': 'Mentés sikertelen', 'en': 'Save failed', 'ro': 'Salvare esuata'},
    'avatar_updated': {'hu': 'Avatar frissítve.', 'en': 'Avatar updated.', 'ro': 'Avatar actualizat.'},
    'banner_updated': {'hu': 'Banner frissítve.', 'en': 'Banner updated.', 'ro': 'Banner actualizat.'},
    'upload_error': {'hu': 'Feltöltési hiba', 'en': 'Upload error', 'ro': 'Eroare upload'},
    'avatar_delete_failed': {'hu': 'Avatar törlése sikertelen', 'en': 'Avatar delete failed', 'ro': 'Stergere avatar esuata'},
    'banner_delete_failed': {'hu': 'Banner törlése sikertelen', 'en': 'Banner delete failed', 'ro': 'Stergere banner esuata'},
    'invalid_session': {'hu': 'Érvénytelen/lejárt munkamenet. Jelentkezz be újra.', 'en': 'Invalid/expired session. Please sign in again.', 'ro': 'Sesiune invalida/expirata. Te rugam sa te reconectezi.'},
    'unsaved_changes': {'hu': 'Mentetlen módosítások', 'en': 'Unsaved changes', 'ro': 'Modificari nesalvate'},
    'leave_without_saving': {'hu': 'Elhagyod az oldalt mentés nélkül?', 'en': 'Leave page without saving?', 'ro': 'Vrei sa parasesti pagina fara sa salvezi?'},
    // Choosers
    'pick_from_gallery': {'hu': 'Válassz a galériából', 'en': 'Choose from gallery', 'ro': 'Alege din galerie'},
    'take_photo': {'hu': 'Készíts fotót', 'en': 'Take a photo', 'ro': 'Fa o poza'},
    'delete_avatar': {'hu': 'Avatar törlése', 'en': 'Delete avatar', 'ro': 'Sterge avatarul'},
    'zoom_avatar': {'hu': 'Nagyítás (pinch-to-zoom)', 'en': 'Zoom (pinch-to-zoom)', 'ro': 'Marire (pinch-to-zoom)'},
    'image_load_error': {'hu': 'Hiba a kép betöltésekor', 'en': 'Error loading image', 'ro': 'Eroare la incarcare imagine'},
    'pick_banner': {'hu': 'Válassz bannert', 'en': 'Choose banner', 'ro': 'Alege bannerul'},
    'delete_banner': {'hu': 'Banner törlése', 'en': 'Delete banner', 'ro': 'Sterge bannerul'},
    'banner_load_error': {'hu': 'Hiba a banner betöltésekor', 'en': 'Error loading banner', 'ro': 'Eroare la incarcare banner'},
    'edit_banner': {'hu': 'Banner szerkesztése', 'en': 'Edit banner', 'ro': 'Editeaza bannerul'},
    'no_banner': {'hu': 'Nincs beállított banner', 'en': 'No banner set', 'ro': 'Fara banner setat'},
    // Settings bits
    'stickers': {'hu': 'Matricák', 'en': 'Stickers', 'ro': 'Stickere'},
    'choose_sticker': {'hu': 'Válassz matricát', 'en': 'Choose a sticker', 'ro': 'Alege un sticker'},
    'remove': {'hu': 'Eltávolítás', 'en': 'Remove', 'ro': 'Sterge'},
    'reduce_motion': {'hu': 'Animációk csökkentése (minimális effektusok)', 'en': 'Reduce motion (minimal effects)', 'ro': 'Reduce motion (efecte minime)'},
    'halo_power': {'hu': 'Halo ereje', 'en': 'Halo power', 'ro': 'Puterea haloului'},
    'no_stickers': {'hu': 'Nincs elérhető matrica. Adj hozzá PNG-ket az assets/stickers mappába.', 'en': 'No stickers available. Add PNGs to assets/stickers.', 'ro': 'Nu exista stickere disponibile. Adauga PNG-uri in assets/stickers.'},
    'social_media': {'hu': 'Közösségi média', 'en': 'Social media', 'ro': 'Social media'},
    'edit_link': {'hu': 'Link szerkesztése', 'en': 'Edit link', 'ro': 'Editeaza: link'},
    'link_hint': {'hu': 'Link vagy @felhasználó (pl. https://..., @user, user)', 'en': 'Link or @handle (e.g., https://..., @user, user)', 'ro': 'Link sau @handle (ex. https://..., @user, user)'},
    'open_link': {'hu': 'Megnyitás', 'en': 'Open', 'ro': 'Deschide'},
    'link_copied': {'hu': 'Link másolva.', 'en': 'Link copied.', 'ro': 'Link copiat.'},
    'whats_on_your_mind': {'hu': 'Mi jár a fejedben?', 'en': "What's on your mind?", 'ro': 'La ce te gandesti?'},
    'add_image': {'hu': 'Kép hozzáadása', 'en': 'Add image', 'ro': 'Adauga imagine'},
    'gif_from_device': {'hu': 'GIF választása eszközről', 'en': 'Pick GIF from device', 'ro': 'Alege GIF din dispozitiv'},
    'gif_from_url': {'hu': 'GIF beillesztése URL-ből', 'en': 'Paste GIF URL', 'ro': 'Introdu URL GIF'},
    'gif_url_hint': {'hu': 'https://...', 'en': 'https://...', 'ro': 'https://...'},
    'invalid_gif': {'hu': 'Csak GIF fájl választható.', 'en': 'Only GIF files are supported.', 'ro': 'Doar fișiere GIF sunt acceptate.'},
    'invalid_gif_url': {'hu': 'Érvénytelen GIF hivatkozás.', 'en': 'Invalid GIF URL.', 'ro': 'URL GIF invalid.'},
    'create_post': {'hu': 'Bejegyzés létrehozása', 'en': 'Create post', 'ro': 'Creeaza postare'},
    'edit_post': {'hu': 'Bejegyzés szerkesztése', 'en': 'Edit post', 'ro': 'Editeaza postarea'},
    'share_something': {'hu': 'Ossz meg valamit...', 'en': 'Share something...', 'ro': 'Imparte ceva...'},
    'publish': {'hu': 'Közzététel', 'en': 'Publish', 'ro': 'Publica'},
    'post_published': {'hu': 'Bejegyzés közzétéve.', 'en': 'Post published.', 'ro': 'Postare publicata.'},
    'post_updated': {'hu': 'Bejegyzés frissítve.', 'en': 'Post updated.', 'ro': 'Postare actualizata.'},
    'post_deleted': {'hu': 'Bejegyzés törölve.', 'en': 'Post deleted.', 'ro': 'Postare stearsa.'},
    'delete_post_confirm': {
      'hu': 'Biztosan törlöd a bejegyzést?',
      'en': 'Are you sure you want to delete this post?',
      'ro': 'Sigur vrei sa stergi aceasta postare?'
    },
    'gif_fetch_failed': {'hu': 'GIF letöltése sikertelen.', 'en': 'Failed to fetch GIF.', 'ro': 'Descărcarea GIF-ului a eșuat.'},
    'edit_attachment_not_supported': {
      'hu': 'A csatolmány módosítása szerkesztéskor nem támogatott.',
      'en': 'Updating attachments while editing is not supported.',
      'ro': 'Actualizarea atașamentelor în timpul editării nu este suportată.'
    },
    'feeling_activity': {'hu': 'Hangulat', 'en': 'Feeling', 'ro': 'Stare'},
    'tag_friends': {'hu': 'Barátok megjelölése', 'en': 'Tag friends', 'ro': 'Eticheteaza prieteni'},
    'check_in': {'hu': 'Helyszín bejelölése', 'en': 'Check in', 'ro': 'Check-in'},
    'go_live': {'hu': 'Élő indítása', 'en': 'Go live', 'ro': 'Porneste live'},
    'no_comments_yet': {'hu': 'Még nincs hozzászólás.', 'en': 'No comments yet.', 'ro': 'Nu exista comentarii.'},
    'delete_comment_confirm': {
      'hu': 'Biztosan törlöd a hozzászólást?',
      'en': 'Delete this comment?',
      'ro': 'Stergi acest comentariu?'
    },
    'comment_deleted': {'hu': 'Hozzászólás törölve.', 'en': 'Comment deleted.', 'ro': 'Comentariu sters.'},
    'write_comment': {'hu': 'Írj egy hozzászólást...', 'en': 'Write a comment...', 'ro': 'Scrie un comentariu...'},
    'share': {'hu': 'Megosztás', 'en': 'Share', 'ro': 'Distribuie'},
    'like': {'hu': 'Tetszik', 'en': 'Like', 'ro': 'Imi place'},
    'liked': {'hu': 'Tetszik', 'en': 'Liked', 'ro': 'Apreciat'},
    'comment': {'hu': 'Hozzászólás', 'en': 'Comment', 'ro': 'Comentariu'},
    'coming_soon': {'hu': 'Hamarosan', 'en': 'Coming soon', 'ro': 'In curand'},
    'add_status': {'hu': 'Állapot hozzáadása', 'en': 'Add status', 'ro': 'Adauga stare'},
    'reactions': {'hu': 'Reakciók', 'en': 'Reactions', 'ro': 'Reactii'},
    'people_reacted': {
      'hu': 'Reagálók listája',
      'en': 'People who reacted',
      'ro': 'Persoane care au reactionat'
    },
    'no_reactions_yet': {
      'hu': 'Még nincs reakció.',
      'en': 'No reactions yet.',
      'ro': 'Nu exista reactii.'
    },
    'hide_replies': {'hu': 'Válaszok elrejtése', 'en': 'Hide replies', 'ro': 'Ascunde raspunsuri'},
    'view_replies': {
      'hu': 'Mutasd a %d választ',
      'en': 'View %d replies',
      'ro': 'Vezi %d raspunsuri'
    },
    'choose_reaction': {'hu': 'Válassz reakciót', 'en': 'Choose a reaction', 'ro': 'Alege o reactie'},
    'reaction_like': {'hu': 'Tetszik', 'en': 'Like', 'ro': 'Imi place'},
    'reaction_love': {'hu': 'Imádom', 'en': 'Love', 'ro': 'Iubesc'},
    'reaction_care': {'hu': 'Ölelem', 'en': 'Care', 'ro': 'Imi pasa'},
    'reaction_wow': {'hu': 'Hűha', 'en': 'Wow', 'ro': 'Uau'},
    'reaction_haha': {'hu': 'Haha', 'en': 'Haha', 'ro': 'Haha'},
    'reaction_sad': {'hu': 'Szomorú', 'en': 'Sad', 'ro': 'Trist'},
    'reaction_angry': {'hu': 'Dühös', 'en': 'Angry', 'ro': 'Furios'},
    'reply': {'hu': 'Válasz', 'en': 'Reply', 'ro': 'Raspunde'},
    'editing_comment': {
      'hu': 'Hozzászólás szerkesztése',
      'en': 'Editing comment',
      'ro': 'Editezi comentariul'
    },
    'replying_to': {
      'hu': 'Válasz %s részére',
      'en': 'Replying to %s',
      'ro': 'Raspunzi lui %s'
    },
    'add_emoji': {'hu': 'Emoji hozzáadása', 'en': 'Add emoji', 'ro': 'Adauga emoji'},
    'attach_gif': {'hu': 'GIF csatolása', 'en': 'Attach GIF', 'ro': 'Ataseaza GIF'},
    'attach_photo': {'hu': 'Fotó csatolása', 'en': 'Attach photo', 'ro': 'Ataseaza fotografie'},
    'attachment_added': {'hu': 'Csatolmány hozzáadva.', 'en': 'Attachment added.', 'ro': 'Atasament adaugat.'},
    'attachment_removed': {'hu': 'Csatolmány eltávolítva.', 'en': 'Attachment removed.', 'ro': 'Atasament eliminat.'},
    'uploading_attachment': {'hu': 'Csatolmány feltöltése...', 'en': 'Uploading attachment...', 'ro': 'Se incarca atasamentul...'},
    'attachment_upload_failed': {
      'hu': 'A csatolmány feltöltése sikertelen',
      'en': 'Attachment upload failed',
      'ro': 'Incarcarea atasamentului a esuat'
    },
    'use_current_location': {
      'hu': 'Aktuális hely használata',
      'en': 'Use current location',
      'ro': 'Folosește locația curentă'
    },
    'set_location': {'hu': 'Hely megadása', 'en': 'Set location', 'ro': 'Setează locația'},
    'location_hint': {'hu': 'Város, helyszín...', 'en': 'City, venue...', 'ro': 'Oraș, locație...'},
    'location_fetch_failed': {
      'hu': 'Nem sikerült a helyzetet lekérni.',
      'en': 'Could not determine location.',
      'ro': 'Nu s-a putut determina locația.'
    },
  };

  static String t(BuildContext context, String key) {
    final code = SettingsController.instance.locale?.languageCode ??
        Localizations.localeOf(context).languageCode;
    final m = _k[key];
    if (m == null) return key;
    // Default/fallback is Romanian without diacritics
    final ro = _romanizeRo(m['ro'] ?? '');
    if (code == 'hu') return m['hu'] ?? ro;
    if (code == 'en') return m['en'] ?? ro;
    return ro; // any other -> Romanian (romanized)
  }
}