@tool
extends RefCounted

# Private domain: editor language only; never alter the game's translations.
const ENGLISH := {
	"Activer Texture Paint": "Enable Texture Paint",
	"Résolution (avant ajout)": "Resolution (before adding)",
	"Couches : 0": "Layers: 0",
	"Couches : %d": "Layers: %d",
	"Aucune texture ajoutée. Cliquez sur Ajouter texture.": "No textures yet. Click Add image / material.",
	"Aucune couche sélectionnée": "No layer selected",
	"Ajouter image / matériau .tres": "Add image / material .tres",
	"Supprimer la couche": "Delete layer",
	"Afficher / masquer la couche": "Show / hide layer",
	"Monter la couche": "Move layer up",
	"Descendre la couche": "Move layer down",
	"Propriétés PBR (inspecteur)": "PBR properties (Inspector)",
	"Enregistrer en bibliothèque .tres": "Save layer preset .tres",
	"Opacité couche": "Layer opacity",
	"Transition (exposant)": "Transition (exponent)",
	"Échelle UV couche": "Layer UV scale",
	"Ajouter": "Add",
	"Remplacer les couches": "Replace layers",
	"Effacer couche": "Erase layer",
	"Lisser couche": "Smooth layer",
	"Restaurer original": "Restore original",
	"Rayon monde": "Radius (world units)",
	"Intensité par seconde": "Strength per second",
	"Dureté": "Hardness",
	"Falloff (exposant)": "Falloff (exponent)",
	"Remplir couche": "Fill layer",
	"Réinitialiser couche": "Reset layer",
	"Inverser masque": "Invert mask",
	"Désactiver / réactiver le rendu": "Disable / enable paint rendering",
	"Retirer le système (réversible)": "Remove paint system (undoable)",
	"Clic gauche maintenu : peindre · Alt : navigation\nCtrl+Z / Ctrl+Y : historique éditeur\nUV automatiques si nécessaire · mesh statique opaque\n32 couches/objet ; 2–8 recommandées.": "Hold left mouse: paint · Alt: navigate\nCtrl+Z / Ctrl+Y: undo / redo\nAutomatic UVs if needed · opaque static meshes\n32 layers/object; 2–8 recommended.",
	"*.png,*.jpg,*.jpeg,*.webp,*.svg,*.tres,*.res ; Image, matériau PBR ou couche": "*.png,*.jpg,*.jpeg,*.webp,*.svg,*.tres,*.res ; Image, PBR material or layer",
	"*.tres ; Bibliothèque TexturePaintLayer": "*.tres ; TexturePaintLayer preset",
	"Sélectionnez un MeshInstance3D statique. Les UV manquants sont générés automatiquement.": "Select a static MeshInstance3D. Missing UVs are generated automatically.",
	"%s : peinture sauvegardée retrouvée (%d couches). Activez le mode pour continuer.": "%s: saved paint found (%d layers). Enable paint mode to continue.",
	"%s : activez le mode pour vérifier les UV.": "%s: enable paint mode to check UVs.",
	"Script non compilé : %s. Consultez la première erreur dans Sortie et relancez Godot après mise à jour du plugin.": "Script failed to compile: %s. Check the first error in Output and restart Godot after updating the plugin.",
	"Sélectionnez un MeshInstance3D avec mesh.": "Select a MeshInstance3D with a mesh.",
	"Squelettes non pris en charge : utilisez un mesh statique.": "Skeletons are not supported. Use a static mesh.",
	"Blend shapes non pris en charge.": "Blend shapes are not supported.",
	"Material Overlay existant : combinaison non prise en charge.": "An existing Material Overlay is not supported.",
	"Surface %d : matériau personnalisé non pris en charge.": "Surface %d: custom materials are not supported.",
	"Surface %d : transparence ou next_pass non pris en charge.": "Surface %d: transparency or next_pass is not supported.",
	"Surface %d : déplacement/fondu du matériau incompatible.": "Surface %d: material displacement or fading is not supported.",
	"Géométrie/UV modifiés après peinture. Restaurez le mesh ou retirez le système pour recommencer.": "Geometry/UVs changed after painting. Restore the mesh or remove the paint system to start over.",
	"Création automatique des UV de peinture…": "Generating paint UVs automatically…",
	"Ajouter Texture Paint": "Add Texture Paint",
	"Prêt · %d triangles · %s · base conservée. Ajoutez une texture.": "Ready · %d triangles · %s · original material preserved. Add a texture.",
	"UV automatiques": "Automatic UVs",
	"[masquée] ": "[hidden] ",
	"Texture albedo absente": "Missing albedo texture",
	"Couche active : %s": "Active layer: %s",
	"Choisissez une image, un matériau Standard/ORM .tres ou un préréglage de couche.": "Choose an image, a Standard/ORM .tres material or a layer preset.",
	"Ajout impossible : activez Texture Paint sur un mesh avant d'ajouter une texture.": "Cannot add texture: enable Texture Paint on a mesh first.",
	"Ajout de texture annulé.": "Texture import cancelled.",
	"Ajout impossible : le mesh ou sa scène a été fermé. Sélectionnez le mesh puis recommencez.": "Cannot add texture: the mesh or its scene was closed. Select the mesh and try again.",
	"Ajout impossible : aucun système Texture Paint actif sur le mesh sélectionné.": "Cannot add texture: no Texture Paint system is active on the selected mesh.",
	"Ajout impossible : limite de 32 couches atteinte sur cet objet.": "Cannot add texture: this object has reached the 32-layer limit.",
	"Chargement de %s…": "Loading %s…",
	"Texture introuvable ou non importée : %s": "Texture not found or not imported: %s",
	"Échec du chargement : %s. Consultez les erreurs d'import Godot.": "Failed to load %s. Check Godot's import errors.",
	"hauteur/parallaxe": "height/parallax",
	"projection triplanaire": "triplanar projection",
	"émission": "emission",
	"détail secondaire": "detail mapping",
	"passes supplémentaires": "additional passes",
	" Cartes PBR importées.": " PBR maps imported.",
	" Non repris : %s.": " Not imported: %s.",
	"Fichier refusé : %s (%s). Choisissez une image, un matériau Standard/ORM ou une couche avec albedo.": "Unsupported file: %s (%s). Choose an image, a Standard/ORM material or a layer with albedo.",
	"Ajouter une couche": "Add layer",
	"Texture ajoutée : %s · %d couche(s). Couche sélectionnée, prête à peindre.%s": "Texture added: %s · %d layer(s). Layer selected and ready to paint.%s",
	"Supprimer couche": "Delete layer",
	"Déplacer couche": "Move layer",
	"Modifier couche %d : %s": "Edit layer %d: %s",
	"Bibliothèque enregistrée : ": "Layer preset saved: ",
	"Échec sauvegarde : %d": "Save failed: %d",
	"Modifier masque entier": "Edit entire mask",
	"Activer rendu peinture": "Toggle paint rendering",
	"Retirer Texture Paint": "Remove Texture Paint",
	"Peindre texture": "Paint texture",
	"Texture Paint : géométrie/UV modifiés. Peinture suspendue pour préserver les masques.": "Texture Paint: geometry/UVs changed. Painting is suspended to preserve the masks.",
	"Peinture indisponible sous Direct3D 12 sur Intel : perte GPU reproduite. Dans les paramètres du projet, choisissez rendering/rendering_device/driver.windows = vulkan, puis redémarrez Godot. Forward+ reste utilisable.": "Painting is unavailable with Direct3D 12 on Intel: a GPU device loss was reproduced. Set rendering/rendering_device/driver.windows = vulkan in Project Settings, then restart Godot. Forward+ is still supported.",
	"Seules les surfaces triangulées sont prises en charge.": "Only triangle surfaces are supported.",
	"UV1 absents sur la surface %d.": "Surface %d has no UV1 coordinates.",
	"UV1 hors [0,1] sur la surface %d.": "Surface %d has UV1 coordinates outside [0,1].",
	"Triangle UV dégénéré sur la surface %d.": "Surface %d has a degenerate UV triangle.",
	"Impossible de construire le BVH.": "Failed to build the BVH.",
	"Le dépliage automatique nécessite des triangles.": "Automatic UV unwrapping requires triangles.",
	"Échec du dépliage automatique Godot (code %d).": "Godot automatic UV unwrapping failed (code %d).",
	"Le dépliage a supprimé une surface dégénérée ; peinture interrompue.": "UV unwrapping removed a degenerate surface; painting was stopped.",
	"Le dépliage Godot ne fournit pas de coordonnées valides.": "Godot UV unwrapping did not produce valid coordinates.",
	"Rouge,Vert,Bleu,Alpha,Gris": "Red,Green,Blue,Alpha,Grayscale",
}

