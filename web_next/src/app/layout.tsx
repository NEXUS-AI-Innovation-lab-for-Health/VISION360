/**
 * Layout racine de l'application Vision360 Web.
 *
 * Ce fichier définit la structure HTML de base et les métadonnées
 * pour toutes les pages de l'application Next.js.
 *
 * @module layout
 */

import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

// =============================================================================
// Configuration des polices
// =============================================================================

/**
 * Police sans-serif principale (Geist).
 * Utilisée pour le texte courant de l'interface.
 */
const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

/**
 * Police monospace (Geist Mono).
 * Utilisée pour l'affichage du code et des données JSON.
 */
const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

// =============================================================================
// Métadonnées SEO
// =============================================================================

/**
 * Métadonnées de l'application pour le SEO et les réseaux sociaux.
 */
export const metadata: Metadata = {
  title: "Vision360 - Assistance IA pour PMR",
  description:
    "Application web d'assistance intelligente pour les personnes à mobilité réduite. Analyse d'images, recommandations personnalisées et commandes vocales.",
};

// =============================================================================
// Composant Layout
// =============================================================================

/**
 * Layout racine de l'application.
 *
 * Encapsule toutes les pages avec la structure HTML de base,
 * les polices et les styles globaux.
 *
 * @param children - Contenu de la page à afficher
 * @returns Structure HTML complète de la page
 */
export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr">
      <body className={`${geistSans.variable} ${geistMono.variable}`}>
        {children}
      </body>
    </html>
  );
}
