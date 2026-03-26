# 📊 Datasets Vision360

Ce dossier contient les ressources pour l'entraînement de modèles de détection d'objets personnalisés pour le projet Vision360.

## Objectif

Entraîner un modèle YOLO spécialisé pour la détection d'objets pertinents pour les personnes à mobilité réduite, notamment :
- Produits de supermarché (pour l'aide aux courses)
- Obstacles urbains (pour la navigation)
- Éléments de restaurant (pour l'aide à table)

## Structure

```
datasets/
├── data-template.yaml    # Configuration YOLO avec les classes
├── README.md             # Ce fichier
└── [données]             # Images et labels (non versionnés)
    ├── images/
    │   ├── train/
    │   └── val/
    └── labels/
        ├── train/
        └── val/
```

## Format YOLO

### Structure des fichiers

```
dataset/
├── images/
│   ├── train/
│   │   ├── image001.jpg
│   │   └── image002.jpg
│   └── val/
│       └── image003.jpg
└── labels/
    ├── train/
    │   ├── image001.txt
    │   └── image002.txt
    └── val/
        └── image003.txt
```

### Format des labels

Chaque fichier `.txt` contient une ligne par objet :
```
<class_id> <x_center> <y_center> <width> <height>
```

Où :
- `class_id` : Index de la classe (0, 1, 2, ...)
- `x_center`, `y_center` : Centre de la boîte (normalisé 0-1)
- `width`, `height` : Dimensions de la boîte (normalisé 0-1)

**Exemple** :
```
0 0.5 0.5 0.2 0.3
14 0.25 0.75 0.1 0.15
```

## Classes actuelles

Le fichier `data-template.yaml` définit 44 classes de produits :

| ID | Classe | Description |
|----|--------|-------------|
| 0 | bakery | Produits de boulangerie |
| 1 | biscuits | Biscuits |
| 2 | bombons | Bonbons |
| 3 | canned | Conserves |
| 4 | cereals | Céréales |
| 5 | cheese | Fromage |
| 6 | chips | Chips |
| 7 | choco | Chocolat |
| 8 | coffee | Café |
| 9 | creme | Crème |
| ... | ... | ... |
| 43 | product | Produit générique |

## Scripts disponibles

### prepare_yolo_dataset.py

Convertit les annotations COCO en format YOLO.

```bash
python scripts/prepare_yolo_dataset.py \
  --annotations path/to/annotations.json \
  --images-dir path/to/images \
  --output-dir datasets/labels/train \
  --classes bakery biscuits chips \
  --names-file datasets/names.txt
```

**Arguments** :
| Argument | Description |
|----------|-------------|
| `--annotations` | Fichier JSON d'annotations COCO |
| `--images-dir` | Dossier contenant les images |
| `--output-dir` | Dossier de sortie pour les labels YOLO |
| `--classes` | Liste des classes à conserver (optionnel) |
| `--names-file` | Fichier de sortie avec la liste des classes |

### merge_datasets.py

Fusionne plusieurs datasets YOLO en un seul.

```bash
python scripts/merge_datasets.py \
  --input-dirs dataset1 dataset2 \
  --output-dir merged_dataset
```

### generate_data_yaml.py

Génère un fichier `data.yaml` pour l'entraînement YOLO.

```bash
python scripts/generate_data_yaml.py \
  --dataset-dir path/to/dataset \
  --output data.yaml
```

## Entraînement YOLO

### Avec Ultralytics YOLOv8

```bash
# Installer ultralytics
pip install ultralytics

# Entraîner
yolo train model=yolov8n.pt data=datasets/data-template.yaml epochs=100 imgsz=640
```

### Configuration recommandée

```yaml
# data.yaml
path: /chemin/vers/datasets
train: images/train
val: images/val

names:
  0: bakery
  1: biscuits
  # ...
```

## Sources de données

### Datasets publics utilisables

| Dataset | Description | Lien |
|---------|-------------|------|
| Grocery Store | Produits de supermarché | [Kaggle](https://www.kaggle.com/datasets/lxl198751/grocerystoredataset) |
| SKU-110K | Produits en rayon | [GitHub](https://github.com/eg4000/SKU110K_CVPR19) |
| COCO | Objets généraux | [cocodataset.org](https://cocodataset.org) |

### Collecte personnalisée

Le POC web permet d'exporter des samples annotés :
1. Lancer le POC (`poc-web/index.html`)
2. Détecter des objets
3. Cliquer "Capture Sample" pour télécharger PNG + JSON

## Bonnes pratiques

### Qualité des données
- Minimum 100 images par classe
- Variation d'éclairage et d'angles
- Balance entre les classes

### Augmentation de données
```python
# Exemple avec Albumentations
import albumentations as A

transform = A.Compose([
    A.RandomBrightnessContrast(p=0.5),
    A.HorizontalFlip(p=0.5),
    A.Rotate(limit=15, p=0.5),
], bbox_params=A.BboxParams(format='yolo'))
```

### Validation
- 80% train / 20% val typique
- Éviter les images similaires entre train et val
- Valider sur différents contextes (magasins différents)
