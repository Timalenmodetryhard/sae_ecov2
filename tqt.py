# Script Python pour créer et remplir la BDD - CORRECTION DE CHEMIN D'ACCÈS
import pandas as pd
import sqlite3

# 1. Définition des chemins d'accès des fichiers CSV
# ATTENTION: Si les fichiers CSV ne sont pas à la racine de App/, vous devez adapter ces chemins.
PATH_FINAL_CSV = 'spotify_data_preprocessed_final.csv'
PATH_POP_CSV = 'spotify_songs.csv'

# 2. Charger le DataFrame final (avec CP et Cluster_Style)
try:
    df_final = pd.read_csv(PATH_FINAL_CSV)
    print(f"✅ Fichier '{PATH_FINAL_CSV}' chargé.")
except FileNotFoundError:
    print(f"❌ ERREUR: Fichier '{PATH_FINAL_CSV}' non trouvé. Vérifiez le chemin d'accès.")
    exit()

# 3. Charger les données du fichier original pour récupérer 'track_popularity'
try:
    df_pop = pd.read_csv(PATH_POP_CSV, usecols=['track_id', 'track_popularity'])
    print(f"✅ Fichier '{PATH_POP_CSV}' chargé.")
except FileNotFoundError:
    print(f"❌ ERREUR: Fichier '{PATH_POP_CSV}' non trouvé. Vérifiez le chemin d'accès.")
    exit()

# 4. Fusionner les deux DataFrames sur 'track_id'
df = df_final.merge(df_pop, on='track_id', how='left')
print("✅ Fusion des DataFrames réussie (Ajout de 'track_popularity').")

# 5. Ajout de la colonne 'liked'
df['liked'] = 0 

# 6. Créer la connexion à la BDD
# Le fichier 'app_data.db' sera créé dans le même dossier que le script.
conn = sqlite3.connect('app_data.db')

# 7. Écrire le DataFrame corrigé dans la table 'tracks'
df.to_sql('tracks', conn, if_exists='replace', index=False)

# 8. Fermer la connexion
conn.close()

print("\n🚀 Fichier app_data.db CORRIGÉ créé avec succès.")
print("ÉTAPE SUIVANTE : Copiez ce nouveau fichier 'app_data.db' dans le dossier 'App/assets/' et relancez Flutter.")