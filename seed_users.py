"""
Skrypt do generowania realistycznych profili uzytkownikow i tablic estetycznych (Valores).
Tworzy uzytkownikow bezposrednio przez Admin API Supabase (z potwierdzonym adresem email),
wpisuje wiek do user_profiles oraz tworzy proceduralnie wygenerowana tablice (board)
z roznymi zainteresowaniami, wartosciami, cytatami i stylami.

Uruchomienie:
    python seed_users.py [--count 12] [--clean]
"""

import argparse
import os
import random
import sys
from dotenv import find_dotenv, load_dotenv
from supabase import create_client

load_dotenv(find_dotenv())

SUPABASE_URL = os.getenv("SUPABASE_URL")
SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SERVICE_KEY:
    print("BLAD: Brak SUPABASE_URL lub SUPABASE_SERVICE_ROLE_KEY w pliku .env!")
    sys.exit(1)

admin = create_client(SUPABASE_URL, SERVICE_KEY)

# ────────────────── DANE DO GENEROWANIA PROCEDURALNEGO ──────────────────

PERSONAS = [
    {
        "name": "Maja",
        "email_prefix": "maja",
        "age_range": (18, 22),
        "vibe": "artystyczna dusza, analogowa fotografia, ambient, kawiarnie",
        "fav_categories": ["Wartości", "Hobby", "Muzyka", "Książki", "Filmy & Seriale", "Motto"]
    },
    {
        "name": "Kuba",
        "email_prefix": "kuba",
        "age_range": (20, 25),
        "vibe": "technologia, góry, minimalizm, sci-fi i podróże z plecakiem",
        "fav_categories": ["Wartości", "Hobby", "Podróże", "Książki", "Przekonania", "Wolny czas"]
    },
    {
        "name": "Zofia",
        "email_prefix": "zofia",
        "age_range": (19, 24),
        "vibe": "literatura piękna, vintage, ogrodnictwo balkonowe, herbaty",
        "fav_categories": ["Książki", "Wartości", "Jak się czuję", "Jedzenie", "Motto", "Wolny czas"]
    },
    {
        "name": "Tomasz",
        "email_prefix": "tomek",
        "age_range": (22, 28),
        "vibe": "muzyk, produkcja audio, gitara, psychologia, nocne spacery",
        "fav_categories": ["Muzyka", "Wartości", "Przekonania", "Filmy & Seriale", "Wolny czas"]
    },
    {
        "name": "Lena",
        "email_prefix": "lena",
        "age_range": (17, 21),
        "vibe": "architektura, bieganie, joga, skandynawski design, zrównoważony rozwój",
        "fav_categories": ["Wartości", "Cele życiowe", "Hobby", "Podróże", "Motto"]
    },
    {
        "name": "Michał",
        "email_prefix": "michal",
        "age_range": (21, 26),
        "vibe": "gry planszowe, astronomia, kino autorskie, parzenie kawy alternatywami",
        "fav_categories": ["Hobby", "Filmy & Seriale", "Jedzenie", "Przekonania", "Książki"]
    },
    {
        "name": "Alicja",
        "email_prefix": "alicja",
        "age_range": (18, 23),
        "vibe": "poezja, teatr, ochrona praw zwierząt, winyle i retro plakaty",
        "fav_categories": ["Wartości", "Muzyka", "Książki", "Przekonania", "Jak się czuję"]
    },
    {
        "name": "Piotr",
        "email_prefix": "piotr",
        "age_range": (23, 29),
        "vibe": "rower gravelowy, podcasty popularnonaukowe, gotowanie kuchni azjatyckiej",
        "fav_categories": ["Hobby", "Jedzenie", "Podróże", "Cele życiowe", "Motto"]
    }
]

