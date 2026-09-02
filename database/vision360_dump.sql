--
-- =============================================================================
-- Vision360 - EXPORT DUMP COMPLET DE LA BASE DE DONNÉES
-- =============================================================================
-- Base       : vision360
-- SGBD       : PostgreSQL 16 (image postgres:16-alpine)
-- Format     : plain text (SQL), généré par pg_dump
-- Commande   : pg_dump -U postgres -d vision360 --no-owner --no-privileges
-- Contenu    : structure complète + données
--
-- -----------------------------------------------------------------------------
-- ÉTAT DES DONNÉES : BASE VIDE (0 ligne dans les 7 tables)
-- -----------------------------------------------------------------------------
-- Ce n'est pas une erreur d'export. L'application Vision360 ne crée aucun
-- utilisateur par défaut : toutes les tables sont alimentées uniquement par
-- l'inscription d'un utilisateur réel (POST /api/users/register), puis en
-- cascade par ses actions (profil, allergies, préférences, interactions).
--
-- Aucun compte n'ayant été créé sur l'environnement exporté, les blocs COPY
-- ci-dessous sont volontairement vides. La STRUCTURE, elle, est complète et
-- restaurable telle quelle.
--
-- Pour obtenir une base peuplée à des fins de démonstration ou de correction,
-- jouer le jeu d'essai fourni : database/02_seed_demo.sql
-- -----------------------------------------------------------------------------
--
-- RESTAURATION :
--   createdb -U postgres vision360
--   psql -U postgres -d vision360 -f vision360_dump.sql
--
-- Ou dans Docker :
--   docker compose exec -T postgres psql -U postgres -d vision360 < vision360_dump.sql
--
-- Voir database/README.md pour la procédure détaillée.
-- =============================================================================
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- =============================================================================
-- TYPES ÉNUMÉRÉS
-- =============================================================================
--

--
-- Name: mobilitytype; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.mobilitytype AS ENUM (
    'FAUTEUIL',
    'CANNE',
    'DEAMBULATEUR',
    'MARCHE'
);


--
-- Name: visionlevel; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.visionlevel AS ENUM (
    'NORMAL',
    'FAIBLE',
    'MALVOYANT',
    'NON_VOYANT'
);


--
-- Name: severity; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.severity AS ENUM (
    'FAIBLE',
    'MODERE',
    'SEVERE',
    'MORTEL'
);


--
-- Name: preferencecategory; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.preferencecategory AS ENUM (
    'PRODUIT',
    'MARQUE',
    'RECETTE',
    'INGREDIENT',
    'LIEU',
    'TEXTURE',
    'CUISINE'
);


--
-- Name: sentiment; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sentiment AS ENUM (
    'ADORE',
    'AIME',
    'NEUTRE',
    'NAIME_PAS',
    'DETESTE',
    'INTERDIT'
);


--
-- Name: preferencesource; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.preferencesource AS ENUM (
    'USER_EXPLICIT',
    'LLM_INFERRED',
    'BEHAVIOR',
    'MEDICAL'
);


--
-- Name: contexttype; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contexttype AS ENUM (
    'SUPERMARCHE',
    'RESTAURANT',
    'NAVIGATION',
    'MAISON',
    'TRANSPORT'
);


--
-- =============================================================================
-- TABLES
-- =============================================================================
--

--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    is_active boolean,
    created_at timestamp without time zone,
    last_login timestamp without time zone
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    name character varying(100),
    mobility public.mobilitytype,
    vision_level public.visionlevel,
    tts_enabled boolean,
    tts_speed double precision,
    tts_voice character varying(50),
    high_contrast boolean,
    large_text boolean,
    language character varying(10),
    updated_at timestamp without time zone
);


--
-- Name: allergies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allergies (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    allergen character varying(100) NOT NULL,
    severity public.severity,
    confirmed boolean,
    source public.preferencesource,
    notes text,
    created_at timestamp without time zone
);


--
-- Name: conditions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conditions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    condition character varying(100) NOT NULL,
    severity public.severity,
    dietary_impact text,
    medications text,
    created_at timestamp without time zone
);


--
-- Name: preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.preferences (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    category public.preferencecategory NOT NULL,
    item_name character varying(255) NOT NULL,
    normalized_name character varying(255),
    sentiment public.sentiment NOT NULL,
    reason text,
    source public.preferencesource,
    confidence double precision,
    times_mentioned integer,
    created_at timestamp without time zone,
    last_mentioned timestamp without time zone
);


