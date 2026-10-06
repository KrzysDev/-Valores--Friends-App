# Valores

### Swipe on who people are, not how they look.

Every dating or friendship app I've used starts the same way: a photo, and a few words. In half a second you've already decided whether you like someone. **Valores flips that.** There are no profile photos. Instead, you meet people through their *aesthetic board*: a personal, visual map of what they believe in, what they love, what they read, watch and do, and how they see life.

You get to know the person first. Everything else can come later.

> **Status:** early development. The prototype is already built and it is being polished.
> **Built for:** Creator Colosseum Startup Competition
> **Author:** Krzysztof Sokołowski
> **Design doc:** [docs/design.md](docs/design.md)

---

## Questions and Answers for the Creator Colosseum Startup Competition.

### 1. What is your startup idea?

Valores is a mobile app for making friends based on values and interests instead of looks. Each user builds a personal **values board**, a diagram of their life in essence, and other people discover them by swiping through short intro cards and opening their boards. When two people both show interest, they can start talking.

Friendship is the goal. Dating can happen naturally, but it **IS NOT** what the app is built for.

### 2. What problem are you solving, and why does it matter?

**The problem.** Photo-first apps make appearance the gatekeeper. Before you learn anything about someone's character, humour or values, you've already judged them by how they look. This makes it easy to connect with people who are attractive to you but have very little in common with you.

**Why I care.** This comes from my own experience. More than once I got into relationships because I was physically attracted to someone, not because we shared the same values. I've also noticed that most people say they'd rather get to know someone's character than their photos, yet the tools they use push them the other way.

**Why it matters.** Loneliness and shallow first impressions are real problems, especially for young people who are moving to a new school, city or stage of life and want to build a circle of people who actually get them. A tool that starts with substance can make those first connections more meaningful.

## 3. What is your solution, and how does it work?

**The "values board".** Users create a board made of blocks such as values, beliefs, books, films, free-time activities, and things they love. They choose what to show and decorate the board in their own style. There are no photo uploads, only text and a closed set of images.

**Discovering people.**
1. You see the name, age and blocks on the board which contain values of some person.
2. If you think you have a lot in common, you swipe right if not you swipe left.
3. The rest is pretty intuitive - if both of you swipe each other right, then you get a match.

**What makes it different.** Other apps hide or blur photos and reveal them later (S'More, BlindLove, Lovetastic and others). Valores goes further: there are no photos, and the thing you swipe on is a rich, personal board instead of a short bio. The board *is* the profile.

## 4. Execution and business plan

**Phase 1: prototype (first month).** Board editor and browsing of boards with a few example profiles, to test whether people understand and enjoy the core idea. Flutter app, Python backend.

**Phase 2: real product (next ~90 days).** Accounts, swiping, matching and chat. Safety tools (report, block, delete account). Consent flow for sensitive information.

**Phase 3: pilot (~180 days).** Launch in one small community in one city (for example a single school, university or interest group) and aim for about 100 real users before expanding. A small, dense group makes the app useful much faster than a scattered one.

**Business model.** Free at the start, because I need users before revenue. Later: optional premium features, a daily swipe limit for free users, and occasional ads. I will only add these once there is a real community, since limits and ads too early would push people away.

**Costs.** At the beginning close to zero (free tiers and serverless hosting). At larger scale I estimate the backend at around 100 PLN per month.

**Main risks and how I'll handle them.**
- *Cold start (getting the first users):* start with one tight community instead of a whole city.
- *Boards can be a performance:* keep the board quick and simple to fill in so it feels honest.
- *Safety and age:* match people only within similar age bands, ask for date of birth, offer report and block, and no photo uploads.
- *Sensitive data:* beliefs such as religion or politics are optional, shared only with explicit consent, and can be deleted at any time (GDPR-aware design).

## 5. Who are your target users and market?

**Primary users:** people aged roughly 16-30 who want to meet new friends through shared values and interests, especially those starting somewhere new (a new school, university or city) or who feel photo-first apps are too superficial.

**Where I'd start:** one city, one small community, then expand.

**Competition.** Apps that de-emphasise photos already exist, and some hide them until you chat or both agree to reveal. Valores' difference is the **value board as the main unit of discovery**, and its focus on friendship built on values.

## 6. Technical details

| Part | Technology |
|------|-----------|
| Mobile app | Flutter (Android first, iOS later) |
| Backend | Python (FastAPI) |
| Database | PostgreSQL |
| Hosting | Google Cloud (serverless, EU region) |

Architecture, data model and key decisions are in [docs/design.md](docs/design.md).

## 7. Current status and roadmap

- [x] Idea, research, design document
- [ ] Prototype: board editor + browsing boards
- [ ] Accounts, swiping, matching
- [ ] Chat
- [ ] Safety and consent features
- [ ] Pilot in one community

## 8. Run it locally

1. clone the repository
```bash
git clone https://github.com/KrzysDev/-Valores--Friends-App.git
```

2. locate the "backend" directory. 
```
    src/valores/backend
```

3. download the python dependecies
```
uv sync 
```

4. run the fastapi server like this:
```bash
    uv run uvicorn src.valores.backend.main:app --reload --host 0000 --port 8000
```

5. make sure flutter is installed on your device, and install the dependencies.

6. locate the frontend direcotry. 
```
    src/valores/frontend/valores
```

7. plug your android / ios mobile device into your computer with USB cable, make sure debugging mode on it is enabled then run the frontend with following command:
```
flutter run
```

8. If you have done everything correctly app should be run on mobile device.

9. You are all set. Enjoy!

---

"More than your looks"

---

Copyright © Krzysztof Sokołowski 2026