BLOCK_TEMPLATES = {
    "Wartości": [
        "Autentyczność ponad idealny wizerunek. Wolę trudną prawdę i szczerość niż powierzchowne komplementy.",
        "Ciekawość świata i spokój ducha. Uczenie się czegoś nowego każdego dnia.",
        "Empatia i uważność na drugiego człowieka. Prawdziwa obecność w rozmowie.",
        "Wolność wyboru, niezależność myślenia i szacunek dla innych perspektyw.",
        "Lojalność i głębokie więzi. Wolę dwóch prawdziwych przyjaciół niż 100 powierzchownych znajomych."
    ],
    "Hobby": [
        "Fotografia analogowa (stary Zenit), szukanie światła w szarym mieście i wywoływanie klisz w domu.",
        "Rowerowe wyprawy za miasto bez mapy – po prostu skręcam tam, gdzie jest ładna droga.",
        "Ceramika i rzeźbienie w glinie. Brudne ręce i pełen spokój głowy.",
        "Długie sesje przy planszówkach strategicznych ze znajomymi i herbatą z imbirem.",
        "Joga o poranku i kalistenika w parku. Ruch daje mi czysty umysł."
    ],
    "Muzyka": [
        "Indie folk, Phoebe Bridgers, Bon Iver, akustyczne brzmienia i jesienny melancholijny nastrój.",
        "Elektronika, synthwave, ambient na nocne kodowanie i wędrówki po pustym mieście.",
        "Jazz z winyli, Miles Davis, Chet Baker i stare polskie płyty z lat 70.",
        "Post-rock i brzmienia gitarowe: Explosions in the Sky, Mogwai, Radiohead.",
        "Klasyczny rock lat 70/80 połączony z nowoczesnym soulem i R&B."
    ],
    "Książki": [
        "Haruki Murakami, Hermann Hesse, Reportaże Czarnego i książki o psychologii poznawczej.",
        "Sci-fi: Stanisław Lem, Philip K. Dick, Liu Cixin – uwielbiam pytania o granice człowieczeństwa.",
        "Literatura faktu, biografie ludzi z pasją oraz poezja Wisławy Szymborskiej.",
        "Filozofia stoicka (Marek Aureliusz) + literatura iberoamerykańska (Marquez, Borges)."
    ],
    "Filmy & Seriale": [
        "Kino A24, 'Past Lives', 'Aftersun', filmy Wesa Andersona i wszystko od Denisa Villeneuve.",
        "Klasyka kina noir, twórczość Finchera i klimatyczne skandynawskie kryminały.",
        "Animacje Studia Ghibli ('Spirited Away', 'Księżniczka Mononoke') za ich ciepło i detal.",
        "Filmy dokumentalne o przyrodzie i kosmosie oraz seriale z głębokimi postaciami."
    ],
    "Przekonania": [
        "Nie ma sensu gonić za cudzymi definicjami sukcesu. Najważniejsze to żyć w zgodzie ze sobą.",
        "Małe codzienne nawyki i życzliwość mają większy wpływ na świat niż wielkie deklaracje.",
        "Cisza w relacji nie musi być niezręczna – wspólne milczenie bywa najpiękniejszym porozumieniem.",
        "Każdy człowiek, którego spotykasz, wie coś, czego ty jeszcze nie wiesz."
    ],
    "Cele życiowe": [
        "Zbudować dom blisko lasu z dużą biblioteką i miejscem na pracownię twórczą.",
        "Przejechać rowerem wzdłuż wybrzeża Portugalii i spędzić miesiąc w małej wiosce w Japonii.",
        "Tworzyć rzeczy, które realnie pomagają ludziom i dają im poczucie, że nie są sami.",
        "Nauczyć się płynnie włoskiego i założyć mały ogród warzywny."
    ],
    "Motto": [
        "„Nie ma drogi do spokoju – to spokój jest drogą.”",
        "„Bądź ciekawy, a nie oceniający.” – Walt Whitman",
        "„Wszystko, co warte zrobienia, warte jest zrobienia powoli.”",
        "„Szukaj ludzi, przy których twoja dusza czuje się bezpiecznie.”"
    ],
    "Wolny czas": [
        "Spacer z psem bez telefonu, dobra kawa drippowa z Etiopii i gapienie się w chmury.",
        "Wieczorne gotowanie dla bliskich: domowy makaron, świeże zioła i dobre rozmowy.",
        "Lumpowanie w second-handach w poszukiwaniu unikalnych perełek i starych wydań książek.",
        "Nocne oglądanie gwiazd za miastem z ciepłym kocem i termosem."
    ],
    "Jak się czuję": [
        "W trybie wyciszenia i głębokiego skupienia. Czas na refleksję i zwolnienie tempa.",
        "Pełen energii na nowe znajomości, głodne rozmowy i spontaniczne wypady.",
        "Spokojna wdzięczność za drobne rzeczy i ciepłe jesienne popołudnia."
    ],
    "Podróże": [
        "Północna Norwegia pod namiotem, Lofoty o północy i surowe krajobrazy.",
        "Włoskie małe miasteczka w Toskanii, zapach pomidorów i leniwe popołudnia.",
        "Schroniska w Tatrach po zmroku, gdy turyści zeszli już w doliny."
    ],
    "Jedzenie": [
        "Prawdziwy ramen gotowany przez 12 godzin, chrupiący chleb na zakwasie z masłem.",
        "Kuchnia roślinna, ostre tajskie curry, świeże mango i matcha latte.",
        "Proste włoskie dania: cacio e pepe z dobrym pieprzem i oliwą."
    ]
}