static var _domain: TranslationDomain
static var _language := ""
const EDITOR_DOMAIN := &"mesh_texture_painter.editor"

static func text(source: String) -> String:
	# Share the editor locale even if Windows loads Addons/addons as two scripts.
	var domain := TranslationServer.get_or_add_domain(EDITOR_DOMAIN)
	if domain.get_locale_override().is_empty():
		set_editor_locale(TranslationServer.get_tool_locale())
	return source if domain.get_locale_override() == "fr" else String(domain.translate(source))

static func set_editor_locale(locale: String) -> void:
	var domain := TranslationServer.get_or_add_domain(EDITOR_DOMAIN)
	if not domain.has_translation_for_locale("en", true):
		var english := Translation.new()
		english.locale = "en"
		for message in ENGLISH:
			english.add_message(message, ENGLISH[message])
		domain.add_translation(english)
	domain.set_locale_override("fr" if locale.to_lower().begins_with("fr") else "en")

static func in_language(source: String, locale: String) -> String:
	if _domain == null:
		_domain = TranslationDomain.new()
		var english := Translation.new()
		english.locale = "en"
		for message in ENGLISH:
			english.add_message(message, ENGLISH[message])
		_domain.add_translation(english)
	var language := "fr" if locale.to_lower().begins_with("fr") else "en"
	if language != _language:
		_domain.set_locale_override(language)
		_language = language
	# Source strings form the French catalogue. Avoid project fallback locales.
	return source if language == "fr" else String(_domain.translate(source))