--
-- Name: interactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interactions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    session_id uuid,
    context public.contexttype,
    location character varying(255),
    image_hash character varying(64),
    image_url character varying(500),
    user_query text,
    gemini_description text,
    groq_response json,
    recommendations json,
    extracted_preferences json,
    created_at timestamp without time zone
);


--
-- Name: feedback; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feedback (
    id uuid NOT NULL,
    interaction_id uuid NOT NULL,
    user_id uuid NOT NULL,
    rating integer,
    was_helpful boolean,
    was_accurate boolean,
    feedback_text text,
    preference_extracted json,
    created_at timestamp without time zone
);


--
-- =============================================================================
-- DONNÉES
-- =============================================================================
-- Les blocs COPY sont vides : aucun utilisateur n'est enregistré sur
-- l'environnement exporté (voir l'en-tête de ce fichier).
-- =============================================================================
--

--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, email, password_hash, is_active, created_at, last_login) FROM stdin;
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.profiles (id, user_id, name, mobility, vision_level, tts_enabled, tts_speed, tts_voice, high_contrast, large_text, language, updated_at) FROM stdin;
\.


--
-- Data for Name: allergies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allergies (id, user_id, allergen, severity, confirmed, source, notes, created_at) FROM stdin;
\.


--
-- Data for Name: conditions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.conditions (id, user_id, condition, severity, dietary_impact, medications, created_at) FROM stdin;
\.


--
-- Data for Name: preferences; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.preferences (id, user_id, category, item_name, normalized_name, sentiment, reason, source, confidence, times_mentioned, created_at, last_mentioned) FROM stdin;
\.


--
-- Data for Name: interactions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.interactions (id, user_id, session_id, context, location, image_hash, image_url, user_query, gemini_description, groq_response, recommendations, extracted_preferences, created_at) FROM stdin;
\.


--
-- Data for Name: feedback; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.feedback (id, interaction_id, user_id, rating, was_helpful, was_accurate, feedback_text, preference_extracted, created_at) FROM stdin;
\.


--
-- =============================================================================
-- CONTRAINTES
-- =============================================================================
--

--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: allergies allergies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergies
    ADD CONSTRAINT allergies_pkey PRIMARY KEY (id);


--
-- Name: conditions conditions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conditions
    ADD CONSTRAINT conditions_pkey PRIMARY KEY (id);


--
-- Name: preferences preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preferences
    ADD CONSTRAINT preferences_pkey PRIMARY KEY (id);


--
-- Name: interactions interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions
    ADD CONSTRAINT interactions_pkey PRIMARY KEY (id);


--
-- Name: feedback feedback_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedback
    ADD CONSTRAINT feedback_pkey PRIMARY KEY (id);


--
-- =============================================================================
-- INDEX
-- =============================================================================
--

--
-- Name: ix_users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_users_email ON public.users USING btree (email);


--
-- Name: ix_profiles_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_profiles_user_id ON public.profiles USING btree (user_id);


--
-- Name: ix_allergies_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_allergies_user_id ON public.allergies USING btree (user_id);


--
-- Name: ix_conditions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_conditions_user_id ON public.conditions USING btree (user_id);


--
-- Name: ix_preferences_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_preferences_user_id ON public.preferences USING btree (user_id);


--
-- Name: ix_preferences_user_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_preferences_user_category ON public.preferences USING btree (user_id, category);


--
-- Name: ix_interactions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_interactions_user_id ON public.interactions USING btree (user_id);


--
-- Name: ix_interactions_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_interactions_user_created ON public.interactions USING btree (user_id, created_at DESC);


--
-- Name: ix_feedback_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_feedback_user_id ON public.feedback USING btree (user_id);


--
-- =============================================================================
-- CLÉS ÉTRANGÈRES
-- =============================================================================
--

--
-- Name: profiles profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: allergies allergies_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allergies
    ADD CONSTRAINT allergies_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: conditions conditions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conditions
    ADD CONSTRAINT conditions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: preferences preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preferences
    ADD CONSTRAINT preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: interactions interactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interactions
    ADD CONSTRAINT interactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: feedback feedback_interaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedback
    ADD CONSTRAINT feedback_interaction_id_fkey FOREIGN KEY (interaction_id) REFERENCES public.interactions(id);


--
-- Name: feedback feedback_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedback
    ADD CONSTRAINT feedback_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--
