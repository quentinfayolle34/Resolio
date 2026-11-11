// Connexion à la base Supabase de Resolio.
// Ces deux valeurs sont publiques (elles sont dans l'app) : la sécurité est assurée par les règles
// de la base (Row Level Security). Ne mets JAMAIS ici la clé "service_role" / "secret".
window.RESOLIO_CONFIG = {
  supabaseUrl: 'https://dtvmkqeohhlwwviphnkz.supabase.co',
  supabaseKey: 'sb_publishable_2iJn-qqvxAQprBiXYkq17Q_Vw6Kok98',
};