def create_procedural_board(fav_categories):
    """Generuje losowy zestaw blokow dla tablicy w oparciu o preferencje persony."""
    chosen_categories = list(fav_categories)
    # Dodaj jeszcze 1-2 losowe kategorie
    all_categories = list(BLOCK_TEMPLATES.keys())
    extra = [c for c in all_categories if c not in chosen_categories]
    random.shuffle(extra)
    chosen_categories.extend(extra[:random.randint(1, 2)])

    blocks = []
    for cat in chosen_categories:
        options = BLOCK_TEMPLATES.get(cat, [])
        if not options:
            continue
        desc = random.choice(options)
        blocks.append({
            "name": cat,
            "description": desc
        })

    return {"blocks": blocks}


def seed(count: int = 8, clean: bool = False):
    print(f"Rozpoczynam generowanie {count} proceduralnych uzytkownikow...")

    created_users = []

    for i in range(count):
        persona = PERSONAS[i % len(PERSONAS)]
        suffix = random.randint(100, 999)
        email = f"{persona['email_prefix']}_{suffix}@valores-demo.pl"
        password = "Password123!"
        age = random.randint(persona["age_range"][0], persona["age_range"][1])

        print(f"\n[{i+1}/{count}] Tworzenie uzytkownika: {persona['name']} ({email}, wiek: {age})...")

        try:
            # 1. Stworz uzytkownika w Supabase Auth bez koniecznosci klikania w link weryfikacyjny
            auth_res = admin.auth.admin.create_user({
                "email": email,
                "password": password,
                "email_confirm": True,
                "user_metadata": {
                    "nickname": persona["name"],
                    "vibe": persona["vibe"]
                }
            })

            user = auth_res.user
            user_id = str(user.id)
            print(f"    [+] Auth utworzony, ID: {user_id}")

            # 2. Wpisz profil i wiek do user_profiles
            profile_data = {
                "user_id": user_id,
                "age": age
            }
            # Sprawdz czy tabela obsluguje nickname
            try:
                admin.table("user_profiles").insert({**profile_data, "nickname": persona["name"]}).execute()
            except Exception:
                admin.table("user_profiles").insert(profile_data).execute()
            print("    [+] user_profiles zapisany")

            # 3. Wygeneruj proceduralna tablice
            board_content = create_procedural_board(persona["fav_categories"])
            admin.table("boards").insert({
                "user_id": user_id,
                "board": board_content
            }).execute()
            print(f"    [+] Tablica zapisana ({len(board_content['blocks'])} kafelkow)")

            created_users.append({
                "name": persona["name"],
                "email": email,
                "password": password,
                "age": age,
                "id": user_id
            })

        except Exception as e:
            print(f"    [-] Blad przy tworzeniu {email}: {e}")

    print("\n" + "="*60)
    print(f"Pomyslnie utworzono {len(created_users)} uzytkownikow z tablicami!")
    print("="*60)
    print("Mozesz teraz uzyc ktoregos z nich do logowania w aplikacji:")
    for u in created_users[:4]:
        print(f"  * {u['name']} (lat {u['age']}): {u['email']}  | haslo: {u['password']}")
    print("="*60)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed Valores demo users and boards")
    parser.add_argument("--count", type=int, default=8, help="Liczba uzytkownikow do stworzenia (domyslnie: 8)")
    args = parser.parse_args()

    seed(count=args.count)
