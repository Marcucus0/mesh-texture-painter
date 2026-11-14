# Mesh Texture Painter — Guide français

**Version 1.0 · Par Rhacode**

[English README](README.md) · [Architecture](docs/ARCHITECTURE.md) · [Tests et développement](docs/DEVELOPMENT.md)

Plugin pour **Godot 4.7.x**, testé avec **4.7.2**. La peinture utilise des masques de texture indépendants du nombre de sommets. Le mesh, les matériaux d’origine et les fichiers importés sont conservés.

## Installation

1. Copier `addons/mesh_texture_painter` dans le projet, en conservant le chemin `addons` en minuscules.
2. Activer **Mesh Texture Painter** dans **Projet → Paramètres du projet → Extensions**.
3. Sélectionner un `MeshInstance3D` statique et opaque pour utiliser le panneau **Texture Paint**.

Pour mettre à jour, fermer Godot, remplacer le dossier du plugin et rouvrir le projet. Les peintures et préférences restent compatibles. Garder les scripts et le shader dans les exports du jeu : ils reconstruisent les couches sauvegardées à l’exécution.

## Utilisation

Pour un modèle personnel :

1. Sélectionner son `MeshInstance3D`, puis activer le mode peinture.
2. Choisir la résolution avant la première couche : **256 ou 512** pour commencer.
3. Cliquer sur **Ajouter image / matériau .tres** et choisir une image, un matériau Standard/ORM ou un préréglage de couche.
4. Maintenir le **clic gauche** sur la surface pour peindre. **Alt** conserve la navigation.
5. Ajuster l’échelle UV de la couche pour répéter sa texture. La résolution des masques contrôle la précision de la peinture ; elle ne contrôle pas la répétition de la texture.
6. Sauvegarder la scène avec **Ctrl+S**. Les masques y sont embarqués.

À la prochaine ouverture, sélectionner le même mesh et réactiver le mode pour continuer à modifier ses couches. L’enfant `TexturePaint` existant est réutilisé.

## Pinceaux et couches

| Outil | Effet |
| --- | --- |
| Ajouter | Accumule la peinture sur la couche active. |
| Remplacer les couches | Ajoute la couche active et efface progressivement les autres sous le pinceau. |
| Effacer couche | Efface uniquement la couche active. |
| Lisser couche | Lisse son masque, sans flouter la texture source. |
| Restaurer original | Efface localement toutes les couches, y compris les couches masquées. |

Le rayon est mesuré en unités monde. L’intensité, la dureté et le falloff règlent la forme du pinceau. L’opacité et la transition de chaque couche restent modifiables après peinture.

La couche en haut de la liste se dessine au-dessus des autres. **Monter / Descendre** déplacent la couche dans la direction annoncée. Masquer une couche conserve ses données. Remplir, réinitialiser et inverser affectent son masque entier, sur toutes les surfaces du mesh.

**Propriétés PBR** donne accès aux cartes albedo, normale, roughness, metallic et AO, à leurs canaux, à la teinte et aux paramètres UV. **Enregistrer en bibliothèque .tres** crée un préréglage sans les masques, réutilisable sur un autre mesh.

**Ctrl+Z** annule ; **Ctrl+Y** rétablit. Un geste maintenu correspond à une action. L’historique Godot ne persiste pas après fermeture, mais les couches et les masques sauvegardés restent modifiables.

Le rayon, l’intensité, la dureté, le falloff et la résolution proposée sont mémorisés localement par projet. Le mode de pinceau démarre toujours sur **Ajouter**. Supprimer les données locales `.godot` réinitialise ces préférences, sans effacer les masques enregistrés dans les scènes.

## Matériau original, imports et UV

Le plugin ajoute des passes de peinture au-dessus de la base. Désactiver le rendu ou retirer l’enfant `TexturePaint` permet de retrouver le matériau original. Le retrait est annulable. Les peintures de meshes dupliqués sont indépendantes ; leurs textures source restent partagées en lecture.

Les GLB/GLTF peuvent être instanciés dans une scène de travail. Activer au besoin **Enfants éditables** pour sélectionner les meshes internes. Les fichiers sources importés ne sont pas réécrits.

Si les UV manquent, sont invalides ou présentent un recouvrement détecté, le plugin génère un atlas sur une copie privée. Le résultat est sauvegardé dans la scène. Ce dépliage automatique peut introduire des coutures ; il ne remplace pas un dépliage artistique. Les recouvrements très fins peuvent échapper au diagnostic. Une modification ultérieure de la topologie ou des UV impose de restaurer le mesh initial ou de recommencer : la reprojection automatique n’est pas implémentée.

## Langue et limites

Le panneau suit la langue de l’éditeur au chargement : français pour les variantes françaises, anglais sinon. La langue du jeu n’influence pas le plugin. Les noms personnalisés des couches ne sont jamais traduits.

Le backend est un prototype de peinture CPU avec rendu multipasse GPU : **32 couches maximum par objet**, **2 à 8 recommandées**, masques de **128 à 2048**. Les grands rayons, grandes résolutions et nombreuses couches visibles restent coûteux. Les matériaux opaques Standard/ORM statiques sont acceptés ; les shaders personnalisés, squelettes, blend shapes et certains effets de matériau sont refusés. Les effets hauteur/parallaxe, triplanaires, d’émission, de détail et les passes supplémentaires ne sont pas repris à l’import des couches.

Les autres objets de la scène ne bloquent que le rayon central du pinceau ; les faces opposées du mesh cible sont protégées texel par texel. Réactiver le mode après déplacement d’un objet occultant. La prévisualisation est un cercle tangent à la surface.

Sous **Intel + Direct3D 12**, la peinture est bloquée après reproduction d’une perte GPU et d’un crash natif. Choisir **Vulkan + Forward+**, avec `rendering/rendering_device/driver.windows = vulkan`, puis redémarrer Godot.

Voir le [README principal](README.md#compatibility-and-limitations) pour les limites complètes du rendu, de la mémoire et des outils.
