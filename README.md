# fedora-config

Ma configuration de Fedora (base Fedora Workstation). Configure & met à jour Fedora

Versions testées : 40

**Ne fonctionne qu'avec Fedora Workstation disposant de l'environnement de bureau GNOME.**

# Guide

## Liste des fichiers

 **config-fedora.sh** : Script principal

 **packages.list** : Fichier de paquets à ajouter ou retirer du système

 **flatpak.list** : Fichier de flatpak à ajouter ou retirer du système

## Fonctionnement

Les fichiers mentionnés ci-dessus doivent être dans le même dossier.

Exécuter avec les droits de super-utilisateur le script principal :

    sudo ./config-fedora.sh

Celui-ci peut être exécuté plusieurs fois de suite. Si des étapes sont déjà configurées, elles ne le seront pas à nouveau. De fait, le script peut être utilisé pour : 

 - Réaliser la configuration initiale du système
 - Mettre à jour la configuration du système
 - Effectuer les mises à jour des paquets

Il est possible de faire uniquement une vérification des mises à jour (listing des paquets et flatpak à mettre à jour sans appliquer de modifications) via l'option check : 

    sudo ./config-fedora.sh check

## Opérations réalisées par le script

Le script lancé va effectuer les opérations suivantes : 

- Configurer le système DNF
    - Modifier la configuration DNF
    - Mettre à jour les paquets RPM
- Configurer le système Flatpak *(si activer)*
    - Installer les paquets requis pour Flatpak
    - Mettre à jour les paquets Flatpak + *Proposition de redémarrage du système si nécessaire*
- Ajouter les dépôts additionnels RPM / Flatpak
- Ajouter les composants utiles en provenance de RPM Fusion
- Ajouter ou Supprimer les paquets RPM paramétrés dans le fichier packages.list
- Ajouter ou Supprimer les paquets Flatpak paramétrés dans le fichier flatpak.list
- Personnaliser la configuration du système + *Proposition de redémarrage du système si nécessaire*

# Crédits

Ce script est basé sur [celui](https://github.com/aaaaadrien/fedora-config) d'Adrien de [linuxtricks.fr](https://www.linuxtricks.fr)