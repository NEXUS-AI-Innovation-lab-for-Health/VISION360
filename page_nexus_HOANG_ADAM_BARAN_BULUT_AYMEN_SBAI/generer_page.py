#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================================
Vision360 - Générateur de la page Nexus AI (.docx)
=============================================================================
Produit "Page_Nexus_AI_Vision360.docx" : résumé du projet + biographies et
photos de l'équipe, mis en page pour alimenter une page du site Nexus AI.

PHOTOS
------
Déposer les trois portraits dans le sous-dossier photos/ :

    photos/aymen_sbai.jpg      (ou .png)
    photos/adam_hoang.jpg
    photos/baran_bulut.jpg

Le script recadre automatiquement chaque image en carré centré, puis applique
un masque circulaire sur fond blanc — le rendu est identique quelles que
soient les proportions d'origine.

Si une photo est absente, un médaillon provisoire portant les initiales est
inséré à sa place : le document reste complet et correctement mis en page.
Il suffit d'ajouter la photo manquante et de relancer le script.

UTILISATION
-----------
    python generer_page.py

Dépendances : python-docx, Pillow
    pip install python-docx Pillow
=============================================================================
"""

import sys
from pathlib import Path

try:
    from docx import Document
    from docx.enum.section import WD_SECTION
    from docx.enum.table import WD_ALIGN_VERTICAL
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.oxml import OxmlElement
    from docx.oxml.ns import qn
    from docx.shared import Cm, Pt, RGBColor
except ImportError:
    sys.exit("python-docx manquant. Installer avec : pip install python-docx Pillow")

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Pillow manquant. Installer avec : pip install python-docx Pillow")


# =============================================================================
# CONFIGURATION
# =============================================================================

BASE_DIR = Path(__file__).resolve().parent
PHOTOS_DIR = BASE_DIR / "photos"
BUILD_DIR = BASE_DIR / ".build"          # images intermédiaires recadrées
OUTPUT = BASE_DIR / "Page_Nexus_AI_Vision360.docx"

# Palette
BLEU = RGBColor(0x1A, 0x56, 0xDB)        # accent principal
ENCRE = RGBColor(0x0F, 0x17, 0x2A)       # texte courant
GRIS = RGBColor(0x64, 0x74, 0x8B)        # texte secondaire

POLICE = "Calibri"
DIAMETRE_PHOTO_CM = 3.6                  # diamètre du médaillon dans le document
TAILLE_RENDU_PX = 600                    # résolution de l'image générée

# Resserrement appliqué après le recadrage carré : on ne garde que cette
# fraction centrale de l'image. Deux effets recherchés :
#  - le visage occupe une plus grande part du médaillon ;
#  - les artefacts de bord (liserés, fonds détourés) sortent du cadre.
ZOOM = 0.88


# =============================================================================
# ÉQUIPE
# =============================================================================
# `fichier` : nom attendu dans photos/ (sans extension)
# `initiales` : utilisées pour le médaillon provisoire si la photo est absente

EQUIPE = [
    {
        "fichier": "aymen_sbai",
        "nom": "Aymen Sbai",
        "initiales": "AS",
        "role": "Backend & intégration IA",
        "bio": (
            "Boxeur thaï de niveau professionnel, Aymen a apporté au projet la rigueur "
            "qu'il applique à l'entraînement : répéter, mesurer, corriger. Il s'est "
            "concentré sur le cœur du backend — l'API FastAPI et le chaînage des modèles "
            "Gemini et Groq — avec une attention particulière aux cas qui font tomber un "
            "système : réponse mal formée, service externe indisponible, quantité "
            "illisible. C'est cette exigence qui a donné au module d'assistance au "
            "passage en caisse ses vingt-deux tests unitaires. Il défend une idée simple : "
            "un système qui conseille sur la santé n'a pas le droit d'affirmer ce dont il "
            "n'est pas certain."
        ),
    },
    {
        "fichier": "adam_hoang",
        "nom": "Adam Hoang",
        "initiales": "AH",
        "role": "Application mobile & accessibilité",
        "bio": (
            "Passionné de jeux vidéo et de nature, Adam est arrivé sur le projet avec une "
            "conviction empruntée au game design : une interface se juge à ce qu'elle "
            "permet de faire sans y réfléchir. Il a porté l'application Flutter et ses "
            "cinq onglets, en traitant l'accessibilité comme une contrainte de conception "
            "et non comme une option — synthèse vocale à vitesse réglable, contraste "
            "renforcé, grandes zones tactiles. Ses sorties en pleine nature lui ont aussi "
            "donné le goût du guidage : le module GPS piéton, entièrement bâti sur des "
            "services cartographiques libres, est celui qu'il a le plus retravaillé."
        ),
    },
    {
        "fichier": "baran_bulut",
        "nom": "Baran Bulut",
        "initiales": "BB",
        "role": "Données, déploiement & industrialisation",
        "bio": (
            "Sportif et amateur d'aventure, Baran aime les projets qui sortent de la salle "
            "de TP pour tourner pour de vrai. Il s'est chargé du modèle de données "
            "PostgreSQL et de toute la chaîne de déploiement : conteneurisation Docker, "
            "orchestration des trois services, scripts de sauvegarde et de restauration. "
            "C'est en grande partie grâce à ce travail que le projet a survécu à la "
            "fermeture de l'infrastructure cloud : l'image déployée en ligne était déjà "
            "celle que produit un simple « docker compose up »."
        ),
    },
]


# =============================================================================
# TRAITEMENT DES IMAGES
# =============================================================================

def medaillon_depuis_photo(chemin: Path, destination: Path) -> None:
    """
    Recadre une photo en carré centré et lui applique un masque circulaire.

    Le fond est blanc plutôt que transparent : Word gère mal la transparence
    PNG selon les versions, et la page est blanche de toute façon.
    """
    img = Image.open(chemin).convert("RGB")
    cote = min(img.size)

    # Recadrage carré centré, légèrement remonté : sur un portrait, le sujet
    # est presque toujours dans la moitié haute de l'image.
    gauche = (img.width - cote) // 2
    haut = max(0, (img.height - cote) // 2 - int(cote * 0.06))
    img = img.crop((gauche, haut, gauche + cote, haut + cote))

    # Resserrement centré : agrandit le visage et élimine les bords parasites
    marge = int(cote * (1 - ZOOM) / 2)
    if marge > 0:
        img = img.crop((marge, marge, cote - marge, cote - marge))

    img = img.resize((TAILLE_RENDU_PX, TAILLE_RENDU_PX), Image.LANCZOS)

    # Masque circulaire, dessiné en 4x puis réduit pour lisser les bords
    facteur = 4
    masque = Image.new("L", (TAILLE_RENDU_PX * facteur,) * 2, 0)
    ImageDraw.Draw(masque).ellipse(
        (0, 0, TAILLE_RENDU_PX * facteur, TAILLE_RENDU_PX * facteur), fill=255
    )
    masque = masque.resize((TAILLE_RENDU_PX,) * 2, Image.LANCZOS)

    fond = Image.new("RGB", (TAILLE_RENDU_PX,) * 2, (255, 255, 255))
    fond.paste(img, (0, 0), masque)
    fond.save(destination, "PNG")


def medaillon_provisoire(initiales: str, destination: Path) -> None:
    """Médaillon de remplacement affichant les initiales, si la photo manque."""
    facteur = 4
    grand = TAILLE_RENDU_PX * facteur
    img = Image.new("RGB", (grand, grand), (255, 255, 255))
    dessin = ImageDraw.Draw(img)

    # Disque bleu pâle avec liseré
    dessin.ellipse((0, 0, grand, grand), fill=(0xE3, 0xEB, 0xFB))
    dessin.ellipse((0, 0, grand - 1, grand - 1), outline=(0x1A, 0x56, 0xDB), width=facteur * 3)

    # Initiales centrées
    taille = int(grand * 0.34)
    police = None
    for nom in ("calibrib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf", "seguisb.ttf"):
        try:
            police = ImageFont.truetype(nom, taille)
            break
        except OSError:
            continue
    if police is None:
        police = ImageFont.load_default()

    x0, y0, x1, y1 = dessin.textbbox((0, 0), initiales, font=police)
    dessin.text(
        ((grand - (x1 - x0)) / 2 - x0, (grand - (y1 - y0)) / 2 - y0),
        initiales,
        font=police,
        fill=(0x1A, 0x56, 0xDB),
    )

    img.resize((TAILLE_RENDU_PX,) * 2, Image.LANCZOS).save(destination, "PNG")


def preparer_medaillon(membre: dict) -> tuple[Path, bool]:
    """
    Prépare le médaillon d'un membre.

    Returns:
        (chemin de l'image prête, True si la vraie photo a été trouvée)
    """
    BUILD_DIR.mkdir(exist_ok=True)
    sortie = BUILD_DIR / f"{membre['fichier']}_rond.png"

    for ext in (".jpg", ".jpeg", ".png", ".JPG", ".JPEG", ".PNG", ".webp"):
        source = PHOTOS_DIR / f"{membre['fichier']}{ext}"
        if source.exists():
            medaillon_depuis_photo(source, sortie)
            return sortie, True

    medaillon_provisoire(membre["initiales"], sortie)
    return sortie, False


# =============================================================================
# OUTILS DE MISE EN FORME
# =============================================================================

def para(doc_ou_cell, texte="", taille=11, gras=False, couleur=ENCRE,
         alignement=WD_ALIGN_PARAGRAPH.LEFT, avant=0, apres=6, interligne=1.15):
    """Ajoute un paragraphe entièrement formaté et le retourne."""
    p = doc_ou_cell.add_paragraph()
    p.alignment = alignement
    pf = p.paragraph_format
    pf.space_before = Pt(avant)
    pf.space_after = Pt(apres)
    pf.line_spacing = interligne
    if texte:
        run = p.add_run(texte)
        run.font.name = POLICE
        run.font.size = Pt(taille)
        run.font.bold = gras
        run.font.color.rgb = couleur
    return p


def filet(paragraphe, couleur="1A56DB", epaisseur=12):
    """Trace un filet horizontal sous un paragraphe (bordure basse)."""
    pPr = paragraphe._p.get_or_add_pPr()
    bordures = OxmlElement("w:pBdr")
    bas = OxmlElement("w:bottom")
    bas.set(qn("w:val"), "single")
    bas.set(qn("w:sz"), str(epaisseur))
    bas.set(qn("w:space"), "4")
    bas.set(qn("w:color"), couleur)
    bordures.append(bas)
    pPr.append(bordures)


def fond_cellule(cellule, couleur_hex):
    """Applique une couleur de fond à une cellule de tableau."""
    tcPr = cellule._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), couleur_hex)
    tcPr.append(shd)


def sans_bordures(table):
    """Retire toutes les bordures d'un tableau utilisé pour la mise en page."""
    tblPr = table._tbl.tblPr
    borders = OxmlElement("w:tblBorders")
    for cote in ("top", "left", "bottom", "right", "insideH", "insideV"):
        el = OxmlElement(f"w:{cote}")
        el.set(qn("w:val"), "none")
        el.set(qn("w:sz"), "0")
        borders.append(el)
    tblPr.append(borders)


def marges_cellules(table, haut=0, bas=0, gauche=0, droite=0):
    """Définit les marges internes des cellules, en dixièmes de millimètre."""
    tblPr = table._tbl.tblPr
    marges = OxmlElement("w:tblCellMar")
    for cote, valeur in (("top", haut), ("bottom", bas), ("left", gauche), ("right", droite)):
        el = OxmlElement(f"w:{cote}")
        el.set(qn("w:w"), str(valeur))
        el.set(qn("w:type"), "dxa")
        marges.append(el)
    tblPr.append(marges)


# =============================================================================
# CONSTRUCTION DU DOCUMENT
# =============================================================================

def construire() -> list:
    """Assemble le document et le sauvegarde. Retourne les photos manquantes."""
    doc = Document()

    # --- Mise en page A4, marges resserrées -----------------------------------
    section = doc.sections[0]
    section.page_width = Cm(21.0)
    section.page_height = Cm(29.7)
    for attr, valeur in (
        ("top_margin", 1.8), ("bottom_margin", 1.8),
        ("left_margin", 2.0), ("right_margin", 2.0),
    ):
        setattr(section, attr, Cm(valeur))

    largeur_utile = Cm(21.0 - 4.0)

    # Police par défaut du document
    normal = doc.styles["Normal"]
    normal.font.name = POLICE
    normal.font.size = Pt(11)
    normal.font.color.rgb = ENCRE

    # =========================================================================
    # EN-TÊTE
    # =========================================================================
    para(doc, "PROJET ÉTUDIANT · BUT INFORMATIQUE 3ᵉ ANNÉE", taille=8.5,
         gras=True, couleur=GRIS, apres=2)

    titre = para(doc, "Vision360", taille=32, gras=True, couleur=BLEU, apres=2)
    titre.runs[0].font.name = POLICE

    para(doc, "L'intelligence artificielle au service de l'autonomie",
         taille=13.5, couleur=ENCRE, apres=10)

    p = para(doc, apres=12)
    filet(p)

    # =========================================================================
    # RÉSUMÉ DU PROJET
    # =========================================================================
    para(doc, "Le projet", taille=15, gras=True, couleur=BLEU, avant=4, apres=6)

    para(doc,
         "Faire ses courses, passer en caisse, traverser une rue : autant de gestes "
         "ordinaires qui deviennent des obstacles quotidiens pour les 1,7 million de "
         "personnes atteintes d'un trouble de la vision en France, et pour celles dont "
         "la mobilité est réduite. Vision360 est un écosystème d'agents d'intelligence "
         "artificielle conçu pour les accompagner dans ces situations précises.",
         apres=8)

    para(doc,
         "Le principe tient en une phrase : une information générique n'aide personne. "
         "Signaler la présence d'un pot de pâte à tartiner dans un rayon n'a aucune "
         "valeur. Annoncer qu'il contient des fruits à coque alors que l'utilisateur est "
         "allergique à l'arachide, et indiquer où trouver l'alternative sur la deuxième "
         "étagère, en a une. Tout le système est construit autour de cette exigence de "
         "personnalisation.",
         apres=8)

    para(doc,
         "Concrètement, l'utilisateur prend une photo. Un modèle de vision la décrit en "
         "texte ; un second modèle, spécialisé dans le langage, croise cette description "
         "avec son profil — allergies, pathologies, goûts — pour produire un résumé, les "
         "risques identifiés et les actions recommandées. Le tout est lu à voix haute. "
         "L'application se pilote entièrement à la voix, sans jamais avoir à regarder "
         "l'écran.",
         apres=8)

    para(doc,
         "Au-delà de la description de scène, Vision360 identifie un produit par son "
         "code-barres en s'appuyant sur une base alimentaire certifiée, assiste le "
         "passage en caisse de bout en bout — vérifier que rien n'a été oublié sur le "
         "tapis, contrôler le ticket — et guide un déplacement piéton par des "
         "instructions vocales pas à pas.",
         apres=12)

    # =========================================================================
    # CHIFFRES CLÉS
    # =========================================================================
    chiffres = [
        ("4", "applications", "mobile, web,\nAPI, prototype"),
        ("10 600", "lignes de code", "Python, Dart,\nTypeScript, SQL"),
        ("34", "tests unitaires", "cas limites\net erreurs"),
        ("1", "commande", "pour déployer\ntoute la stack"),
    ]

    t = doc.add_table(rows=1, cols=len(chiffres))
    t.autofit = False
    sans_bordures(t)
    marges_cellules(t, haut=120, bas=120, gauche=120, droite=120)
    largeur_col = Cm((21.0 - 4.0) / len(chiffres))

    for cellule, (valeur, libelle, detail) in zip(t.rows[0].cells, chiffres):
        cellule.width = largeur_col
        fond_cellule(cellule, "F1F5FD")
        cellule.vertical_alignment = WD_ALIGN_VERTICAL.CENTER

        cellule.paragraphs[0]._p.getparent().remove(cellule.paragraphs[0]._p)
        para(cellule, valeur, taille=20, gras=True, couleur=BLEU,
             alignement=WD_ALIGN_PARAGRAPH.CENTER, apres=0, interligne=1.0)
        para(cellule, libelle, taille=9.5, gras=True, couleur=ENCRE,
             alignement=WD_ALIGN_PARAGRAPH.CENTER, apres=2, interligne=1.0)
        for ligne in detail.split("\n"):
            para(cellule, ligne, taille=8, couleur=GRIS,
                 alignement=WD_ALIGN_PARAGRAPH.CENTER, apres=0, interligne=1.0)

    para(doc, apres=10)

    # =========================================================================
    # TECHNOLOGIES
    # =========================================================================
    para(doc, "Les technologies", taille=15, gras=True, couleur=BLEU, avant=2, apres=6)

    para(doc,
         "Une API FastAPI en Python orchestre l'ensemble et reste le seul dépositaire "
         "des clés d'accès aux services d'intelligence artificielle : aucun secret ne "
         "figure dans les applications installées chez l'utilisateur. Les données "
         "personnelles sont stockées dans PostgreSQL, l'application mobile est "
         "développée en Flutter, l'interface web en Next.js, et un prototype de "
         "détection d'obstacles fonctionne directement dans le navigateur grâce à "
         "TensorFlow.js. L'ensemble se déploie en une seule commande avec Docker "
         "Compose.",
         apres=8)

    para(doc,
         "Un choix d'architecture mérite d'être souligné : plutôt qu'un modèle unique, "
         "deux modèles spécialisés sont enchaînés. Le premier voit, le second conseille. "
         "Cette séparation améliore la qualité du raisonnement, réduit le coût, rend "
         "chaque étape auditable — et surtout, elle évite d'envoyer la moindre donnée "
         "médicale au service d'analyse d'images.",
         apres=12)

    # =========================================================================
    # ÉQUIPE
    # =========================================================================
    # Saut de page : sans lui, le titre « L'équipe » reste orphelin en bas de
    # la première page, séparé des fiches qu'il introduit.
    doc.add_page_break()

    para(doc, "L'équipe", taille=15, gras=True, couleur=BLEU, avant=0, apres=3)
    para(doc,
         "Trois étudiants de troisième année de BUT Informatique, réunis autour d'un "
         "projet qu'ils ont voulu utile avant d'être démonstratif.",
         taille=10.5, couleur=GRIS, apres=10)

    manquantes = []

    for index, membre in enumerate(EQUIPE):
        image, trouvee = preparer_medaillon(membre)
        if not trouvee:
            manquantes.append(f"photos/{membre['fichier']}.jpg")

        fiche = doc.add_table(rows=1, cols=2)
        fiche.autofit = False
        sans_bordures(fiche)
        marges_cellules(fiche, haut=0, bas=0, gauche=0, droite=160)

        col_photo, col_texte = fiche.rows[0].cells
        col_photo.width = Cm(DIAMETRE_PHOTO_CM + 0.5)
        col_texte.width = largeur_utile - Cm(DIAMETRE_PHOTO_CM + 0.5)
        col_photo.vertical_alignment = WD_ALIGN_VERTICAL.TOP

        # Médaillon
        p_photo = col_photo.paragraphs[0]
        p_photo.alignment = WD_ALIGN_PARAGRAPH.LEFT
        p_photo.paragraph_format.space_after = Pt(0)
        p_photo.add_run().add_picture(str(image), width=Cm(DIAMETRE_PHOTO_CM))

        # Identité et biographie
        col_texte.paragraphs[0]._p.getparent().remove(col_texte.paragraphs[0]._p)
        para(col_texte, membre["nom"], taille=13.5, gras=True, couleur=ENCRE,
             apres=1, interligne=1.0)
        para(col_texte, membre["role"], taille=10, gras=True, couleur=BLEU,
             apres=5, interligne=1.0)
        para(col_texte, membre["bio"], taille=10, couleur=ENCRE,
             apres=0, alignement=WD_ALIGN_PARAGRAPH.JUSTIFY, interligne=1.13)

        # Espace entre les fiches
        if index < len(EQUIPE) - 1:
            para(doc, taille=5, apres=8)

    # =========================================================================
    # PIED DE PAGE
    # =========================================================================
    p = para(doc, avant=14, apres=6)
    filet(p, couleur="CBD5E1", epaisseur=6)

    para(doc,
         "SAE Vision360 · BUT Informatique 3ᵉ année, semestres 5 et 6 · Parcours A et C · "
         "Projet open source sous licence MIT",
         taille=8.5, couleur=GRIS, alignement=WD_ALIGN_PARAGRAPH.CENTER, apres=0)

    try:
        doc.save(OUTPUT)
    except PermissionError:
        sys.exit(
            f"\nERREUR : impossible d'ecrire {OUTPUT.name}.\n"
            "Le fichier est ouvert dans Word, qui le verrouille.\n"
            "Fermer le document puis relancer :  python generer_page.py\n"
        )

    return manquantes


# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if __name__ == "__main__":
    PHOTOS_DIR.mkdir(exist_ok=True)
    absentes = construire()

    print(f"Document généré : {OUTPUT.name}")
    print(f"  {OUTPUT}")

    if absentes:
        print()
        print("  /!\\ Photos manquantes - medaillons provisoires inseres a la place :")
        for chemin in absentes:
            print(f"       {chemin}")
        print()
        print("     Déposer les images dans le dossier photos/ sous ces noms,")
        print("     puis relancer :  python generer_page.py")
    else:
        print("  Les trois photos ont été intégrées.")
